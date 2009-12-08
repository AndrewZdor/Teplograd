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