/**
 * Returns current or given-name user id.
 */
CREATE OR REPLACE FUNCTION sys_getUserId(
	UserNameIn TEXT = NULL
)
RETURNS INTEGER AS

$BODY$
DECLARE
	_UserName TEXT;
    _UserIdResult INTEGER;
BEGIN
	IF COALESCE(UserNameIn, '') = '' THEN
        _UserName := CURRENT_USER;
    ELSE
        _UserName := UserNameIn;
    END IF;

    SELECT Id
    INTO _UserIdResult
    FROM Users
    WHERE Name = _UserName;

    RETURN _UserIdResult;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY INVOKER -- Do not change this because CURRENT_USER will return function owner instead of invoker
COST 10;
