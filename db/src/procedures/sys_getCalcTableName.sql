/**
	Returns table name for calculation tables
*/
CREATE OR REPLACE FUNCTION sys_getCalcTableName (
	IN ModeIn TEXT, -- 'in' or 'out' or 'obj' or '_<reportname>'.
	IN CalcIdIn INTEGER)
RETURNS TEXT AS

$BODY$
	SELECT 'z_calc_' || $2 /*CalcIdIn*/  || '_' || LOWER($1 /*ModeIn*/);
$BODY$

LANGUAGE SQL
IMMUTABLE
SECURITY DEFINER;
