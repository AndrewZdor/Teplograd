/**
 * Returns calculated data for the report engine.
 */
CREATE OR REPLACE FUNCTION rcp_getReportData (
	IN ReportCodeIn TEXT
)
RETURNS SETOF RECORD AS

$BODY$
DECLARE
    rec RECORD;
	_ReportSQL TEXT;
	_CalcTypeId INTEGER;
	_CalcId INTEGER;
	_ReportTable TEXT;

BEGIN

	SELECT r.CalcTypeId, r.ReportSQL
	INTO _CalcTypeId, _ReportSQL
	FROM Reports r
	WHERE LOWER(r.Code) = LOWER(ReportCodeIn);

	IF _CalcTypeId IS NOT NULL THEN -- Calculational procedures.

	    -- See rcp_getReportInfo - the same code.
        SELECT Id
        INTO _CalcId
        FROM Calculations c
        WHERE CalcTypeId = _CalcTypeId
            AND State = 'OK'
            AND DateFrom <= sys_getWorkingDate()
        ORDER BY (sys_getWorkingDate() - DateFrom)
        LIMIT 1
        ;

        IF _CalcId IS NULL THEN
            PERFORM sys_signalException('EmptyReport: %s ON %s', COALESCE(ReportCodeIn, 'NULL') || E'\\d' || sys_getWorkingDate());
        END IF;

		_ReportSQL := REPLACE(_ReportSQL, '%result%', sys_getCalcTableName('out', _CalcId));
        _ReportTable := sys_getCalcTableName('_rpt_' || ReportCodeIn, _CalcId);

    ELSE -- Non-calculational report.
	   _ReportTable := 'z_rpt_' || ReportCodeIn;
	END IF;

    IF sys_ifTableExists(_ReportTable) != 0 THEN
        EXECUTE 'DROP TABLE ' || _ReportTable;
    END IF;

    EXECUTE 'CREATE TABLE ' || _ReportTable || ' AS ' || _ReportSQL;
    EXECUTE 'GRANT SELECT ON TABLE ' || _ReportTable || ' TO public';

	PERFORM sys_DebugMessage('ReportSQL:' || _ReportSQL);
    RETURN QUERY EXECUTE 'SELECT * FROM ' || _ReportTable;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;