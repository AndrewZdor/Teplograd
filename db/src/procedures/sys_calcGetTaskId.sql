/**
 * Returns TaskId for given CalcId.
 */
CREATE OR REPLACE FUNCTION sys_calcGetTaskId (
	IN CalcIdIn INTEGER,
	OUT TaskIdOut INTEGER
) RETURNS INTEGER AS

$BODY$
	SELECT t.Id
	FROM Tasks t
	JOIN TaskTypes tt ON tt.Id = t.TypeId
	WHERE tt.Code = 'Calculations'
		AND t.SubjectId = $1
	ORDER BY t.InsertTS DESC
	LIMIT 1;
$BODY$

LANGUAGE SQL
SECURITY DEFINER;