/**
Client wrapper for sys_getFormConstrols.
*/
CREATE OR REPLACE FUNCTION rcp_getFormControls (
    IN FormIdIn INTEGER
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getFormControls' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getFormControls(FormIdIn);

	RETURN result;
END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
