/**
* Trim trailing zeros from a string.
*/
CREATE OR REPLACE FUNCTION sys_trimZero (
    NIn NUMERIC
)
RETURNS TEXT AS

$BODY$
DECLARE
	 _i INTEGER;
	 _L INTEGER;
	 _S2 TEXT;

BEGIN
/*
	_i := -1; -- Last letter;
	_S2 := StrIn;

	_L := LENGTH(_S2);
	WHILE (_S2 LIKE '%0' OR _S2 LIKE '%.') AND _L > 1 LOOP
		_L := _L - 1;
		_S2 := SUBSTR(_S2, 1, _L);
	END LOOP;

	RETURN _S2;
*/

	RETURN NIn::TEXT;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
STRICT
SECURITY DEFINER;
