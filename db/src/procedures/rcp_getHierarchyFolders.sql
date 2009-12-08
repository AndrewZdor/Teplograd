/**
	Get HierarchyFolders.
*/

CREATE OR REPLACE FUNCTION rcp_getHierarchyFolders (
	IN idin integer DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getHierarchyFolders';

BEGIN
	OPEN result FOR
	SELECT Id,
		   HierarchyId,
		   Code,
		   ParentEntityId,
		   ParentField,
		   EntityId,
		   ChildField,
		   CriteriaSQL,
		   Hint,
		   Action,
		   isSelectable
    FROM HierarchyFolders
    WHERE Id = idin OR COALESCE(idin, 0) = 0
    ORDER BY Priority;

    RETURN result;
END;
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
