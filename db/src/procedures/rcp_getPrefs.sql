/**
Get Preferences list for caching on the client side.
*/

CREATE OR REPLACE FUNCTION rcp_getprefs (
	IN IdIn INTEGER DEFAULT 0
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getprefs';

BEGIN
	OPEN result FOR
	SELECT Id, Code, DataType, Rem
    FROM Prefs
    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
    ORDER BY Code;
END;

$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;