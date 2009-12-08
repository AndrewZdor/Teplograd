/**
Get entity types (Entities) for caching on the client side. {Entities}
*/

CREATE OR REPLACE FUNCTION rcp_getEntities(
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getEntities' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
    SELECT Id,
    	Code,
    	sys_getDictionaryValue('Table.' || t.Code, 'name') AS Name,
        sys_getDictionaryValue('Table.' || t.Code, 'names') AS Names,
    	Decorator,
    	LookupCategory,
    	Type,
    	LookupHierarchyId,
    	isTranslatable,
    	Rem
    FROM Entities t
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;

    RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;
