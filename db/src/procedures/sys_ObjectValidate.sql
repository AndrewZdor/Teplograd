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