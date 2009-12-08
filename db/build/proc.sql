SET client_min_messages TO warning;

/**
 * Drop all procedures and functions
 */
CREATE OR REPLACE FUNCTION dropAllProc ()
RETURNS void AS

$BODY$
DECLARE
	_func RECORD;

BEGIN
	FOR _func IN
		SELECT proname || '(' || OIDVECTORTYPES(proargtypes) || ')' AS name
		FROM pg_proc
		WHERE 1 = 1 --proowner = (select oid from pg_authid where rolname = 'tnd')
			AND SUBSTR(proname,1, 4) in ('sys_', 'rcp_', 'util', 'calc')
			and NOT proisagg
	LOOP
		EXECUTE 'DROP FUNCTION IF EXISTS ' || _func.name || ' CASCADE';
	END LOOP;
END;
$BODY$

LANGUAGE PLPGSQL;

SELECT dropAllProc();
DROP FUNCTION dropAllProc();



/**
 * Returns TaskId for given CalcId.
 */
CREATE OR REPLACE FUNCTION sys_calcGetTaskId (
	IN CalcIdIn INTEGER,
	OUT TaskIdOut INTEGER
) RETURNS INTEGER AS

$BODY$
	SELECT t.Id
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE tt.Code = 'Calculations'
		AND t.SubjectId = $1
	ORDER BY t.InsertTS DESC
	LIMIT 1;
$BODY$

LANGUAGE SQL
SECURITY DEFINER;



/**
	Returns table name for calculation tables
*/
CREATE OR REPLACE FUNCTION sys_getCalcTableName (
	IN ModeIn TEXT, -- 'in' or 'out' or 'obj' or '_<reportname>'.
	IN CalcIdIn INTEGER)
RETURNS TEXT AS

$BODY$
	SELECT 'z_calc_' || $2 /*CalcIdIn*/  || '_' || LOWER($1 /*ModeIn*/);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;




CREATE OR REPLACE FUNCTION sys_getCalcTmlId (
	CalcIdIn INTEGER,
	FieldNameIn TEXT
)
RETURNS INTEGER AS

$BODY$
	SELECT ct.Id
	FROM Calculations c
	JOIN CalcTemplates ct ON ct.CalcTypeId = c.CalcTypeId
	WHERE c.Id = $1
		AND LOWER(ct.FieldName) = LOWER($2);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;




/**
Marks that one iteration of the task is done.
*/
CREATE OR REPLACE FUNCTION sys_taskWorked(
	IN TaskIdIn INTEGER,
	IN ProgressRemIn TEXT,
	OUT DummyOut INTEGER
)
RETURNS INTEGER AS

$BODY$
BEGIN
	PERFORM sys_DebugMessage(ProgressRemIn);

	UPDATE Tasks
	SET State = 'IN_USE',
		Progress = COALESCE(Progress, 0) + 1,
		ProgressRem = ProgressRemIn,
		Revision = COALESCE(Revision, 0) + 1
	WHERE Id = TaskIdIn;
END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER;





/**
* Trim trailing zeros from a string.
*/
CREATE OR REPLACE FUNCTION sys_trimZero (
    NIn NUMERIC
)
RETURNS TEXT AS

$BODY$
DECLARE
	 _i INTEGER;
	 _L INTEGER;
	 _S2 TEXT;

BEGIN
/*
	_i := -1; -- Last letter;
	_S2 := StrIn;

	_L := LENGTH(_S2);
	WHILE (_S2 LIKE '%0' OR _S2 LIKE '%.') AND _L > 1 LOOP
		_L := _L - 1;
		_S2 := SUBSTR(_S2, 1, _L);
	END LOOP;

	RETURN _S2;
*/

	RETURN NIn::TEXT;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
STRICT
SECURITY DEFINER;




/**
Makes calculation of "ChargesByPlaces_Consumers" task.
*/

CREATE OR REPLACE FUNCTION calc_PlacesConsumersServices(
	IN CalcIdIn INT
)
RETURNS VOID AS

$BODY$
DECLARE
    logz RECORD;
    objz RECORD;
	tmpz RECORD;

	_TaskId INT;
	_CalcTypeId INT;
	_ProgressMax INT;
    _SQL TEXT;
    _CalcFields TEXT;

	_Period NUMERIC;
    _State INT;
    _PayerId INT;
    _Capacity NUMERIC;
    _Tariff NUMERIC;
    _DateFrom DATE;
    _DateTo DATE;
    _Value NUMERIC;
    _Money NUMERIC;
    _Days NUMERIC;
    _Rem TEXT;

BEGIN
	DROP TABLE IF EXISTS TmpParents;
	CREATE LOCAL TEMPORARY TABLE TmpParents(
		ObjectId INT, ParentId INT, ServiceId INT, DateFrom DATE, State INT)
		ON COMMIT PRESERVE ROWS;

	PERFORM sys_taskWorked(_TaskId,  '
	/********************************************
	* Charges by places data preparation part.
	*********************************************/');

	_SQL := $SQL$
		ALTER TABLE z_calc_out ADD PayerId INT;
		ALTER TABLE z_calc_out ADD DateFrom DATE;
		ALTER TABLE z_calc_out ADD DateTo DATE;
		ALTER TABLE z_calc_out ADD Days Number;
		ALTER TABLE z_calc_out ADD Value Number;
		ALTER TABLE z_calc_out ADD Tariff Number;
		ALTER TABLE z_calc_out ADD Money Number;
		ALTER TABLE z_calc_out ADD Rem LongestString;
		CREATE UNIQUE INDEX UN_%CalcTableName% ON z_calc_out(ObjectId, PayerId, ServiceId, DateFrom)
	$SQL$;
	_SQL := REPLACE(_SQL, '%CalcTableName%', sys_getCalcTableName('out', CalcIdIn));
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	SELECT CalcTypeId,  DateFrom,  DateTo
	INTO  _CalcTypeId, _DateFrom, _DateTo
	FROM Calculations
	WHERE Id = CalcIdIn;

	_TaskId := sys_calcGetTaskId(CalcIdIn);

	PERFORM sys_taskWorked(_TaskId,  'Prepare Parent Objects.');
/*
	INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
	SELECT DISTINCT ON (o.ObjectId, o.ParentId, o.ServiceId)
		o.ObjectId, o.ParentId, o.ServiceId, GREATEST(GREATEST(o.DateFrom, o.InsDate), _DateFrom)
	FROM (
		SELECT op.ObjectId, op.Value::INT AS ParentId, s.Id AS ServiceId, op.DateFrom, o.InsDate,
			MAX(op.DateFrom) OVER (PARTITION BY o.Id, op.Value, s.Id) AS DateFromMax
		FROM Objects o
		JOIN ObjectProperties op ON op.ObjectId = o.Id
		JOIN EntityProperties ep ON ep.Id = op.PropertyId
		    AND ep.Code LIKE '%ParentId'
		LEFT JOIN Services s ON 'Svc' || s.Id || 'ParentId' = ep.Code
		WHERE o.InsDate <= _DateTo
			AND (o.DelDate IS NULL OR o.DelDate > _DateFrom)
			AND op.DateFrom < _DateTo
		) o
	ORDER BY o.ObjectId, o.ParentId, o.ServiceId, o.DateFrom DESC;
*/

/* FIXME!!!
	PERFORM sys_taskWorked(_TaskId,  'If the place is not connected to topology - uses House''s connection instead.');
	INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
	SELECT DISTINCT ON (o.ObjectId, o.ParentId, o.ServiceId)
		o.ObjectId, o.ParentId, o.ServiceId, GREATEST(GREATEST(o.DateFrom, o.InsDate), _DateFrom)
	FROM (
		SELECT op.ObjectId, op.Value AS ParentId, s.Id AS ServiceId, op.DateFrom, o.InsDate,
			MAX(op.DateFrom) OVER (PARTITION BY o.Id, op.Value, s.Id) AS DateFromMax
		FROM Objects o
		JOIN ObjectProperties op ON op.ObjectId = o.Id
		JOIN EntityProperties ep ON ep.Id = op.PropertyId
		    AND ep.Code LIKE '%ParentId'
		LEFT JOIN Services s ON 'Svc' || s.Id || 'ParentId' = ep.Code
		WHERE o.InsDate <= _DateTo
			AND (o.DelDate IS NULL OR o.DelDate > _DateFrom)
			AND op.DateFrom < _DateTo
		) o
	ORDER o.ObjectId, o.ParentId, o.ServiceId, o.DateFrom DESC;
*/

	PERFORM sys_taskWorked(_TaskId,  'Consider deleted Objects.');
/*
	INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
	SELECT o.Id, NULL, tp.ServiceId, o.DelDate
	FROM Objects o
	JOIN TmpParents tp ON tp.ObjectId = o.Id
	WHERE o.DelDate > _DateFrom AND o.DelDate < _DateTo;
*/
    PERFORM sys_taskWorked(_TaskId,  'Replicate universal parents for all services.');
/*
    INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
    SELECT tp.ObjectId, tp.ParentId, s.Id, tp.DateFrom
    FROM TmpParents tp
    CROSS JOIN Services s
    WHERE tp.ServiceId IS NULL
    ;
    DELETE FROM TmpParents tp WHERE tp.ServiceId IS NULL;

--DROP TABLE IF EXISTS TmpParents2;
--CREATE TABLE TmpParents2 AS SELECT * FROM TmpParents;
*/
	-- Insert ServiceLog switching records into tmpPatrents table with switching date.
	PERFORM sys_taskWorked(_TaskId,  'Prepare data for objects state calculation.');
/*
	FOR logz IN -- Looping by ServiceLog records ('Switched' nodes).
	SELECT z.ObjectId, z.ServiceId, z.DateFrom, z.Value::INT AS State
	FROM z_calc_in z
	WHERE z.TmlId = sys_getCalcTmlId(CalcIdIn, 'ServiceLog.State')
	LOOP
		FOR objz IN -- Cascading children of switched objects at the switch date.
		WITH RECURSIVE t AS (
            SELECT (SELECT tp.ParentId
                FROM TmpParents tp
                WHERE tp.ObjectId = logz.ObjectId AND tp.ServiceId = logz.ServiceId
                    AND tp.DateFrom <= logz.DateFrom
                ORDER BY tp.DateFrom DESC LIMIT 1
                ) AS ParentId, logz.ObjectId AS ObjectId, logz.State AS State
            UNION ALL
            SELECT r.ParentId, r.ObjectId, r.State
            FROM (
			    SELECT DISTINCT ON (tp.ObjectId)
			        tp.ParentId, tp.ObjectId, LEAST(t.State, tp.State) AS State
			    FROM t
			    JOIN TmpParents tp ON tp.ParentId = t.ObjectId
	    		    AND tp.ServiceId = logz.ServiceId
	    		    AND tp.DateFrom <= logz.DateFrom
		        ORDER BY tp.ObjectId, tp.DateFrom DESC
		        ) r
		) -- WITH
		SELECT t.ParentId, t.ObjectId, logz.ServiceId, logz.DateFrom, t.State FROM t
        LOOP
	        UPDATE TmpParents tp
	        SET State = LEAST(tp.State, objz.State) -- WHEN tp.State IS NULL it sets it to objz.State.
	        WHERE tp.ObjectId = objz.ObjectId
                AND tp.ServiceId = logz.ServiceId AND tp.DateFrom = logz.DateFrom
	        ;
	        IF NOT FOUND THEN
	            INSERT INTO TmpParents(ParentId, ObjectId, ServiceId, DateFrom, State)
	            VALUES (objz.ParentId, objz.ObjectId, logz.ServiceId, logz.DateFrom, logz.State);
	        END IF;
        END LOOP;
	END LOOP;
*/
	-- FIXME !!!
	-- Crawl upwards by hierarchy (TmpParents) from resulting objects (mostly places)
	-- and calculate their state on each date.

	PERFORM sys_taskWorked(_TaskId,  'Calculate place states by date.');
/*
	-- IF one of objects is OFF - the place is OFF too.
	INSERT INTO z_calc_in(ObjectId, ServiceId, RowId, TmlId, DateFrom, Value)
	SELECT tp.ObjectId, tp.ServiceId, NULL,
		sys_getCalcTmlId(CalcIdIn, 'Objects.State'),
		tp.DateFrom, COALESCE(MIN(tp.State), 0) -- Place's State is 0 by default (if not switched on explicitly).
	FROM TmpParents tp
	JOIN z_calc_obj r ON r.ObjectId = tp.ObjectId AND r.ServiceId = tp.ServiceId
	WHERE tp.State IS NOT NULL -- Don't use empty states.
	GROUP BY tp.ObjectId, tp.ServiceId, tp.DateFrom;
*/
	PERFORM sys_taskWorked(_TaskId,  '
	/********************************************
	* Main calculation part.
	*********************************************/');


	-- Bulk insert optimization.
	/*
	INSERT INTO z_calc_out(ObjectId, ServiceId, PayerId, DateFrom, Value)
	SELECT DISTINCT t1.ObjectId, t1.ServiceId, t2.PayerId, t1.DateFrom, 0
	FROM (SELECT DISTINCT ObjectId, ServiceId, DateFrom FROM z_calc_in WHERE Value IS NOT NULL) t1
	JOIN (SELECT DISTINCT ObjectId, Value::INT AS PayerId FROM z_calc_in WHERE Value IS NOT NULL
	          AND TmlId = sys_getCalcTmlId(CalcIdIn, 'Objects.PayerId')) t2
        ON t2.ObjectId = t1.ObjectId;
    */

    SELECT sys_List(
           E'COALESCE( CAST( \n'
        || E'(SELECT z.Value FROM z_calc_in z \n'
        || E'WHERE z.ObjectId = t.ObjectId \n'
        || E'    AND z.ServiceId = t.ServiceId \n'
        || E'    AND z.DateFrom <= t.DateFrom \n'
        || E'    AND z.TmlId = ' || ct.Id || E'\n'
        || E'ORDER BY z.DateFrom DESC LIMIT 1) \n'
        || E' AS NUMERIC), 0) AS "' || ct.FieldName || E'" \n'
        , ', ')
    INTO _CalcFields
    FROM CalcTemplates ct
    WHERE ct.CalcTypeId = _CalcTypeId
        AND ct.DoRestrict = TRUE; -- This condition is important!!!

    _SQL := E'SELECT t.ObjectId, t.ServiceId, t.DateFrom, \n'
        || E'    LAG(t.DateFrom, 1, %DateTo%) OVER DateToWin AS DateTo, \n'
        || E'    %CalcFields% \n'
        || E'FROM z_calc_in t \n'
        || E'WHERE COALESCE(t.ServiceId, 0) != 0 \n'
        || E'GROUP BY t.ObjectId, t.ServiceId, t.DateFrom \n'
        || E'WINDOW DateToWin AS (PARTITION BY t.ObjectId, t.ServiceId ORDER BY t.DateFrom DESC) \n';
    _SQL := REPLACE(_SQL, '%DateTo%', QUOTE_LITERAL(_DateTo) || '::DATE');
    _SQL := REPLACE(_SQL, '%CalcFields%', _CalcFields);

	PERFORM sys_taskWorked(_TaskId,  'Main calculation cycle.');
	PERFORM sys_DebugMessage('Looping SQL: ' || _SQL);
	FOR tmpz IN EXECUTE _SQL
	LOOP
/*
PERFORM sys_DebugMessage( 'PlaceId:' || C_PlaceId || ', PayerId:' || PlaceOwners_PayerId || ', ServiceId:' || C_ServiceId || ', DateFrom:' || C_DateFrom );
PERFORM sys_DebugMessage( '    Places_State:' || Places_State );
PERFORM sys_DebugMessage( '    Tariffs_Value2:' || Tariffs_Value2 );
PERFORM sys_DebugMessage( '    PlaceCapacities_Value2:' || PlaceCapacities_Value2 );
*/
		IF COALESCE(tmpz."Objects.PayerId", 0) = 0 THEN CONTINUE; END IF;

		_PayerId := tmpz."Objects.PayerId";
		_Period := tmpz.DateTo - tmpz.DateFrom;
		_Capacity := tmpz."ObjectCapacities.Value";
		_State := tmpz."Objects.State";
		_Tariff := tmpz."TariffValues.Value";

--		IF  _State != 0 THEN -- IF Service is ON.
			_Money := ROUND(_Tariff * 12 / 365 * _Capacity * _Period, 2);
			_Rem := '+ ' || sys_trimZero(_Money)
				|| ' [' || tmpz.DateFrom || ' - ' || tmpz.DateTo || ' = ' || sys_trimZero(_Period) || ']'
				|| ' {Tariff=' || sys_trimZero(_Tariff) || ', Capacity=' || sys_trimZero(_Capacity) || '}'
				|| ' ';
/*		ELSE -- Service is OFF.
			_Money := 0;
			_Rem := '+ 0'
				|| ' [' || tmpz.DateFrom || ' - ' || tmpz.DateTo || ' = ' || sys_trimZero(_Period) || ']'
				|| ' {State=' || sys_trimZero(_State) || ', PayerId=' || sys_trimZero(_PayerId) || '}'
				|| ' ';
		END IF;
*/
		INSERT INTO z_calc_out (ObjectId, ServiceId, PayerId, DateFrom, DateTo, Days, Value, Tariff, Money, Rem)
		VALUES(tmpz.ObjectId, tmpz.ServiceId, _PayerId, tmpz.DateFrom, tmpz.DateTo, _Period, _Capacity, _Tariff, _Money, _Rem);

	END LOOP;

	PERFORM sys_taskWorked(_TaskId,  'Task complete.');

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
 * Returns current or given-name user id.
 */
CREATE OR REPLACE FUNCTION sys_getUserId(
	UserNameIn TEXT = NULL
)
RETURNS INTEGER AS

$BODY$
DECLARE
	_UserName TEXT;
    _UserIdResult INTEGER;
BEGIN
	IF COALESCE(UserNameIn, '') = '' THEN
        _UserName := CURRENT_USER;
    ELSE
        _UserName := UserNameIn;
    END IF;

    SELECT Id
    INTO _UserIdResult
    FROM Users
    WHERE Name = _UserName;

    RETURN _UserIdResult;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY INVOKER -- Do not change this because CURRENT_USER will return function owner instead of invoker
COST 10;




/**
Get Preferences list for caching on the client side.
TODO: Redesign using OUT params.
*/
CREATE OR REPLACE FUNCTION sys_getPrefValue(
    IN CodeIn Text
)
RETURNS TABLE (
	Id INTEGER,
	Code TEXT,
	DefaultDateFrom DATE,
	DefaultValue TEXT,
	DateFrom DATE,
	Value TEXT
) AS $BODY$

BEGIN

	RETURN QUERY(
		SELECT pv.Id,
		       p.Code::TEXT,
		       pv.DateFrom, --AS DefaultDateFrom
		       pv.Value::TEXT, --AS DefaultValue
		COALESCE(pvU.DateFrom, pv.DateFrom),
		COALESCE(pvU.Value, pv.Value)::TEXT --AS Value
		FROM Prefs p
		LEFT JOIN PrefValues pv ON p.Id = pv.PrefId -- General.
		  AND pv.UserId IS NULL
		  AND pv.SessionId IS NULL
		LEFT JOIN PrefValues pvU ON p.Id = pvU.PrefId -- User.
		  AND pvU.UserId = sys_getUserId()
		--          AND (pvU.SessionId = _SessionIdIn OR COALESCE(_SessionIdIn, 0) = 0)
		WHERE LOWER(p.Code) = LOWER(CodeIn)
	);
	--AND pv.DateFrom ... --TODO

END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
 * APPLY before using:
 * SET client_min_messages TO 'DEBUG'
 */
CREATE OR REPLACE FUNCTION sys_DebugMessage(
	IN MsgIn TEXT
)
RETURNS VOID AS

$BODY$
DECLARE
	_DebugMode TEXT;
BEGIN
	SELECT Value
	INTO _DebugMode
	FROM sys_getPrefValue('System.Debug'); -- TODO: Use session here!

	IF LOWER(_DebugMode) IN ('1', 'true', 'yes') THEN
		RAISE DEBUG E'--------------------------------------------------------------------------------\n%', MsgIn;

		INSERT INTO EventLog(TS, SQLState, SQLErrM)
		VALUES(clock_timestamp(), 'DebugMessage', MsgIn);
	END IF;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;




/**
Writes errors in EventLog table.
*/
CREATE OR REPLACE FUNCTION sys_EventLog(
    IN SQLStateIn TEXT,
    IN SQLErrMIn TEXT,
    IN DataIn TEXT
) RETURNS VOID AS

$BODY$
BEGIN
--	PERFORM sys_DebugMessage('sys_EventLog: SQLSTATE=' || COALESCE(SQLStateIn, '<NULL>')
--		|| ', SQLERRM=' || COALESCE(SQLErrMIn, '<NULL>'));

	INSERT INTO EventLog(UserId, SQLState, SQLErrM, Data)
	VALUES (sys_getUserId(), SQLStateIn, SQLErrMIn, DataIn);
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;





/**
Returns table name by its id.
*/

CREATE OR REPLACE FUNCTION sys_getTableName(EntityIdIn INTEGER)
RETURNS TEXT AS

$body$
DECLARE
	_Result String;
BEGIN
	SELECT CASE WHEN Type = 'SOFT' THEN 'Objects' ELSE Code END
	INTO _Result
	FROM Entities
	WHERE Id = EntityIdIn;

	RETURN _Result;
END;
$body$

LANGUAGE 'plpgsql'
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER
;




/**
	SELECTS the value of named attribute for Object entities.
*/

CREATE OR REPLACE FUNCTION sys_getAttrValue (
	IN _EntityIdIn INTEGER, -- NULL hint for Object Entities.
	IN _ObjectIdIn INTEGER, -- Row Id.
	IN _CodeIn TEXT, -- Property(Field) Code.
	IN _DateFromIn DATE
)
RETURNS TEXT AS

$BODY$
DECLARE
	 _Result TEXT;
	 _EntityType TEXT;
	 _SQL TEXT;
	 _Code TEXT;
	 _Name TEXT;
	 _Rem TEXT;
BEGIN

	IF LOWER(_CodeIn) = 'id' THEN
		RETURN _ObjectIdIn;
	END IF;

	IF _EntityIdIn IS NOT NULL THEN
		SELECT Type
		INTO _EntityType
		FROM Entities
		WHERE Id = _EntityIdIn;
	ELSE
		_EntityType := 'SOFT';
	END IF;

	IF _EntityType = 'SOFT' THEN -- Determine enity type.

		IF LOWER(_CodeIn) NOT IN ('code', 'name', 'rem') THEN
			SELECT Value
			INTO _Result
			FROM Objects o
			JOIN ObjectProperties op ON o.Id = op.ObjectId
			WHERE op.ObjectId = _ObjectIdIn
			  AND op.DateFrom <= _DateFromIn
			  AND op.PropertyId = (SELECT Id FROM EntityProperties WHERE LOWER(Code) = LOWER(_CodeIn) AND EntityId = o.EntityId)
			ORDER BY DateFrom DESC
			LIMIT 1;
		ELSE
			SELECT Code, Name, Rem
			INTO _Code, _Name, _Rem
			FROM Objects
			WHERE Id = _ObjectIdIn;

			IF LOWER(_CodeIn) = 'code' THEN
				RETURN _Code;
			ELSEIF LOWER(_CodeIn) = 'name' THEN
				RETURN _Name;
			ELSEIF LOWER(_CodeIn) = 'rem' THEN
				RETURN _Rem;
			END IF;
		END IF;

	ELSE -- Table Entities.

		IF EXISTS(SELECT 1 FROM EntityProperties
		          WHERE EntityId = _EntityIdIn
		            AND LOWER(Code) = LOWER(_CodeIn)) THEN

			SELECT Value
			INTO _Result
			FROM ObjectProperties
			WHERE RowId = _ObjectIdIn
			  AND DateFrom <= _DateFromIn
			  AND PropertyId = (SELECT Id FROM EntityProperties WHERE LOWER(Code) = LOWER(_CodeIn)
			  					AND EntityId = _EntityIdIn)
			ORDER BY DateFrom DESC
			LIMIT 1;

		ELSE
			_SQL :=
			$sql$
				SELECT $1
				FROM %TableName%
				WHERE Id = $2
			$sql$ ;

			_SQL := REPLACE(_SQL, '%TableName%', sys_getTableName(_EntityIdIn));
			PERFORM sys_debugMessage('sys_getAttrValue: ' || _SQL);
			EXECUTE _SQL INTO _Result USING LOWER(_CodeIn), _ObjectIdIn;
			PERFORM sys_debugMessage('sys_getAttrValue: Result=' || _Result);

		END IF;

	END IF;

	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;



/**
	Get translation from Dictionary
*/

CREATE OR REPLACE FUNCTION sys_getDictionaryValue(
	CodeIn TEXT,
	FieldIn TEXT DEFAULT NULL
)
RETURNS TEXT AS

$BODY$
DECLARE
    _SQL LongestString;

    _Lang CHAR(3);
	_Name String;
	_Code String;
	_Field String;
	_i INTEGER;
	_NotTranslatable String;
BEGIN
	-- Во View можно писать алиас по русски и он не будет переводиться
	_NotTranslatable := replace(CodeIn, substring(CodeIn, E'[0-9|a-z|A-Z|_|\.]*'), '' ) ;
	IF COALESCE(_NotTranslatable, '') <> '' THEN
		RETURN _NotTranslatable;
	END IF;

	IF lower(FieldIn) IN ('names', 'abbr', 'rem') THEN
		_Field := FieldIn;
	ELSE
		_Field := 'name';
	END IF ;

    SELECT Value INTO _Lang
	FROM sys_getPrefValue('GUI.General.Language');

	_Code := CodeIn ;
	_i := 0;
	WHILE _Name IS NULL AND _i < 2 LOOP

		_SQL :=
		$sql$
			SELECT _Field
			FROM Dictionary
			WHERE lower(Code) = lower($1)
			  AND lower(LanguageCode) = lower($2)
		$sql$ ;

		_SQL := REPLACE(_SQL, '_Field', _Field) ;

		EXECUTE _SQL INTO _Name USING _Code, _Lang;

		_i := _i + 1;
		_Code := 'Common' || SUBSTRING(CodeIn from '%#".%#"' for '#');
	END LOOP;

	_Code := CASE WHEN FieldIn IS NULL THEN CodeIn ELSE CodeIn || '(' || FieldIn || ')' END ;
	_Name := COALESCE(_Name, _Code) ;

	RETURN _Name;

END;
$BODY$

LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER;




/**
	Checks if the given field is system (not retrieved by client).
*/

CREATE OR REPLACE FUNCTION sys_isSystemField (
	IN FieldNameIn text
)
RETURNS boolean AS

$body$

BEGIN
	IF lower(FieldNameIn) IN (
		'id', 'revision', 'insertuserid', 'insertts', 'updateuserid', 'updatets', 'deldate', 'insdate'
		) THEN
	  RETURN true;
	ELSE
	  RETURN false;
	END IF;
END;

$body$

LANGUAGE 'plpgsql'
IMMUTABLE
SECURITY DEFINER
COST 10;



/**
Gets list of controls and their values for given form (Entity) id.
For negative FormIdIn returns virtual forms - attributes.
Processes Object entities as well.';
*/
CREATE OR REPLACE FUNCTION sys_getFormControls (
    IN FormIdIn INTEGER
)
RETURNS TABLE (
	Id INTEGER,
	EntityId INTEGER,
	FieldName TEXT,
	Label TEXT,
	IsEditable TEXT,
	Type TEXT,
	Length INTEGER,
	Mandatory BOOLEAN,
	RefEntityId INTEGER,
	Style TEXT,
	Misc TEXT,
	Rem TEXT,
	OrderNo INTEGER,
	doNumSort BOOLEAN,
	LookupHierarchyId INTEGER
) AS

$BODY$
DECLARE
	 _SQLState String;
     _ErrorMsg LongString;
     _ProcId INTEGER;

	 EntityTypeTemp String;
	 EntityCodeTemp String;
	 _ObjectsEntityId INTEGER;
	 _UniqueFields LongString;

BEGIN
	-- Positive FormId for Real Forms.
	IF SIGN(FormIdIn) >= 0 THEN
		RETURN;

	-- Negative FormId for Virtual Forms (i.e. EntityId).
	ELSE
		SELECT e.Code, e.Type, e.UniqueFields
		INTO EntityCodeTemp, EntityTypeTemp, _UniqueFields
		FROM Entities e
		WHERE e.Id = -FormIdIn;

		SELECT Id INTO _ObjectsEntityId
		FROM Entities WHERE Code = 'Objects';

		IF EntityCodeTemp = 'ObjectProperties' THEN -- Tags and History forms.
			RETURN QUERY(
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'ObjectId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.ObjectId') AS "Label",
					sys_getDictionaryValue('GUI.Editor.ThisColumnCannotBeEdited') AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", _ObjectsEntityId AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 10 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'RowId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.RowId') AS "Label",
					sys_getDictionaryValue('GUI.Editor.ThisColumnCannotBeEdited') AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", -1 AS "RefEntityId", NULL AS "Style", -- -1 as Reference to any Entity.
					NULL AS "Misc", NULL AS "Rem", 20 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'DateFrom' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.DateFrom') AS "Label",
					NULL AS "IsEditable", 'DATE' AS "Type", 128 AS "Length",
					TRUE AS "Mandatory", NULL AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 30 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'PropertyId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.PropertyId') AS "Label",
					NULL AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					TRUE AS "Mandatory", e.Id AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 40 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				FROM Entities e
				WHERE Code = 'EntityProperties'
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'Value' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.Value') AS "Label",
					NULL AS "IsEditable", 'NVARCHAR' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", NULL AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 50 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				ORDER BY "OrderNo"
			);

		ELSEIF EntityTypeTemp = 'SOFT' THEN -- Property-based forms.
			RETURN QUERY(
				-- Code, Name, Rem.
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", t.fn AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.' || t.fn) AS "Label",
					NULL AS "IsEditable", 'NVARCHAR'::TEXT AS "Type", NULL::INT AS "Length",
					CASE t.fn WHEN 'Code' THEN TRUE ELSE FALSE END AS "Mandatory",
					NULL::INTEGER AS "RefEntityId", NULL AS "Style",
					NULL AS "Misc", NULL::TEXT AS "Rem",
					CASE t.fn WHEN 'Code' THEN -10 WHEN 'Name' THEN -9 ELSE 9999 END AS "OrderNo",
					COALESCE((SELECT ep.doNumSort FROM EntityProperties ep WHERE ep.EntityId = -FormIdIn AND ep.Code = t.fn), FALSE) AS "doNumSort",
					NULL::INT AS "LookupHierarchyId"
				FROM (VALUES ('Code'), ('Name'), ('Rem')) t(fn)
				UNION ALL
				-- Main query.
				SELECT ep.Id, ep.EntityId AS "EntityId", ep.Code AS "FieldName",
				    sys_getDictionaryValue('Table.' || EntityCodeTemp || '.' || ep.Code) AS "Label",
				    NULL AS "IsEditable", ep.DataType AS "Type", ep.DataLength AS "Length",
				    CASE WHEN uf.row_value IS NULL THEN ep.Mandatory ELSE TRUE END AS "Mandatory",
				    ep.RefEntityId AS "RefEntityId", NULL AS "Style", NULL AS "Misc", ep.Rem, ep.OrderNo,
				    COALESCE(ep.doNumSort, FALSE) AS "doNumSort",
				    COALESCE(ep.LookupHierarchyId, re.LookupHierarchyId) AS "LookupHierarchyId"
			    FROM EntityProperties ep
			    LEFT JOIN Entities re ON re.Id = ep.RefEntityId
			    LEFT JOIN regexp_split_to_table(_UniqueFields, ',') uf(row_value) ON uf.row_value = ep.Code
			    WHERE ep.EntityId = -FormIdIn
			    	AND ep.PropGroup IS NULL
			    	AND LOWER(ep.Code) NOT IN ('code', 'name', 'rem')
				ORDER BY "OrderNo"
			);

		ELSEIF EntityTypeTemp IN ('HARD', 'VIEW') THEN -- Table-based forms.
			RETURN QUERY(
				SELECT
					CAST(-(t.Id * 1000 + sc.ordinal_position) AS INTEGER) AS "Id", -- ControlId = -(EntityId * 1000 + ColNo)
					t.Id AS "EntityId",
					quote_ident(sc.column_name)::TEXT AS "FieldName",
					sys_getDictionaryValue('Table.' || t.Code || '.' || sc.column_name)::text AS "Label",
					COALESCE(ep.Editable, CASE WHEN ccu.constraint_name like 'pk_%' THEN 'in_primary_key' END)::text AS "IsEditable",
					COALESCE(tm.JavaSQLType, 'UNKNOWN:' || sc.udt_name)::TEXT AS "Type",
					sc.character_maximum_length::INTEGER AS "Length",
					COALESCE(ep.Mandatory, CAST(CASE WHEN sc.is_nullable = 'NO' THEN 1 ELSE 0 END AS boolean)) AS "Mandatory",
					COALESCE(ep.RefEntityId, t2.Id) AS "RefEntityId",
					NULL::TEXT AS "Style",
					NULL::TEXT AS "Misc",
					sys_getDictionaryValue('Table.' || t.Code || '.' || sc.column_name, 'rem')::TEXT AS "Rem",
					COALESCE(ep.OrderNo, sc.ordinal_position) AS "OrderNo",
					COALESCE(ep.doNumSort, FALSE) AS "doNumSort",
					COALESCE(ep.LookupHierarchyId, re.LookupHierarchyId) AS "LookupHierarchyId"
				FROM Entities t
				JOIN information_schema.columns sc ON sc.table_schema = 'public'
					AND LOWER(t.Code) = sc.table_name
				LEFT JOIN TypeMapping tm ON tm.SQLType = sc.udt_name
				LEFT JOIN information_schema.constraint_column_usage ccu
					ON ccu.table_schema = 'public'
					AND sc.table_name = ccu.table_name AND sc.column_name = ccu.column_name
				LEFT JOIN EntityProperties ep ON ep.EntityId = t.Id AND LOWER(ep.Code) = LOWER(sc.column_name)
				LEFT JOIN (select tname.relname as table_name, col.attname as column_name, ftname.relname as ftable_name
				           from pg_constraint con
				           join pg_class tname  on tname.oid  = con.conrelid
				           join pg_class ftname on ftname.oid = con.confrelid
				           join pg_attribute col  on col.attnum  = any(con.conkey)  and col.attrelid  = con.conrelid
				           where con.contype = 'f'
				           ) sfc ON sc.table_name = sfc.table_name AND sc.column_name = sfc.column_name
				LEFT JOIN Entities t2 ON LOWER(t2.Code) = sfc.ftable_name
				LEFT JOIN Entities re ON LOWER(re.Code) = LOWER(t2.Code)
				WHERE t.Id = -FormIdIn
				--AND Creator = sys_getTableOwner()
		          AND sys_isSystemField(sc.column_name) = FALSE
				ORDER BY "OrderNo", "Id"
			);

		END IF;
	END IF;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Returns working date for the user.
*/
CREATE OR REPLACE FUNCTION sys_getWorkingDate()
RETURNS DATE AS

$BODY$
DECLARE
	_Result DATE;

BEGIN
	SELECT CAST(pv.Value AS DATE)
	INTO _Result
	FROM PrefValues pv
	JOIN Prefs p ON p.Id = pv.PrefId
	WHERE p.Code = 'Work.Period.DateFrom'
		AND pv.UserId = sys_getUserId() ;

	IF _Result IS NULL THEN
		_Result := CURRENT_DATE;
		--INSERT INTO PrefValues(PrefId, UserId, Value)
		--SELECT (SELECT Id FROM Prefs WHERE Code = 'Work.Period.DateFrom'), sys_getUserId(), TODAY(*) ;
	END IF;

	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;





/**
Signals custom exception.
Produces SQLState and SQLErrM from given Error Code and Data.
*/
CREATE OR REPLACE FUNCTION sys_SignalException(
	IN ErrCodeIn TEXT,
	IN ErrDataIn TEXT DEFAULT NULL
) RETURNS VOID AS

$BODY$
DECLARE
	_SQLState TEXT;
	_Msg TEXT;
	_D TEXT;

BEGIN
	PERFORM sys_debugMessage('sys_SignalException (ErrCodeIn=' || ErrCodeIn || ', ErrDataIn=' || COALESCE(ErrDataIn, '<NULL>') || ')');

	SELECT e.State INTO _SQLState
	FROM Errors e WHERE e.Code = ErrCodeIn;

	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	_Msg := sys_getDictionaryValue('Error.' || ErrCodeIn) -- Translated message.
		|| _D || COALESCE(REPLACE(ErrDataIn, E'\\d', _D), '');

	RAISE EXCEPTION USING ERRCODE = _SQLState, MESSAGE = _Msg;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Returns object properties, delimited by standard delimiter.
When _ObjIdIn specified (NOT NULL or != 0) - used for audit - returns attributes of concrete object in the form <FieldName1>=<Value>|<FieldName2>=<Value>|...
Else returns SQL for getting object properties - used in rcp_getObjects().
*/
CREATE OR REPLACE FUNCTION sys_getAttrList(
	IN _EntityIdIn INTEGER,
	IN _ObjIdIn INTEGER
)
RETURNS LongestString AS

$BODY$
DECLARE
	 _Result TEXT;
	 _SQL TEXT;
	 _SQLArray CITEXT[];
	 _ObjectCodeSQL TEXT;
	 _ObjectNameSQL TEXT;
	 _ObjectRemSQL TEXT;
     _EntityCode TEXT;
	 _EntityType TEXT;
	 _D TEXT =  (SELECT Value FROM sys_getPrefValue('System.SQL.Delimiter'));
	 _D2 TEXT = (SELECT Value FROM sys_getPrefValue('System.SQL.Delimiter2'));
	 _ObjectsEntityId INTEGER = (SELECT Id FROM Entities WHERE Code = 'Objects');
	 _IsTranslatable BOOLEAN;

BEGIN
	PERFORM sys_debugMessage('sys_getAttrList(_EntityIdIn=' || COALESCE(_EntityIdIn,0) || ', _ObjIdIn=' || COALESCE(_ObjIdIn,0) || ')');

    SELECT Code, Type, IsTranslatable
    INTO _EntityCode, _EntityType, _IsTranslatable
    FROM Entities
    WHERE Id = _EntityIdIn;

	IF _EntityCode = 'ObjectProperties' THEN -- Tags
		IF COALESCE(_ObjIdIn, 0) != 0 THEN
			SELECT 'ObjectId=' || COALESCE(op.ObjectId, '') || _D || 'RowId=' || COALESCE(op.RowId, '') || _D
				|| 'DateFrom=' || op.DateFrom || _D || 'PropertyId=' || op.PropertyId || _D
				|| 'Value=' || _D
			INTO _SQL
			FROM ObjectProperties op
			WHERE op.Id = _ObjIdIn;
		ELSE
			SELECT sys_SignalException('NotImplemented', 'sys_getAttrValues Designed in "A" mode only for table ObjectProperties');
		END IF;

	ELSIF _EntityType = 'SOFT' THEN
		IF _IsTranslatable THEN
			_ObjectCodeSQL := 'sys_getDictionaryValue(''TableRows.' || _EntityCode || ''' || Code)';
		ELSE
			_ObjectCodeSQL := 'COALESCE(Code, '''')';
		END IF;

		_ObjectNameSQL := 'COALESCE(Name, '''')';
		_ObjectRemSQL := 'COALESCE(Rem, '''')';
		IF COALESCE(_ObjIdIn, 0) != 0 THEN
			_ObjectCodeSQL := '''Code='' || ' || _ObjectCodeSQL;
			_ObjectNameSQL := '''Name='' || ' || _ObjectNameSQL;
			_ObjectRemSQL := '''Rem='' || ' || _ObjectRemSQL;
		END IF;

		_SQLArray := ARRAY(SELECT ' || '
				|| CASE WHEN COALESCE(_ObjIdIn, 0) != 0 THEN '''' || COALESCE(fc.FieldName, '') || '='' || ' ELSE '' END
				|| 'COALESCE((SELECT op.Value '
				|| CASE WHEN COALESCE(fc.RefEntityId,0) != _ObjectsEntityId THEN '' -- Give a hint to client - what entityId Object reference belongs.
				   ELSE ' || CASE WHEN op.Value IS NULL THEN '''' ELSE ''' || _D2 || ''' || (SELECT EntityId FROM Objects WHERE Id = op.Value::INT) END ' END
				|| 'FROM ObjectProperties op '
				|| 'WHERE op.ObjectId = Objects.Id AND op.PropertyId = ' || fc.Id || ' '
				|| '	AND op.DateFrom <= _WorkingDate '
				|| 'ORDER BY op.DateFrom DESC LIMIT 1), '''' )'
		FROM sys_getFormControls(-_EntityIdIn) fc
		WHERE LOWER(fc.FieldName) NOT IN ('code', 'name', 'rem')
		ORDER BY fc.OrderNo, fc.Id);

		_SQL := array_to_string(_SQLArray, ' || ''' || _D || '''') ;
		_SQL := _ObjectCodeSQL || ' || ''' || _D || ''''
			|| ' || ' || _ObjectNameSQL || ' || ''' || _D || ''''
			|| _SQL || ' || ''' || _D || ''''
			|| ' || ' || _ObjectRemSQL || ' || ''' || _D || '''';

	ELSIF _EntityType IN ('HARD', 'VIEW') THEN

		_SQLArray := ARRAY(SELECT ' || COALESCE('
				|| CASE WHEN COALESCE(_ObjIdIn, 0) != 0 THEN '''' || fc.FieldName || '='' || ' ELSE '' END
				|| fc.FieldName
				|| CASE WHEN COALESCE(fc.RefEntityId,0) != _ObjectsEntityId THEN '' -- Give a hint to client - what entityId Object reference belongs.
				   ELSE ' || CASE WHEN ' || fc.FieldName || ' IS NULL THEN '''' ELSE ''' || _D2
				|| ''' || (SELECT EntityId FROM Objects WHERE Id = ' || _EntityCode || '.' || fc.FieldName || ') END ' END
				|| '::TEXT, '''') '
		FROM sys_getFormControls(-_EntityIdIn) fc
		ORDER BY fc.OrderNo, fc.Id );

		_SQL := array_to_string(_SQLArray, ' || ''' || _D || '''') ;
		_SQL := ''''' ' || _SQL || ' || ''' || _D || '''';

	END IF;

	-- Return CLAUSE in CREATE SQL mode.
	IF COALESCE(_ObjIdIn, 0) = 0 THEN
		RETURN _SQL;
	END IF;

	-- GetValues for concrete object.
	_SQL := REPLACE(_SQL, '_WorkingDate', '''' || sys_getWorkingDate() || '''');
	_SQL := 'SELECT ' || _SQL || ' '
		|| 'FROM ' || sys_getTableName(_EntityIdIn) || ' '
		|| 'WHERE Id = ' || _ObjIdIn;
	PERFORM sys_debugMessage('sys_getAttrList: ' || _SQL);
	EXECUTE _SQL INTO _Result;

	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;



/**
 * Checks if the table exists.
 */

CREATE OR REPLACE FUNCTION sys_ifTableExists(tablenamein text)
  RETURNS oid AS

$BODY$

DECLARE
    _tbloid OID;
BEGIN
	SELECT relfilenode
	INTO _tbloid
	FROM pg_class
	WHERE relkind = 'r'
	  AND relname = LOWER(tablenamein)
	;
	IF FOUND THEN
          RETURN _tbloid ;
	ELSE
          RETURN 0 ;
	END IF;
END;

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER
;



/**
Checks if the table has given field.
*/

CREATE OR REPLACE FUNCTION sys_ifTableHasField(
	TableNameIn text,
	FieldNameIn text
)
RETURNS OID AS

$BODY$

DECLARE
    _tbloid OID := sys_ifTableExists(TableNameIn);
    _colnum OID;
BEGIN

	IF _tbloid=0 THEN
          RETURN 0 ;
	ELSE

  	  SELECT attnum INTO _colnum
  	  FROM pg_attribute
  	  WHERE attrelid = _tbloid
  	    AND attname = LOWER(FieldNameIn);

	  IF FOUND THEN
	    RETURN _colnum ;
	  ELSE
	    RETURN 0 ;
	  END IF;

	END IF;
END

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;




/**
 * Numeric test.
 */
CREATE OR REPLACE FUNCTION sys_isNumeric (TEXT)
RETURNS BOOLEAN AS
$BODY$
	SELECT $1 ~ '^[0-9]+$';
$BODY$
LANGUAGE SQL
STRICT
IMMUTABLE;



/**
	Checks if the object can be edited by its DateFrom and DelDates.
	Returns NULL if editable.
	If one of dates is not specified - it is NOT used.
*/

CREATE OR REPLACE FUNCTION sys_ObjectIsEditable (
	IN _EntityIdIn INTEGER,
	IN _ObjIdIn INTEGER,
	IN _WorkingDateIn DATE,
	IN _DateFromIn DATE,
	IN _InsDateIn DATE,
	IN _DelDateIn DATE
)
RETURNS String AS

$BODY$
DECLARE
    _CalcDate DATE;
BEGIN

	-- Allow editing calculations.
	IF (SELECT Code FROM Entities WHERE Id = _EntityIdIn) = 'Calculations' THEN
		RETURN NULL;
	END IF;

	IF _InsDateIn > _WorkingDateIn THEN
		RETURN 'Object is not inserted yet.';
	END IF;

	IF _DelDateIn <= _WorkingDateIn THEN
		RETURN 'Object is already deleted.';
	END IF;

	IF _DateFromIn IS NOT NULL THEN
        SELECT c.DateFrom
        INTO _CalcDate c
        FROM Calculations c
        WHERE c.DateTo > _DateFromIn;

		IF _CalcDate IS NOT NULL THEN
			RETURN 'There are calculation on ' || _CalcDate::TEXT
                || ', blocking the object (Date = ' || _DateFromIn::TEXT || '.';
		END IF;
	END IF;

	RETURN NULL;
END;

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;




/**
Validate addition, update and deletion of an object.
Raises exception on error.
*/
CREATE OR REPLACE FUNCTION sys_ObjectValidate (
	IN ModeIn TEXT, -- pre, post, del.
    IN EntityIdIn INTEGER,
    IN ObjIdIn INTEGER -- Object id. If negative - insert new object.
) RETURNS VOID AS

$BODY$
DECLARE
	rulez RECORD;
	fieldz RECORD;
	_IsEditable TEXT;
	_TableName TEXT;
	_EntityType TEXT;
	_SQL TEXT;
	_WhereSQL TEXT;
	_WorkingDate DATE;
	_DateFrom DATE;
	_InsDate DATE;
	_DelDate DATE;
	_ObjectEntityId INTEGER;
	_D TEXT;
	_UniqueFields TEXT;
	_unObjectId INTEGER;
	_unObjectCode TEXT;
	_unInsDate DATE;
	_EmptyField TEXT;
	_Value TEXT;

BEGIN
	PERFORM sys_DebugMessage('sys_ObjectValidate: ' || ModeIn);
	_WorkingDate := sys_getWorkingDate();

	SELECT sys_getTableName(e.Id), e.Type, e.UniqueFields
	INTO _TableName, _EntityType, _UniqueFields
	FROM Entities e
	WHERE e.Id = EntityIdIn;

	_SQL := 'SELECT DateFrom, InsDate, DelDate FROM ' || _TableName || ' WHERE Id = ' || ObjIdIn;
	IF sys_ifTableHasField(_TableName, 'DateFrom') = 0 THEN
		_SQL := REPLACE(_SQL, 'DateFrom', 'NULL');
	END IF;
	IF sys_ifTableHasField(_TableName, 'DelDate') = 0 THEN
		_SQL := REPLACE(_SQL, 'InsDate', 'NULL');
		_SQL := REPLACE(_SQL, 'DelDate', 'NULL');
	END IF;
	EXECUTE _SQL INTO _DateFrom, _InsDate, _DelDate;

	IF _EntityType = 'SOFT' THEN
		_DateFrom := _WorkingDate;
	END IF;
	_IsEditable := sys_ObjectIsEditable(EntityIdIn, ObjIdIn, _WorkingDate, _DateFrom, _InsDate, _DelDate);
	IF _IsEditable IS NOT NULL THEN
		PERFORM sys_SignalException('AccessBlocked', _IsEditable);
	END IF;

	-- Object-entities specific validations.
	IF LOWER(ModeIn) = 'post' AND _EntityType = 'SOFT' THEN
--MESSAGE 'sys_ObjectValidate: 01' TO CLIENT;

		-- Validation by Mandatory fields.
		SELECT fc.FieldName
		INTO _EmptyField
		FROM sys_getFormControls(-EntityIdIn) fc
		WHERE fc.Mandatory = TRUE
			AND COALESCE(sys_getAttrValue(NULL, ObjIdIn, fc.FieldName, _WorkingDate), '')
				IN ('', '!!!NEW_ROW!!!') -- DON'T CHANGE THIS - USED IN ANOTHER PLACE.
		ORDER BY fc.OrderNo LIMIT 1
		;
		IF _EmptyField IS NOT NULL THEN
			PERFORM sys_SignalException('EmptyMandatoryField', _EmptyField);
		END IF;

--MESSAGE 'sys_ObjectValidate: 02' TO CLIENT;

		-- Check entity's UniqueFields or unique code (consider DelDate) for Object entities.
		_SQL := E'SELECT o.Id, o.Code, o.InsDate \n'
			|| E'    FROM Objects o \n'
			|| E'    WHERE o.EntityId = EntityIdIn \n'
			|| E'    	AND o.Id != ObjIdIn \n'
			|| E'    	AND (o.DelDate IS NULL OR o.DelDate > _WorkingDate) \n'
			|| E'       _WhereSQL \n'
			|| E'	ORDER BY Id LIMIT 1 \n';

		IF COALESCE(_UniqueFields, '') = '' THEN -- No unique fields specified - use code.
			_WhereSQL := 'AND Code = ''' || (SELECT o.Code FROM Objects o WHERE o.Id = ObjIdIn) || '''';
			_UniqueFields := 'Code'; -- Used in error message.

--MESSAGE 'sys_ObjectValidate: 03' TO CLIENT;

		ELSE -- parsing unique fields.
--MESSAGE 'sys_ObjectValidate: 04' TO CLIENT;

			FOR fieldz IN
				SELECT REGEXP_SPLIT_TO_TABLE(_UniqueFields, ',') AS Code
			LOOP
				_Value := COALESCE(sys_getAttrValue(NULL, ObjIdIn, fieldz.Code, _WorkingDate), '');

				IF fieldz.Code IN ('Code', 'Name', 'Rem') THEN -- Performance optimisation.
					_WhereSQL := COALESCE(_WhereSQL, '')
						|| ' AND COALESCE(' || fieldz.Code || ', '''') ';

				ELSE
					_WhereSQL := COALESCE(_WhereSQL, '')
						|| ' AND COALESCE(sys_getAttrValue(NULL, Id, '''
						|| fieldz.Code  || ''', _WorkingDate), '''') ';
				END IF;
				_WhereSQL := _WhereSQL || ' = COALESCE(' || QUOTE_LITERAL(_Value) || ', '''') ';
			END LOOP;
		END IF;

--MESSAGE 'sys_ObjectValidate: 05' TO CLIENT;

		_SQL := REPLACE(_SQL, '_WhereSQL', _WhereSQL);
		_SQL := REPLACE(_SQL, 'EntityIdIn', EntityIdIn::TEXT);
		_SQL := REPLACE(_SQL, 'ObjIdIn', ObjIdIn::TEXT);
		_SQL := REPLACE(_SQL, '_WorkingDate', QUOTE_LITERAL(_WorkingDate));
		PERFORM sys_debugMessage('sys_ObjectValidate (UniqueFields): ' || _SQL);
		EXECUTE _SQL INTO _unObjectId, _unObjectCode, _unInsDate;

--MESSAGE 'sys_ObjectValidate: 06' TO CLIENT;

		IF _unObjectId IS NOT NULL THEN
			PERFORM sys_SignalException('UniqueConstraint', _UniqueFields || E'\\d'
				|| _unObjectId || E'\\d' || _unObjectCode || E'\\d' || _unInsDate);
		END IF;

--MESSAGE 'sys_ObjectValidate: 07' TO CLIENT;
	END IF;

--MESSAGE 'sys_ObjectValidate: 08' TO CLIENT;
	-- Validation by EntityValidation rules.
	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');
	SELECT e.Id INTO _ObjectEntityId FROM Entities e WHERE e.Code = 'Objects';

--MESSAGE 'sys_ObjectValidate: 09' TO CLIENT;
/*
	ValRulesLoop:
	FOR rulez IN
		SELECT ev.Id, ev.Code, ev.RuleSQL, ev.ErrorCode
		FROM EntityValidation ev
		WHERE ev.CheckMode = ModeIn
			AND (ev.EntityId = EntityIdIn
				OR (_EntityType = 'SOFT' AND ev.EntityId = _ObjectEntityId))
		ORDER BY ev.EntityId DESC
	LOOP

--MESSAGE 'sys_ObjectValidate: 10: ' || C_Id TO CLIENT;

		SET _SQL = REPLACE(C_RuleSQL, 'EntityIdIn', EntityIdIn);
		SET _SQL = REPLACE(_SQL, 'ObjIdIn', ObjIdIn);
		SET _SQL = REPLACE(_SQL, '\d', _D);
		SET _SQL = E'BEGIN \n' || _SQL || E'\n END;';
		PERFORM sys_DebugMessage('sys_ObjectValidate (validation ruleId=' || rulez.Id || ': ' || _SQL);
		EXECUTE _SQL;
		PERFORM sys_DebugMessage('_EntityValidation=' || _EntityValidation);

--MESSAGE 'sys_ObjectValidate: 11: ' || C_Id TO CLIENT;

		IF _EntityValidation != 'OK' THEN
			PERFORM sys_SignalException(C_ErrorCode, _EntityValidation);
			LEAVE ValRulesLoop; -- REDUNDANT: Really not needed.
		END IF;
	END FOR ValRulesLoop;
*/
	PERFORM sys_DebugMessage('sys_ObjectValidate: Finished OK');
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
 * Add new object or updates existing one.
 */
CREATE OR REPLACE FUNCTION rcp_addObject (
    IN FormIdIn INTEGER, -- Negative values stand for virtual forms.
    IN ObjIdIn INTEGER, -- Object id. If negative - insert new object.
    IN ValuesIn TEXT,  -- Delimiter separated value list. Already quoted on client (' replaced with '').
    OUT NewObjIdOut INTEGER -- Identity of inserted row.
) RETURNS INTEGER AS

$BODY$
DECLARE
	valuez RECORD;
	fieldz RECORD;
	_NewObjId INTEGER;
	_RowCount INTEGER = 0;
	_SQL TEXT = '';
	_SQLClause TEXT;
	_KeyX TEXT;
	_CurEntityCode TEXT;
	_EntityCode TEXT;
	_EntityType TEXT;
    _FieldName TEXT;
    _FieldList TEXT = '';
    _ValueList TEXT = '';
    _Value TEXT;
    _EntityId INTEGER;
    _PropertyId INTEGER;
    _Revision INTEGER = 0;
    _RevisionThreshold BIGINT;
    _Audit TEXT = '';
    _AuditFull TEXT = '';
    _SQL2 TEXT = '';
    _Mandatory BOOLEAN;
    _DateFrom DATE;
    _OPId INTEGER;
    _Validation TEXT;
	_DoInsert BOOLEAN;
	_RefEntityId INTEGER;
	_RefTableName TEXT;
	_Id INTEGER;
	_SQL3 TEXT = '';
	_WrongField TEXT;
    _D TEXT = (SELECT Value FROM sys_getPrefValue('System.SQL.Delimiter'));
	_WorkingDate DATE = sys_getWorkingDate();

BEGIN
	PERFORM sys_debugMessage('rcp_addObject: WorkingDate=' || sys_getWorkingDate()::TEXT);

	IF COALESCE(ValuesIn, '') = '' THEN
	   PERFORM sys_signalException('Assert', 'Empty ValuesIn!');
	END IF;

	CREATE TEMPORARY TABLE _FieldValues (Code TEXT PRIMARY KEY, Value TEXT) ON COMMIT DROP;

    SELECT t.Code, t.Type, t.RevisionThreshold
    INTO _EntityCode, _EntityType, _RevisionThreshold
    FROM Entities t
    WHERE t.Id = -FormIdIn;

	-- Validate Update BEFORE object is changed (later - AFTER update);
	IF ObjIdIn > 0 THEN
		PERFORM sys_ObjectValidate('pre', -FormIdIn, ObjIdIn);
	END IF;

PERFORM sys_debugMessage('HERE 01');

	-- Create new Object if needed, get exiting object's revision.
    IF _EntityType = 'SOFT' THEN
		IF ObjIdIn < 0 THEN
			INSERT INTO Objects(EntityId, Code, Revision, InsDate)
			VALUES(-FormIdIn, '!!!NEW_ROW!!!', 1, sys_getWorkingDate()); -- DON'T CHANGE THIS - USED IN ANOTHER PLACE.

			_NewObjId := CURRVAL('objects_id_seq');
			GET DIAGNOSTICS _RowCount = ROW_COUNT;
		ELSE
			SELECT Revision INTO _Revision
			FROM Objects WHERE Id = ObjIdIn;

			_NewObjId := ObjIdIn;
			_RowCount := 0;
		END IF;

	ELSEIF _EntityType = 'HARD' THEN -- Table Entities.
		IF ObjIdIn > 0 THEN -- Get current row revision.
			_SQL2 := 'SELECT Revision FROM %t WHERE Id = %ObjId';
			_SQL2 := REPLACE(_SQL2, '%t', _EntityCode);
			_SQL2 := REPLACE(_SQL2, '%ObjId', ObjIdIn::TEXT);
			EXECUTE _SQL2 INTO STRICT _Revision;
			_Revision := COALESCE(_Revision, 0);
		END IF;
    END IF;

PERFORM sys_debugMessage('HERE 02');

	-- Prepare Audit record for not-yet-backed-up and "ripe" records.
	-- Full audit record for new row is composed together with _Audit.
    IF ObjIdIn > 0 AND MOD(_Revision, _RevisionThreshold) = 0 THEN
		_AuditFull := _AuditFull || sys_getAttrList(-FormIdIn, ObjIdIn);
	END IF;

	-- Parse Input line (format <EntityCode>.<FieldName>=<Value><Delimiter>...)
	FOR valuez IN
		SELECT * FROM REGEXP_SPLIT_TO_TABLE(ValuesIn, _D) t(Entry) WHERE Entry != ''
	LOOP
		_KeyX := SPLIT_PART(valuez.Entry, '=', 1);
		_CurEntityCode := SPLIT_PART(_KeyX, '.', 1);

		IF LOWER(_CurEntityCode) != LOWER(_EntityCode) THEN
			PERFORM sys_SignalException('CannotCommit', 'Wrong field: ' || valuez.Entry);
		END IF;

		_FieldName := SPLIT_PART(_KeyX, '.', 2);
		_Audit := _Audit || _FieldName || '=';
        IF LENGTH(_KeyX) + 1 = LENGTH(valuez.Entry) THEN
            _Value := NULL;
            _Audit := _Audit || '<NULL>';
        ELSE
		    _Value := SUBSTR(valuez.Entry, LENGTH(_KeyX) + 1 + 1);
		    _Audit := _Audit || _Value;
        END IF;
        _Audit := _Audit || _D;

		INSERT INTO _FieldValues(Code, Value)
		VALUES (_FieldName, _Value);
	END LOOP;

PERFORM sys_debugMessage('HERE 03');

	-- Validate FieldNames.
	SELECT fv.Code || '=' || fv.Value
	INTO _WrongField
	FROM _FieldValues fv
	LEFT JOIN sys_getFormControls(FormIdIn) fc ON fc.FieldName = fv.Code
	WHERE fc.FieldName IS NULL
	ORDER BY fc.OrderNo LIMIT 1
	;
	IF _WrongField IS NOT NULL THEN
		PERFORM sys_SignalException('CannotCommit', 'Wrong field: ' || _WrongField);
	END IF
	;
	UPDATE _FieldValues
	SET Value = NULL
	WHERE Value = '';

PERFORM sys_debugMessage('HERE 04');

	-- FieldValues loop.
	FOR fieldz IN
		SELECT Code, Value AS V, QUOTE_NULLABLE(Value) AS QV  FROM _FieldValues
	LOOP
PERFORM sys_debugMessage('HERE 05, LOOPING: fieldz.Code=' || fieldz.Code);

       	IF _EntityType = 'HARD' THEN -- Table entities.
    		IF ObjIdIn < 0 THEN -- INSERT
				_FieldList := _FieldList || fieldz.Code || ',';
				_ValueList := _ValueList || fieldz.QV || ',';
    		ELSE -- UPDATE
			    _SQL := _SQL || fieldz.Code || ' = ' || fieldz.QV || ',';
    		END IF;

    	ELSEIF _EntityType = 'SOFT' THEN -- Object entities.
			-- Test for special properties Code, Name, Rem.
			IF LOWER(fieldz.Code) IN ('code', 'name', 'rem') THEN
                _SQL := _SQL || fieldz.Code || ' = ' || fieldz.QV || ',';

			ELSE
                SELECT Id, Mandatory, RefEntityId
                INTO STRICT _PropertyId, _Mandatory, _RefEntityId
                FROM EntityProperties
                WHERE EntityId = -FormIdIn
                    AND Code = fieldz.Code
                ;
                IF _Value IS NOT NULL THEN
                    _Value := REPLACE(fieldz.V, '''''', ''''); -- Unquote.
                ELSE
					IF _Mandatory THEN
						PERFORM sys_SignalException('EmptyMandatoryField', fieldz.Code);
					END IF;
                END IF;

                -- ValiDation - if referenced object exists for reference fields.
                IF _RefEntityId IS NOT NULL AND COALESCE(_Value, '') != '' THEN
                	_RefTableName := sys_getTableName(_RefEntityId);

                	-- Check if value is numeric.
                	IF NOT sys_isNumeric(_Value) THEN
						PERFORM sys_SignalException('CannotCommit', 'Reference field value must be numeric!'
							|| E'\nField:' || fieldz.Code || 'value:' || _Value );
					END IF;

					_SQL3 := E'SELECT Id \n'
						|| 'FROM ' || _RefTableName || E' \n'
						|| 'WHERE Id=' || _Value || E' \n';
					IF sys_ifTableHasField(_RefTableName, 'DelDate') != 0  THEN
						_SQL3 := _SQL3
							|| E' 	AND (DelDate IS NULL OR DelDate > sys_getWorkingDate()) \n'
							|| E'	AND InsDate <= sys_getWorkingDate() \n';
					END IF;
					PERFORM sys_DebugMessage('rcp_addObject (check if referenced object exists): ' || _SQL3);
					EXECUTE _SQL3 INTO STRICT _Id;

					IF _Id IS NULL THEN
						PERFORM sys_SignalException('CannotCommit', 'Referenced object does not exist!'
							|| E'\nField:' || fieldz.Code || 'table:' || _RefTableName || ', id:' || _Value );
					END IF;
                END IF;

				_DoInsert := TRUE;
				IF COALESCE(ObjIdIn, 0) > 0 THEN
					_OPId := NULL;

					SELECT op.Id, op.DateFrom
					INTO _OPId, _DateFrom
					FROM ObjectProperties op
					WHERE op.ObjectId = ObjIdIn
						AND op.PropertyId = _PropertyId
						AND op.DateFrom <= _WorkingDate
					ORDER BY op.DateFrom DESC LIMIT 1;

					IF _OPId IS NOT NULL THEN
						IF (DATE_TRUNC('month', _DateFrom) = DATE_TRUNC('month', _WorkingDate)) THEN
							_DoInsert := FALSE;

							UPDATE ObjectProperties
							SET Value = _Value,
								DateFrom = _WorkingDate
							WHERE Id = _OPId
							;
							GET DIAGNOSTICS _RowCount = ROW_COUNT;
						END IF;
					END IF;
				END IF
				;
				IF _DoInsert THEN
					INSERT INTO ObjectProperties(ObjectId, PropertyId, Value, DateFrom)
                    VALUES(_NewObjId, _PropertyId, _Value, _WorkingDate)
                    ;
					GET DIAGNOSTICS _RowCount = ROW_COUNT;
				END IF;

                IF _RowCount = 0 THEN
                	PERFORM sys_SignalException('CannotCommit', '_RowCount = 0 for field ' || fieldz.Code);
                END IF;
			END IF; -- NOT (Code, Name, Rem).
    	END IF; -- HARD OR SOFT;

	END LOOP; -- FieldValues loop.
	_SQL := TRIM(TRAILING ',' FROM _SQL);

PERFORM sys_debugMessage('HERE 07: ');
	IF _EntityType = 'HARD'  THEN
		IF ObjIdIn < 0 AND _FieldList != '' THEN
	        _SQLClause := 'INSERT INTO %table (%FieldList, Revision, %InsDate) VALUES (%ValueList, 1, %InsDateValue)';
	        _FieldList := TRIM(TRAILING ',' FROM _FieldList);
			_ValueList := TRIM(TRAILING ',' FROM _ValueList);
	        _SQLClause := REPLACE(_SQLClause, '%FieldList', _FieldList);
	        _SQLClause := REPLACE(_SQLClause, '%ValueList', _ValueList);
	        IF sys_ifTableHasField(_EntityCode, 'InsDate') != 0 THEN
	        	_SQLClause := REPLACE(_SQLClause, '%InsDateValue', 'sys_getWorkingDate()');
	        	_SQLClause := REPLACE(_SQLClause, '%InsDate', 'InsDate');
	        ELSE
	        	_SQLClause := REPLACE(_SQLClause, ', %InsDateValue', '');
	        	_SQLClause := REPLACE(_SQLClause, ', %InsDate', '');
	        END IF;
	    ELSEIF _SQL != '' THEN
	        _SQLClause := 'UPDATE %table SET %_SQL WHERE %table.Id = %objId';
	        _SQL := _SQL || ', Revision = ' || _Revision + 1;
	        _SQLClause := REPLACE(_SQLClause, '%_SQL', _SQL);
	    END IF;
	    _SQLClause := REPLACE(_SQLClause, '%table', _EntityCode);
        _SQLClause := REPLACE(_SQLClause, '%objId', ObjIdIn::TEXT);

	ELSEIF _EntityType = 'SOFT' AND _SQL != '' THEN
		_SQLClause := 'UPDATE Objects SET %_SQL WHERE Id = %ObjId';
		_SQLClause := REPLACE(_SQLClause, '%_SQL', _SQL);
        _SQLClause := REPLACE(_SQLClause, '%ObjId', _NewObjId::TEXT);
	END IF;

	IF _SQLClause != '' THEN
		PERFORM sys_DebugMessage('rcp_addObject: ' || _SQLClause);
	    EXECUTE _SQLClause;
	    GET DIAGNOSTICS _RowCount = ROW_COUNT;
    	IF _RowCount = 0 THEN
			PERFORM sys_SignalException('CannotCommit', 'cause ROW_COUNT = 0');
		END IF;
	END IF;

	-- Validate Update AFTER object is changed (formerly - BEFORE update);
	PERFORM sys_ObjectValidate('post', -FormIdIn, COALESCE(_NewObjId, ObjIdIn));

	-- Update Revision count on objects when updated.
	IF ObjIdIn > 0 AND _EntityType = 'SOFT' THEN
		UPDATE Objects
		SET Revision = _Revision + 1
		WHERE Id = ObjIdIn;
	END IF;

    -- Return new Id.
    IF _EntityType = 'HARD' THEN
		IF ObjIdIn < 0 THEN
		    _NewObjId := CURRVAL(sys_getTableName(-FormIdIn) || '_id_seq');
		ELSE
			_NewObjId := ObjIdIn;
	    END IF;
	END IF;

PERFORM sys_debugMessage('HERE 13: ');
    -- Make Audit record.
    IF _RowCount > 0 THEN
        IF ObjIdIn < 0 THEN
        	_AuditFull := _Audit;
            _Audit := 'New:' || _Audit;
        END IF;
        INSERT INTO AuditLog(EventTS, UserId, EntityId, RowId, FieldValues, FieldValuesFull, Revision)
    	VALUES (NOW(), sys_getUserId(NULL), -FormIdIn, _NewObjId, _Audit, _AuditFull, _Revision + 1);
    ELSE
    	PERFORM sys_signalException('CannotCommit', 'No rows updated(inserted)!');
    END IF;

	NewObjIdOut := _NewObjId;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_addObject');
	RAISE;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Sets PrefValue for selected user.
Cannot be used in COMMIT mode from sys_EventLog and from ATOMIC transactions.
*/
CREATE OR REPLACE FUNCTION rcp_addPrefValue (
    IN CodeIn TEXT,
    IN ValueIn TEXT,
--    IN DateFromIn Date = NULL, -- TODO: DateFromIn not used yet.
    OUT PrefValueIdOut INTEGER
) RETURNS INTEGER AS

$BODY$
DECLARE
	_PrefId INTEGER;
	_PrefType TEXT;
	_UserId INTEGER;
	_IsAdmin BOOLEAN;

BEGIN
	_UserId := sys_getUserId();

	SELECT Id, Type INTO _PrefId, _PrefType
	FROM Prefs WHERE LOWER(Code) = LOWER(CodeIn);

	-- Insert user preference if it does not exist yet.
	IF _PrefId IS NULL THEN
	   _PrefType := 'USER';

        INSERT INTO Prefs(Code, DataType, Type)
	    VALUES (CodeIn, 'VarChar', _PrefType);

	    _PrefId := CURRVAL('prefs_id_seq');
	END IF;

	IF LOWER(_PrefType) = LOWER('SYSTEM')
		AND NOT EXISTS(SELECT 1 FROM UserGroups ug
					JOIN Groups g ON g.Id = ug.GroupId
					WHERE ug.UserId = _UserId
						AND g.IsAdmin)
	THEN
		PERFORM sys_SignalException('AccessDenied', 'Prefs.Code=' || CodeIn || ', UserId=' || _UserId);
	END IF;

	UPDATE PrefValues pv
	SET Value = ValueIn
	WHERE pv.PrefId = _PrefId
		AND COALESCE(pv.UserId, 0) = COALESCE(_UserId, 0)
	RETURNING pv.Id INTO PrefValueIdOut;

	IF NOT FOUND THEN
		INSERT INTO PrefValues(PrefId, UserId, Value, DateFrom)
		VALUES (_PrefId, _UserId, ValueIn, NULL /*DateFromIn*/);

		PrefValueIdOut := CURRVAL('prefvalues_id_seq');
	END IF;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Prepares and starts calculation.
*/
CREATE OR REPLACE FUNCTION rcp_calculate(
	IN  CalcIdIn INTEGER
) RETURNS VOID AS

$BODY$
DECLARE
	_TaskId INTEGER = sys_calcGetTaskId(CalcIdIn);
    _CalcProcedure TEXT;
    _ItEntityId INTEGER;
    _ItEntityCode TEXT;
    _ItEntityType TEXT;
	_DateFrom Date;
	_DateTo Date;
	_PropertyId INTEGER;
	_SQL TEXT;
	_ItSQL TEXT;
	_InTableName TEXT;
	_OutTableName TEXT;
	_ObjTableName TEXT;
	_InputFields TEXT;
	_InputFields2 TEXT;
	_InputSQL TEXT;
	_Criteria TEXT;
	_Criteria2 TEXT;
	fieldz RECORD;
	tmlz RECORD;
	_RowCount INTEGER = 0;

BEGIN
	UPDATE Calculations
	SET State = 'STARTED'
	WHERE Id = CalcIdIn;

	PERFORM sys_taskWorked(_TaskId,  'Create or clear calculation tables');

	SELECT ct.Code, c.DateFrom, c.DateTo, ct.InputFields, ct.InputSQL
	INTO _CalcProcedure, _DateFrom, _DateTo, _InputFields, _InputSQL
	FROM Calculations c
	JOIN calcTypes ct ON ct.Id = c.CalcTypeId
	WHERE c.Id = CalcIdIn;

	-- Define input and  table.
	_InTableName  := sys_getCalcTableName('in',  CalcIdIn);
	_OutTableName := sys_getCalcTableName('out', CalcIdIn);
	_ObjTableName := sys_getCalcTableName('obj', CalcIdIn);

	TRUNCATE TABLE z_calc_in;

	-- Create table with calculated objects ('iterator' fields only).
	IF sys_ifTableExists('z_calc_obj') <> 0 THEN
		_SQL :='DROP TABLE z_calc_obj';
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	IF sys_ifTableExists('z_calc_out') <> 0 THEN
		_SQL :='DROP TABLE z_calc_out';
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	_InputFields2 := REPLACE(REPLACE(_InputFields, '{', ''), '}', '');

	_SQL := 'CREATE Table z_calc_obj(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_SQL := 'CREATE Table z_calc_out(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_InputFields2 := REPLACE(REPLACE(_InputFields, '{', '/*'), '}', '*/');

	PERFORM sys_taskWorked(_TaskId,  'Populate results table with Iterator objects.');

	_InputSQL := 'SELECT ' || _InputFields2 || ' FROM (' || _InputSQL || ') s ' ||
	             'WHERE s.InsDate <= _DateTo AND (s.DelDate IS NULL OR s.DelDate > _DateFrom)' ;
	_SQL := 'INSERT INTO z_calc_obj(' || _InputFields2 || ') ' || _InputSQL ;
	_SQL := REPLACE(_SQL, '_DateFrom', quote_literal(_DateFrom) || '::DATE');
	_SQL := REPLACE(_SQL, '_DateTo', quote_literal(_DateTo) || '::DATE');
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	-- Выходим если нет объктов для расчета
	--IF NOT FOUND THEN RETURN; END IF;
	GET DIAGNOSTICS _RowCount = ROW_COUNT;
	IF _RowCount = 0 THEN
		UPDATE Calculations
		SET State = 'Ok',
			Revision = COALESCE(Revision, 0) + 1
		WHERE Id = CalcIdIn ;

		UPDATE Tasks
		SET State = 'Ok',
			Revision = COALESCE(Revision, 0) + 1
		WHERE Id = _TaskId;

		RETURN;
	END IF;

	_SQL := 'ANALYZE z_calc_obj; CREATE INDEX IDX_z_calc_obj ON z_calc_obj(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	-- Calculate criteria from InputField:
	-- 		'ObjectId, ServiceId' -> 't1.ObjectId = t2.ObjectId AND t1.ServiceId = t2.ServiceId'.
	_Criteria := '';
	_Criteria2 := '';
	FOR fieldz IN  SELECT f.Name FROM regexp_split_to_table(_InputFields2, ', ') f(Name)
	LOOP
        _Criteria := _Criteria || ' AND t2.' || fieldz.Name || ' = t1.' || fieldz.Name;
        _Criteria2 := _Criteria2 || ' AND (t2.' || fieldz.Name || ' = t1.' || fieldz.Name || ' OR t1.' || fieldz.Name || ' IS NULL)';
	END LOOP;
	_Criteria := sys_Right(_Criteria, LENGTH(_Criteria) - LENGTH(' AND')) || ' ';
	_Criteria2 := sys_Right(_Criteria2, LENGTH(_Criteria2) - LENGTH(' AND')) || ' ';
	PERFORM sys_DebugMessage('_Criteria: ' || _Criteria);
	PERFORM sys_DebugMessage('_Criteria2: ' || _Criteria2);

	PERFORM sys_taskWorked(_TaskId,  'Populate prerequisites.');

	_SQL :='DROP INDEX idx_z_calc_in';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	FOR tmlz IN
	    SELECT ct.Id, ct.FieldName, ct.QuerySQL, ct.doRestrict
		FROM Calculations c
 		JOIN CalcTemplates ct ON ct.CalcTypeId = c.CalcTypeId
 		WHERE c.Id = CalcIdIn AND ct.QuerySQL IS NOT NULL
		ORDER BY ct.OrderNo
	LOOP
		PERFORM sys_taskWorked(_TaskId,  '    Iteration started for CalcTemplates: FieldName=' || tmlz.FieldName)
		;
		_SQL := $sql$
			INSERT INTO z_calc_in(%InputFields2%, TmlId, RowId, DateFrom, Value)
			WITH SubQ AS (%QuerySQL%) -- (_InputFields2, RowId, DateFrom, Value)
			SELECT %InputFields2%, %Id%, t1.RowId, GREATEST(t1.DateFrom, %DateFrom%), t1.Value
			FROM SubQ t1
			WHERE t1.DateFrom >= COALESCE((SELECT MAX(t2.DateFrom)
			  							   FROM SubQ t2
			  							   WHERE %Criteria%
			  							       AND t2.DateFrom < %DateFrom%), '-Infinity'::Date)
				AND t1.DateFrom < %DateTo%
			$sql$;
        IF tmlz.doRestrict THEN
            _SQL := _SQL || E'\n AND EXISTS (SELECT 1 FROM z_calc_obj t2 WHERE %Criteria2%)';
        END IF;

		_SQL := REPLACE(_SQL, '%InputFields2%', _InputFields2);
		_SQL := REPLACE(_SQL, '%QuerySQL%', tmlz.QuerySQL);
		_SQL := REPLACE(_SQL, '%Id%', tmlz.Id::TEXT);
		_SQL := REPLACE(_SQL, '%Criteria%', _Criteria);
		_SQL := REPLACE(_SQL, '%Criteria2%', _Criteria2);
		_SQL := REPLACE(_SQL, '%DateFrom%', quote_literal(_DateFrom) || '::DATE');
		_SQL := REPLACE(_SQL, '%DateTo%', quote_literal(_DateTo) || '::DATE');
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END LOOP;

	-- Create index on input table.
	_SQL :=E'ANALYZE z_calc_in; \n'
		|| E'CREATE INDEX idx_z_calc_in ON z_calc_in (ObjectId, ServiceId, TmlId, DateFrom DESC)';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	/*
	PERFORM sys_taskWorked(_TaskId,  E'=============================\n     Duplicate records with DateTo.') ;
	_SQL := $sql$
		INSERT INTO z_calc_in(_InputFields2, TmlId, RowId, DateFrom, DateTo, Value)
		SELECT _InputFields2, TmlId, RowId, DateTo, NULL, NULL
		FROM z_calc_in
		WHERE DateTo IS NOT NULL
	$sql$;
	_SQL := REPLACE(_SQL, '_InputFields2', _InputFields2);
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	PERFORM sys_taskWorked(_TaskId,  '    Recalculate DateTo.') ;
	_SQL := $sql$
		UPDATE z_calc_in t1
		SET DateTo = COALESCE((SELECT MIN(t2.DateFrom)
							   FROM z_calc_in t2
							   WHERE _Criteria
							     AND t2.TmlId = t1.TmlId
							     AND t2.DateFrom > t1.DateFrom), _DateTo)
	$sql$;
	_SQL := REPLACE(_SQL, '_Criteria', _Criteria);
	_SQL := REPLACE(_SQL, '_DateTo', quote_literal(_DateTo));
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;
	*/

	PERFORM sys_taskWorked(_TaskId,  '------------------------------------Call calculation procedure.');
	_SQL := 'SELECT calc_' || _CalcProcedure || '(' || CalcIdIn || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	-- Create In and Out tables.
	IF sys_ifTableExists(_InTableName)<>0 THEN
		_SQL := 'DROP TABLE ' || _InTableName;
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	_SQL := 'CREATE TABLE ' || _InTableName || ' AS TABLE z_calc_in' ;
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL ;

	_SQL := 'CREATE INDEX IDX_' || _InTableName || ' ON ' || _InTableName || '(ObjectId, ServiceId, TmlId, DateFrom DESC)';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	IF sys_ifTableExists(_OutTableName) != 0 THEN
		_SQL := 'DROP TABLE ' || _OutTableName;
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	_SQL := 'CREATE TABLE ' || _OutTableName || ' AS TABLE z_calc_out' ;
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_SQL := 'CREATE INDEX IDX_' || _OutTableName || ' ON ' || _OutTableName || '(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	IF sys_ifTableExists(_ObjTableName) != 0 THEN
		_SQL := 'DROP TABLE ' || _ObjTableName;
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	_SQL := 'CREATE TABLE ' || _ObjTableName || ' AS TABLE z_calc_obj' ;
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_SQL := 'CREATE INDEX IDX_' || _ObjTableName || ' ON ' || _ObjTableName || '(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	UPDATE Calculations
	SET State = 'Ok',
		Revision = COALESCE(Revision, 0) + 1
	WHERE Id = CalcIdIn ;

	UPDATE Tasks
	SET State = 'Ok',
		Revision = COALESCE(Revision, 0) + 1
	WHERE Id = _TaskId;

--EXCEPTION WHEN OTHERS THEN
--	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_calculate');
--	RAISE;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;

--select * from rcp_calculate(1)



/**
Deletes one object from db.
Note: When table or object item is deleted - all its ObjectProperties stay intact for History purpose.
*/
CREATE OR REPLACE FUNCTION rcp_delObject (
    IN  FormIdIn    INTEGER, -- Negative values stand for virtual forms.
    IN  ObjIdIn     INTEGER, -- Object id.
    OUT RowCountOut INTEGER
)
RETURNS INTEGER AS

$BODY$
DECLARE
	 Refz RECORD;
	 _Validation LongString;
     _TableName String;
     _RefTableName String;
     _EntityType String;
     _WorkingDate DATE := sys_getWorkingDate();
     _AuditData LongestString;
     _Id INTEGER;
     _SQL LongestString;
     _Value String;
     _ObjectsEntityId INTEGER;
     _Flag BOOLEAN;

BEGIN
    SELECT sys_getTableName(t.Id), t.Type
    INTO _TableName, _EntityType
    FROM Entities t
    WHERE t.Id = -FormIdIn;

    -- Cancel Deletion if row does not exist.
	_SQL := 'SELECT Id FROM %TableName WHERE Id = %ObjIdIn';
	IF sys_ifTableHasField(_TableName, 'DelDate') != 0 THEN
		_SQL := _SQL || E'\n AND (DelDate IS NULL OR DelDate > sys_getWorkingDate()) AND InsDate <= sys_getWorkingDate()';
	END IF;

	_SQL := REPLACE(_SQL, '%TableName', _TableName);
	_SQL := REPLACE(_SQL, '%ObjIdIn', ObjIdIn::TEXT);

	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL INTO _Id;

	IF _Id IS NULL THEN
		PERFORM sys_SignalException('CannotDelete', 'There are no record for deletion: EntityId=' || -FormIdIn::TEXT || ', ObjId=' || ObjIdIn::TEXT);
	END IF;

	-- Validate deletion.
	PERFORM sys_ObjectValidate('del', -FormIdIn, ObjIdIn);

	-- Check for Referencing objects.
    SELECT CASE WHEN _EntityType = 'SOFT' THEN Id ELSE -FormIdIn END
    INTO _ObjectsEntityId
    FROM Entities WHERE Code = 'Objects'
    ;

	PERFORM sys_DebugMessage('rcp_delObject: _EntityType=' || _EntityType || ', _ObjectsEntityId=' || _ObjectsEntityId::TEXT);

	FOR Refz IN --Loop through all referencing objects (dates ignored).
		SELECT op.ObjectId AS C_ObjectId, op.RowId AS C_RowId,
			op.PropertyId AS C_PropertyId, ep.EntityId AS C_EntityId
		FROM EntityProperties ep
		JOIN ObjectProperties op ON op.PropertyId = ep.Id
		WHERE ep.RefEntityId IN(-FormIdIn, _ObjectsEntityId)
			AND op.Value = CAST(ObjIdIn AS String)
			--AND ep.PropGroup != 'Tags'
		GROUP BY op.ObjectId, op.RowId, op.PropertyId, ep.EntityId
	LOOP

		PERFORM sys_DebugMessage('rcp_delObject: C_ObjectId=' || COALESCE(Refz.C_ObjectId::TEXT, 'NULL') || ', C_RowId=' || COALESCE(Refz.C_RowId::TEXT, 'NULL') || ',C_PropertyId=' || Refz.C_PropertyId::TEXT || ', C_EntityId=' || Refz.C_EntityId::TEXT);

		_RefTableName := sys_getTableName(Refz.C_EntityId);
		_Flag := NULL;

		-- Check if referencing object is live at the moment.
		_SQL := $sql$
			SELECT Id
			FROM %RefTableName
			WHERE Id = COALESCE(%C_ObjectId, %C_RowId)
		$sql$ ;

		_SQL := REPLACE(_SQL, '%RefTableName', _RefTableName);
		_SQL := REPLACE(_SQL, '%C_ObjectId', COALESCE(Refz.C_ObjectId::TEXT, 'NULL'));
		_SQL := REPLACE(_SQL, '%C_RowId', COALESCE(Refz.C_RowId::TEXT, 'NULL'));

		IF sys_ifTableHasField(_RefTableName, 'DelDate') != 0 THEN
			_SQL := _SQL || E'	AND (DelDate IS NULL OR DelDate > sys_getWorkingDate()) \n';
				-- Not using InsDate because of referencing "in future".
		END IF;

		PERFORM sys_DebugMessage('rcp_delObject: C_PropertyId=' || Refz.C_PropertyId::TEXT || E':\n' || _SQL);
		EXECUTE _SQL INTO STRICT _Id;

		_Flag := CASE WHEN _Id IS NULL THEN FALSE ELSE TRUE END;

		PERFORM sys_DebugMessage( 'rcp_delObjects: _Id=' || _Id::TEXT);

		-- Check if referencing object has active reference at present.
		IF _Flag = TRUE THEN
			SELECT op.Value
			INTO STRICT _Value
			FROM ObjectProperties op
			WHERE (op.ObjectId = Refz.C_ObjectId OR op.ObjectId IS NULL)
				AND (op.RowId = Refz.C_RowId OR op.RowId IS NULL)
				AND op.PropertyId = Refz.C_PropertyId
				AND op.DateFrom <= _WorkingDate
			ORDER BY op.DateFrom DESC
			LIMIT 1 ;

			IF _Value = ObjIdIn::TEXT THEN
				_Flag := TRUE;
			ELSE
				_Flag := FALSE;
			END IF;

			-- Referencing Error reporting.
			IF _Flag = TRUE THEN
				PERFORM sys_SignalException('CannotDelete',
					'Referencing Object found: EntityTable=' || _RefTableName || ', Id=' || COALESCE(Refz.C_ObjectId, Refz.C_RowId)::TEXT);
			END IF;

		END IF;

	END LOOP;

	-- Memorize audit record.
	_AuditData := sys_getAttrList(-FormIdIn, ObjIdIn);

	IF sys_ifTableHasField(_TableName, 'DelDate') = 0 THEN
		_SQL := 'DELETE FROM %t WHERE %t.Id = %ObjId';
	ELSE -- DelDate handling.
		_SQL := 'UPDATE %t SET DelDate = _WorkingDate WHERE Id = %ObjId';
	END IF;

	_SQL := REPLACE(_SQL, '%t', _TableName);
    _SQL := REPLACE(_SQL, '%ObjId', ObjIdIn::TEXT);
    _SQL := REPLACE(_SQL, '_WorkingDate', quote_literal(_WorkingDate::TEXT));

    PERFORM sys_DebugMessage('rcp_DelObjects: ' || _SQL);
    EXECUTE _SQL;
    GET DIAGNOSTICS RowCountOut = ROW_COUNT;

    IF RowCountOut > 0 THEN -- Make audit record.
		INSERT INTO AuditLog(EventTS, UserId, EntityId, RowId, FieldValues, FieldValuesFull)
		VALUES (current_timestamp, sys_getUserId(NULL), -FormIdIn, ObjIdIn, NULL, _AuditData);
    ELSE -- Error - cannot delete.
    	PERFORM sys_SignalException('CannotDelete', 'Row being deleted does not exist in DB!');
    END IF;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_delObject');
	RAISE;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;




/**
Backtracks tree for CTreeCombo.
*/
CREATE OR REPLACE FUNCTION rcp_getBackTracking (
    IN HierarchyIdIn INTEGER, -- Lookup hierarchy id.
	IN EntityIdIn INTEGER, -- Entitiy of object, being backtracked.
	IN ObjectIdIn INTEGER -- Id of object, being backtracked.
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getBackTracking' || '.' || uuid_generate_v1();
	_resultEntityIds INT[];
	_resultObjectIds INT[];
	parentNodez RECORD;
    _curLevel INTEGER;
    _curEntityId INTEGER;
    _newEntityId INTEGER;
    _curObjectId INTEGER;
    _newObjectId INTEGER;
    _SQLTemplate LongString;
    _SQL LongString;
    _curEntityType String;
    _curEntityCode String;
    _MetaEntityId INTEGER;
    _MetaEntityCode String;
    --DECLARE _ParentEntityId INTEGER;


BEGIN
--DELETE FROM EventLog;

    SELECT e.Id, e.Code
    INTO _MetaEntityId, _MetaEntityCode
    FROM Entities e
    WHERE e.Code = 'Objects';
--MESSAGE '_MetaEntityId=' || _MetaEntityId TO CLIENT;

	_curLevel := 0;
	_curEntityId := EntityIdIn;
	_curObjectId := ObjectIdIn;

    SELECT e.Code, e.Type
    INTO _curEntityCode, _curEntityType
    FROM Entities e
    WHERE Id = EntityIdIn;

	-- FIXME: Now implemented only for "Id" ParentField.
	_SQLTemplate := 'SELECT %Field FROM %t WHERE Id = %id';

    <<hierarchyLevelsLoop>>
    LOOP
PERFORM sys_debugMessage('LOOPING: _curLevel=' || _curLevel || ', _curEntityId=' || _curEntityId || ', _curObjectId=' || _curObjectId);
--INSERT INTO EventLog(SQLState, SQLErrM, Data) VALUES ('LOOPING:', '_curLevel=' || _curLevel || ', _curEntityId=' || _curEntityId || ', _curObjectId=' || _curObjectId, NULL);
		_resultEntityIds := _resultEntityIds || _curEntityId;
		_resultObjectIds := _resultObjectIds || _curObjectId;

		_curLevel := _curLevel + 1;
        _newObjectId := NULL; -- if parentNodesLoop: has no iterations.

		<<parentNodesLoop>>
		FOR parentNodez IN
			SELECT CASE WHEN e.Type = 'SOFT' AND hf.ChildField = 'ParentId'
				THEN _MetaEntityId ELSE hf.ParentEntityId END AS ParentEntityId,
                e.Type AS ParentEntityType,
                CASE WHEN e.Type = 'SOFT' AND hf.ChildField = 'ParentId'
                THEN _MetaEntityCode ELSE e.Code END AS ParentEntityCode,
                hf.ParentField, hf.ChildField
		    FROM HierarchyFolders hf -- child.
		    JOIN Entities e ON e.Id = hf.ParentEntityId
			WHERE hf.HierarchyId = HierarchyIdIn
		        AND hf.EntityId = _curEntityId
            -- Optimization: group Object parents together - so current object MUST have childField 'ParentId'.
            	AND hf.ParentField IS NOT NULL
            	AND hf.Type = 'TREE'
            GROUP BY ParentEntityId, ParentEntityType, ParentEntityCode, ParentField, ChildField
		LOOP
--MESSAGE '    ParentEntityCode=' || ParentEntityCode || ', ChildField=' || ChildField TO CLIENT;
			IF parentNodez.ParentField != 'Id' THEN
				PERFORM sys_SignalException('InvalidMetadata', '"Id"-parentField ONLY supported in lookup hierarchies.');
			END IF;

			_newEntityId := parentNodez.ParentEntityId;

			IF _curEntityType = 'SOFT' THEN
				_newObjectId := sys_getAttrValue(NULL, _curObjectId, parentNodez.ChildField, sys_getWorkingDate())::INT;
    			IF _newObjectId IS NOT NULL AND _newEntityId = _MetaEntityId THEN
					SELECT o.EntityId INTO _newEntityId
					FROM Objects o 	WHERE o.Id = _newObjectId;
                END IF;

			ELSEIF _curEntityType IN ('HARD', 'VIEW') THEN
--PERFORM sys_debugMessage('=============> _curEntityCode=' || COALESCE(_curEntityCode, '<NULL>'));
--PERFORM sys_debugMessage('=============> _curObjectId=' || COALESCE(_curObjectId::TEXT, '<NULL>'));
--PERFORM sys_debugMessage('=============> _parentNodez.ChildField=' || COALESCE(parentNodez.ChildField, '<NULL>'));
				_SQL := REPLACE(_SQLTemplate, '%t', _curEntityCode);
				_SQL := REPLACE(_SQL, '%id', _curObjectId::TEXT);
				_SQL := REPLACE(_SQL, '%Field', COALESCE(parentNodez.ChildField, ''));
--MESSAGE '    ' + _SQL TO CLIENT;

--INSERT INTO EventLog(SQLState, SQLErrM, Data) VALUES ('EXECUTE:', _SQL, _newObjectId::TEXT);
				EXECUTE _SQL INTO STRICT _newObjectId;
			END IF;

			IF _newObjectId IS NOT NULL THEN
                _curObjectId := _newObjectId;
                _curEntityId := _newEntityId;
                _curEntityCode := parentNodez.ParentEntityCode;
                _curEntityType := parentNodez.ParentEntityType;

    			EXIT parentNodesLoop;
    		END IF;
		END LOOP parentNodesLoop;

--MESSAGE 'Out of parentNodesLoop: _newObjectId=' || _newObjectId TO CLIENT;
		IF _newObjectId IS NULL THEN
--MESSAGE 'Leaving hierarchyLevelsLoop;' TO CLIENT;
    			EXIT hierarchyLevelsLoop;
    	END IF;
        _curObjectId := _newObjectId;
     END LOOP hierarchyLevelsLoop;

	-- Retrieving final resultset.
	OPEN result FOR
	SELECT e.EntityId, o.ObjectId
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.EntityId FROM UNNEST(_resultEntityIds) AS A(EntityId)) e
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId FROM UNNEST(_resultObjectIds) AS A(ObjectId)) o
		ON e.RowNum = o.RowNum
	ORDER BY e.RowNum DESC;

RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;





/**
Returns given dictionary values (by code) to client.
*/

CREATE OR REPLACE FUNCTION rcp_getDictionaryValues (
	IN idin text
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getDictionaryValues' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT 0 AS Id, idin AS Code,
		sys_getDictionaryValue(idin, 'name'::text) AS Name,
		sys_getDictionaryValue(idin, 'names'::text) AS Names,
		sys_getDictionaryValue(idin, 'abbr'::text) AS Abbr,
		sys_getDictionaryValue(idin, 'rem'::text) AS Rem;

	RETURN result;
END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




CREATE OR REPLACE FUNCTION rcp_getDropEntities (
	IN HFolderIdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getDropEntities' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT DISTINCT hf2.ParentEntityId
    FROM HierarchyFolders hf
    JOIN HierarchyFolders hf2 ON hf2.HierarchyId = hf.HierarchyId
    	AND hf2.EntityId = hf.EntityId
    WHERE hf.Id = HFolderIdIn
    	AND hf2.ParentField IS NOT NULL
    	AND hf2.ChildField IS NOT NULL
    	AND hf2.ChildField NOT LIKE '=%'
    	AND hf2.ChildField NOT LIKE 'IN %';

    RETURN result;
END;
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
Get entity types (Entities) for caching on the client side. {Entities}
*/

CREATE OR REPLACE FUNCTION rcp_getEntities(
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getEntities' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
    SELECT Id,
    	Code,
    	sys_getDictionaryValue('Table.' || t.Code, 'name') AS Name,
        sys_getDictionaryValue('Table.' || t.Code, 'names') AS Names,
    	Decorator,
    	LookupCategory,
    	Type,
    	LookupHierarchyId,
    	isTranslatable,
    	Rem
    FROM Entities t
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;

    RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;




/**
Returns criteria for connecting two tied Entities based on hierarchies.
For object entities SELECTed from rcp_getFolders only.
*/
CREATE OR REPLACE FUNCTION sys_getCriteriaSQL(
	IN HFolderIdIn INTEGER, -- Id of child Hierarchy folder.
	IN ParentObjIdIn INTEGER
)
RETURNS TEXT AS

$BODY$
DECLARE
     _Result TEXT;
	 _ParentField TEXT;
	 _ChildField TEXT;
	 _CriteriaSQL TEXT;
	 _ParentEntityType TEXT;
	 _ChildEntityType TEXT;
	 _ChildTableName TEXT;
	 _ChildPropertyId INTEGER;
	 _ParentEntityId INTEGER;
	 _ChildEntityId INTEGER;
	 _ParentTableName TEXT;
	 _D String;
	 _ParentFieldValue TEXT;
	 _ChildFieldValue TEXT;
	 _PropertyId INTEGER;
	 _SQL TEXT;
	 _WorkingDate DATE := sys_getWorkingDate();

BEGIN
	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	SELECT hf.ParentField, hf.ChildField, hf.CriteriaSQL, pe.Type, e.Type,
		sys_getTableName(hf.ParentEntityId) AS ParentTableName,
		sys_getTableName(hf.EntityId) AS ChildTableName,
		hf.ParentEntityId, hf.EntityId
	INTO _ParentField, _ChildField, _CriteriaSQL, _ParentEntityType, _ChildEntityType,
		_ParentTableName, _ChildTableName, _ParentEntityId, _ChildEntityId
	FROM HierarchyFolders hf
	JOIN Entities e ON e.Id = hf.EntityId
	JOIN Entities pe ON pe.Id = hf.ParentEntityId
	WHERE hf.Id = HFolderIdIn;

	-- Default simple criteria.
	IF _CriteriaSQL IS NULL AND _ParentField IS NOT NULL THEN
		_CriteriaSQL := '%ParentField = %ChildField';
	END IF;

	-- Simple case.
	IF _CriteriaSQL IS NULL THEN -- No criteria.
		_Result := ' AND 1 = 1 ';

	ELSEIF _ParentField IS NULL AND _ChildField IS NULL THEN -- Simple Criteria.
		_Result := ' AND ' || _CriteriaSQL;

	ELSE -- Parent field value estimation.

		_ParentFieldValue := sys_getAttrValue(_ParentEntityId, ParentObjIdIn, _ParentField, _WorkingDate);

		IF _ChildField IS NOT NULL THEN-- Child field value estimation.
			IF _ChildEntityType IN ('HARD', 'VIEW') THEN -- Table Child Entities.
				_ChildFieldValue := _ChildTableName || '.' || _ChildField;

			ELSEIF _ChildEntityType = 'SOFT' THEN -- Object Child Entities.
				SELECT Id
				INTO _ChildPropertyId
				FROM EntityProperties
				WHERE EntityId = _ChildEntityId
					AND Code = _ChildField;

				-- Validate EntityProperties table content.
				IF _ChildPropertyId IS NULL THEN
					PERFORM sys_SignalException('InvalidMetadata', 'HierarchyFolders.ChildField' || '_HFolderId=' || HFolderIdIn || 'calculating _ChildPropertyId');
				END IF;

				-- _ParentFieldValue := _ParentTableName || '.' || _ParentField;
				-- FIXME: works for integer references only!!!
				_ChildFieldValue := $sql$
					(SELECT op.Value
					 FROM ObjectProperties op
					 WHERE op.ObjectId = Objects.Id
					   AND op.PropertyId = %_ChildPropertyId
					   AND op.DateFrom <= %_WorkingDate
					 ORDER BY op.DateFrom
					 DESC LIMIT 1)::INTEGER
				$sql$;
			END IF;
		END IF;

		_Result := _CriteriaSQL;
		_Result := REPLACE(_Result, '%ParentField', _ParentFieldValue);
		_Result := REPLACE(_Result, '%ChildField', COALESCE(_ChildFieldValue, ''));
		_Result := REPLACE(_Result, '%_ChildPropertyId', COALESCE(_ChildPropertyId::TEXT,''));
		_Result := REPLACE(_Result, '%_WorkingDate', '''' || _WorkingDate || '''');
		_Result := ' AND ' || _Result || E'\n';
	END IF;

	IF sys_ifTableHasField(_ChildTableName, 'DelDate') != 0 THEN
		_Result := _Result || ' AND (DelDate IS NULL OR DelDate > sys_getWorkingDate()) '
			|| E' AND InsDate <= sys_getWorkingDate() \n';
	END IF;

	PERFORM sys_DebugMessage('sys_getCriteriaSQL (HFolderIdIn=' || HFolderIdIn || ', ParentObjIdIn=' || ParentObjIdIn || E')\n'
		|| 'Result: ' || COALESCE(_Result, '<NULL>'));
	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;



/**
Get conditions to apply to WHERE clause of the given Entity for Hierarchic request.
*/

CREATE OR REPLACE FUNCTION sys_getHierConditions(
	IN EntityIdIn INTEGER,
	IN ParentValuesIn TEXT -- <EntityCode>.Id=<Value><Delimiter>...
)
RETURNS LongString AS

$BODY$
DECLARE
    entriez RECORD;
    _SQL TEXT = '';
	_D TEXT;
	_EntityCode TEXT;
	_EntityType TEXT;
	_ParentEntityCode TEXT;
	_ParentId INTEGER;
	_ChildFieldName TEXT;
	_ChildPropertyId INTEGER;

BEGIN

	PERFORM sys_debugMessage('CALLED sys_getHierConditions(EntityIdIn=' || EntityIdIn || ', ParentValuesIn=' || ParentValuesIn || ')');

	IF COALESCE(ParentValuesIn, '') = '' THEN
        RETURN '';
    END IF;

	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	SELECT Code, Type
	INTO _EntityCode, _EntityType
	FROM Entities WHERE Id = EntityIdIn;

	FOR entriez IN
		SELECT * FROM REGEXP_SPLIT_TO_TABLE(ParentValuesIn, _D) t(V) WHERE V != ''
	LOOP
		_ParentEntityCode := SPLIT_PART(SPLIT_PART(entriez.V, '=', 1), '.', 1);
		_ParentId := SPLIT_PART(entriez.V, '=', 2);

		IF _EntityType IN ('HARD', 'VIEW') THEN -- Check foreign keys.
			SELECT col.attname as column_name
			INTO _ChildFieldName
			FROM pg_constraint con
				JOIN pg_class tname  on tname.oid  = con.conrelid
				JOIN pg_class ftname on ftname.oid = con.confrelid
				JOIN pg_attribute col  on col.attnum  = any(con.conkey)  and col.attrelid  = con.conrelid
			WHERE con.contype = 'f'
			  AND tname.relname = _EntityCode
			  AND ftname.relname = _ParentEntityCode;
			--AND sfk.Primary_Creator = sys_getTableOwner()
			--AND sfk.Foreign_Creator = sys_getTableOwner()

			IF _ChildFieldName IS NOT NULL THEN
				_SQL := _SQL || ' AND '
					|| _EntityCode || '.' || _ChildFieldName|| '=' || _ParentId || E'\n';
			END IF;

		ELSEIF _EntityType = 'SOFT' THEN -- Check referencing EntityPpoperties.
			SELECT MIN(ep.Id)
			INTO _ChildPropertyId
			FROM EntityProperties ep
			JOIN Entities er ON er.Id = ep.RefEntityId
			WHERE ep.EntityId = EntityIdIn
				AND er.Code = _ParentEntityCode;

			IF _ChildPropertyId IS NOT NULL THEN
				_SQL := _SQL || ' AND ' || _ParentId::TEXT || E' = \n'
					|| E'(SELECT Value::INT \n'
					|| E' FROM ObjectProperties \n'
					|| E' WHERE ObjectId = Objects.Id \n'
					|| ' 	AND PropertyId = ' || _ChildPropertyId::TEXT || E' \n'
					|| E' 	AND DateFrom <= sys_getWorkingDate() \n'
					|| E' ORDER BY DateFrom DESC LIMIT 1) \n';
			END IF;
		END IF;
	END LOOP;

	PERFORM sys_debugMessage('sys_getHierConditions result: ' || COALESCE(_SQL, '<NULL>'));
	RETURN _SQL;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;




/**
 * Returns child count of the specified folder.
 */
CREATE OR REPLACE FUNCTION rcp_getFolderChildCount(
    IN HFolderIdIn INTEGER, -- Current hierarchy.
	IN ParentObjIdIn INTEGER, -- Parent Object id.
	IN ParentValuesIn TEXT
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = uuid_generate_v1();
	_ChildEntityId INTEGER;
	_ChildEntityType TEXT;
	_ChildTableName TEXT;
	_SQL TEXT;

BEGIN
	SELECT hf.EntityId INTO _ChildEntityId
	FROM HierarchyFolders hf WHERE hf.Id = HFolderIdIn;

	_ChildTableName := sys_getTableName(_ChildEntityId)
	;
	SELECT e.Type INTO _ChildEntityType
	FROM Entities e WHERE e.Id = _ChildEntityId;

	_SQL := 'SELECT COUNT(*) AS ChildCount '
		|| 'FROM ' || _ChildTableName || ' '
		|| 'WHERE 1 = 1 '	|| COALESCE(sys_getCriteriaSQL(HFolderIdIn, ParentObjIdIn), '')
		|| E'\n';

	IF _ChildEntityType = 'SOFT' THEN
		_SQL := _SQL || ' AND EntityId = ' || _ChildEntityId || E'\n';
	END IF;

	-- Hierarchic query.
	IF COALESCE(ParentValuesIn, '') != '' THEN
		_SQL := _SQL || COALESCE(sys_getHierConditions(_ChildEntityId, ParentValuesIn), '');
	END IF;

	PERFORM sys_debugMessage('rcp_getFolderChildCount: ' || COALESCE(_SQL, '<NULL>'));
	OPEN result FOR EXECUTE _SQL;
	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;




/**
 * Returns folders of given db object to client app.
 */
CREATE OR REPLACE FUNCTION rcp_getFolders (
    IN HierarchyIdIn INTEGER, -- Current hierarchy.
	IN EntityIdIn INTEGER, -- Entity of the parent Object.
	IN ObjIdIn INTEGER -- Parent Object id.
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	_ChildCount INTEGER;
	_SQL LongestString;
	_AllSQL LongestString;
	_UnionAll VARCHAR(16);
	_ParentEntityType String;

	result REFCURSOR = 'rcp_getFolders' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();
	folderz RECORD;

BEGIN
	SELECT Type INTO _ParentEntityType
	FROM Entities WHERE Id = EntityIdIn;

	_AllSQL := '';
	_UnionAll := E'UNION ALL\n';

	FOR folderz IN
		-- History folder in Details section of the form for Object entities.
		SELECT -2 AS Id, 'DETAILS' AS Type, e.Id AS ChildEntityId,
			'Id' AS ParentField, 'ObjectId' AS ChildField,
			sys_getDictionaryValue('GUI.Editor.Details.HistorySection') AS FolderName,
			NULL AS Hint, 0 AS FormId, 0 AS Priority
		FROM Entities e, Entities e2
		WHERE e.Code = 'ObjectProperties'
			AND e2.Id = EntityIdIn
			AND e2.Type = 'SOFT'
		-- Tags folder in Details section of the form.
		UNION ALL
		SELECT -1 AS Id, 'DETAILS' AS Type, e.Id AS ChildEntityId,
			'Id' AS ParentField,
			CASE WHEN _ParentEntityType = 'SOFT' THEN 'ObjectId' ELSE 'RowId' END AS ChildField,
			sys_getDictionaryValue('GUI.Editor.Details.TagsSection') AS FolderName,
			'{PropertyId:CCombo Restrict EntityId=' || EntityIdIn || ',PropGroup=Tags}' AS Hint,
			0 AS FormId, 0 AS Priority
		FROM Entities e
		WHERE EXISTS (SELECT 1 FROM EntityProperties WHERE EntityId = EntityIdIn AND PropGroup = 'Tags')
			AND e.Code = 'ObjectProperties'
		-- Common folders.
		UNION ALL
		SELECT hf.Id, hf.Type, hf.EntityId AS ChildEntityId,
			hf.ParentField, hf.ChildField,
			sys_getDictionaryValue(COALESCE(hf.Code, 'Table.' || t.Code),
					CASE WHEN hf.Code IS NULL THEN 'names' ELSE 'name' END
			) AS FolderName,
			hf.Hint, 0 AS FormId, hf.Priority --TODO: Use hf.FormId
		FROM HierarchyFolders hf -- Current node.
		JOIN Entities t ON t.Id = hf.EntityId
		WHERE hf.HierarchyId = HierarchyIdIn
			AND hf.ParentEntityId = EntityIdIn
		ORDER BY Type, Priority, Id
	LOOP
--PERFORM sys_DebugMessage('Id: ' || folderz.Id);

		-- Final query.
		_SQL := 'SELECT $Id, $Type, $EntityId, $Decorator, '
			|| '$ParentField, $ChildField, $FormId, $Hint, $Priority ';

--PERFORM sys_DebugMessage('_mySQL BEFORE: ' || COALESCE(_mySQL, 'NulL'));

		_SQL := REPLACE(_SQL, '$Id', folderz.Id || ' AS Id');
		_SQL := REPLACE(_SQL, '$Type', '''' || COALESCE(folderz.Type, '') || ''' AS Type');
		_SQL := REPLACE(_SQL, '$EntityId', COALESCE(folderz.ChildEntityId, 0) || ' AS EntityId');
		_SQL := REPLACE(_SQL, '$Decorator', QUOTE_NULLABLE(folderz.FolderName) || ' AS Decorator');
		_SQL := REPLACE(_SQL, '$ParentField', QUOTE_NULLABLE(folderz.ParentField) || ' AS ParentField');
		_SQL := REPLACE(_SQL, '$ChildField', QUOTE_NULLABLE(folderz.ChildField) || ' AS ChildField');
		_SQL := REPLACE(_SQL, '$FormId', COALESCE(folderz.FormId, 0) || ' AS FormId');
		_SQL := REPLACE(_SQL, '$Hint', QUOTE_NULLABLE(folderz.Hint) || ' AS Hint');
		_SQL := REPLACE(_SQL, '$Priority', COALESCE(folderz.Priority, 0) || ' AS Priority');
		_SQL := _SQL || E'\n' || _UnionAll;

--PERFORM sys_DebugMessage('MySQL AFTEr: ' || COALESCE(_mySQL, ''));
		_AllSQL := _AllSQL || _SQL;
	END LOOP;


	IF COALESCE(_AllSQL, '') != '' THEN
		-- Executing Total UNION'ed query.
		_AllSQL := SUBSTRING(_AllSQL FOR LENGTH(_AllSQL) - LENGTH(_UnionAll));
		_AllSQL := _AllSQL || ' ORDER BY Type, Priority, Id ';

	--	SELECT Type INTO _HierarchyType
	--	FROM Hierarchies WHERE Id = HierarchyIdIn
	--	;
	--	IF _HierarchyType = 'System' THEN -- Hide empty folders for lookup hierarchies.
	--		_SQL := 'SELECT Id, Type, EntityID, Decorator, ParentField, ChildField, FormId, Hint '
	--			|| 'FROM (' || _SQL || ') t '
	--			|| 'WHERE ChildCount > 0 ';
	--	END IF;
	ELSE
		_AllSQL := 'VALUES(NULL) LIMIT 0';
	END IF;

	PERFORM sys_DebugMessage('rcp_getFolders: ' || _AllSQL);
	OPEN result FOR EXECUTE _AllSQL;
	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Client wrapper for sys_getFormConstrols.
*/
CREATE OR REPLACE FUNCTION rcp_getFormControls (
    IN FormIdIn INTEGER
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getFormControls' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getFormControls(FormIdIn);

	RETURN result;
END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
*/
CREATE OR REPLACE FUNCTION rcp_getForms(
    IN IdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getForms';

BEGIN
	-- Real Form.
    IF SIGN(IdIn) >= 0 THEN
		OPEN result FOR
		SELECT Id, 'Real'::text , Code
			, sys_getDictionaryValue('Form.' || Name, 'Name') AS "Name"
			, sys_getDictionaryValue('Form.' || Rem, 'Rem') AS "Rem"
	    FROM Forms
	    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
		ORDER BY Name;

	-- Virtual Form.
	ELSE
		OPEN result FOR
		SELECT -Id , 'Virtual'::text , Code
			, sys_getDictionaryValue('Table.' || t.Code, 'Name') AS "Name"
			, sys_getDictionaryValue('Table.' || t.Code, 'Rem') AS "Rem"
	    FROM Entities t
	    WHERE Id = IdIn;
	END IF;
END;
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
	Returns hierarchies. {Hierarchies}
*/
CREATE OR REPLACE FUNCTION rcp_getHierarchies (
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getHierarchies';

BEGIN
	OPEN result FOR
    SELECT Id, Code,
    	sys_getDictionaryValue('TableRows.Hierarchies.' || Code) AS Name,
    	Rem, Type
    FROM Hierarchies
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    --Id = IdIn OR (COALESCE(IdIn, 0) = 0 AND sys_inRM(rm_mask))
    ORDER BY Priority;

    RETURN result;
END
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
	Get HierarchyFolders.
*/

CREATE OR REPLACE FUNCTION rcp_getHierarchyFolders (
	IN idin integer DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getHierarchyFolders';

BEGIN
	OPEN result FOR
	SELECT Id,
		   HierarchyId,
		   Code,
		   ParentEntityId,
		   ParentField,
		   EntityId,
		   ChildField,
		   CriteriaSQL,
		   Hint,
		   Action,
		   isSelectable
    FROM HierarchyFolders
    WHERE Id = idin OR COALESCE(idin, 0) = 0
    ORDER BY Priority;

    RETURN result;
END;
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
Returns db objects to client app.
*/

CREATE OR REPLACE FUNCTION rcp_getObjects (   -- |Table-many |Table-1 | Lookup |Objects-many | Objects-1 | Tags
    IN HFolderIdIn INTEGER, 		-- | >0        | >0     | 0      | >0          | >0		   | < 0
    IN ParentEntityIdIn INTEGER,   -- Used when HFolderIdIn <=0 (unknown), e.g. for Tags, etc.
    IN ParentObjIdIn INTEGER,      -- | >0        | ignore | ignore | >0          | ignore
	IN EntityIdIn INTEGER,         -- | >0        | >0     | >0     | >0          | >0
	IN ObjIdIn INTEGER,            -- | 0         | >0     | 0, >0  | 0           | >0
	IN ParentValuesIn TEXT   -- | yes       | no     | no	 | no	       | no
	-- If ObjIdIn > 0 - single object returned.
	-- ParentValuesIn: <EntityCode>.Id=<Value><Delimiter>...
)
RETURNS REFCURSOR AS
/*
RETURNS TABLE (
	Id INTEGER,
	AttrStr TEXT,
	HasChildren BOOLEAN,
	Revision INTEGER,
	IsEditable String,
	InsDate Date,
	DelDate DATE ) */

$BODY$

DECLARE

	 result REFCURSOR = 'rcp_getObjects';

	 _SQLState String;
     _ErrorMsg LongString;
     _ProcId INTEGER;

     _TableName String := sys_getTableName(EntityIdIn);
	 _OrderBy LongestString;
     _ParentEntityId INTEGER;
	 _EntityCode String;
	 _EntityType TEXT;
	 _CriteriaSQL LongestString;
     _SQL CITEXT;
     _Conditions LongestString;
     _D String;
     _LastPos INTEGER;
     _CurPos INTEGER;
     _Str LongestString;
     _ParentEntityCode String;
     _ParentEntityType String;
     _ParentTableName String := sys_getTableName(ParentEntityIdIn);
     _ParentId INTEGER;
     _ParentFieldName String;
	 _ChildFieldName String;
     _ChildPropertyId INTEGER;
     _HintedRefEntityId INTEGER;
     _HintedPropertyId INTEGER;
     _HintedValue LongString;
     _HasChildren BOOLEAN;
     _ParentField String;
     _ChildField String;
	 _WorkingDate DATE := sys_getWorkingDate();
	 _ParentFieldValue String;
	 _Condition String;

BEGIN

	-- TODO: Add security handling here!!!

	SELECT e.Type, REPLACE(e.OrderBy, '%t', _TableName::text)
    INTO _EntityType, _OrderBy
    FROM Entities e WHERE e.Id = EntityIdIn ;

    SELECT e.Type INTO _ParentEntityType
    FROM Entities e WHERE e.Id = ParentEntityIdIn;

    SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	/*
	======================================
     From Now - For Tags and History.
     They are not working-date dependant.
	======================================
	*/
	IF HFolderIdIn < 0 THEN

		-- Dynamic SQL for getting ObjectProperties by ObjectId or RowId.
		_SQL :=
		$sql$
			SELECT op.Id,
			COALESCE(op.ObjectId::TEXT, '') || %D% || COALESCE(op.RowId::TEXT, '') || %D% || op.DateFrom || %D% || op.PropertyId::TEXT || %D% || COALESCE(op.Value, '') || %D% AS AttrStr,
			FALSE AS HasChildren, op.Revision,
			sys_ObjectIsEditable(o.EntityId, o.Id, _WorkingDate, op.DateFrom, o.InsDate, o.DelDate) AS IsEditable,
			o.InsDate, (CASE WHEN o.DelDate <= _WorkingDate THEN o.DelDate ELSE NULL::DATE END) AS DelDate
			FROM ObjectProperties op
			JOIN %ParentTable o ON o.Id = op.%RowId
			WHERE op.%RowId = ParentObjIdIn
			%Condition
			ORDER BY op.DateFrom, op.Id
		$sql$ ;

		IF _ParentEntityType = 'SOFT' THEN
			_SQL := REPLACE(_SQL, '%RowId', 'ObjectId');
		ELSIF _ParentEntityType IN ('HARD', 'VIEW') THEN
			_SQL := REPLACE(_SQL, '%RowId', 'RowId');
			_SQL := REPLACE(_SQL, '%ParentTable',
				'(SELECT ParentEntityIdIn AS EntityId, Id, %InsDate, %DelDate FROM %ParentTable WHERE Id = ParentObjIdIn) ');

			IF sys_ifTableHasField(_TableName, 'DelDate') != 0 THEN
				_SQL := REPLACE(_SQL, '%InsDate', 'InsDate');
				_SQL := REPLACE(_SQL, '%DelDate', 'DelDate');
			ELSE
				_SQL := REPLACE(_SQL, '%InsDate', 'NULL::DATE AS InsDate');
				_SQL := REPLACE(_SQL, '%DelDate', 'NULL::DATE AS DelDate');
			END IF;
		END IF;

		IF HFolderIdIn = -1 THEN -- Tags.
			_Condition := 'AND op.PropertyId IN (SELECT Id FROM EntityProperties WHERE EntityId = ParentEntityIdIn AND PropGroup = ''Tags'')' ;
		ELSE -- History.
			_Condition := '';
		END IF;

		_SQL := REPLACE(_SQL, '%ParentTable', _ParentTableName);
		_SQL := REPLACE(_SQL, '%D%', '''' || _D || '''');
		_SQL := REPLACE(_SQL, 'ParentObjIdIn', ParentObjIdIn::TEXT);
		_SQL := REPLACE(_SQL, '%Condition', _Condition);
		_SQL := REPLACE(_SQL, 'ParentEntityIdIn', ParentEntityIdIn::TEXT);
		_SQL := REPLACE(_SQL, '_WorkingDate', '''' || _WorkingDate || '''');

		PERFORM sys_DebugMessage('rcp_getObjects: ' || COALESCE(_SQL, '') );
    	OPEN result FOR EXECUTE _SQL;
		RETURN result;
	END IF;

	/*
	================================================
     From Now - Common for NOT (Tags and History).
	================================================
	*/

	-- Determine HasChildren.
	IF EXISTS(SELECT 1 FROM HierarchyFolders hf -- Current folder.
				JOIN HierarchyFolders hf2 ON hf.HierarchyId = hf2.HierarchyId -- Child folders.
					AND hf2.ParentEntityId = hf.EntityId
					AND hf2.Type = 'TREE'
				WHERE hf.Id = HFolderIdIn) THEN
		_HasChildren := TRUE;
	ELSE
		_HasChildren := FALSE;
	END IF;

	/*
	================================================
     From Now - For Object and Table entities.
	================================================
	*/
	_SQL :=
	$sql$
		SELECT Id, %AttrStr AS AttrStr,
			   _HasChildren AS HasChildren, Revision,
			   sys_ObjectIsEditable(EntityIdIn, Id, _WorkingDate, NULL, %InsDate, %DelDate) AS IsEditable,
			   %InsDate::Date AS InsDate, %DelDate::Date AS DelDate
		FROM %TableName
		WHERE 1=1 %Conditions
		ORDER BY %OrderBy
	$sql$;
	_Conditions := '';

	IF COALESCE(ObjIdIn,0) > 0 THEN -- One object.
		_Conditions := ' AND Id = ObjIdIn';
	ELSE -- Many objects.
		IF _EntityType = 'SOFT' THEN
			_Conditions := ' AND EntityId = EntityIdIn';
		END IF;

    	IF HFolderIdIn > 0 THEN -- non-lookup (conditional) queries.
			_Conditions := _Conditions || sys_getCriteriaSQL(HFolderIdIn, ParentObjIdIn);
            IF COALESCE(ParentValuesIn, '') != '' THEN -- Hierarhic SQL.
				_Conditions := _Conditions || sys_getHierConditions(EntityIdIn, ParentValuesIn);
            END IF;
        END IF;
    END IF;

	-- Final SQL preparation.
	_SQL := REPLACE(_SQL, '_HasChildren', _HasChildren::CITEXT);
	_SQL := REPLACE(_SQL, '%AttrStr', sys_getAttrList(EntityIdIn, NULL));
	IF sys_ifTableHasField(_TableName, 'DelDate') != 0 THEN
		_SQL := REPLACE(_SQL, '%InsDate', 'InsDate');
		_SQL := REPLACE(_SQL, '%DelDate', 'CASE WHEN DelDate <= _WorkingDate THEN DelDate ELSE NULL END');
	ELSE
		_SQL := REPLACE(_SQL, '%InsDate', 'NULL');
		_SQL := REPLACE(_SQL, '%DelDate', 'NULL');
	END IF;
	_SQL := REPLACE(_SQL, '%TableName', _TableName);
	_SQL := REPLACE(_SQL, '%Conditions', _Conditions);
	_SQL := REPLACE(_SQL, '%OrderBy', COALESCE(_OrderBy, '1'));
	_SQL := REPLACE(_SQL, '_WorkingDate', '''' || _WorkingDate || '''');
	_SQL := REPLACE(_SQL, 'EntityIdIn', EntityIdIn::text);
	_SQL := REPLACE(_SQL, 'ObjIdIn', COALESCE(ObjIdIn,0)::text);

	PERFORM sys_DebugMessage('rcp_getObjects: ' || coalesce(_SQL,'') );
    OPEN result FOR EXECUTE _SQL;
    RETURN result;

END;

$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;

-- TEST CASES

--HARD

-- select * from rcp_getObjects(1, NULL, NULL, 10, NULL, NULL); -- Departments
-- select * from rcp_getObjects(0, NULL, NULL, 10, NULL, NULL); -- Departments LookUp
-- select * from rcp_getObjects(1, NULL, NULL, 10, 1, NULL); -- Departments Id = 1
-- select * from rcp_getObjects(0, NULL, NULL, 10, 1, NULL); -- Departments Id = 1 LookUp
-- select * from rcp_getObjects(-1, 18, 1, 35, NULL, NULL); -- Consumers get Tags

-- SOFT

-- select * from rcp_getObjects(1, 12, 36, 13, NULL, NULL); -- Houses
-- select * from rcp_getObjects(0, 12, 36, 13, NULL, NULL); --  Houses LookUp
-- select * from rcp_getObjects(1, 12, 36, 13, 16180, NULL); -- Houses id = 16180
-- select * from rcp_getObjects(0, 12, 36, 13, 16180, NULL); -- Houses id = 16180 LookUp
-- select * from rcp_getObjects(-1, 14, 6185, 35, NULL, NULL); -- Places get Tags
-- select * from rcp_getObjects(-2, 13, 16180, 35, NULL, NULL); -- Houses Id = 1 get History




/**
	Get Parent Entities
*/

CREATE OR REPLACE FUNCTION rcp_getparententities(
	IN _HierarchyIdIn INTEGER,
	IN _ChildEntityIdIn INTEGER,
	IN _ChildFieldIn TEXT
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getparententities';

BEGIN
	OPEN result FOR
	SELECT DISTINCT hf.ParentEntityId AS EntityId
	FROM HierarchyFolders hf
	WHERE hf.HierarchyId = _HierarchyIdIn
		AND hf.ChildField = _ChildEntityIdIn
		AND hf.EntityId = _ChildFieldIn;
END;

$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;




/**
Get Preferences list for caching on the client side.
*/

CREATE OR REPLACE FUNCTION rcp_getprefs (
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getprefs';

BEGIN
	OPEN result FOR
	SELECT Id, Code, DataType, Rem
    FROM Prefs
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;
END;

$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;



/**
Client wrapper for sys_getPrefValue.
*/
CREATE OR REPLACE FUNCTION rcp_getPrefValue (
    IN IdIn Text
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getPrefValue';

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getPrefValue(IdIn);

	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Get queries used by client app.
*/
CREATE OR REPLACE FUNCTION rcp_getRCPQueries()
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getRCPQueries';
	procs RECORD;
	paramz RECORD;
	_paramList TEXT;

BEGIN

	CREATE TEMPORARY TABLE tmp (procName TEXT, paramList TEXT, returnType TEXT) ON COMMIT DROP;

	FOR procs IN
		SELECT r.specific_schema, r.specific_name, r.routine_name AS procName, r.data_type AS returnType
		FROM information_schema.routines r
		WHERE r.specific_schema = 'public'
			AND r.routine_name LIKE 'rcp%'
		ORDER BY r.routine_name
	LOOP
		_paramList := NULL;

		FOR paramz IN
			SELECT p.parameter_mode, p.parameter_name, p.udt_name
			FROM information_schema.parameters p
			WHERE p.specific_schema = procs.specific_schema
				AND p.specific_name = procs.specific_name
			ORDER BY p.ordinal_position
		LOOP
			_paramList := COALESCE(_paramList, '')
				|| '{mode=' || paramz.parameter_mode
				|| ', name=' || paramz.parameter_name
				|| ', type=' || paramz.udt_name
				|| '} ';
		END LOOP;

		INSERT INTO tmp(procName, paramList, returnType)
		VALUES (procs.procName, _paramList, procs.returnType);
	END LOOP;

	OPEN result FOR
	SELECT * FROM tmp
	;
	RETURN result;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_getRCPQueries');
	RAISE;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;

/*
BEGIN;
SELECT rcp_getRCPQueries();
FETCH ALL IN "rcp_getRCPQueries";
END;
*/





/**
 * Returns calculated data for the report engine.
 */
CREATE OR REPLACE FUNCTION rcp_getReportData (
	IN ReportCodeIn TEXT
)
RETURNS SETOF RECORD AS

$BODY$
DECLARE
    rec RECORD;
	_ReportSQL TEXT;
	_CalcTypeId INTEGER;
	_CalcId INTEGER;
	_ReportTable TEXT;

BEGIN

	SELECT r.CalcTypeId, r.ReportSQL
	INTO _CalcTypeId, _ReportSQL
	FROM Reports r
	WHERE LOWER(r.Code) = LOWER(ReportCodeIn);

	IF _CalcTypeId IS NOT NULL THEN -- Calculational procedures.

	    -- See rcp_getReportInfo - the same code.
        SELECT Id
        INTO _CalcId
        FROM Calculations c
        WHERE CalcTypeId = _CalcTypeId
            AND State = 'OK'
            AND DateFrom <= sys_getWorkingDate()
        ORDER BY (sys_getWorkingDate() - DateFrom)
        LIMIT 1
        ;

        IF _CalcId IS NULL THEN
            PERFORM sys_signalException('EmptyReport: %s ON %s', COALESCE(ReportCodeIn, 'NULL') || E'\\d' || sys_getWorkingDate());
        END IF;

		_ReportSQL := REPLACE(_ReportSQL, '%result%', sys_getCalcTableName('out', _CalcId));
        _ReportTable := sys_getCalcTableName('_rpt_' || ReportCodeIn, _CalcId);

    ELSE -- Non-calculational report.
	   _ReportTable := 'z_rpt_' || ReportCodeIn;
	END IF;

    IF sys_ifTableExists(_ReportTable) != 0 THEN
        EXECUTE 'DROP TABLE ' || _ReportTable;
    END IF;

    EXECUTE 'CREATE TABLE ' || _ReportTable || ' AS ' || _ReportSQL;
    EXECUTE 'GRANT SELECT ON TABLE ' || _ReportTable || ' TO public';

	PERFORM sys_DebugMessage('ReportSQL:' || _ReportSQL);
    RETURN QUERY EXECUTE 'SELECT * FROM ' || _ReportTable;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
 * Report detailed info.
 */
CREATE OR REPLACE FUNCTION rcp_getReportInfo (
    IN ReportIdIn INTEGER,
    IN CalcIdIn INTEGER
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getReportInfo';
	_ReportCode TEXT;
	_ReportName TEXT;
	_CalcTypeId INTEGER;
	_CalcId INTEGER;
	_DateFrom DATE;
	_DateTo DATE;
	_ReportSQL TEXT;
	_JrXML TEXT;

BEGIN
	SELECT r.Code, sys_getDictionaryValue('TableRows.Reports.' || r.Code),
	   r.CalcTypeId, r.ReportSQL, r.JrXml
	INTO _ReportCode, _ReportName, _CalcTypeId, _ReportSQL, _JrXML
	FROM Reports r
	WHERE r.Id = ReportIdIn;

	IF _CalcTypeId IS NULL THEN -- Non-calculational.
		_DateFrom := sys_getWorkingDate();
		_DateTo := NULL;

	ELSE -- Calculational.
		IF COALESCE(CalcIdIn, 0) = 0 THEN -- Find CalcId.
			-- See rcp_getReportData - the same code.
			SELECT c.Id
			INTO _CalcId
			FROM Calculations c
			WHERE c.CalcTypeId = _CalcTypeId
				AND c.State = 'OK'
				AND c.DateFrom <= sys_getWorkingDate()
			ORDER BY (sys_getWorkingDate() - c.DateFrom)
			LIMIT 1;
		ELSE
			_CalcId := CalcIdIn;
		END IF;

		SELECT DateFrom, DateTo
		INTO _DateFrom, _DateTo
		FROM Calculations
		WHERE Id = _CalcId;
	END IF;

	OPEN result FOR
	SELECT _ReportCode AS ReportCode, _ReportName AS ReportName,
		_CalcTypeId AS CalcTypeId, _DateFrom AS DateFrom, _DateTo AS DateTo,
		_ReportSQL AS ReportSQL, _JrXML AS JrXML;

	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



CREATE OR REPLACE FUNCTION rcp_getRM()
  RETURNS INT AS
$BODY$
DECLARE
	_Result INT;
BEGIN
	SELECT pv.Value::INT
	INTO _Result
	FROM PrefValues pv
	JOIN Prefs p ON p.Id = pv.PrefId
	WHERE p.Code = 'System.rm'
		AND pv.UserId = sys_getUserId() ;

	IF _Result IS NULL THEN
		_Result := 1;
	END IF;

	RETURN _Result;
END;
$BODY$
  LANGUAGE 'plpgsql' IMMUTABLE SECURITY DEFINER
  COST 100;





/**
Returns Task state for given TaskId
*/
CREATE OR REPLACE FUNCTION rcp_getTaskState (
	IN  TaskIdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getTaskState';

BEGIN
	OPEN result FOR
	SELECT t.State, t.Progress, t.ProgressRem, tt.ProgressMax
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE (t.Id = TaskIdIn OR COALESCE(TaskIdIn, 0) = 0);

	RETURN result;
END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;



CREATE OR REPLACE FUNCTION rcp_setRM (IN valuein text, OUT prefvalueidout integer)
  RETURNS integer AS
$BODY$
DECLARE
	_PrefId INTEGER;
	_PrefType TEXT;
	_UserId INTEGER;
	_IsAdmin BOOLEAN;

BEGIN
	_UserId := sys_getUserId();

	SELECT Id, Type INTO _PrefId, _PrefType
	FROM Prefs WHERE Code = 'System.rm';

	UPDATE PrefValues pv
	SET Value = ValueIn
	WHERE pv.PrefId = _PrefId
		AND COALESCE(pv.UserId, 0) = COALESCE(_UserId, 0)
	RETURNING pv.Id INTO PrefValueIdOut;

	IF NOT FOUND THEN
		INSERT INTO PrefValues(PrefId, UserId, Value, DateFrom)
		VALUES (_PrefId, _UserId, ValueIn, NULL /*DateFromIn*/);

		PrefValueIdOut := CURRVAL('prefvalues_id_seq');
	END IF;

END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER
  COST 100;




/**
Creates the new task.
*/
CREATE OR REPLACE FUNCTION rcp_taskCancel (
	IN TaskIdIn INTEGER,
	IN ReasonIn TEXT,
	OUT ResultOut INTEGER -- Dummy Field
) RETURNS INTEGER AS

$BODY$
DECLARE
    _SQLState TEXT;
    _ErrorMsg TEXT;
    _ProcId INTEGER;
    _SubjectId INTEGER;

    _TypeCode TEXT;

BEGIN
	UPDATE Tasks
	SET State = 'CANCELLED',
		ProgressRem = ProgressRem || E'\n' || _ReasonIn
	WHERE Id = _TaskIdIn;

	-- Update Calculations. FIXME: HardCode!!!
	SELECT tt.Code, t.SubjectId
	INTO _TypeCode, _SubjectId
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE t.Id = _TaskIdIn
	;
	IF _TypeCode = 'Calculations' THEN
		UPDATE Calculations
		SET State = 'Cancelled'
		WHERE Id = _SubjectId;
	END IF;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_taskCancel');
	RAISE;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
Creates the new task.
*/
CREATE OR REPLACE FUNCTION rcp_taskStart (
	IN  TypeCodeIn TEXT,
	IN  SubjectIdIn INTEGER,
	IN  DescriptionIn TEXT,
	OUT TaskIdOut INTEGER
)
RETURNS INTEGER AS

$BODY$
BEGIN

	INSERT INTO Tasks(TypeId, State, Progress, SubjectId, Description)
	SELECT tt.Id, 'PRISTINE', 0, SubjectIdIn, DescriptionIn
	FROM TaskTypes tt
	WHERE tt.Code = TypeCodeIn
	RETURNING Tasks.Id INTO TaskIdOut;

END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;




/**
Add new field to results table.
Before invocation of the procedure tmp_calc_<id> table should be filled with rcp_Calculate()
*/

CREATE OR REPLACE FUNCTION sys_calcAddResultField(
	IN CalcIdIn INTEGER,
	IN FieldNameIn String
)
RETURNS VOID AS

$BODY$
DECLARE
	_SQL LongString;
BEGIN

	IF sys_ifTableHasField(sys_getResultTableName(_CalcIdIn), _FieldNameIn) = 0 THEN
		_SQL := 'ALTER TABLE ' || sys_getResultTableName(_CalcIdIn) || ' ADD (' || _FieldNameIn || ' String)';
		EXECUTE _SQL;
	END IF;

END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;



/**
 * Return Table of Addresses for all heat objects (Houses and Places).
 */
CREATE OR REPLACE FUNCTION sys_getAddresses(
	IN DateIn DATE DEFAULT sys_getWorkingDate()
)
RETURNS TABLE (
	ObjectId INTEGER,
	Address TEXT,
	PlaceCode TEXT
) AS

$BODY$

    -- Houses.
    SELECT o.Id AS ObjectId,
        st.code || ' ' || s.name || ', ' || COALESCE(o.Code, '') AS Address, '' AS PlaceCode
    FROM Objects o -- Houses.
    JOIN Entities e ON e.Id = o.EntityId
    LEFT JOIN Streets s ON s.Id = ( --sys_getAttrValue(NULL, o.Id, 'StreetId', $1)::INT
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = o.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Houses' AND ep.Code = 'StreetId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    LEFT JOIN StreetTypes st ON st.Id = s.StreetTypeId
    WHERE e.Code = 'Houses'

    -- Places
    UNION ALL
    SELECT o.Id AS ObjectId,
        st.code || ' ' || s.name || ', ' || COALESCE(h.Code, '') AS Address,
        COALESCE(o.Name, '') || ' ' || COALESCE(o.Code, '') AS PlaceCode
    FROM Objects o -- Places.
    JOIN Entities e ON e.Id = o.EntityId
    JOIN Objects h ON h.Id = ( --sys_getAttrValue(NULL, o.Id, 'HouseId', $1)::INT -- Houses.
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = o.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Places' AND ep.Code = 'HouseId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    JOIN Streets s ON s.Id = ( --sys_getAttrValue(NULL, h.id, 'StreetId', $1)::INT
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = h.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Houses' AND ep.Code = 'StreetId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    JOIN StreetTypes st ON st.Id = s.StreetTypeId
    WHERE e.Code = 'Places';

$BODY$

LANGUAGE SQL
SECURITY DEFINER
COST 10;




/**
 * Returns results for given calctype for current working date
 */
CREATE OR REPLACE FUNCTION sys_getCalcResults(
	CalcTypeCodeIn TEXT
)
RETURNS TABLE (
	ObjectId INTEGER,
	ServiceId INTEGER,
	PayerId INTEGER,
	DateFrom DATE,
	DateTo DATE,
	Days NUMBER,
	Value NUMBER,
	Tariff NUMBER,
	Money NUMBER,
	Rem LONGESTSTRING
) AS

$BODY$
DECLARE
    _CalcTypeId INTEGER;
    _CalcId INTEGER;
    _WorkingDate DATE := sys_getWorkingDate();
    _SQL CITEXT;
BEGIN

	SELECT Id
	INTO _CalcTypeId
	FROM CalcTypes
	WHERE Code = CalcTypeCodeIn;

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || 'CalcTypeCodeIn = ' || coalesce(CalcTypeCodeIn::TEXT,'') );
	PERFORM sys_DebugMessage('sys_getCalcResults: ' || '_CalcTypeId = ' || coalesce(_CalcTypeId::TEXT,'') );

	SELECT Id
	INTO _CalcId
	FROM Calculations
	WHERE CalcTypeId = _CalcTypeId
	--AND _WorkingDate BETWEEN DateFrom AND DateTo
	ORDER BY Id DESC
	LIMIT 1;

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || 'WorkingDate = ' || coalesce(sys_getWorkingDate()::TEXT,'') );
	PERFORM sys_DebugMessage('sys_getCalcResults: ' || '_CalcId = ' || coalesce(_CalcId::TEXT,'') );

	--ObjectId, ServiceId, PayerId, DateFrom, DateTo, Days, Value, Tariff, Money, Rem
    _SQL := $sql$
    	SELECT
		ObjectId,
		ServiceId,
		PayerId,
		DateFrom,
		DateTo,
		Days,
		Value,
		Tariff,
		Money,
		Rem
    	FROM z_calc_%_CalcId%_out
    $sql$ ;

    _SQL := REPLACE(_SQL, '%_CalcId%', _CalcId::TEXT);

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || coalesce(_SQL,'') );

	IF _SQL IS NOT NULL THEN
		RETURN QUERY EXECUTE _SQL;
	END IF;


END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER
COST 10;




/**
Returns parent objects for current one (including that one).
Level = 0 for callee object.
Uses 'ParentId' as "parent" attribute.
*/

CREATE OR REPLACE FUNCTION sys_getParentObjects(
	ObjectIdIn INTEGER,
	DateFromIn DATE
)
RETURNS TABLE (
	ObjectId INTEGER,
	ParentId INTEGER,
	Level INTEGER,
	DateFrom DATE
) AS

$BODY$
DECLARE

	_ObjectId INTEGER := ObjectIdIn;
	_ParentId INTEGER := 0;
	_Level INTEGER := 0;
	_DateFrom DATE;

	_resultObjectIds INTEGER[];
	_resultParentIds INTEGER[];
	_resultLevels INTEGER[];
	_resultDateFroms DATE[];

BEGIN

	WHILE _ParentId IS NOT NULL LOOP
		_ParentId := NULL;

		SELECT op.DateFrom, CAST(op.Value AS INTEGER)
		INTO _DateFrom, _ParentId
		FROM Objects o
		JOIN ObjectProperties op ON op.ObjectId = o.Id
			AND op.DateFrom <= DateFromIn
		JOIN EntityProperties ep ON ep.Id = op.PropertyId
			AND ep.EntityId = o.EntityId
			AND ep.Code = 'ParentId'
		WHERE o.Id = _ObjectId
			AND (o.DelDate IS NULL OR o.DelDate > DateFromIn)
			AND o.InsDate <= DateFromIn
		ORDER BY op.DateFrom DESC
		LIMIT 1;

		_resultObjectIds := _resultObjectIds || _ObjectId;
		_resultParentIds := _resultParentIds || _ParentId;
		_resultLevels    := _resultLevels || _Level;
		_resultDateFroms := _resultDateFroms || _DateFrom;

		_Level := _Level + 1;
		_ObjectId := _ParentId;
	END LOOP;

	RETURN QUERY(
	SELECT o.ObjectId_ AS "ObjectId", p.ParentId_ AS "ParentId", l.Level_ AS "Level", d.DateFrom_ AS "DateFrom"
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId_ FROM UNNEST(_resultObjectIds) AS A(ObjectId_)) o
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ParentId_ FROM UNNEST(_resultParentIds) AS A(ParentId_)) p
		ON o.RowNum = p.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.Level_ FROM UNNEST(_resultLevels) AS A(Level_)) l
		ON o.RowNum = l.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.DateFrom_ FROM UNNEST(_resultDateFroms) AS A(DateFrom_)) d
		ON o.RowNum = d.RowNum
	ORDER BY l.Level_);

END;

$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;





/**
Total parent objects table on given date.
FIXME: Performance is HIGHLY INEFFECTIVE! OPTIMIZE!!!
*/

CREATE OR REPLACE FUNCTION sys_getParentObjectsAll(
	DateFromIn DATE
)
RETURNS TABLE (
	ObjectId INTEGER,
	ParentId INTEGER,
	Level INTEGER
) AS

$BODY$
DECLARE
	_resultObjectIds INTEGER[];
	_resultParentIds INTEGER[];
	_resultLevels INTEGER[];

	Objz RECORD;
	t RECORD;

BEGIN

	FOR Objz IN
		SELECT o.Id AS ObjectIdCur
		FROM Objects o
		WHERE (o.DelDate IS NULL OR o.DelDate > DateFromIn)
		  AND o.InsDate <= DateFromIn
		ORDER BY o.Id
	LOOP
		FOR t IN
			SELECT Objz.ObjectIdCur, s.ObjectId, s.Level
			FROM sys_getParentObjects(Objz.ObjectIdCur, DateFromIn) s
		LOOP
			_resultObjectIds := _resultObjectIds || Objz.ObjectIdCur;
			_resultParentIds := _resultParentIds || t.ObjectId;
			_resultLevels    := _resultLevels || t.Level;
		END LOOP;
	END LOOP;

	RETURN QUERY(
	SELECT o.ObjectId_ AS "ObjectId", p.ParentId_ AS "ParentId", l.Level_ AS "Level"
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId_ FROM UNNEST(_resultObjectIds) AS A(ObjectId_)) o
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ParentId_ FROM UNNEST(_resultParentIds) AS A(ParentId_)) p
		ON o.RowNum = p.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.Level_ FROM UNNEST(_resultLevels) AS A(Level_)) l
		ON o.RowNum = l.RowNum
	 );

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
	SELECTS the value of named attribute for Object entities.
*/

CREATE OR REPLACE FUNCTION sys_getPropId (
	IN EnityCodeIn TEXT,
	IN FieldNameIn TEXT
)
RETURNS INT AS

$BODY$
    SELECT ep.Id
    FROM EntityProperties ep
    JOIN Entities e ON e.Id = ep.EntityId
    WHERE LOWER(e.Code) = LOWER($1)
        AND LOWER(ep.Code) = LOWER($2);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;



/**
Returns service supply tree on the current date.
*/
CREATE OR REPLACE FUNCTION sys_getServiceTree ()
RETURNS TABLE (
    ServiceId INT,
	ObjectId INT,
	ParentId INT,
	Level INT
) AS

$BODY$
DECLARE
	_resultObjectIds INTEGER[];
	_resultParentIds INTEGER[];
	_resultLevels INTEGER[];

	Objz RECORD;
	t RECORD;

BEGIN
	CREATE TEMPORARY TABLE tmpParents0 ("ServiceId" INT, "ObjectId" INT); -- Lower level nodes.
	CREATE TEMPORARY TABLE tmpParents  ("ServiceId" INT, "ParentId" INT, "ObjectId" INT);

	-- Fill initial obejcts.
    INSERT INTO tmpParents0("ServiceId", "ObjectId")
    SELECT s.Id, o.Id
	FROM Objects o -- Places and Houses.
	JOIN Entities e ON e.Id = o.EntityId
	CROSS JOIN Services s
	WHERE s.Code IN ('01', '02') -- Отопление, гор. вода.
	   AND (e.Code = 'Places'
	        OR (e.Code = 'Houses' AND NOT EXISTS -- Don't show houses with places.
	            (SELECT 1 FROM Objects p -- Places.
	            WHERE o.EntityId = (SELECT Id FROM Entities WHERE Code = 'Places')
	                AND o.Id = (SELECT op.Value::INT FROM ObjectProperties op WHERE op.ObjectId = p.Id AND op.DateFrom <= sys_getWorkingDate() AND op.PropertyId = sys_getPropId('Places', 'HouseId') ORDER BY op.DateFrom DESC LIMIT 1)
	            )
	        ))
	    AND (o.DelDate IS NULL OR o.DelDate > sys_getWorkingDate() )
	    AND (o.InsDate IS NULL OR o.InsDate <= sys_getWorkingDate() );

	-- Fill temp table.
--	INSERT INTO tmpParents("ServiceId", "ParentId", "ObjectId")


    RETURN QUERY (
        SELECT r."ServiceId", NULL::INT AS "ParentId", r."ObjectId", NULL::INT AS "Level"
        FROM tmpParents0 r
    );
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



/**
	Returns owner of data Entities (used to distinguish them from other Entities with the same name).
*/
CREATE OR REPLACE FUNCTION sys_getTableOwner()
RETURNS TEXT AS

$body$

BEGIN
	RETURN 'tnd';
END;

$body$
LANGUAGE 'plpgsql'
IMMUTABLE
SECURITY DEFINER;



CREATE OR REPLACE FUNCTION sys_inRM (IN maskrm BIT(16))
  RETURNS boolean AS
$BODY$
DECLARE
	_RmNo INTEGER;

BEGIN
	_RmNo := rcp_getRM();

	RETURN COALESCE((maskrm >> (_RmNo-1))&B'0000000000000001',1::bit)::int::boolean;

END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER
  COST 10;





CREATE OR REPLACE FUNCTION sys_instr(
	IN string varchar,
	IN string_to_search varchar,
	IN beg_index integer,
	IN occur_index integer)
RETURNS integer AS $$

DECLARE
    pos integer NOT NULL DEFAULT 0;
    occur_number integer NOT NULL DEFAULT 0;
    temp_str varchar;
    beg integer;
    i integer;
    length integer;
    ss_length integer;

BEGIN
    IF beg_index > 0 THEN
        beg := beg_index;
        temp_str := substring(string FROM beg_index);

        FOR i IN 1..occur_index LOOP
            pos := position(string_to_search IN temp_str);

            IF i = 1 THEN
                beg := beg + pos - 1;
            ELSE
                beg := beg + pos;
            END IF;

            temp_str := substring(string FROM beg + 1);
        END LOOP;

        IF pos = 0 THEN
            RETURN 0;
        ELSE
            RETURN beg;
        END IF;
    ELSE
        ss_length := char_length(string_to_search);
        length := char_length(string);
        beg := length + beg_index - ss_length + 2;

        WHILE beg > 0 LOOP
            temp_str := substring(string FROM beg FOR ss_length);
            pos := position(string_to_search IN temp_str);

            IF pos > 0 THEN
                occur_number := occur_number + 1;

                IF occur_number = occur_index THEN
                    RETURN beg;
                END IF;
            END IF;

            beg := beg - 1;
        END LOOP;

        RETURN 0;
    END IF;
END;

$$ LANGUAGE plpgsql STRICT IMMUTABLE;



/**
 * sys_list state changing implementation for TEXT data type.
 */
CREATE OR REPLACE FUNCTION sys_list_text(state TEXT, nextValue TEXT, delimiter TEXT = ',')
RETURNS TEXT AS
$BODY$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || $3 END
		|| COALESCE($2, '');
$BODY$
LANGUAGE SQL
IMMUTABLE;

CREATE OR REPLACE FUNCTION sys_list_text(state TEXT, nextValue TEXT)
RETURNS TEXT AS
$BODY$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || ',' END
		|| COALESCE($2, '');
$BODY$
LANGUAGE SQL
IMMUTABLE;

DROP AGGREGATE IF EXISTS sys_list(TEXT);
DROP AGGREGATE IF EXISTS sys_list(TEXT, TEXT);
/**
 * Aggregate function producing delimiter-separated list.
 * NULL are threted as empty atrings.
 */
CREATE AGGREGATE sys_list(TEXT, /*delimiter*/ TEXT) (
	sfunc = sys_list_text,
	stype = TEXT,
	initcond = ''
);
CREATE AGGREGATE sys_list(TEXT) (
	sfunc = sys_list_text,
	stype = TEXT,
	initcond = ''
);



/**
 * Works as standard Right function.
 */
CREATE OR REPLACE FUNCTION sys_right(
	IN StrIn TEXT,
	IN CountIn INTEGER
)
RETURNS TEXT AS

$BODY$
	SELECT SUBSTR($1, LENGTH($1) - $2 + 1);
$BODY$

LANGUAGE SQL
STRICT
IMMUTABLE;



CREATE OR REPLACE FUNCTION updateUsTS ()
RETURNS TRIGGER AS

$BODY$
BEGIN
    NEW.UpdateTS := LOCALTIMESTAMP;
    NEW.UpdateUserId := CURRENT_USER;
    RETURN NEW;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER
;





/**
 * Apply patch file to db, check if patch already applied.
 */

CREATE OR REPLACE FUNCTION util_db_migrate (
    IN StageIn TEXT, -- begin or end
    IN RevisionIn CITEXT
) RETURNS VOID AS

$BODY$
DECLARE
	_LastChangedRevision String := RevisionIn;
	_Revision String;
	_RevisionDate Date := localtimestamp;
	_RevisionPrefId Integer;
BEGIN

	SELECT Id INTO _RevisionPrefId
	FROM Prefs WHERE Code = 'System.Revision' ;

	IF StageIn = 'begin' THEN

		-- TODO: Don't delete - make rake task.
		UPDATE PrefValues pv
		SET Value = 1
		WHERE PrefId = (SELECT Id FROM Prefs WHERE Code = 'GUI.Editor.ShowIdInHeader');

		---------------------------------------------------------------------------------
		-- Revision control block
		---------------------------------------------------------------------------------

		SELECT pv.Value
		INTO _Revision
		FROM Prefs p
		JOIN PrefValues pv ON pv.PrefId = p.Id
		WHERE p.Code = 'System.Revision'
		ORDER BY DateFrom DESC NULLS LAST
		LIMIT 1;

		IF _Revision IS NULL THEN
			IF _RevisionPrefId IS NULL THEN
				INSERT INTO Prefs(Code, DataType, Rem)
				VALUES('System.Revision', 'Varchar', 'Revision of the DB') ;
			END IF;

			INSERT INTO PrefValues(PrefId, DateFrom, Value)
			VALUES(_RevisionPrefId, _RevisionDate, _LastChangedRevision || ' ERROR');
		ELSE
			IF _Revision = (_LastChangedRevision || ' OK') THEN
				PERFORM sys_DebugMessage('Patch stopped - already patched. Exiting.');
				RAISE USING MESSAGE = 'Patch stopped - already patched.' ;
			ELSE
				PERFORM sys_DebugMessage('Updating System.Revision parameter...');
				INSERT INTO PrefValues(PrefId, DateFrom, Value)
			    VALUES(_RevisionPrefId, _RevisionDate, _LastChangedRevision || ' ERROR');

			END IF;
		END IF;

	ELSIF StageIn = 'end' THEN

		---------------------------------------------------------------------------------
		-- End of Script.
		---------------------------------------------------------------------------------
		PERFORM sys_DebugMessage('Patch for revision ' || _LastChangedRevision || ' Finished OK') ;

		SELECT MAX(DateFrom)
		INTO _RevisionDate
		FROM PrefValues
		WHERE PrefId = _RevisionPrefId;

		UPDATE PrefValues
		SET Value = _LastChangedRevision || ' OK'
		WHERE PrefId = _RevisionPrefId
		AND DateFrom = _RevisionDate;

	END IF;

EXCEPTION WHEN OTHERS THEN
	--PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_addObject');
	RAISE;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;



