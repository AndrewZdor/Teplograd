/**
Checks if the table has given field.
*/

CREATE OR REPLACE FUNCTION sys_ifTableHasField(
	TableNameIn text,
	FieldNameIn text
)
RETURNS OID AS

$BODY$

DECLARE
    _tbloid OID := sys_ifTableExists(TableNameIn);
    _colnum OID;
BEGIN

	IF _tbloid=0 THEN
          RETURN 0 ;
	ELSE

  	  SELECT attnum INTO _colnum
  	  FROM pg_attribute
  	  WHERE attrelid = _tbloid
  	    AND attname = LOWER(FieldNameIn);

	  IF FOUND THEN
	    RETURN _colnum ;
	  ELSE
	    RETURN 0 ;
	  END IF;

	END IF;
END

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;
