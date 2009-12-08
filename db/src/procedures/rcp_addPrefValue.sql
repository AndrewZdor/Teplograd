/**
Sets PrefValue for selected user.
Cannot be used in COMMIT mode from sys_EventLog and from ATOMIC transactions.
*/
CREATE OR REPLACE FUNCTION rcp_addPrefValue (
    IN CodeIn TEXT,
    IN ValueIn TEXT,
--    IN DateFromIn Date = NULL, -- TODO: DateFromIn not used yet.
    OUT PrefValueIdOut INTEGER
) RETURNS INTEGER AS

$BODY$
DECLARE
	_PrefId INTEGER;
	_PrefType TEXT;
	_UserId INTEGER;
	_IsAdmin BOOLEAN;

BEGIN
	_UserId := sys_getUserId();

	SELECT Id, Type INTO _PrefId, _PrefType
	FROM Prefs WHERE LOWER(Code) = LOWER(CodeIn);

	-- Insert user preference if it does not exist yet.
	IF _PrefId IS NULL THEN
	   _PrefType := 'USER';

        INSERT INTO Prefs(Code, DataType, Type)
	    VALUES (CodeIn, 'VarChar', _PrefType);

	    _PrefId := CURRVAL('prefs_id_seq');
	END IF;

	IF LOWER(_PrefType) = LOWER('SYSTEM')
		AND NOT EXISTS(SELECT 1 FROM UserGroups ug
					JOIN Groups g ON g.Id = ug.GroupId
					WHERE ug.UserId = _UserId
						AND g.IsAdmin)
	THEN
		PERFORM sys_SignalException('AccessDenied', 'Prefs.Code=' || CodeIn || ', UserId=' || _UserId);
	END IF;

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

LANGUAGE PLPGSQL
SECURITY DEFINER;