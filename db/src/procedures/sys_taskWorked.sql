/**
Marks that one iteration of the task is done.
*/
CREATE OR REPLACE FUNCTION sys_taskWorked(
	IN TaskIdIn INTEGER,
	IN ProgressRemIn TEXT,
	OUT DummyOut INTEGER
)
RETURNS INTEGER AS

$BODY$
BEGIN
	PERFORM sys_DebugMessage(ProgressRemIn);

	UPDATE Tasks
	SET State = 'IN_USE',
		Progress = COALESCE(Progress, 0) + 1,
		ProgressRem = ProgressRemIn,
		Revision = COALESCE(Revision, 0) + 1
	WHERE Id = TaskIdIn;
END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER;

