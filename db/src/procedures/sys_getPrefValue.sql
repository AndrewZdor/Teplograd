/**
Get Preferences list for caching on the client side.
TODO: Redesign using OUT params.
*/
CREATE OR REPLACE FUNCTION sys_getPrefValue(
    IN CodeIn Text
)
RETURNS TABLE (
	Id INTEGER,
	Code TEXT,
	DefaultDateFrom DATE,
	DefaultValue TEXT,
	DateFrom DATE,
	Value TEXT
) AS $BODY$

BEGIN

	RETURN QUERY(
		SELECT pv.Id,
		       p.Code::TEXT,
		       pv.DateFrom, --AS DefaultDateFrom
		       pv.Value::TEXT, --AS DefaultValue
		COALESCE(pvU.DateFrom, pv.DateFrom),
		COALESCE(pvU.Value, pv.Value)::TEXT --AS Value
		FROM Prefs p
		LEFT JOIN PrefValues pv ON p.Id = pv.PrefId -- General.
		  AND pv.UserId IS NULL
		  AND pv.SessionId IS NULL
		LEFT JOIN PrefValues pvU ON p.Id = pvU.PrefId -- User.
		  AND pvU.UserId = sys_getUserId()
		--          AND (pvU.SessionId = _SessionIdIn OR COALESCE(_SessionIdIn, 0) = 0)
		WHERE LOWER(p.Code) = LOWER(CodeIn)
	);
	--AND pv.DateFrom ... --TODO

END; $BODY$

LANGUAGE plpgsql
SECURITY DEFINER;
