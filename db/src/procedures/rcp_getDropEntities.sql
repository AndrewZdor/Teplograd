CREATE OR REPLACE FUNCTION rcp_getDropEntities (
	IN HFolderIdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
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
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
