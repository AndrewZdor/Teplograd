CREATE OR REPLACE FUNCTION sys_getCalcTmlId (
	CalcIdIn INTEGER,
	FieldNameIn TEXT
)
RETURNS INTEGER AS

$BODY$
	SELECT ct.Id
	FROM Calculations c
	JOIN CalcTemplates ct ON ct.CalcTypeId = c.CalcTypeId
	WHERE c.Id = $1
		AND LOWER(ct.FieldName) = LOWER($2);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;
