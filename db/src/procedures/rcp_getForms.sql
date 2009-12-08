/**
*/
CREATE OR REPLACE FUNCTION rcp_getForms(
    IN IdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getForms';

BEGIN
	-- Real Form.
    IF SIGN(IdIn) >= 0 THEN
		OPEN result FOR
		SELECT Id, 'Real'::text , Code
			, sys_getDictionaryValue('Form.' || Name, 'Name') AS "Name"
			, sys_getDictionaryValue('Form.' || Rem, 'Rem') AS "Rem"
	    FROM Forms
	    WHERE Id = IdIn OR COALESCE(IdIn, 0) = 0
		ORDER BY Name;

	-- Virtual Form.
	ELSE
		OPEN result FOR
		SELECT -Id , 'Virtual'::text , Code
			, sys_getDictionaryValue('Table.' || t.Code, 'Name') AS "Name"
			, sys_getDictionaryValue('Table.' || t.Code, 'Rem') AS "Rem"
	    FROM Entities t
	    WHERE Id = IdIn;
	END IF;
END;
$BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
