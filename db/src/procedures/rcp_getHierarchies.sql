/**
	Returns hierarchies. {Hierarchies}
*/
CREATE OR REPLACE FUNCTION rcp_getHierarchies (
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getHierarchies';

BEGIN
	OPEN result FOR
    SELECT Id, Code,
    	sys_getDictionaryValue('TableRows.Hierarchies.' || Code) AS Name,
    	Rem, Type
    FROM Hierarchies
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    --Id = IdIn OR (COALESCE(IdIn, 0) = 0 AND sys_inRM(rm_mask))
    ORDER BY Priority;

    RETURN result;
END
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
