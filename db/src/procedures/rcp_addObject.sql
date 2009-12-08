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