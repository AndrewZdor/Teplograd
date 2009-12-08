/**
Returns table name by its id.
*/

CREATE OR REPLACE FUNCTION sys_getTableName(EntityIdIn INTEGER)
RETURNS TEXT AS

$body$
DECLARE
	_Result String;
BEGIN
	SELECT CASE WHEN Type = 'SOFT' THEN 'Objects' ELSE Code END
	INTO _Result
	FROM Entities
	WHERE Id = EntityIdIn;

	RETURN _Result;
END;
$body$

LANGUAGE 'plpgsql'
IMMUTABLE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER
;
