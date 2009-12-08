--DROP VIEW calc_results_by_payers;

CREATE OR REPLACE VIEW calc_results_by_payers
AS
SELECT
	row_number() OVER()::INTEGER AS Id,
	COALESCE(c.Code || ' ' || c.Nam, cr.PayerId::TEXT) AS PayerId,
	s.Code || ' ' || s.Name AS ServiceId,
	SUM(cr.Money) AS Money,
	0 AS Revision
FROM sys_getCalcResults('PlacesConsumersServices') cr
LEFT JOIN Consumers c ON c.Id = cr.PayerId
LEFT JOIN Services s ON s.Id = cr.ServiceId
GROUP BY cr.PayerId, c.Code, c.Nam, cr.ServiceId, s.Code, s.Name
ORDER BY 2, 3
;

--SELECT * FROM calc_results_by_payers LIMIT 100;