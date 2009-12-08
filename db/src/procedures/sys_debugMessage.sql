/**
 * APPLY before using:
 * SET client_min_messages TO 'DEBUG'
 */
CREATE OR REPLACE FUNCTION sys_DebugMessage(
	IN MsgIn TEXT
)
RETURNS VOID AS

$BODY$
DECLARE
	_DebugMode TEXT;
BEGIN
	SELECT Value
	INTO _DebugMode
	FROM sys_getPrefValue('System.Debug'); -- TODO: Use session here!

	IF LOWER(_DebugMode) IN ('1', 'true', 'yes') THEN
		RAISE DEBUG E'--------------------------------------------------------------------------------\n%', MsgIn;

		INSERT INTO EventLog(TS, SQLState, SQLErrM)
		VALUES(clock_timestamp(), 'DebugMessage', MsgIn);
	END IF;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;
