/**
	SELECTS the value of named attribute for Object entities.
*/

CREATE OR REPLACE FUNCTION sys_getPropId (
	IN EnityCodeIn TEXT,
	IN FieldNameIn TEXT
)
RETURNS INT AS

$BODY$
    SELECT ep.Id
    FROM EntityProperties ep
    JOIN Entities e ON e.Id = ep.EntityId
    WHERE LOWER(e.Code) = LOWER($1)
        AND LOWER(ep.Code) = LOWER($2);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;