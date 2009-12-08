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