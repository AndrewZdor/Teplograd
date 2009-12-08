/**
 * Report detailed info.
 */
CREATE OR REPLACE FUNCTION rcp_getReportInfo (
    IN ReportIdIn INTEGER,
    IN CalcIdIn INTEGER
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getReportInfo';
	_ReportCode TEXT;
	_ReportName TEXT;
	_CalcTypeId INTEGER;
	_CalcId INTEGER;
	_DateFrom DATE;
	_DateTo DATE;
	_ReportSQL TEXT;
	_JrXML TEXT;

BEGIN
	SELECT r.Code, sys_getDictionaryValue('TableRows.Reports.' || r.Code),
	   r.CalcTypeId, r.ReportSQL, r.JrXml
	INTO _ReportCode, _ReportName, _CalcTypeId, _ReportSQL, _JrXML
	FROM Reports r
	WHERE r.Id = ReportIdIn;

	IF _CalcTypeId IS NULL THEN -- Non-calculational.
		_DateFrom := sys_getWorkingDate();
		_DateTo := NULL;

	ELSE -- Calculational.
		IF COALESCE(CalcIdIn, 0) = 0 THEN -- Find CalcId.
			-- See rcp_getReportData - the same code.
			SELECT c.Id
			INTO _CalcId
			FROM Calculations c
			WHERE c.CalcTypeId = _CalcTypeId
				AND c.State = 'OK'
				AND c.DateFrom <= sys_getWorkingDate()
			ORDER BY (sys_getWorkingDate() - c.DateFrom)
			LIMIT 1;
		ELSE
			_CalcId := CalcIdIn;
		END IF;

		SELECT DateFrom, DateTo
		INTO _DateFrom, _DateTo
		FROM Calculations
		WHERE Id = _CalcId;
	END IF;

	OPEN result FOR
	SELECT _ReportCode AS ReportCode, _ReportName AS ReportName,
		_CalcTypeId AS CalcTypeId, _DateFrom AS DateFrom, _DateTo AS DateTo,
		_ReportSQL AS ReportSQL, _JrXML AS JrXML;

	RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;