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
