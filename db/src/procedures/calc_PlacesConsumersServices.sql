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