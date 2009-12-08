/**
Returns Task state for given TaskId
*/
CREATE OR REPLACE FUNCTION rcp_getTaskState (
	IN  TaskIdIn INTEGER
)
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getTaskState';

BEGIN
	OPEN result FOR
	SELECT t.State, t.Progress, t.ProgressRem, tt.ProgressMax
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE (t.Id = TaskIdIn OR COALESCE(TaskIdIn, 0) = 0);

	RETURN result;
END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;