/**
Creates the new task.
*/
CREATE OR REPLACE FUNCTION rcp_taskCancel (
	IN TaskIdIn INTEGER,
	IN ReasonIn TEXT,
	OUT ResultOut INTEGER -- Dummy Field
) RETURNS INTEGER AS

$BODY$
DECLARE
    _SQLState TEXT;
    _ErrorMsg TEXT;
    _ProcId INTEGER;
    _SubjectId INTEGER;

    _TypeCode TEXT;

BEGIN
	UPDATE Tasks
	SET State = 'CANCELLED',
		ProgressRem = ProgressRem || E'\n' || _ReasonIn
	WHERE Id = _TaskIdIn;

	-- Update Calculations. FIXME: HardCode!!!
	SELECT tt.Code, t.SubjectId
	INTO _TypeCode, _SubjectId
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE t.Id = _TaskIdIn
	;
	IF _TypeCode = 'Calculations' THEN
		UPDATE Calculations
		SET State = 'Cancelled'
		WHERE Id = _SubjectId;
	END IF;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_taskCancel');
	RAISE;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;