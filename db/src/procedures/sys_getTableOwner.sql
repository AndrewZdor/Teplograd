/**
	Returns owner of data Entities (used to distinguish them from other Entities with the same name).
*/
CREATE OR REPLACE FUNCTION sys_getTableOwner()
RETURNS TEXT AS

$body$

BEGIN
	RETURN 'tnd';
END;

$body$
LANGUAGE 'plpgsql'
IMMUTABLE
SECURITY DEFINER;