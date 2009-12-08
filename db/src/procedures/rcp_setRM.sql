CREATE OR REPLACE FUNCTION rcp_setRM (IN valuein text, OUT prefvalueidout integer)
  RETURNS integer AS
$BODY$
DECLARE
	_PrefId INTEGER;
	_PrefType TEXT;
	_UserId INTEGER;
	_IsAdmin BOOLEAN;

BEGIN
	_UserId := sys_getUserId();

	SELECT Id, Type INTO _PrefId, _PrefType
	FROM Prefs WHERE Code = 'System.rm';

	UPDATE PrefValues pv
	SET Value = ValueIn
	WHERE pv.PrefId = _PrefId
		AND COALESCE(pv.UserId, 0) = COALESCE(_UserId, 0)
	RETURNING pv.Id INTO PrefValueIdOut;

	IF NOT FOUND THEN
		INSERT INTO PrefValues(PrefId, UserId, Value, DateFrom)
		VALUES (_PrefId, _UserId, ValueIn, NULL /*DateFromIn*/);

		PrefValueIdOut := CURRVAL('prefvalues_id_seq');
	END IF;

END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER
  COST 100;
