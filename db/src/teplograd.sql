--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

--
-- Name: boolnotnull; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN boolnotnull AS boolean;


--
-- Name: boolnull; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN boolnull AS boolean;


--
-- Name: breakpoint; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE breakpoint AS (
	func oid,
	linenumber integer,
	targetname text
);


--
-- Name: frame; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE frame AS (
	level integer,
	targetname text,
	func oid,
	linenumber integer,
	args text
);


--
-- Name: hugestring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN hugestring AS citext;


--
-- Name: ident; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN ident AS integer;


--
-- Name: longeststring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN longeststring AS citext;


--
-- Name: longstring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN longstring AS citext;


--
-- Name: nstring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN nstring AS citext;


--
-- Name: number; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN number AS numeric(18,8);


--
-- Name: proxyinfo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE proxyinfo AS (
	serverversionstr text,
	serverversionnum integer,
	proxyapiver integer,
	serverprocessid integer
);


--
-- Name: smallstring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN smallstring AS citext;


--
-- Name: string; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN string AS citext;


--
-- Name: targetinfo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE targetinfo AS (
	target oid,
	schema oid,
	nargs integer,
	argtypes oidvector,
	targetname name,
	argmodes "char"[],
	argnames text[],
	targetlang oid,
	fqname text,
	returnsset boolean,
	returntype oid
);


--
-- Name: tinystring; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN tinystring AS citext;


--
-- Name: var; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE var AS (
	name text,
	varclass character(1),
	linenumber integer,
	isunique boolean,
	isconst boolean,
	isnotnull boolean,
	dtype oid,
	value text
);


--
-- Name: calc_placesconsumersservices(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION calc_placesconsumersservices(calcidin integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
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
		ALTER TABLE z_tmpResult ADD PayerId INT;
		ALTER TABLE z_tmpResult ADD DateFrom DATE;
		ALTER TABLE z_tmpResult ADD DateTo DATE;
		ALTER TABLE z_tmpResult ADD Days Number;
		ALTER TABLE z_tmpResult ADD Value Number;
		ALTER TABLE z_tmpResult ADD Tariff Number;
		ALTER TABLE z_tmpResult ADD Money Number;
		ALTER TABLE z_tmpResult ADD Rem LongestString;
		CREATE UNIQUE INDEX UN_%CalcTableName% ON z_tmpResult(ObjectId, PayerId, ServiceId, DateFrom)
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
	INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
	SELECT o.Id, NULL, tp.ServiceId, o.DelDate
	FROM Objects o
	JOIN TmpParents tp ON tp.ObjectId = o.Id
	WHERE o.DelDate > _DateFrom AND o.DelDate < _DateTo;

    PERFORM sys_taskWorked(_TaskId,  'Replicate universal parents for all services.');
    INSERT INTO TmpParents(ObjectId, ParentId, ServiceId, DateFrom)
    SELECT tp.ObjectId, tp.ParentId, s.Id, tp.DateFrom
    FROM TmpParents tp
    CROSS JOIN Services s
    WHERE tp.ServiceId IS NULL
    ;
    DELETE FROM TmpParents tp WHERE tp.ServiceId IS NULL;

--DROP TABLE IF EXISTS TmpParents2;
--CREATE TABLE TmpParents2 AS SELECT * FROM TmpParents;

	-- Insert ServiceLog switching records into tmpPatrents table with switching date.
	PERFORM sys_taskWorked(_TaskId,  'Prepare data for objects state calculation.');
	FOR logz IN -- Looping by ServiceLog records ('Switched' nodes).
	SELECT z.ObjectId, z.ServiceId, z.DateFrom, z.Value::INT AS State
	FROM z_tmpCalc z
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

	-- FIXME !!!
	-- Crawl upwards by hierarchy (TmpParents) from resulting objects (mostly places)
	-- and calculate their state on each date.

	PERFORM sys_taskWorked(_TaskId,  'Calculate place states by date.');
	-- IF one of objects is OFF - the place is OFF too.
	INSERT INTO z_tmpCalc(ObjectId, ServiceId, RowId, TmlId, DateFrom, Value)
	SELECT tp.ObjectId, tp.ServiceId, NULL,
		sys_getCalcTmlId(CalcIdIn, 'Objects.State'),
		tp.DateFrom, COALESCE(MIN(tp.State), 0) -- Place's State is 0 by default (if not switched on explicitly).
	FROM TmpParents tp
	JOIN z_TmpResult r ON r.ObjectId = tp.ObjectId AND r.ServiceId = tp.ServiceId
	WHERE tp.State IS NOT NULL -- Don't use empty states.
	GROUP BY tp.ObjectId, tp.ServiceId, tp.DateFrom;

	PERFORM sys_taskWorked(_TaskId,  '
	/********************************************
	* Main calculation part.
	*********************************************/');


	-- Bulk insert optimization.
	INSERT INTO z_tmpResult(ObjectId, ServiceId, PayerId, DateFrom, Value)
	SELECT DISTINCT t1.ObjectId, t1.ServiceId, t2.PayerId, t1.DateFrom, 0
	FROM (SELECT DISTINCT ObjectId, ServiceId, DateFrom FROM z_tmpCalc WHERE Value IS NOT NULL) t1
	JOIN (SELECT DISTINCT ObjectId, Value::INT AS PayerId FROM z_tmpCalc WHERE Value IS NOT NULL
	          AND TmlId = sys_getCalcTmlId(CalcIdIn, 'Objects.PayerId')) t2
        ON t2.ObjectId = t1.ObjectId;

    SELECT sys_List(
           E'COALESCE( CAST( \n'
        || E'(SELECT z.Value FROM z_tmpCalc z \n'
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
        || E'FROM z_tmpCalc t \n'
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
		_Period := tmpz.DateTo - tmpz.DateFrom;
		_Capacity := tmpz."ObjectCapacities.Value";
		_State := tmpz."Objects.State";
		_PayerId := tmpz."Objects.PayerId";
		_Tariff := tmpz."TariffValues.Value";

		IF  _State != 0 THEN -- IF Service is NOT in off state.
			_Money := ROUND(_Tariff * 12 / 365 * _Capacity * _Period, 2);
			_Rem := '+ ' || sys_trimZero(_Money)
				|| ' [' || tmpz.DateFrom || ' - ' || tmpz.DateTo || ' = ' || sys_trimZero(_Period) || ']'
				|| ' {Tariff=' || sys_trimZero(_Tariff) || ', Capacity=' || sys_trimZero(_Capacity) || '}'
				|| ' ';
		ELSE -- Service is OFF.
			_Money := 0;
			_Rem := '+ 0'
				|| ' [' || tmpz.DateFrom || ' - ' || tmpz.DateTo || ' = ' || sys_trimZero(_Period) || ']'
				|| ' {State=' || sys_trimZero(_State) || ', PayerId=' || sys_trimZero(_PayerId) || '}'
				|| ' ';
		END IF;

		UPDATE z_tmpResult t
		SET DateTo = tmpz.DateTo,
			Days = COALESCE(t.Days, 0) + _Period,
			Value = COALESCE(t.Value, 0) + _Capacity,
			Tariff = _Tariff,
			Money = COALESCE(_Money, 0),
			Rem = Rem || _Rem
		WHERE t.ObjectId = tmpz.ObjectId
			AND t.ServiceId = tmpz.ServiceId
			AND t.PayerId = _PayerId
			AND t.DateFrom = tmpz.DateFrom;

		IF NOT FOUND THEN
			INSERT INTO z_tmpResult (ObjectId, ServiceId, PayerId, DateFrom, DateTo, Days, Value, Tariff, Money, Rem)
			VALUES(tmpz.ObjectId, tmpz.ServiceId, _PayerId, tmpz.DateFrom, tmpz.DateTo, _Period, _Capacity, _Tariff, _Money, _Rem);
		END IF;
	END LOOP;

	PERFORM sys_taskWorked(_TaskId,  'Task complete.');

END;
$_$;


--
-- Name: pldbg_abort_target(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_abort_target(session integer) RETURNS SETOF boolean
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_abort_target';


--
-- Name: pldbg_attach_to_port(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_attach_to_port(portnumber integer) RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_attach_to_port';


--
-- Name: pldbg_continue(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_continue(session integer) RETURNS breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_continue';


--
-- Name: pldbg_create_listener(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_create_listener() RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_create_listener';


--
-- Name: pldbg_deposit_value(integer, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_deposit_value(session integer, varname text, linenumber integer, value text) RETURNS boolean
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_deposit_value';


--
-- Name: pldbg_drop_breakpoint(integer, oid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_drop_breakpoint(session integer, func oid, linenumber integer) RETURNS boolean
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_drop_breakpoint';


--
-- Name: pldbg_get_breakpoints(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_breakpoints(session integer) RETURNS SETOF breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_get_breakpoints';


--
-- Name: pldbg_get_proxy_info(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_proxy_info() RETURNS proxyinfo
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_get_proxy_info';


--
-- Name: pldbg_get_source(integer, oid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_source(session integer, func oid) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_get_source';


--
-- Name: pldbg_get_stack(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_stack(session integer) RETURNS SETOF frame
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_get_stack';


--
-- Name: pldbg_get_target_info(text, "char"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_target_info(signature text, targettype "char") RETURNS targetinfo
    LANGUAGE c STRICT
    AS '$libdir/targetinfo', 'pldbg_get_target_info';


--
-- Name: pldbg_get_variables(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_get_variables(session integer) RETURNS SETOF var
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_get_variables';


--
-- Name: pldbg_select_frame(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_select_frame(session integer, frame integer) RETURNS breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_select_frame';


--
-- Name: pldbg_set_breakpoint(integer, oid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_set_breakpoint(session integer, func oid, linenumber integer) RETURNS boolean
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_set_breakpoint';


--
-- Name: pldbg_set_global_breakpoint(integer, oid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_set_global_breakpoint(session integer, func oid, linenumber integer, targetpid integer) RETURNS boolean
    LANGUAGE c
    AS '$libdir/pldbgapi', 'pldbg_set_global_breakpoint';


--
-- Name: pldbg_step_into(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_step_into(session integer) RETURNS breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_step_into';


--
-- Name: pldbg_step_over(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_step_over(session integer) RETURNS breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_step_over';


--
-- Name: pldbg_wait_for_breakpoint(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_wait_for_breakpoint(session integer) RETURNS breakpoint
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_wait_for_breakpoint';


--
-- Name: pldbg_wait_for_target(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pldbg_wait_for_target(session integer) RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/pldbgapi', 'pldbg_wait_for_target';


--
-- Name: plpgsql_oid_debug(oid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION plpgsql_oid_debug(functionoid oid) RETURNS integer
    LANGUAGE c STRICT
    AS '$libdir/plugins/plugin_debugger', 'plpgsql_oid_debug';


--
-- Name: rcp_addobject(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_addobject(formidin integer, objidin integer, valuesin text, OUT newobjidout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_addprefvalue(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_addprefvalue(codein text, valuein text, OUT prefvalueidout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_calculate(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_calculate(calcidin integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
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
	_InputFields TEXT;
	_InputFields2 TEXT;
	_InputSQL TEXT;
	_Criteria TEXT;
	_Criteria2 TEXT;
	fieldz RECORD;
	tmlz RECORD;

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

	-- Create input table.
	_InTableName := sys_getCalcTableName('in', CalcIdIn);

	TRUNCATE TABLE z_tmpCalc;

	-- Create output table with 'iterator' fields only.
	_OutTableName := sys_getCalcTableName('out', CalcIdIn);
	IF sys_ifTableExists('z_TmpResult') <> 0 THEN
		_SQL :='DROP TABLE z_TmpResult';
		PERFORM sys_DebugMessage(_SQL);
		EXECUTE _SQL;
	END IF;

	_InputFields2 := REPLACE(REPLACE(_InputFields, '{', ''), '}', '');
	_SQL := 'CREATE Table z_TmpResult(' || _InputFields2 || ')';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;
	_InputFields2 := REPLACE(REPLACE(_InputFields, '{', '/*'), '}', '*/');

	PERFORM sys_taskWorked(_TaskId,  'Populate results table with Iterator objects.');

	_InputSQL := 'SELECT ' || _InputFields2 || ' FROM (' || _InputSQL || ') s ' ||
	             'WHERE s.InsDate <= _DateTo AND (s.DelDate IS NULL OR s.DelDate > _DateFrom)' ;
	_SQL := 'INSERT INTO z_TmpResult(' || _InputFields2 || ') ' || _InputSQL ;
	_SQL := REPLACE(_SQL, '_DateFrom', quote_literal(_DateFrom) || '::DATE');
	_SQL := REPLACE(_SQL, '_DateTo', quote_literal(_DateTo) || '::DATE');
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_SQL := 'ANALYZE z_TmpResult; CREATE INDEX IDX_z_TmpResult ON z_TmpResult(' || _InputFields2 || ')';
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

	_SQL :='DROP INDEX idx_z_tmpcalc';
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
			INSERT INTO z_tmpCalc(%InputFields2%, TmlId, RowId, DateFrom, Value)
			WITH SubQ AS (%QuerySQL%) -- (_InputFields2, RowId, DateFrom, Value)
			SELECT %InputFields2%, %Id%, t1.RowId, GREATEST(t1.DateFrom, %DateFrom%), t1.Value
			FROM SubQ t1
			WHERE t1.DateFrom >= COALESCE((SELECT MAX(t2.DateFrom)
			  							   FROM SubQ t2
			  							   WHERE %Criteria%
			  							       AND t2.DateFrom <= %DateTo%), '-Infinity'::Date)
			$sql$;
        IF tmlz.doRestrict THEN
            _SQL := _SQL || E'\n AND EXISTS (SELECT 1 FROM z_TmpResult t2 WHERE %Criteria2%)';
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
	_SQL :=E'ANALYZE z_tmpCalc; \n'
		|| E'CREATE INDEX idx_z_tmpcalc ON z_tmpCalc (ObjectId, ServiceId, TmlId, DateFrom DESC)';
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	/*
	PERFORM sys_taskWorked(_TaskId,  E'=============================\n     Duplicate records with DateTo.') ;
	_SQL := $sql$
		INSERT INTO z_tmpCalc(_InputFields2, TmlId, RowId, DateFrom, DateTo, Value)
		SELECT _InputFields2, TmlId, RowId, DateTo, NULL, NULL
		FROM z_tmpCalc
		WHERE DateTo IS NOT NULL
	$sql$;
	_SQL := REPLACE(_SQL, '_InputFields2', _InputFields2);
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	PERFORM sys_taskWorked(_TaskId,  '    Recalculate DateTo.') ;
	_SQL := $sql$
		UPDATE z_tmpCalc t1
		SET DateTo = COALESCE((SELECT MIN(t2.DateFrom)
							   FROM z_tmpCalc t2
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

	_SQL := 'CREATE TABLE ' || _InTableName || ' AS TABLE z_tmpCalc' ;
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

	_SQL := 'CREATE TABLE ' || _OutTableName || ' AS TABLE z_tmpResult' ;
	PERFORM sys_DebugMessage(_SQL);
	EXECUTE _SQL;

	_SQL := 'CREATE INDEX IDX_' || _OutTableName || ' ON ' || _OutTableName || '(' || _InputFields2 || ')';
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
$_$;


--
-- Name: rcp_delobject(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_delobject(formidin integer, objidin integer, OUT rowcountout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
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
$_$;


--
-- Name: rcp_getbacktracking(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getbacktracking(hierarchyidin integer, entityidin integer, objectidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

			ELSEIF _curEntityType = 'HARD' THEN
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
$$;


--
-- Name: rcp_getdictionaryvalues(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getdictionaryvalues(idin text) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

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
END; $$;


--
-- Name: rcp_getdropentities(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getdropentities(hfolderidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_getentities(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getentities(idin integer DEFAULT 0) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    	Rem
    FROM Entities t
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;

    RETURN result;
END;
$$;


--
-- Name: rcp_getfolderchildcount(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getfolderchildcount(hfolderidin integer, parentobjidin integer, parentvaluesin text) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_getfolders(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getfolders(hierarchyidin integer, entityidin integer, objidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
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
					CASE WHEN hf.Code IS NULL THEN 'Names' ELSE 'Name' END
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

	PERFORM sys_DebugMessage('sys_rcpFetFolders: ' || _AllSQL);
	OPEN result FOR EXECUTE _AllSQL;
	RETURN result;
END;
$_$;


--
-- Name: rcp_getformcontrols(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getformcontrols(formidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE
	result REFCURSOR = 'rcp_getFormControls' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getFormControls(FormIdIn);

	RETURN result;
END; $$;


--
-- Name: rcp_getforms(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getforms(idin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_gethierarchies(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_gethierarchies(idin integer DEFAULT 0) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_gethierarchyfolders(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_gethierarchyfolders(idin integer DEFAULT 0) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_getobjects(integer, integer, integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getobjects(hfolderidin integer, parententityidin integer, parentobjidin integer, entityidin integer, objidin integer, parentvaluesin text) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$

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
		ELSIF _ParentEntityType = 'HARD' THEN
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

$_$;


--
-- Name: rcp_getparententities(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getparententities(_hierarchyidin integer, _childentityidin integer, _childfieldin text) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

$$;


--
-- Name: rcp_getprefs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getprefs(idin integer DEFAULT 0) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	result REFCURSOR = 'rcp_getprefs';

BEGIN
	OPEN result FOR
	SELECT Id, Code, DataType, Rem
    FROM Prefs
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;
END;

$$;


--
-- Name: rcp_getprefvalue(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getprefvalue(idin text) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE
	result REFCURSOR = 'rcp_getPrefValue';

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getPrefValue(IdIn);

	RETURN result;
END;
$$;


--
-- Name: rcp_getrcpqueries(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getrcpqueries() RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_getreportdata(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getreportdata(reportidin integer, calcidin integer DEFAULT NULL::integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	result REFCURSOR = 'rcp_getReportData';
	_CalcTypeId INTEGER;
	_ReportSQL TEXT;
	_SQL TEXT;
	_CalcId INTEGER;
	_CalcTableName TEXT;
	_ReportCode TEXT;

BEGIN
	SELECT CalcTypeId, ReportSQL, Code
	INTO _CalcTypeId, _ReportSQL, _ReportCode
	FROM Reports
	WHERE Id = ReportIdIn;

	IF _CalcTypeId IS NULL THEN -- Non-calculational procedures.
		_SQL := _ReportSQL;

	ELSE -- Calculational report.
		IF COALESCE(CalcIdIn, 0) = 0 THEN
			-- See rcp_getReportInfo - the same code.
			SELECT Id
			INTO _CalcId
			FROM Calculations c
			WHERE CalcTypeId = _CalcTypeId
				AND State = 'OK'
				AND DateFrom <= sys_getWorkingDate()
			ORDER BY (sys_getWorkingDate() - DateFrom)
			LIMIT 1;

			IF _CalcId IS NULL THEN
				PERFORM sys_signalException('EmptyReport: %s ON %s', _ReportCode || E'\\d' || sys_getWorkingDate());
			END IF;
		ELSE
			_CalcId := CalcIdIn;
		END IF;

		_CalcTableName := sys_getCalcTableName('out', _CalcId);

		IF _ReportSQL IS NULL THEN
			_SQL := 'SELECT * FROM ' || _CalcTableName;
		ELSE
			_SQL := REPLACE(_ReportSQL, '%t', _CalcTableName);
			_SQL := REPLACE(_ReportSQL, '%CalcId', COALESCE(_CalcId, 0)::TEXT);
		END IF;
	END IF;

	PERFORM sys_debugMessage('rcp_getReportData: ' || COALESCE(_SQL, '<NULL>'));
	OPEN result FOR EXECUTE _SQL;

	RETURN result;
END;
$$;


--
-- Name: rcp_getreportinfo(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getreportinfo(reportidin integer, calcidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	result REFCURSOR = 'rcp_getReportInfo';
	_ReportCode TEXT;
	_ReportName TEXT;
	_CalcTypeId INTEGER;
	_CalcId INTEGER;
	_DateFrom DATE;
	_DateTo DATE;

BEGIN
	SELECT r.Code, sys_getDictionaryValue('TableRows.Reports.' || r.Code), r.CalcTypeId
	INTO _ReportCode, _ReportName, _CalcTypeId
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
		_CalcTypeId AS CalcTypeId, _DateFrom AS DateFrom, _DateTo AS DateTo;

	RETURN result;
END;
$$;


--
-- Name: rcp_getrm(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_getrm() RETURNS integer
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_gettaskstate(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_gettaskstate(taskidin integer) RETURNS refcursor
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_setrm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_setrm(valuein text, OUT prefvalueidout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_taskcancel(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_taskcancel(taskidin integer, reasonin text, OUT resultout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: rcp_taskstart(text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcp_taskstart(typecodein text, subjectidin integer, descriptionin text, OUT taskidout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN

	INSERT INTO Tasks(TypeId, State, Progress, SubjectId, Description)
	SELECT tt.Id, 'PRISTINE', 0, SubjectIdIn, DescriptionIn
	FROM TaskTypes tt
	WHERE tt.Code = TypeCodeIn
	RETURNING Tasks.Id INTO TaskIdOut;

END;
$$;


--
-- Name: sys_calcaddresultfield(integer, string); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_calcaddresultfield(calcidin integer, fieldnamein string) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
	_SQL LongString;
BEGIN

	IF sys_ifTableHasField(sys_getResultTableName(_CalcIdIn), _FieldNameIn) = 0 THEN
		_SQL := 'ALTER TABLE ' || sys_getResultTableName(_CalcIdIn) || ' ADD (' || _FieldNameIn || ' String)';
		EXECUTE _SQL;
	END IF;

END;
$$;


--
-- Name: sys_calcgettaskid(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_calcgettaskid(calcidin integer, OUT taskidout integer) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    AS $_$
	SELECT t.Id
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE tt.Code = 'Calculations'
		AND t.SubjectId = $1
	ORDER BY t.InsertTS DESC
	LIMIT 1;
$_$;


--
-- Name: sys_debugmessage(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_debugmessage(msgin text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: sys_eventlog(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_eventlog(sqlstatein text, sqlerrmin text, datain text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
--	PERFORM sys_DebugMessage('sys_EventLog: SQLSTATE=' || COALESCE(SQLStateIn, '<NULL>')
--		|| ', SQLERRM=' || COALESCE(SQLErrMIn, '<NULL>'));

	INSERT INTO EventLog(UserId, SQLState, SQLErrM, Data)
	VALUES (sys_getUserId(), SQLStateIn, SQLErrMIn, DataIn);
END;
$$;


--
-- Name: sys_getattrlist(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getattrlist(_entityidin integer, _objidin integer) RETURNS longeststring
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$
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

	ELSIF _EntityType = 'HARD' THEN

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
$$;


--
-- Name: sys_getattrvalue(integer, integer, text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getattrvalue(_entityidin integer, _objectidin integer, _codein text, _datefromin date) RETURNS text
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $_$
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
$_$;


--
-- Name: sys_getcalctablename(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getcalctablename(modein text, calcidin integer) RETURNS text
    LANGUAGE sql IMMUTABLE SECURITY DEFINER
    AS $_$
	SELECT 'z_calc_' || $2 /*CalcIdIn*/  || '_' || LOWER($1 /*ModeIn*/);
$_$;


--
-- Name: sys_getcalctmlid(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getcalctmlid(calcidin integer, fieldnamein text) RETURNS integer
    LANGUAGE sql IMMUTABLE SECURITY DEFINER
    AS $_$
	SELECT ct.Id
	FROM Calculations c
	JOIN CalcTemplates ct ON ct.CalcTypeId = c.CalcTypeId
	WHERE c.Id = $1
		AND LOWER(ct.FieldName) = LOWER($2);
$_$;


--
-- Name: sys_getcriteriasql(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getcriteriasql(hfolderidin integer, parentobjidin integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $_$
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
			IF _ChildEntityType = 'HARD' THEN -- Table Child Entities.
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
$_$;


--
-- Name: sys_getdictionaryvalue(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getdictionaryvalue(codein text, fieldin text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $_$
DECLARE
    _SQL LongestString;

    _Lang CHAR(3);
	_Name String;
	_Code String;
	_Field String;
	_i INTEGER;
BEGIN

	IF FieldIn IN ('names', 'abbr', 'rem') THEN
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
			WHERE Code = $1
			  AND LanguageCode = $2
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
$_$;


--
-- Name: sys_getformcontrols(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getformcontrols(formidin integer) RETURNS TABLE(id integer, entityid integer, fieldname text, label text, iseditable text, type text, length integer, mandatory boolean, refentityid integer, style text, misc text, rem text, orderno integer, donumsort boolean, lookuphierarchyid integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

		ELSEIF EntityTypeTemp = 'HARD' THEN -- Table-based forms.
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
$$;


--
-- Name: sys_gethierconditions(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_gethierconditions(entityidin integer, parentvaluesin text) RETURNS longstring
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$
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

		IF _EntityType = 'HARD' THEN -- Check foreign keys.
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
$$;


--
-- Name: sys_getparentobjects(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getparentobjects(objectidin integer, datefromin date) RETURNS TABLE(objectid integer, parentid integer, level integer, datefrom date)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

$$;


--
-- Name: sys_getparentobjectsall(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getparentobjectsall(datefromin date) RETURNS TABLE(objectid integer, parentid integer, level integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: sys_getprefvalue(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getprefvalue(codein text) RETURNS TABLE(id integer, code text, defaultdatefrom date, defaultvalue text, datefrom date, value text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

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

END; $$;


--
-- Name: sys_gettablename(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_gettablename(entityidin integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT SECURITY DEFINER
    AS $$
DECLARE
	_Result String;
BEGIN
	SELECT CASE WHEN Type = 'SOFT' THEN 'Objects' ELSE Code END
	INTO _Result
	FROM Entities
	WHERE Id = EntityIdIn;

	RETURN _Result;
END;
$$;


--
-- Name: sys_gettableowner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_gettableowner() RETURNS text
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$

BEGIN
	RETURN 'tnd';
END;

$$;


--
-- Name: sys_getuserid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getuserid(usernamein text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER COST 10
    AS $$
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
$$;


--
-- Name: sys_getworkingdate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_getworkingdate() RETURNS date
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: sys_iftableexists(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_iftableexists(tablenamein text) RETURNS oid
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$

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

$$;


--
-- Name: sys_iftablehasfield(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_iftablehasfield(tablenamein text, fieldnamein text) RETURNS oid
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$

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

$$;


--
-- Name: sys_inrm(bit); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_inrm(maskrm bit) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER COST 10
    AS $$
DECLARE
	_RmNo INTEGER;

BEGIN
	_RmNo := rcp_getRM();

	RETURN COALESCE((maskrm >> (_RmNo-1))&B'0000000000000001',1::bit)::int::boolean;

END;
$$;


--
-- Name: sys_instr(character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_instr(string character varying, string_to_search character varying, beg_index integer, occur_index integer) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$

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

$$;


--
-- Name: sys_isnumeric(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_isnumeric(text) RETURNS boolean
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
	SELECT $1 ~ '^[0-9]+$';
$_$;


--
-- Name: sys_issystemfield(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_issystemfield(fieldnamein text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER COST 10
    AS $$

BEGIN
	IF lower(FieldNameIn) IN (
		'id', 'revision', 'insertuserid', 'insertts', 'updateuserid', 'updatets', 'deldate', 'insdate'
		) THEN
	  RETURN true;
	ELSE
	  RETURN false;
	END IF;
END;

$$;


--
-- Name: sys_list_text(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_list_text(state text, nextvalue text, delimiter text DEFAULT ','::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || $3 END
		|| COALESCE($2, '');
$_$;


--
-- Name: sys_list_text(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_list_text(state text, nextvalue text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || ',' END
		|| COALESCE($2, '');
$_$;


--
-- Name: sys_objectiseditable(integer, integer, date, date, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_objectiseditable(_entityidin integer, _objidin integer, _workingdatein date, _datefromin date, _insdatein date, _deldatein date) RETURNS string
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$

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
		IF EXISTS(SELECT 1 FROM Calculations WHERE DateFrom >= _DateFromIn) THEN
			RETURN 'There are calculations, blocking the object.';
		END IF;
	END IF;

	RETURN NULL;
END;

$$;


--
-- Name: sys_objectvalidate(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_objectvalidate(modein text, entityidin integer, objidin integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: sys_right(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_right(strin text, countin integer) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
	SELECT SUBSTR($1, LENGTH($1) - $2 + 1);
$_$;


--
-- Name: sys_signalexception(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_signalexception(errcodein text, errdatain text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: sys_taskworked(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_taskworked(taskidin integer, progressremin text, OUT dummyout integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
	PERFORM sys_DebugMessage(ProgressRemIn);

	UPDATE Tasks
	SET State = 'IN_USE',
		Progress = COALESCE(Progress, 0) + 1,
		ProgressRem = ProgressRemIn,
		Revision = COALESCE(Revision, 0) + 1
	WHERE Id = TaskIdIn;
END;
$$;


--
-- Name: sys_trimzero(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION sys_trimzero(nin numeric) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: updateusts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION updateusts() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    NEW.UpdateTS := LOCALTIMESTAMP;
    NEW.UpdateUserId := CURRENT_USER;
    RETURN NEW;
END;
$$;


--
-- Name: util_db_migrate(text, citext); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION util_db_migrate(stagein text, revisionin citext) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: uuid_generate_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_generate_v1() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v1';


--
-- Name: uuid_generate_v1mc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_generate_v1mc() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v1mc';


--
-- Name: uuid_generate_v3(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_generate_v3(namespace uuid, name text) RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v3';


--
-- Name: uuid_generate_v4(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_generate_v4() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v4';


--
-- Name: uuid_generate_v5(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_generate_v5(namespace uuid, name text) RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v5';


--
-- Name: uuid_nil(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_nil() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_nil';


--
-- Name: uuid_ns_dns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_ns_dns() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_dns';


--
-- Name: uuid_ns_oid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_ns_oid() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_oid';


--
-- Name: uuid_ns_url(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_ns_url() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_url';


--
-- Name: uuid_ns_x500(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION uuid_ns_x500() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_x500';


--
-- Name: sys_list(text, text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE sys_list(text, text) (
    SFUNC = public.sys_list_text,
    STYPE = text,
    INITCOND = ''
);


--
-- Name: sys_list(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE sys_list(text) (
    SFUNC = public.sys_list_text,
    STYPE = text,
    INITCOND = ''
);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: auditlog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE auditlog (
    id integer NOT NULL,
    eventts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone NOT NULL,
    userid integer NOT NULL,
    entityid integer NOT NULL,
    rowid integer NOT NULL,
    fieldvalues citext,
    fieldvaluesfull citext,
    revision integer DEFAULT 0
);


--
-- Name: auditlog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE auditlog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: auditlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE auditlog_id_seq OWNED BY auditlog.id;


--
-- Name: banks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE banks (
    id integer NOT NULL,
    mfo citext NOT NULL,
    name citext NOT NULL,
    address citext,
    phone citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE banks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE banks IS 'Банки';


--
-- Name: COLUMN banks.mfo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN banks.mfo IS 'МФО';


--
-- Name: COLUMN banks.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN banks.name IS 'Наименование';


--
-- Name: COLUMN banks.address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN banks.address IS 'Адрес';


--
-- Name: COLUMN banks.phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN banks.phone IS 'Телефон';


--
-- Name: banks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE banks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: banks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE banks_id_seq OWNED BY banks.id;


--
-- Name: benefits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE benefits (
    id integer NOT NULL,
    personid integer NOT NULL,
    typeid integer,
    ismain boolean DEFAULT false NOT NULL,
    doc citext,
    rem longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    personcount integer
);


--
-- Name: TABLE benefits; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE benefits IS 'Льготы';


--
-- Name: COLUMN benefits.doc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefits.doc IS 'Документ подтверждающий льготу';


--
-- Name: benefittypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE benefittypes (
    id integer NOT NULL,
    kfk text,
    code text NOT NULL,
    name citext,
    percent integer NOT NULL,
    datefrom date,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE benefittypes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE benefittypes IS 'Категорії пільг';


--
-- Name: COLUMN benefittypes.kfk; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefittypes.kfk IS 'КФК';


--
-- Name: COLUMN benefittypes.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefittypes.code IS 'Код';


--
-- Name: COLUMN benefittypes.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefittypes.name IS 'Назва';


--
-- Name: COLUMN benefittypes.percent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefittypes.percent IS 'Процент';


--
-- Name: COLUMN benefittypes.datefrom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN benefittypes.datefrom IS 'Введено з';


--
-- Name: consumers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE consumers (
    id integer NOT NULL,
    code string,
    nam citext NOT NULL,
    name string,
    rem longstring,
    taxcode citext,
    ndscode citext,
    ndssvidet citext,
    phone citext,
    address string,
    email citext,
    taxmode smallint,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date,
    rs citext,
    mfo citext,
    fax text,
    dirfio citext,
    dirphone text,
    glavbuhfio citext,
    glavbuhphone text,
    calcfio citext,
    calcphone text,
    deliveryaddress text
);


--
-- Name: TABLE consumers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE consumers IS 'Юр.лица';


--
-- Name: COLUMN consumers.nam; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.nam IS 'Краткое назв.';


--
-- Name: COLUMN consumers.taxcode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.taxcode IS 'Код ЕГРПОУ';


--
-- Name: COLUMN consumers.ndscode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.ndscode IS 'Налоговый ном.';


--
-- Name: COLUMN consumers.ndssvidet; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.ndssvidet IS 'Номер свид-ва';


--
-- Name: COLUMN consumers.phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.phone IS 'Телефон';


--
-- Name: COLUMN consumers.address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.address IS 'Адрес';


--
-- Name: COLUMN consumers.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.email IS 'E-mail';


--
-- Name: COLUMN consumers.taxmode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN consumers.taxmode IS 'Вид налогообложения';


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contracts (
    id integer NOT NULL,
    consumerid integer NOT NULL,
    code citext NOT NULL,
    datefrom date NOT NULL,
    dateto date,
    book citext,
    rem citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: COLUMN contracts.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contracts.id IS 'Ссылка на Плательщика';


--
-- Name: COLUMN contracts.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contracts.code IS 'Номер договора';


--
-- Name: COLUMN contracts.datefrom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contracts.datefrom IS 'Дата заключения договора';


--
-- Name: COLUMN contracts.dateto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contracts.dateto IS 'Дата закрытия договора';


--
-- Name: COLUMN contracts.book; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN contracts.book IS 'Номер книги';


--
-- Name: objectcapacities; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE objectcapacities (
    id integer NOT NULL,
    objectid integer NOT NULL,
    datefrom date NOT NULL,
    serviceid integer NOT NULL,
    value1 number,
    value2 number,
    value3 number,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    counterpart numeric,
    contractid integer,
    rem citext
);


--
-- Name: COLUMN objectcapacities.objectid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN objectcapacities.objectid IS 'Указатель на помещение';


--
-- Name: COLUMN objectcapacities.datefrom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN objectcapacities.datefrom IS 'Период начала валидности';


--
-- Name: objects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE objects (
    id integer NOT NULL,
    entityid integer NOT NULL,
    code string NOT NULL,
    name string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    deldate date,
    insdate date NOT NULL,
    oldid integer
);


--
-- Name: persons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE persons (
    id integer NOT NULL,
    lastname string NOT NULL,
    firstname string,
    middlename string,
    inn citext,
    objectid integer NOT NULL,
    gekid integer,
    account integer,
    passport citext,
    birthdate date,
    ismain boolean DEFAULT false NOT NULL,
    excludedate date,
    cardnum citext,
    filenum citext,
    rem longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE persons; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE persons IS 'Физ. лица';


--
-- Name: COLUMN persons.account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN persons.account IS 'Лицевой счет';


--
-- Name: COLUMN persons.excludedate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN persons.excludedate IS 'Дата снятия с учета';


--
-- Name: services; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE services (
    id integer NOT NULL,
    code string,
    name string,
    value1 string,
    value2 string,
    value3 string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date,
    benefitcode citext,
    benefitname citext
);


--
-- Name: TABLE services; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE services IS 'Виды услуг';


--
-- Name: streets; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE streets (
    id integer NOT NULL,
    cityid integer NOT NULL,
    streettypeid integer,
    code citext,
    name citext NOT NULL,
    spec citext DEFAULT ''::citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: streettypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE streettypes (
    id integer NOT NULL,
    code citext NOT NULL,
    name citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: benefit_persons; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW benefit_persons AS
    SELECT p.id, COALESCE(fcs.code, hcs.code) AS consumer_code, COALESCE(fcs.nam, hcs.nam) AS consumer_nam, p.lastname, p.firstname, p.middlename, p.inn, (((((((st.code)::text || ' '::text) || (s.name)::text) || ', '::text) || (h.code)::text) || '/'::text) || (f.code)::text) AS address, fc.value1 AS flat_heat_area, p.gekid, p.account, p.passport, p.birthdate, p.ismain AS is_main_person, p.excludedate, p.cardnum, p.filenum, p.rem AS person_rem, bt.kfk, bt.code AS benefit_code, bt.name AS benefit_name, bt.percent, bt.datefrom AS benefit_date, b.ismain AS is_main_benefit, b.personcount, b.doc, b.rem AS benefit_rem, p.revision FROM ((((((((((((persons p JOIN benefits b ON ((p.id = b.personid))) JOIN benefittypes bt ON ((bt.id = b.typeid))) LEFT JOIN objects f ON ((f.id = p.objectid))) LEFT JOIN (SELECT DISTINCT ON (objectcapacities.objectid) objectcapacities.objectid, objectcapacities.value1, objectcapacities.contractid FROM objectcapacities WHERE ((objectcapacities.serviceid = (SELECT services.id FROM services WHERE ((services.code)::citext = '01'::citext))) AND (objectcapacities.datefrom <= sys_getworkingdate())) ORDER BY objectcapacities.objectid, objectcapacities.datefrom DESC) fc ON ((fc.objectid = f.id))) LEFT JOIN objects h ON ((h.id = (sys_getattrvalue(NULL::integer, f.id, 'HouseId'::text, sys_getworkingdate()))::integer))) LEFT JOIN (SELECT DISTINCT ON (objectcapacities.objectid) objectcapacities.objectid, objectcapacities.contractid FROM objectcapacities WHERE ((objectcapacities.serviceid = (SELECT services.id FROM services WHERE ((services.code)::citext = '01'::citext))) AND (objectcapacities.datefrom <= sys_getworkingdate())) ORDER BY objectcapacities.objectid, objectcapacities.datefrom DESC) hc ON ((hc.objectid = h.id))) LEFT JOIN streets s ON ((s.id = (sys_getattrvalue(NULL::integer, h.id, 'StreetId'::text, sys_getworkingdate()))::integer))) LEFT JOIN streettypes st ON ((st.id = s.streettypeid))) LEFT JOIN contracts fct ON ((fct.id = fc.contractid))) LEFT JOIN consumers fcs ON ((fcs.id = fct.consumerid))) LEFT JOIN contracts hct ON ((hct.id = hc.contractid))) LEFT JOIN consumers hcs ON ((hcs.id = hct.consumerid))) ORDER BY COALESCE(fcs.code, hcs.code), p.lastname, p.firstname, p.middlename;


--
-- Name: benefits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE benefits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: benefits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE benefits_id_seq OWNED BY benefits.id;


--
-- Name: benefittypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE benefittypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: benefittypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE benefittypes_id_seq OWNED BY benefittypes.id;


--
-- Name: calctemplates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE calctemplates (
    id integer NOT NULL,
    calctypeid integer NOT NULL,
    orderno integer NOT NULL,
    fieldname string NOT NULL,
    querysql longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    dorestrict boolean DEFAULT true
);


--
-- Name: calctypedefs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE calctypedefs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: calctypedefs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE calctypedefs_id_seq OWNED BY calctemplates.id;


--
-- Name: calctypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE calctypes (
    id integer NOT NULL,
    code string NOT NULL,
    rem longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    inputfields longstring,
    inputsql longeststring
);


--
-- Name: calctypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE calctypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: calctypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE calctypes_id_seq OWNED BY calctypes.id;


--
-- Name: calculations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE calculations (
    id integer NOT NULL,
    calctypeid integer NOT NULL,
    datefrom date NOT NULL,
    dateto date NOT NULL,
    state string DEFAULT 'PRISTINE'::citext NOT NULL,
    rem longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: calculations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE calculations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: calculations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE calculations_id_seq OWNED BY calculations.id;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cities (
    id integer NOT NULL,
    name citext NOT NULL,
    zip integer,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: TABLE cities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE cities IS 'Города';


--
-- Name: COLUMN cities.zip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN cities.zip IS 'Индекс';


--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cities_id_seq OWNED BY cities.id;


--
-- Name: consumers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE consumers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: consumers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE consumers_id_seq OWNED BY consumers.id;


--
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contracts_id_seq OWNED BY contracts.id;


--
-- Name: countcalctypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE countcalctypes (
    id integer NOT NULL,
    code string,
    name string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: TABLE countcalctypes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE countcalctypes IS 'Типы вычислителей';


--
-- Name: countcalctypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countcalctypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: countcalctypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countcalctypes_id_seq OWNED BY countcalctypes.id;


--
-- Name: countcalculators; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE countcalculators (
    id integer NOT NULL,
    code string,
    name string,
    calctypeid integer,
    num citext,
    nodeid integer NOT NULL,
    combined boolean DEFAULT false NOT NULL,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: TABLE countcalculators; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE countcalculators IS 'Вычислители';


--
-- Name: countcalculators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countcalculators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: countcalculators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countcalculators_id_seq OWNED BY countcalculators.id;


--
-- Name: countdata; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE countdata (
    id integer NOT NULL,
    counterid integer NOT NULL,
    datefrom date NOT NULL,
    value number NOT NULL,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    dateto date NOT NULL
);


--
-- Name: TABLE countdata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE countdata IS 'Показания приборов учета';


--
-- Name: countdata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countdata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: countdata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countdata_id_seq OWNED BY countdata.id;


--
-- Name: counters; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE counters (
    id integer NOT NULL,
    code string,
    name string,
    calcid integer,
    serviceid integer NOT NULL,
    objectid integer,
    pprtypeid integer,
    pprnum citext,
    tsptypeid integer,
    tspnum citext,
    regdate date,
    unregdate date,
    checkdate date,
    rem string,
    deldate date,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    pprtypeid2 integer,
    pprnum2 citext,
    tsptypeid2 integer,
    tspnum2 citext
);


--
-- Name: TABLE counters; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE counters IS 'Счетчики/датчики';


--
-- Name: COLUMN counters.objectid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN counters.objectid IS 'Ссылка на узел топологии';


--
-- Name: COLUMN counters.regdate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN counters.regdate IS 'Дата постановки на коммерческий учет';


--
-- Name: COLUMN counters.unregdate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN counters.unregdate IS 'Дата снятия с коммерческого учета';


--
-- Name: COLUMN counters.checkdate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN counters.checkdate IS 'Дата проверки';


--
-- Name: counters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE counters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: counters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE counters_id_seq OWNED BY counters.id;


--
-- Name: countnodes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE countnodes (
    id integer NOT NULL,
    code string,
    name string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    ownerid integer,
    houseobjectid integer,
    insdate date,
    deldate date
);


--
-- Name: TABLE countnodes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE countnodes IS 'Узлы учета';


--
-- Name: countnodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countnodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: countnodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countnodes_id_seq OWNED BY countnodes.id;


--
-- Name: countpprtypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE countpprtypes (
    id integer NOT NULL,
    code string,
    name string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: countpprtypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countpprtypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: countpprtypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countpprtypes_id_seq OWNED BY countpprtypes.id;


--
-- Name: counttsptypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE counttsptypes (
    id integer NOT NULL,
    code string,
    name string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: counttsptypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE counttsptypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: counttsptypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE counttsptypes_id_seq OWNED BY counttsptypes.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE departments (
    id integer NOT NULL,
    code citext NOT NULL,
    name citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    deldate date,
    insdate date DEFAULT '1900-01-01'::date
);


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE departments_id_seq OWNED BY departments.id;


--
-- Name: dictionary; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dictionary (
    id integer NOT NULL,
    languagecode citext NOT NULL,
    code string NOT NULL,
    name nstring NOT NULL,
    names nstring,
    abbr nstring,
    rem nstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: dictionary_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dictionary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: dictionary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dictionary_id_seq OWNED BY dictionary.id;


--
-- Name: entities; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE entities (
    id integer NOT NULL,
    code citext NOT NULL,
    rem citext,
    decorator citext,
    orderby citext,
    table_id_ integer,
    lookupcategory string,
    priority integer,
    type string NOT NULL,
    validateproc string,
    updateproc string,
    revisionthreshold integer DEFAULT 1000,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    lookuphierarchyid integer,
    istranslatable boolean DEFAULT false NOT NULL,
    uniquefields longstring,
    rm_mask bit(16)
);


--
-- Name: COLUMN entities.validateproc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN entities.validateproc IS 'Процедура валидации перед insert/update';


--
-- Name: entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE entities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entities_id_seq OWNED BY entities.id;


--
-- Name: entityproperties; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE entityproperties (
    id integer NOT NULL,
    entityid integer,
    orderno smallint,
    refentityid integer,
    datatype smallstring,
    datalength smallint,
    mandatory boolean DEFAULT false NOT NULL,
    istemporal boolean DEFAULT false NOT NULL,
    code string,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    propgroup string,
    validationsql longstring,
    retrievesql longeststring,
    editable string,
    donumsort boolean DEFAULT false NOT NULL,
    lookuphierarchyid integer
);


--
-- Name: entityproperties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE entityproperties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: entityproperties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entityproperties_id_seq OWNED BY entityproperties.id;


--
-- Name: entityvalidation; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE entityvalidation (
    id integer NOT NULL,
    entityid integer NOT NULL,
    code string NOT NULL,
    checkmode string NOT NULL,
    rulesql longeststring NOT NULL,
    errorcode string NOT NULL,
    rem longstring
);


--
-- Name: entityvalidation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE entityvalidation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: entityvalidation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entityvalidation_id_seq OWNED BY entityvalidation.id;


--
-- Name: entrances; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE entrances (
    id integer NOT NULL,
    houseobjectid integer NOT NULL,
    num smallint NOT NULL,
    code tinystring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE entrances; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE entrances IS 'Подъезды';


--
-- Name: COLUMN entrances.houseobjectid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN entrances.houseobjectid IS 'Указатель адреса';


--
-- Name: COLUMN entrances.num; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN entrances.num IS 'Номер подъезда';


--
-- Name: COLUMN entrances.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN entrances.code IS 'Код замка';


--
-- Name: entrances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE entrances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: entrances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entrances_id_seq OWNED BY entrances.id;


--
-- Name: errors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE errors (
    code string NOT NULL,
    state string NOT NULL,
    legacystate string,
    rem longstring
);


--
-- Name: eventlog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE eventlog (
    id integer NOT NULL,
    ts timestamp without time zone DEFAULT clock_timestamp(),
    userid integer,
    sqlstate text,
    sqlerrm text,
    data text
);


--
-- Name: eventlog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE eventlog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: eventlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE eventlog_id_seq OWNED BY eventlog.id;


--
-- Name: formcontrols; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formcontrols (
    id integer NOT NULL,
    formid integer NOT NULL,
    orderno smallint NOT NULL,
    column_id_ integer,
    entityid integer NOT NULL,
    fieldname citext NOT NULL,
    iseditable boolean DEFAULT true NOT NULL,
    controltypeid integer,
    style citext,
    misc citext,
    rem citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: formcontrols_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formcontrols_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: formcontrols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formcontrols_id_seq OWNED BY formcontrols.id;


--
-- Name: forms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE forms (
    id integer NOT NULL,
    code citext NOT NULL,
    name citext NOT NULL,
    rem citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: forms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE forms_id_seq OWNED BY forms.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE groups (
    id integer NOT NULL,
    code string,
    rem longstring,
    isadmin boolean DEFAULT false NOT NULL,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE groups_id_seq OWNED BY groups.id;


--
-- Name: objectproperties; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE objectproperties (
    id integer NOT NULL,
    objectid integer,
    propertyid integer NOT NULL,
    datefrom date DEFAULT '1900-01-01'::date NOT NULL,
    value string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    rowid integer
);


--
-- Name: heat_objects; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW heat_objects AS
    WITH obj AS (SELECT p.objectid, p.parentid, p.level, e.code AS entitycode, o.code AS objectcode, o.name AS objectname FROM ((sys_getparentobjectsall(sys_getworkingdate()) p(objectid, parentid, level) JOIN objects o ON ((p.parentid = o.id))) JOIN entities e ON ((o.entityid = e.id)))), objprop AS (SELECT o.id AS objectid, p.propertyid, (SELECT objectproperties.value FROM objectproperties WHERE (((objectproperties.objectid = o.id) AND (objectproperties.datefrom <= sys_getworkingdate())) AND (objectproperties.propertyid = p.propertyid)) ORDER BY objectproperties.datefrom DESC LIMIT 1) AS value FROM (objects o CROSS JOIN (SELECT 14 AS propertyid UNION ALL SELECT 15) p) WHERE (((o.entityid = (SELECT entities.id FROM entities WHERE (entities.code = 'ElevatorNodes'::citext))) AND ((o.deldate IS NULL) OR (o.deldate > sys_getworkingdate()))) AND (o.insdate <= sys_getworkingdate()))), place AS (SELECT o.id, o.code AS num, o.rem, sys_getattrvalue(NULL::integer, o.id, 'HouseId'::text, sys_getworkingdate()) AS houseid, sys_getattrvalue(NULL::integer, o.id, 'Area'::text, sys_getworkingdate()) AS area, sys_getattrvalue(NULL::integer, o.id, 'Rem2'::text, sys_getworkingdate()) AS rem2, sys_getattrvalue(NULL::integer, o.id, 'PayerId'::text, sys_getworkingdate()) AS payerid, sys_getattrvalue(NULL::integer, o.id, 'Svc1ParentId'::text, sys_getworkingdate()) AS svc1parentid, sys_getattrvalue(NULL::integer, o.id, 'Svc2ParentId'::text, sys_getworkingdate()) AS svc2parentid, o.revision FROM objects o WHERE (o.entityid = (SELECT entities.id FROM entities WHERE (entities.code = 'Places'::citext)))), house AS (SELECT o.id, o.code AS num, o.rem, sys_getattrvalue(NULL::integer, o.id, 'StreetId'::text, sys_getworkingdate()) AS streetid, sys_getattrvalue(NULL::integer, o.id, 'DepartmentId'::text, sys_getworkingdate()) AS departmentid FROM objects o WHERE (o.entityid = (SELECT entities.id FROM entities WHERE (entities.code = 'Houses'::citext)))) SELECT p.id, p.revision, d.code AS "Код р-на", d.name AS "Назв. р-на", boiler.objectcode AS "Код кот.", boiler.objectname AS "Котельная", trp.objectcode AS "Код ТРП", trp.objectname AS "ТРП", st.code AS "Код ул.", s.name AS "Назв. ул.", h.num AS "Номер", p.rem AS "Потребитель", c.code AS "Код плат.", c.name AS "Плательщик", sys_getattrvalue(18, c.id, 'ConsumerClass(VID_P)'::text, sys_getworkingdate()) AS "Вид потр.", (p.area)::numeric(18,2) AS "Площадь спр.", (CASE WHEN (COALESCE((otp.value1)::numeric, (0)::numeric) = (0)::numeric) THEN ((otp.value2)::numeric * 0.025) ELSE ((otp.value1)::numeric * 0.025) END)::numeric(18,2) AS "отп Гкал спр.", (otp.value1)::numeric(18,2) AS "отп м.кв.", (otp.value2)::numeric(18,2) AS "отп Гкал", (grv.value1)::numeric(18,2) AS "грв м.куб.", (grv.value2)::numeric(18,2) AS "грв Гкал", (grv.value3)::integer AS "грв чел.", p.rem2 AS "Коментарий 2", en.code AS "Код ЭУ", (((ootp.value)::numeric * 0.00033848))::numeric(18,2) AS "ЭУ отп", (((ogrv.value)::numeric * 0.00033848))::numeric(18,2) AS "ЭУ грв", en.rem AS "Коментарий ЭУ" FROM ((((((((((((place p JOIN house h ON (((p.houseid)::integer = h.id))) JOIN streets s ON (((h.streetid)::integer = s.id))) JOIN streettypes st ON ((s.streettypeid = st.id))) JOIN departments d ON (((h.departmentid)::integer = d.id))) LEFT JOIN consumers c ON (((p.payerid)::integer = c.id))) LEFT JOIN objectcapacities otp ON ((((p.id = otp.objectid) AND (otp.serviceid = 1)) AND (otp.datefrom = (SELECT max(objectcapacities.datefrom) AS max FROM objectcapacities WHERE ((objectcapacities.datefrom <= sys_getworkingdate()) AND (objectcapacities.objectid = otp.objectid))))))) LEFT JOIN objectcapacities grv ON ((((p.id = grv.objectid) AND (grv.serviceid = 2)) AND (grv.datefrom = (SELECT max(objectcapacities.datefrom) AS max FROM objectcapacities WHERE ((objectcapacities.datefrom <= sys_getworkingdate()) AND (objectcapacities.objectid = grv.objectid))))))) LEFT JOIN objects en ON ((en.id = (p.svc1parentid)::integer))) LEFT JOIN objprop ogrv ON (((en.id = ogrv.objectid) AND (ogrv.propertyid = 14)))) LEFT JOIN objprop ootp ON (((en.id = ootp.objectid) AND (ootp.propertyid = 15)))) LEFT JOIN obj trp ON (((trp.objectid = en.id) AND (trp.entitycode = 'TRP'::citext)))) LEFT JOIN obj boiler ON (((boiler.objectid = en.id) AND (boiler.entitycode = 'Boilers'::citext)))) ORDER BY d.code, d.name, s.name, ("substring"((h.num)::text, 'd+'::text))::integer, h.num;


--
-- Name: hierarchies; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE hierarchies (
    id integer NOT NULL,
    code citext NOT NULL,
    priority smallint,
    rem citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    type string,
    rm_mask bit(16)
);


--
-- Name: COLUMN hierarchies.priority; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN hierarchies.priority IS 'Порядок сортировки';


--
-- Name: hierarchies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE hierarchies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: hierarchies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE hierarchies_id_seq OWNED BY hierarchies.id;


--
-- Name: hierarchyfolders; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE hierarchyfolders (
    id integer NOT NULL,
    entityid integer NOT NULL,
    code citext,
    criteriasql longeststring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    type string DEFAULT 'Tree'::citext NOT NULL,
    hint longstring,
    parentfield longstring,
    childfield longstring,
    priority integer,
    hierarchyid integer NOT NULL,
    parententityid integer NOT NULL,
    action string,
    isselectable boolean DEFAULT true NOT NULL,
    rm_mask bit(16)
);


--
-- Name: hierarchyfolders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE hierarchyfolders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: hierarchyfolders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE hierarchyfolders_id_seq OWNED BY hierarchyfolders.id;


--
-- Name: houseowners; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE houseowners (
    id integer NOT NULL,
    datefrom date,
    houseobjectid integer NOT NULL,
    consumerid integer NOT NULL,
    area number,
    flatrange string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE houseowners; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE houseowners IS 'Балансосодержатели';


--
-- Name: COLUMN houseowners.houseobjectid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN houseowners.houseobjectid IS 'Указатель на здание';


--
-- Name: COLUMN houseowners.consumerid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN houseowners.consumerid IS 'ссылка на балансосодержателя здания';


--
-- Name: COLUMN houseowners.area; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN houseowners.area IS 'площадь';


--
-- Name: COLUMN houseowners.flatrange; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN houseowners.flatrange IS 'диапазон квартир';


--
-- Name: houseowners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE houseowners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: houseowners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE houseowners_id_seq OWNED BY houseowners.id;


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE languages (
    code citext NOT NULL,
    name string NOT NULL,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: objectcapacities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE objectcapacities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: objectcapacities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE objectcapacities_id_seq OWNED BY objectcapacities.id;


--
-- Name: objectproperties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE objectproperties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: objectproperties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE objectproperties_id_seq OWNED BY objectproperties.id;


--
-- Name: objects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE objects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: objects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE objects_id_seq OWNED BY objects.id;


--
-- Name: persons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE persons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: persons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE persons_id_seq OWNED BY persons.id;


--
-- Name: prefs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE prefs (
    id integer NOT NULL,
    code string NOT NULL,
    datatype smallstring NOT NULL,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    type string DEFAULT "current_user"() NOT NULL
);


--
-- Name: prefs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE prefs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: prefs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE prefs_id_seq OWNED BY prefs.id;


--
-- Name: prefvalues; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE prefvalues (
    id integer NOT NULL,
    prefid integer NOT NULL,
    userid integer,
    sessionid integer,
    datefrom date,
    value longstring NOT NULL,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: prefvalues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE prefvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: prefvalues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE prefvalues_id_seq OWNED BY prefvalues.id;


--
-- Name: regions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE regions (
    id integer NOT NULL,
    code citext NOT NULL,
    name citext,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE regions_id_seq OWNED BY regions.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE reports (
    id integer NOT NULL,
    code string NOT NULL,
    calctypeid integer,
    rem longstring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    reportsql longeststring,
    rm_mask bit(16)
);


--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE reports_id_seq OWNED BY reports.id;


--
-- Name: rms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rms (
    id integer NOT NULL,
    code citext NOT NULL,
    name citext NOT NULL,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: rms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: rms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rms_id_seq OWNED BY rms.id;


--
-- Name: servicelog; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE servicelog (
    id integer NOT NULL,
    objectid integer,
    datefrom date,
    serviceid integer,
    state boolean NOT NULL,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: TABLE servicelog; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE servicelog IS 'Подача неподача услуг (Журнал отключений)';


--
-- Name: COLUMN servicelog.objectid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN servicelog.objectid IS 'узел топологии';


--
-- Name: COLUMN servicelog.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN servicelog.state IS 'Состояние (вкл/выкл)';


--
-- Name: servicelog_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE servicelog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: servicelog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE servicelog_id_seq OWNED BY servicelog.id;


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE services_id_seq OWNED BY services.id;


--
-- Name: streets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE streets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: streets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE streets_id_seq OWNED BY streets.id;


--
-- Name: streettypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE streettypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: streettypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE streettypes_id_seq OWNED BY streettypes.id;


--
-- Name: tariffs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tariffs (
    id integer NOT NULL,
    code string,
    name string NOT NULL,
    rem string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    insdate date,
    deldate date
);


--
-- Name: TABLE tariffs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE tariffs IS 'Тарифы';


--
-- Name: tariffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tariffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tariffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tariffs_id_seq OWNED BY tariffs.id;


--
-- Name: tariffvalues; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tariffvalues (
    id integer NOT NULL,
    datefrom date NOT NULL,
    tariffid integer NOT NULL,
    serviceid integer NOT NULL,
    value1 number,
    value2 number,
    value3 number,
    rem longstring,
    insertuserid string DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid string DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: tariffvalues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tariffvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tariffvalues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tariffvalues_id_seq OWNED BY tariffvalues.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tasks (
    id integer NOT NULL,
    typeid integer,
    subjectid integer,
    description longstring,
    state string,
    progress integer DEFAULT (-1),
    progressrem longeststring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tasks_id_seq OWNED BY tasks.id;


--
-- Name: tasktypes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tasktypes (
    id integer NOT NULL,
    code string NOT NULL,
    progressmax integer,
    rem longeststring,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0,
    entityid integer NOT NULL
);


--
-- Name: tasktypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tasktypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tasktypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tasktypes_id_seq OWNED BY tasktypes.id;


--
-- Name: typemapping; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE typemapping (
    sqltype text NOT NULL,
    javasqltype text,
    typegroup text
);


--
-- Name: usergroups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE usergroups (
    id integer NOT NULL,
    userid integer NOT NULL,
    groupid integer NOT NULL,
    enabled boolean DEFAULT true NOT NULL
);


--
-- Name: usergroups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE usergroups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: usergroups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE usergroups_id_seq OWNED BY usergroups.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    name string,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: z_ext_streets_ispolkom; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE z_ext_streets_ispolkom (
    code numeric(30,6),
    type citext,
    name citext,
    streettypeid integer,
    streetid integer,
    insertuserid citext DEFAULT "current_user"(),
    insertts timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    updateuserid citext DEFAULT "current_user"(),
    updatets timestamp without time zone DEFAULT ('now'::text)::timestamp without time zone,
    revision integer DEFAULT 0
);


--
-- Name: z_tmpcalc; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE z_tmpcalc (
    objectid integer,
    serviceid integer,
    tmlid integer,
    rowid integer,
    datefrom date,
    dateto date,
    value text
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE auditlog ALTER COLUMN id SET DEFAULT nextval('auditlog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE banks ALTER COLUMN id SET DEFAULT nextval('banks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE benefits ALTER COLUMN id SET DEFAULT nextval('benefits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE benefittypes ALTER COLUMN id SET DEFAULT nextval('benefittypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE calctemplates ALTER COLUMN id SET DEFAULT nextval('calctypedefs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE calctypes ALTER COLUMN id SET DEFAULT nextval('calctypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE calculations ALTER COLUMN id SET DEFAULT nextval('calculations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE cities ALTER COLUMN id SET DEFAULT nextval('cities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE consumers ALTER COLUMN id SET DEFAULT nextval('consumers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE contracts ALTER COLUMN id SET DEFAULT nextval('contracts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE countcalctypes ALTER COLUMN id SET DEFAULT nextval('countcalctypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE countcalculators ALTER COLUMN id SET DEFAULT nextval('countcalculators_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE countdata ALTER COLUMN id SET DEFAULT nextval('countdata_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE counters ALTER COLUMN id SET DEFAULT nextval('counters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE countnodes ALTER COLUMN id SET DEFAULT nextval('countnodes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE countpprtypes ALTER COLUMN id SET DEFAULT nextval('countpprtypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE counttsptypes ALTER COLUMN id SET DEFAULT nextval('counttsptypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE departments ALTER COLUMN id SET DEFAULT nextval('departments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE dictionary ALTER COLUMN id SET DEFAULT nextval('dictionary_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE entities ALTER COLUMN id SET DEFAULT nextval('entities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE entityproperties ALTER COLUMN id SET DEFAULT nextval('entityproperties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE entityvalidation ALTER COLUMN id SET DEFAULT nextval('entityvalidation_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE entrances ALTER COLUMN id SET DEFAULT nextval('entrances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE eventlog ALTER COLUMN id SET DEFAULT nextval('eventlog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE formcontrols ALTER COLUMN id SET DEFAULT nextval('formcontrols_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE forms ALTER COLUMN id SET DEFAULT nextval('forms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE groups ALTER COLUMN id SET DEFAULT nextval('groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE hierarchies ALTER COLUMN id SET DEFAULT nextval('hierarchies_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE hierarchyfolders ALTER COLUMN id SET DEFAULT nextval('hierarchyfolders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE houseowners ALTER COLUMN id SET DEFAULT nextval('houseowners_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE objectcapacities ALTER COLUMN id SET DEFAULT nextval('objectcapacities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE objectproperties ALTER COLUMN id SET DEFAULT nextval('objectproperties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE objects ALTER COLUMN id SET DEFAULT nextval('objects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE persons ALTER COLUMN id SET DEFAULT nextval('persons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE prefs ALTER COLUMN id SET DEFAULT nextval('prefs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE prefvalues ALTER COLUMN id SET DEFAULT nextval('prefvalues_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE regions ALTER COLUMN id SET DEFAULT nextval('regions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE reports ALTER COLUMN id SET DEFAULT nextval('reports_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE rms ALTER COLUMN id SET DEFAULT nextval('rms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE servicelog ALTER COLUMN id SET DEFAULT nextval('servicelog_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE services ALTER COLUMN id SET DEFAULT nextval('services_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE streets ALTER COLUMN id SET DEFAULT nextval('streets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE streettypes ALTER COLUMN id SET DEFAULT nextval('streettypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tariffs ALTER COLUMN id SET DEFAULT nextval('tariffs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tariffvalues ALTER COLUMN id SET DEFAULT nextval('tariffvalues_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tasks ALTER COLUMN id SET DEFAULT nextval('tasks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tasktypes ALTER COLUMN id SET DEFAULT nextval('tasktypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE usergroups ALTER COLUMN id SET DEFAULT nextval('usergroups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: pk_auditlog; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY auditlog
    ADD CONSTRAINT pk_auditlog PRIMARY KEY (id);


--
-- Name: pk_bank; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT pk_bank PRIMARY KEY (mfo);


--
-- Name: pk_benefits; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY benefits
    ADD CONSTRAINT pk_benefits PRIMARY KEY (id);


--
-- Name: pk_benefittypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY benefittypes
    ADD CONSTRAINT pk_benefittypes PRIMARY KEY (id);


--
-- Name: pk_calctypedefs; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY calctemplates
    ADD CONSTRAINT pk_calctypedefs PRIMARY KEY (id);


--
-- Name: pk_calctypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY calctypes
    ADD CONSTRAINT pk_calctypes PRIMARY KEY (id);


--
-- Name: pk_calculations; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY calculations
    ADD CONSTRAINT pk_calculations PRIMARY KEY (id);


--
-- Name: pk_cities; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cities
    ADD CONSTRAINT pk_cities PRIMARY KEY (id);


--
-- Name: pk_consumers; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY consumers
    ADD CONSTRAINT pk_consumers PRIMARY KEY (id);


--
-- Name: pk_contracts; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contracts
    ADD CONSTRAINT pk_contracts PRIMARY KEY (id);


--
-- Name: pk_countcalctypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY countcalctypes
    ADD CONSTRAINT pk_countcalctypes PRIMARY KEY (id);


--
-- Name: pk_countcalculators; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY countcalculators
    ADD CONSTRAINT pk_countcalculators PRIMARY KEY (id);


--
-- Name: pk_countdata; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY countdata
    ADD CONSTRAINT pk_countdata PRIMARY KEY (id);


--
-- Name: pk_counters; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT pk_counters PRIMARY KEY (id);


--
-- Name: pk_countnodes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY countnodes
    ADD CONSTRAINT pk_countnodes PRIMARY KEY (id);


--
-- Name: pk_countpprtypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY countpprtypes
    ADD CONSTRAINT pk_countpprtypes PRIMARY KEY (id);


--
-- Name: pk_counttsptypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY counttsptypes
    ADD CONSTRAINT pk_counttsptypes PRIMARY KEY (id);


--
-- Name: pk_departments; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT pk_departments PRIMARY KEY (id);


--
-- Name: pk_dictionary; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dictionary
    ADD CONSTRAINT pk_dictionary PRIMARY KEY (id);


--
-- Name: pk_entities; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entities
    ADD CONSTRAINT pk_entities PRIMARY KEY (id);


--
-- Name: pk_entityproperties; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entityproperties
    ADD CONSTRAINT pk_entityproperties PRIMARY KEY (id);


--
-- Name: pk_entityvalidation; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entityvalidation
    ADD CONSTRAINT pk_entityvalidation PRIMARY KEY (id);


--
-- Name: pk_entrances; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY entrances
    ADD CONSTRAINT pk_entrances PRIMARY KEY (id);


--
-- Name: pk_errors; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY errors
    ADD CONSTRAINT pk_errors PRIMARY KEY (code);


--
-- Name: pk_eventlog; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY eventlog
    ADD CONSTRAINT pk_eventlog PRIMARY KEY (id);


--
-- Name: pk_formcontrols; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formcontrols
    ADD CONSTRAINT pk_formcontrols PRIMARY KEY (id);


--
-- Name: pk_forms; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT pk_forms PRIMARY KEY (id);


--
-- Name: pk_groups; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT pk_groups PRIMARY KEY (id);


--
-- Name: pk_hierarchies; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hierarchies
    ADD CONSTRAINT pk_hierarchies PRIMARY KEY (id);


--
-- Name: pk_hierarchyfolders; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hierarchyfolders
    ADD CONSTRAINT pk_hierarchyfolders PRIMARY KEY (id);


--
-- Name: pk_houseowners; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY houseowners
    ADD CONSTRAINT pk_houseowners PRIMARY KEY (id);


--
-- Name: pk_languages; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY languages
    ADD CONSTRAINT pk_languages PRIMARY KEY (code);


--
-- Name: pk_objectcapacities; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objectcapacities
    ADD CONSTRAINT pk_objectcapacities PRIMARY KEY (id);


--
-- Name: pk_objectproperties; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objectproperties
    ADD CONSTRAINT pk_objectproperties PRIMARY KEY (id);


--
-- Name: pk_objects; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT pk_objects PRIMARY KEY (id);


--
-- Name: pk_persons; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY persons
    ADD CONSTRAINT pk_persons PRIMARY KEY (id);


--
-- Name: pk_prefs; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY prefs
    ADD CONSTRAINT pk_prefs PRIMARY KEY (id);


--
-- Name: pk_prefvalues; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY prefvalues
    ADD CONSTRAINT pk_prefvalues PRIMARY KEY (id);


--
-- Name: pk_regions; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY regions
    ADD CONSTRAINT pk_regions PRIMARY KEY (id);


--
-- Name: pk_reports; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY reports
    ADD CONSTRAINT pk_reports PRIMARY KEY (id);


--
-- Name: pk_rms; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rms
    ADD CONSTRAINT pk_rms PRIMARY KEY (id);


--
-- Name: pk_servicelog; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY servicelog
    ADD CONSTRAINT pk_servicelog PRIMARY KEY (id);


--
-- Name: pk_services; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT pk_services PRIMARY KEY (id);


--
-- Name: pk_streets; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY streets
    ADD CONSTRAINT pk_streets PRIMARY KEY (id);


--
-- Name: pk_streettypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY streettypes
    ADD CONSTRAINT pk_streettypes PRIMARY KEY (id);


--
-- Name: pk_tariffs; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tariffs
    ADD CONSTRAINT pk_tariffs PRIMARY KEY (id);


--
-- Name: pk_tariffvalues; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tariffvalues
    ADD CONSTRAINT pk_tariffvalues PRIMARY KEY (id);


--
-- Name: pk_tasks; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT pk_tasks PRIMARY KEY (id);


--
-- Name: pk_tasktypes; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tasktypes
    ADD CONSTRAINT pk_tasktypes PRIMARY KEY (id);


--
-- Name: pk_users; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT pk_users PRIMARY KEY (id);


--
-- Name: typemapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY typemapping
    ADD CONSTRAINT typemapping_pkey PRIMARY KEY (sqltype);


--
-- Name: usergroups_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY usergroups
    ADD CONSTRAINT usergroups_pkey PRIMARY KEY (id);


--
-- Name: idx_z_tmpcalc; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_z_tmpcalc ON z_tmpcalc USING btree (objectid, serviceid, tmlid, datefrom DESC);


--
-- Name: ind_z_ext_streets_ispolkom_1; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX ind_z_ext_streets_ispolkom_1 ON z_ext_streets_ispolkom USING btree (streettypeid);


--
-- Name: ind_z_ext_streets_ispolkom_2; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX ind_z_ext_streets_ispolkom_2 ON z_ext_streets_ispolkom USING btree (streetid);


--
-- Name: ix_cities_nm; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_cities_nm ON cities USING btree (name);


--
-- Name: ix_houseowns_houseid_consumerid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_houseowns_houseid_consumerid ON houseowners USING btree (consumerid);


--
-- Name: ix_objectprop_proprtyid_value; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX ix_objectprop_proprtyid_value ON objectproperties USING btree (propertyid, value);


--
-- Name: ix_objectproperties_proprtyid_value; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX ix_objectproperties_proprtyid_value ON objectproperties USING btree (propertyid, value);


--
-- Name: ix_objects_entityid_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX ix_objects_entityid_code ON objects USING btree (entityid, code);


--
-- Name: ix_streets; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_streets ON streets USING btree (streettypeid, name, spec);


--
-- Name: ix_streets_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_streets_code ON streets USING btree (code);


--
-- Name: ix_streettypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_streettypes_code ON streettypes USING btree (code);


--
-- Name: ix_streettypes_nm; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ix_streettypes_nm ON streettypes USING btree (name);


--
-- Name: un_calclockdef_calctyp_ordno; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_calclockdef_calctyp_ordno ON calctemplates USING btree (calctypeid, orderno);


--
-- Name: un_calclockdefs_calctypeid_orderno; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_calclockdefs_calctypeid_orderno ON calctemplates USING btree (calctypeid, orderno);


--
-- Name: un_calctypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_calctypes_code ON calctypes USING btree (code);


--
-- Name: un_calcul_calctype_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_calcul_calctype_datefrom ON calculations USING btree (calctypeid, datefrom);


--
-- Name: un_calculations_calctype_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_calculations_calctype_datefrom ON calculations USING btree (calctypeid, datefrom);


--
-- Name: un_countcalctypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countcalctypes_code ON countcalctypes USING btree (code);


--
-- Name: un_countcalculators_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countcalculators_code ON countcalculators USING btree (code);


--
-- Name: un_countdata_id_count_datfrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countdata_id_count_datfrom ON countdata USING btree (id, counterid, datefrom);


--
-- Name: un_countdata_id_counterid_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countdata_id_counterid_datefrom ON countdata USING btree (id, counterid, datefrom);


--
-- Name: un_counters_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_counters_code ON counters USING btree (code);


--
-- Name: un_countnodes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countnodes_code ON countnodes USING btree (code);


--
-- Name: un_countpprtypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_countpprtypes_code ON countpprtypes USING btree (code);


--
-- Name: un_counttsptypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX un_counttsptypes_code ON counttsptypes USING btree (code);


--
-- Name: un_departments_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_departments_code ON departments USING btree (code);


--
-- Name: un_dictionary_langcode_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_dictionary_langcode_code ON dictionary USING btree (languagecode, code);


--
-- Name: un_entities_lookcategory_prioty; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_entities_lookcategory_prioty ON entities USING btree (lookupcategory, priority);


--
-- Name: un_entities_lookupcategory_priority; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_entities_lookupcategory_priority ON entities USING btree (lookupcategory, priority);


--
-- Name: un_entitypropert_entityid_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_entitypropert_entityid_code ON entityproperties USING btree (entityid, code);


--
-- Name: un_entityproperties_entityid_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_entityproperties_entityid_code ON entityproperties USING btree (entityid, code);


--
-- Name: un_entityvalidation_entityid_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_entityvalidation_entityid_code ON entityvalidation USING btree (entityid, code);


--
-- Name: un_errors_legacystate; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX un_errors_legacystate ON errors USING btree (legacystate);


--
-- Name: un_errors_state; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX un_errors_state ON errors USING btree (state);


--
-- Name: un_groups_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_groups_code ON groups USING btree (code);


--
-- Name: un_hierarchyfolders_hierarchyid_parententityid_entityid_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_hierarchyfolders_hierarchyid_parententityid_entityid_type ON hierarchyfolders USING btree (hierarchyid, parententityid, entityid, code, type);


--
-- Name: un_hierarfold_hier_parid_enid_typ; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_hierarfold_hier_parid_enid_typ ON hierarchyfolders USING btree (entityid, code, type, hierarchyid, parententityid);


--
-- Name: un_objectprop_objid_prop_datfrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_objectprop_objid_prop_datfrom ON objectproperties USING btree (objectid, propertyid, datefrom);


--
-- Name: un_objectprop_rowid_prop_datfrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_objectprop_rowid_prop_datfrom ON objectproperties USING btree (propertyid, datefrom, rowid);


--
-- Name: un_objectproperties_objectid_propertyid_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_objectproperties_objectid_propertyid_datefrom ON objectproperties USING btree (objectid, propertyid, datefrom);


--
-- Name: un_objectproperties_rowid_propertyid_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_objectproperties_rowid_propertyid_datefrom ON objectproperties USING btree (rowid, propertyid, datefrom);


--
-- Name: un_prefs_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_prefs_code ON prefs USING btree (code);


--
-- Name: un_regions_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_regions_code ON regions USING btree (code);


--
-- Name: un_reports_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_reports_code ON reports USING btree (code);


--
-- Name: un_tariffs_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_tariffs_code ON tariffs USING btree (code);


--
-- Name: un_tariffs_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_tariffs_name ON tariffs USING btree (name);


--
-- Name: un_tariffvalues_tariffid_serviceid_datefrom; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_tariffvalues_tariffid_serviceid_datefrom ON tariffvalues USING btree (tariffid, serviceid, datefrom);


--
-- Name: un_tasks_insertts; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_tasks_insertts ON tasks USING btree (insertts);


--
-- Name: un_tasktypes_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_tasktypes_code ON tasktypes USING btree (code);


--
-- Name: un_usergroups_userid_groupid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX un_usergroups_userid_groupid ON usergroups USING btree (userid, groupid);


--
-- Name: ux_benefittypes; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ux_benefittypes ON benefittypes USING btree (kfk, code);


--
-- Name: ux_consumers_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ux_consumers_code ON consumers USING btree (code);


--
-- Name: ux_contracts; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ux_contracts ON contracts USING btree (consumerid, code, datefrom);


--
-- Name: ux_objectcapacities; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ux_objectcapacities ON objectcapacities USING btree (datefrom, objectid, serviceid, contractid);


--
-- Name: ux_persons_gekid_account; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX ux_persons_gekid_account ON persons USING btree (gekid, account);


--
-- Name: updusts_benefits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_benefits
    BEFORE UPDATE ON benefits
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_benefittypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_benefittypes
    BEFORE UPDATE ON benefittypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_calctypedefs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_calctypedefs
    BEFORE UPDATE ON calctemplates
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_calctypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_calctypes
    BEFORE UPDATE ON calctypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_calculations; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_calculations
    BEFORE UPDATE ON calculations
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_cities; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_cities
    BEFORE UPDATE ON cities
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_consumers; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_consumers
    BEFORE UPDATE ON consumers
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_contracts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_contracts
    BEFORE UPDATE ON contracts
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_countcalctypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_countcalctypes
    BEFORE UPDATE ON countcalctypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_countcalculators; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_countcalculators
    BEFORE UPDATE ON countcalculators
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_countdata; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_countdata
    BEFORE UPDATE ON countdata
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_counters; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_counters
    BEFORE UPDATE ON counters
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_countnodes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_countnodes
    BEFORE UPDATE ON countnodes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_countpprtypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_countpprtypes
    BEFORE UPDATE ON countpprtypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_counttsptypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_counttsptypes
    BEFORE UPDATE ON counttsptypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_departments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_departments
    BEFORE UPDATE ON departments
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_dictionary; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_dictionary
    BEFORE UPDATE ON dictionary
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_entities; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_entities
    BEFORE UPDATE ON entities
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_entityproperties; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_entityproperties
    BEFORE UPDATE ON entityproperties
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_entrances; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_entrances
    BEFORE UPDATE ON entrances
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_eventlog; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_eventlog
    BEFORE UPDATE ON eventlog
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_formcontrols; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_formcontrols
    BEFORE UPDATE ON formcontrols
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_forms; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_forms
    BEFORE UPDATE ON forms
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_groups; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_groups
    BEFORE UPDATE ON groups
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_hierarchies; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_hierarchies
    BEFORE UPDATE ON hierarchies
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_hierarchyfolders; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_hierarchyfolders
    BEFORE UPDATE ON hierarchyfolders
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_houseowners; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_houseowners
    BEFORE UPDATE ON houseowners
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_languages; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_languages
    BEFORE UPDATE ON languages
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_objectproperties; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_objectproperties
    BEFORE UPDATE ON objectproperties
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_objects; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_objects
    BEFORE UPDATE ON objects
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_persons; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_persons
    BEFORE UPDATE ON persons
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_prefs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_prefs
    BEFORE UPDATE ON prefs
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_prefvalues; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_prefvalues
    BEFORE UPDATE ON prefvalues
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_regions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_regions
    BEFORE UPDATE ON regions
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_reports; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_reports
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_servicelog; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_servicelog
    BEFORE UPDATE ON servicelog
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_services; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_services
    BEFORE UPDATE ON services
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_streets; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_streets
    BEFORE UPDATE ON streets
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_streettypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_streettypes
    BEFORE UPDATE ON streettypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_tariffs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_tariffs
    BEFORE UPDATE ON tariffs
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_tariffvalues; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_tariffvalues
    BEFORE UPDATE ON tariffvalues
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_tasks; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_tasks
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_tasktypes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_tasktypes
    BEFORE UPDATE ON tasktypes
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_users; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_users
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: updusts_z_ext_streets_ispolkom; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER updusts_z_ext_streets_ispolkom
    BEFORE UPDATE ON z_ext_streets_ispolkom
    FOR EACH ROW
    EXECUTE PROCEDURE updateusts();


--
-- Name: entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entityvalidation
    ADD CONSTRAINT entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: errors; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entityvalidation
    ADD CONSTRAINT errors FOREIGN KEY (errorcode) REFERENCES errors(code) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_auditlog_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY auditlog
    ADD CONSTRAINT fk_auditlog_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_auditlog_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY auditlog
    ADD CONSTRAINT fk_auditlog_users FOREIGN KEY (userid) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_benefits_benefittypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY benefits
    ADD CONSTRAINT fk_benefits_benefittypes FOREIGN KEY (typeid) REFERENCES benefittypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_benefits_persons; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY benefits
    ADD CONSTRAINT fk_benefits_persons FOREIGN KEY (personid) REFERENCES persons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_calclockdefs_calctypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY calctemplates
    ADD CONSTRAINT fk_calclockdefs_calctypes FOREIGN KEY (calctypeid) REFERENCES calctypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_calculations_calctypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY calculations
    ADD CONSTRAINT fk_calculations_calctypes FOREIGN KEY (calctypeid) REFERENCES calctypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_contracts_consumers; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY contracts
    ADD CONSTRAINT fk_contracts_consumers FOREIGN KEY (consumerid) REFERENCES consumers(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_countcalculators_countcalctypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countcalculators
    ADD CONSTRAINT fk_countcalculators_countcalctypes FOREIGN KEY (calctypeid) REFERENCES countcalctypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_countcalculators_countnodes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countcalculators
    ADD CONSTRAINT fk_countcalculators_countnodes FOREIGN KEY (nodeid) REFERENCES countnodes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_countdata_counters; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countdata
    ADD CONSTRAINT fk_countdata_counters FOREIGN KEY (counterid) REFERENCES counters(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_countcalculators; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_countcalculators FOREIGN KEY (calcid) REFERENCES countcalculators(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_countpprtypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_countpprtypes FOREIGN KEY (pprtypeid) REFERENCES countpprtypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_countpprtypes2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_countpprtypes2 FOREIGN KEY (pprtypeid2) REFERENCES countpprtypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_counttsptypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_counttsptypes FOREIGN KEY (tsptypeid) REFERENCES counttsptypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_counttsptypes2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_counttsptypes2 FOREIGN KEY (tsptypeid2) REFERENCES counttsptypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_objects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_objects FOREIGN KEY (objectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_counters_services; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY counters
    ADD CONSTRAINT fk_counters_services FOREIGN KEY (serviceid) REFERENCES services(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_countnodes_consumers; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countnodes
    ADD CONSTRAINT fk_countnodes_consumers FOREIGN KEY (ownerid) REFERENCES consumers(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_countnodes_houseobjects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countnodes
    ADD CONSTRAINT fk_countnodes_houseobjects FOREIGN KEY (houseobjectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_dictionary_languages; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dictionary
    ADD CONSTRAINT fk_dictionary_languages FOREIGN KEY (languagecode) REFERENCES languages(code) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_entityproperties_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entityproperties
    ADD CONSTRAINT fk_entityproperties_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_entityproperties_entities_ref; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entityproperties
    ADD CONSTRAINT fk_entityproperties_entities_ref FOREIGN KEY (refentityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_entrances_houseobjects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entrances
    ADD CONSTRAINT fk_entrances_houseobjects FOREIGN KEY (houseobjectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_formcontrols_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY formcontrols
    ADD CONSTRAINT fk_formcontrols_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_formcontrols_forms; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY formcontrols
    ADD CONSTRAINT fk_formcontrols_forms FOREIGN KEY (formid) REFERENCES forms(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_hierarchyfolders_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hierarchyfolders
    ADD CONSTRAINT fk_hierarchyfolders_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_hierarchyfolders_entities_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hierarchyfolders
    ADD CONSTRAINT fk_hierarchyfolders_entities_parent FOREIGN KEY (parententityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_hierarchyfolders_hierarchies; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY hierarchyfolders
    ADD CONSTRAINT fk_hierarchyfolders_hierarchies FOREIGN KEY (hierarchyid) REFERENCES hierarchies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_houseowners_consumers; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY houseowners
    ADD CONSTRAINT fk_houseowners_consumers FOREIGN KEY (consumerid) REFERENCES consumers(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_houseowners_houseobjects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY houseowners
    ADD CONSTRAINT fk_houseowners_houseobjects FOREIGN KEY (houseobjectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_objectcapacities_contracts; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objectcapacities
    ADD CONSTRAINT fk_objectcapacities_contracts FOREIGN KEY (contractid) REFERENCES contracts(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_objectcapacities_objects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objectcapacities
    ADD CONSTRAINT fk_objectcapacities_objects FOREIGN KEY (objectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_objectproperties_objects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objectproperties
    ADD CONSTRAINT fk_objectproperties_objects FOREIGN KEY (objectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_objectproperties_objecttypeproperties; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objectproperties
    ADD CONSTRAINT fk_objectproperties_objecttypeproperties FOREIGN KEY (propertyid) REFERENCES entityproperties(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_objects_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT fk_objects_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_persons_objects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY persons
    ADD CONSTRAINT fk_persons_objects FOREIGN KEY (objectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_placecapacities_services; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY objectcapacities
    ADD CONSTRAINT fk_placecapacities_services FOREIGN KEY (serviceid) REFERENCES services(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_prefvalues_prefs; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY prefvalues
    ADD CONSTRAINT fk_prefvalues_prefs FOREIGN KEY (prefid) REFERENCES prefs(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_reports_calctypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY reports
    ADD CONSTRAINT fk_reports_calctypes FOREIGN KEY (calctypeid) REFERENCES calctypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_servicelog_objects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY servicelog
    ADD CONSTRAINT fk_servicelog_objects FOREIGN KEY (objectid) REFERENCES objects(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_servicelog_services; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY servicelog
    ADD CONSTRAINT fk_servicelog_services FOREIGN KEY (serviceid) REFERENCES services(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_streets_cities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY streets
    ADD CONSTRAINT fk_streets_cities FOREIGN KEY (cityid) REFERENCES cities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_streets_streettypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY streets
    ADD CONSTRAINT fk_streets_streettypes FOREIGN KEY (streettypeid) REFERENCES streettypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_tasks_tasktypes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT fk_tasks_tasktypes FOREIGN KEY (typeid) REFERENCES tasktypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_tasktypes_entities; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasktypes
    ADD CONSTRAINT fk_tasktypes_entities FOREIGN KEY (entityid) REFERENCES entities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_userprefs_users; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY prefvalues
    ADD CONSTRAINT fk_userprefs_users FOREIGN KEY (userid) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: services; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tariffvalues
    ADD CONSTRAINT services FOREIGN KEY (serviceid) REFERENCES services(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tariffs; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tariffvalues
    ADD CONSTRAINT tariffs FOREIGN KEY (tariffid) REFERENCES tariffs(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usergroups_groupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY usergroups
    ADD CONSTRAINT usergroups_groupid_fkey FOREIGN KEY (groupid) REFERENCES groups(id);


--
-- Name: usergroups_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY usergroups
    ADD CONSTRAINT usergroups_userid_fkey FOREIGN KEY (userid) REFERENCES users(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

