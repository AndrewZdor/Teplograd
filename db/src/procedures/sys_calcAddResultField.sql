/**
Add new field to results table.
Before invocation of the procedure tmp_calc_<id> table should be filled with rcp_Calculate()
*/

CREATE OR REPLACE FUNCTION sys_calcAddResultField(
	IN CalcIdIn INTEGER,
	IN FieldNameIn String
)
RETURNS VOID AS

$BODY$
DECLARE
	_SQL LongString;
BEGIN

	IF sys_ifTableHasField(sys_getResultTableName(_CalcIdIn), _FieldNameIn) = 0 THEN
		_SQL := 'ALTER TABLE ' || sys_getResultTableName(_CalcIdIn) || ' ADD (' || _FieldNameIn || ' String)';
		EXECUTE _SQL;
	END IF;

END;
$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;