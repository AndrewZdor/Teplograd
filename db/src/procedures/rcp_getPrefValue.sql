/**
Client wrapper for sys_getPrefValue.
*/
CREATE OR REPLACE FUNCTION rcp_getPrefValue (
    IN IdIn Text
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getPrefValue';

BEGIN
	OPEN result FOR
	SELECT * FROM sys_getPrefValue(IdIn);

	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;