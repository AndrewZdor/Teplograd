/**
	Checks if the given field is system (not retrieved by client).
*/

CREATE OR REPLACE FUNCTION sys_isSystemField (
	IN FieldNameIn text
)
RETURNS boolean AS

$body$

BEGIN
	IF lower(FieldNameIn) IN (
		'id', 'revision', 'insertuserid', 'insertts', 'updateuserid', 'updatets', 'deldate', 'insdate'
		) THEN
	  RETURN true;
	ELSE
	  RETURN false;
	END IF;
END;

$body$

LANGUAGE 'plpgsql'
IMMUTABLE
SECURITY DEFINER
COST 10;