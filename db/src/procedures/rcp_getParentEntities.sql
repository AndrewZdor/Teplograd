/**
	Get Parent Entities
*/

CREATE OR REPLACE FUNCTION rcp_getparententities(
	IN _HierarchyIdIn INTEGER,
	IN _ChildEntityIdIn INTEGER,
	IN _ChildFieldIn TEXT
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getparententities';

BEGIN
	OPEN result FOR
	SELECT DISTINCT hf.ParentEntityId AS EntityId
	FROM HierarchyFolders hf
	WHERE hf.HierarchyId = _HierarchyIdIn
		AND hf.ChildField = _ChildEntityIdIn
		AND hf.EntityId = _ChildFieldIn;
END;

$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
