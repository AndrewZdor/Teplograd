/**
Returns given dictionary values (by code) to client.
*/

CREATE OR REPLACE FUNCTION rcp_getDictionaryValues (
	IN idin text
)
RETURNS REFCURSOR AS $BODY$

DECLARE
	result REFCURSOR = 'rcp_getDictionaryValues' || '.' || LOCALTIMESTAMP || '.' || uuid_generate_v1();

BEGIN
	OPEN result FOR
	SELECT 0 AS Id, idin AS Code,
		sys_getDictionaryValue(idin, 'name'::text) AS Name,
		sys_getDictionaryValue(idin, 'names'::text) AS Names,
		sys_getDictionaryValue(idin, 'abbr'::text) AS Abbr,
		sys_getDictionaryValue(idin, 'rem'::text) AS Rem;

	RETURN result;
END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
