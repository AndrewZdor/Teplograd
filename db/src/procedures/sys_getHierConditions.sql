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
