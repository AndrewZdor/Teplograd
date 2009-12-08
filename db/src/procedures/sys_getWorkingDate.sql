/**
Returns working date for the user.
*/
CREATE OR REPLACE FUNCTION sys_getWorkingDate()
RETURNS DATE AS

$BODY$
DECLARE
	_Result DATE;

BEGIN
	SELECT CAST(pv.Value AS DATE)
	INTO _Result
	FROM PrefValues pv
	JOIN Prefs p ON p.Id = pv.PrefId
	WHERE p.Code = 'Work.Period.DateFrom'
		AND pv.UserId = sys_getUserId() ;

	IF _Result IS NULL THEN
		_Result := CURRENT_DATE;
		--INSERT INTO PrefValues(PrefId, UserId, Value)
		--SELECT (SELECT Id FROM Prefs WHERE Code = 'Work.Period.DateFrom'), sys_getUserId(), TODAY(*) ;
	END IF;

	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;

