--DROP VIEW calc_results;

CREATE OR REPLACE VIEW calc_results
AS
SELECT
	row_number() OVER()::INTEGER AS Id,
	COALESCE(c.Code || ' ' || c.Nam, cr.PayerId::TEXT) AS PayerId,
	oa.Address,
	oa.PlaceCode,
	s.Code || ' ' || s.Name AS ServiceId,
	cr.DateFrom,
	cr.DateTo,
	cr.Days,
	cr.Value,
	cr.Tariff,
	cr.Money,
	cr.Rem,
	0 AS Revision
FROM sys_getCalcResults('PlacesConsumersServices') cr
LEFT JOIN Consumers c ON c.Id = cr.PayerId
LEFT JOIN sys_getAddresses() oa ON oa.ObjectId = cr.ObjectId
LEFT JOIN Services s ON s.Id = cr.ServiceId
ORDER BY 2,3,4,5,6
;

--SELECT * FROM calc_results LIMIT 100;