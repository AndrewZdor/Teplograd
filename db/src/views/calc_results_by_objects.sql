--DROP VIEW calc_results_by_objects;

CREATE OR REPLACE VIEW calc_results_by_objects
AS
SELECT
	row_number() OVER()::INTEGER AS Id,
	COALESCE(c.Code || ' ' || c.Nam, cr.PayerId::TEXT) AS PayerId,
	oa.Address,
	oa.PlaceCode,
	s.Code || ' ' || s.Name AS ServiceId,
	SUM(cr.Days) AS Days,
	SUM(cr.Value) AS Value,
	MIN(cr.Tariff) AS Tariff,
	SUM(cr.Money) AS Money,
	0 AS Revision
FROM sys_getCalcResults('PlacesConsumersServices') cr
LEFT JOIN Consumers c ON c.Id = cr.PayerId
LEFT JOIN sys_getAddresses() oa ON oa.ObjectId = cr.ObjectId
LEFT JOIN Services s ON s.Id = cr.ServiceId
GROUP BY cr.PayerId, c.Code, c.Nam, oa.Address, oa.PlaceCode, s.Code, s.Name
ORDER BY 3, 4, 2, 5
;

--SELECT * FROM calc_results_by_objects LIMIT 100;