/**
Signals custom exception.
Produces SQLState and SQLErrM from given Error Code and Data.
*/
CREATE OR REPLACE FUNCTION sys_SignalException(
	IN ErrCodeIn TEXT,
	IN ErrDataIn TEXT DEFAULT NULL
) RETURNS VOID AS

$BODY$
DECLARE
	_SQLState TEXT;
	_Msg TEXT;
	_D TEXT;

BEGIN
	PERFORM sys_debugMessage('sys_SignalException (ErrCodeIn=' || ErrCodeIn || ', ErrDataIn=' || COALESCE(ErrDataIn, '<NULL>') || ')');

	SELECT e.State INTO _SQLState
	FROM Errors e WHERE e.Code = ErrCodeIn;

	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	_Msg := sys_getDictionaryValue('Error.' || ErrCodeIn) -- Translated message.
		|| _D || COALESCE(REPLACE(ErrDataIn, E'\\d', _D), '');

	RAISE EXCEPTION USING ERRCODE = _SQLState, MESSAGE = _Msg;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;