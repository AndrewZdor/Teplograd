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
