CREATE OR REPLACE FUNCTION rcp_getRM()
  RETURNS INT AS
$BODY$
DECLARE
	_Result INT;
BEGIN
	SELECT pv.Value::INT
	INTO _Result
	FROM PrefValues pv
	JOIN Prefs p ON p.Id = pv.PrefId
	WHERE p.Code = 'System.rm'
		AND pv.UserId = sys_getUserId() ;

	IF _Result IS NULL THEN
		_Result := 1;
	END IF;

	RETURN _Result;
END;
$BODY$
  LANGUAGE 'plpgsql' IMMUTABLE SECURITY DEFINER
  COST 100;

