/**
 * Checks if the table exists.
 */

CREATE OR REPLACE FUNCTION sys_ifTableExists(tablenamein text)
  RETURNS oid AS

$BODY$

DECLARE
    _tbloid OID;
BEGIN
	SELECT relfilenode
	INTO _tbloid
	FROM pg_class
	WHERE relkind = 'r'
	  AND relname = LOWER(tablenamein)
	;
	IF FOUND THEN
          RETURN _tbloid ;
	ELSE
          RETURN 0 ;
	END IF;
END;

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER
;