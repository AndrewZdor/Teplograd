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