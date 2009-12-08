/**
Writes errors in EventLog table.
*/
CREATE OR REPLACE FUNCTION sys_EventLog(
    IN SQLStateIn TEXT,
    IN SQLErrMIn TEXT,
    IN DataIn TEXT
) RETURNS VOID AS

$BODY$
BEGIN
--	PERFORM sys_DebugMessage('sys_EventLog: SQLSTATE=' || COALESCE(SQLStateIn, '<NULL>')
--		|| ', SQLERRM=' || COALESCE(SQLErrMIn, '<NULL>'));

	INSERT INTO EventLog(UserId, SQLState, SQLErrM, Data)
	VALUES (sys_getUserId(), SQLStateIn, SQLErrMIn, DataIn);
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;

