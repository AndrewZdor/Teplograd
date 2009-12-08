/**
Creates the new task.
*/
CREATE OR REPLACE FUNCTION rcp_taskStart (
	IN  TypeCodeIn TEXT,
	IN  SubjectIdIn INTEGER,
	IN  DescriptionIn TEXT,
	OUT TaskIdOut INTEGER
)
RETURNS INTEGER AS

$BODY$
BEGIN

	INSERT INTO Tasks(TypeId, State, Progress, SubjectId, Description)
	SELECT tt.Id, 'PRISTINE', 0, SubjectIdIn, DescriptionIn
	FROM TaskTypes tt
	WHERE tt.Code = TypeCodeIn
	RETURNING Tasks.Id INTO TaskIdOut;

END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;
