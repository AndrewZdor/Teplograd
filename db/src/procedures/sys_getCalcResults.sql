/**
 * Returns results for given calctype for current working date
 */
CREATE OR REPLACE FUNCTION sys_getCalcResults(
	CalcTypeCodeIn TEXT
)
RETURNS TABLE (
	ObjectId INTEGER,
	ServiceId INTEGER,
	PayerId INTEGER,
	DateFrom DATE,
	DateTo DATE,
	Days NUMBER,
	Value NUMBER,
	Tariff NUMBER,
	Money NUMBER,
	Rem LONGESTSTRING
) AS

$BODY$
DECLARE
    _CalcTypeId INTEGER;
    _CalcId INTEGER;
    _WorkingDate DATE := sys_getWorkingDate();
    _SQL CITEXT;
BEGIN

	SELECT Id
	INTO _CalcTypeId
	FROM CalcTypes
	WHERE Code = CalcTypeCodeIn;

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || 'CalcTypeCodeIn = ' || coalesce(CalcTypeCodeIn::TEXT,'') );
	PERFORM sys_DebugMessage('sys_getCalcResults: ' || '_CalcTypeId = ' || coalesce(_CalcTypeId::TEXT,'') );

	SELECT Id
	INTO _CalcId
	FROM Calculations
	WHERE CalcTypeId = _CalcTypeId
	--AND _WorkingDate BETWEEN DateFrom AND DateTo
	ORDER BY Id DESC
	LIMIT 1;

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || 'WorkingDate = ' || coalesce(sys_getWorkingDate()::TEXT,'') );
	PERFORM sys_DebugMessage('sys_getCalcResults: ' || '_CalcId = ' || coalesce(_CalcId::TEXT,'') );

	--ObjectId, ServiceId, PayerId, DateFrom, DateTo, Days, Value, Tariff, Money, Rem
    _SQL := $sql$
    	SELECT
		ObjectId,
		ServiceId,
		PayerId,
		DateFrom,
		DateTo,
		Days,
		Value,
		Tariff,
		Money,
		Rem
    	FROM z_calc_%_CalcId%_out
    $sql$ ;

    _SQL := REPLACE(_SQL, '%_CalcId%', _CalcId::TEXT);

	PERFORM sys_DebugMessage('sys_getCalcResults: ' || coalesce(_SQL,'') );

	IF _SQL IS NOT NULL THEN
		RETURN QUERY EXECUTE _SQL;
	END IF;


END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER
COST 10;
