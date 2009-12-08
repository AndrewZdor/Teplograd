--DROP VIEW benefit_persons;

CREATE OR REPLACE VIEW benefit_persons
AS
SELECT
p.Id,
COALESCE(fcs.Code, hcs.Code) AS consumer_code,
COALESCE(fcs.Nam,  hcs.Nam) AS consumer_nam,
p.lastname,
p.firstname,
p.middlename,
p.inn,
st.code || ' ' || s.name || ', ' || h.code || '/' || f.code AS address,
fc.value1 AS flat_heat_area,
p.gekid,
p.account,
p.passport,
p.birthdate,
p.ismain AS is_main_person,
p.excludedate,
p.cardnum,
p.filenum,
p.rem AS person_rem,
bt.kfk,
bt.code AS benefit_code,
bt.name AS benefit_name,
bt.percent,
bt.DateFrom AS benefit_date,
b.ismain AS is_main_benefit,
b.PersonCount,
b.doc,
b.rem AS benefit_rem,
p.revision
FROM Persons p
JOIN Benefits b ON p.Id = b.PersonId
JOIN BenefitTypes bt ON bt.Id = b.TypeId
LEFT JOIN Objects f ON f.Id = p.ObjectId
LEFT JOIN (SELECT DISTINCT ON (ObjectId) ObjectId, Value1, ContractId
		   FROM ObjectCapacities
		   WHERE ServiceId = (select id from services where code = '01')
			 AND DateFrom <= sys_getWorkingDate()
		   ORDER BY ObjectId, DateFrom DESC) fc ON fc.ObjectId = f.Id
LEFT JOIN Objects h ON h.Id = sys_getAttrValue(NULL, f.Id, 'HouseId', sys_getWorkingDate())::INT
LEFT JOIN (SELECT DISTINCT ON (ObjectId) ObjectId, ContractId
		   FROM ObjectCapacities
		   WHERE ServiceId = (select id from services where code = '01')
			 AND DateFrom <= sys_getWorkingDate()
		   ORDER BY ObjectId, DateFrom DESC) hc ON hc.ObjectId = h.Id
LEFT JOIN Streets s ON s.Id = sys_getAttrValue(NULL, h.Id, 'StreetId', sys_getWorkingDate())::INT
LEFT JOIN StreetTypes st ON st.Id = s.StreetTypeId
LEFT JOIN Contracts fct ON fct.Id = fc.ContractId
LEFT JOIN Consumers fcs ON fcs.Id = fct.ConsumerId
LEFT JOIN Contracts hct ON hct.Id = hc.ContractId
LEFT JOIN Consumers hcs ON hcs.Id = hct.ConsumerId
ORDER BY consumer_code, p.lastname, p.firstname, p.middlename
;

--SELECT * FROM benefit_persons LIMIT 100;



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



--DROP VIEW heat_objects;

CREATE OR REPLACE VIEW heat_objects
AS
WITH Obj AS (
	 	SELECT p.ObjectId, p.ParentId, p.Level, e.Code as EntityCode,
	 		   o.Code as ObjectCode, o.Name as ObjectName
     	FROM sys_getParentObjectsAll(sys_getWorkingDate()) p
	 	JOIN Objects o ON p.ParentId = o.Id
	    JOIN Entities e ON o.EntityId = e.Id),
	 ObjProp AS (
	 	SELECT Id as ObjectId, PropertyId, (select Value from ObjectProperties
	 										where ObjectId = o.Id
	 										  and DateFrom <= sys_getWorkingDate()
	 										  and PropertyId = p.PropertyId
	 										order by DateFrom desc limit 1) as Value
	 	FROM Objects o CROSS JOIN (Select 14 AS PropertyId UNION ALL Select 15) p
	 	WHERE o.EntityId = (select Id from Entities where Code = 'ElevatorNodes')
          AND (DelDate IS NULL OR DelDate > sys_getWorkingDate())
          AND InsDate <= sys_getWorkingDate() ),
     Place AS (
        SELECT Id, Code as Num, Rem,
               sys_getAttrValue (NULL, Id, 'HouseId', sys_getWorkingDate()) as HouseId,
               sys_getAttrValue (NULL, Id, 'Area', sys_getWorkingDate()) as Area,
               sys_getAttrValue (NULL, Id, 'Rem2', sys_getWorkingDate()) as Rem2,
               sys_getAttrValue (NULL, Id, 'PayerId', sys_getWorkingDate()) as PayerId,
               sys_getAttrValue (NULL, Id, 'Svc1ParentId', sys_getWorkingDate()) as Svc1ParentId,
               sys_getAttrValue (NULL, Id, 'Svc2ParentId', sys_getWorkingDate()) as Svc2ParentId,
               Revision
        FROM Objects o
        WHERE EntityId = (SELECT Id FROM Entities WHERE Code = 'Places') ),
     House AS (
        SELECT Id, Code as Num, Rem,
               sys_getAttrValue (NULL, Id, 'StreetId', sys_getWorkingDate()) as StreetId,
               sys_getAttrValue (NULL, Id, 'DepartmentId', sys_getWorkingDate()) as DepartmentId
        FROM Objects o
        WHERE EntityId = (SELECT Id FROM Entities WHERE Code = 'Houses') )
SELECT p.Id,
	   p.Revision,
	   d.Code "Код р-на",
	   d.Name "Назв. р-на",
	   boiler.ObjectCode "Код кот.",
	   boiler.ObjectName "Котельная",
	   trp.ObjectCode "Код ТРП",
	   trp.ObjectName "ТРП",
 	   st.Code "Код ул.",
 	   s.Name "Назв. ул.",
	   h.Num "Номер",
	   p.Rem "Потребитель",
	   c.Code "Код плат.",
	   c.Name "Плательщик",
	   sys_getAttrValue(18/*consumers*/, c.Id, 'ConsumerClass(VID_P)', sys_getWorkingDate() ) "Вид потр.",
	   cast(p.Area as numeric(18,2)) "Площадь спр.",
	   cast(CASE WHEN COALESCE(otp.Value1,0) = 0 THEN otp.Value2*0.025 ELSE otp.Value1*0.025 END as numeric(18,2)) "отп Гкал спр.",
	   --cast(CASE WHEN p.Area::INT = 0 THEN -1 ELSE "отп Гкал спр."/p.Area END as numeric(18,2)) "УН отп дог.",
       cast(otp.Value1 as numeric(18,2)) "отп м.кв.",
       cast(otp.Value2 as numeric(18,2)) "отп Гкал",
       cast(grv.Value1 as numeric(18,2)) "грв м.куб.",
       cast(grv.Value2 as numeric(18,2)) "грв Гкал",
       cast(grv.Value3 as int) "грв чел.",
	   p.Rem2 "Коментарий 2",
	   en.Code "Код ЭУ",
	   cast((cast(ootp.Value as numeric) * 0.00033848) as numeric(18,2)) AS "ЭУ отп",
	   cast((cast(ogrv.Value as numeric) * 0.00033848) as numeric(18,2)) AS "ЭУ грв",
	   en.Rem "Коментарий ЭУ"/*,
       cast(CASE WHEN SUM(cast(p.Area as numeric)) OVER (PARTITION BY en.Code) = 0 THEN -1 ELSE
        		"ЭУ отп" * cast(p.Area as numeric) / SUM(cast(p.Area as numeric)) OVER (PARTITION BY en.Code)
        	END as numeric(18,2)) AS "Доля нагрузки отп",
       cast(CASE WHEN p.Area::INT = 0 THEN -1 ELSE "Доля нагрузки отп"/p.Area END as numeric(18,2)) "УН ЭУ отп",
       cast(CASE WHEN SUM(cast(p.Area as numeric)) OVER (PARTITION BY en.Code) = 0 THEN -1 ELSE
        		"ЭУ грв" * cast(p.Area as numeric) / SUM(cast(p.Area as numeric)) OVER (PARTITION BY en.Code)
        	END as numeric(18,2)) AS "Доля нагрузки грв",
       cast(CASE WHEN p.Area::INT = 0 THEN -1 ELSE "Доля нагрузки грв"/p.Area END as numeric(18,2)) "УН ЭУ грв"
       */
FROM Place p
	JOIN House h ON p.HouseId::INT = h.Id
	JOIN Streets s ON h.StreetId::INT = s.Id
	JOIN StreetTypes st ON s.StreetTypeId = st.Id
	JOIN Departments d ON h.DepartmentId::INT = d.Id
	LEFT JOIN Consumers c ON p.PayerId::INT = c.Id
    LEFT JOIN ObjectCapacities otp ON p.Id = otp.ObjectId AND otp.ServiceId = 1 AND otp.DateFrom = (select max(DateFrom)
																	   from ObjectCapacities
																	   where DateFrom <= sys_getWorkingDate()
																	     and ObjectId = otp.ObjectId)
    LEFT JOIN ObjectCapacities grv ON p.Id = grv.ObjectId AND grv.ServiceId = 2 AND grv.DateFrom = (select max(DateFrom)
																	   from ObjectCapacities
																	   where DateFrom <= sys_getWorkingDate()
																	     and ObjectId = grv.ObjectId)
	LEFT JOIN Objects en ON en.Id = p.Svc1ParentId::INT
	LEFT JOIN ObjProp ogrv ON en.Id = ogrv.ObjectId AND ogrv.PropertyId = 14 -- Грв
	LEFT JOIN ObjProp ootp ON en.Id = ootp.ObjectId AND ootp.PropertyId = 15 -- Отп
	LEFT JOIN Obj trp ON trp.ObjectId = en.Id AND trp.EntityCode = 'TRP'
	LEFT JOIN Obj boiler ON boiler.ObjectId = en.Id AND boiler.EntityCode = 'Boilers'
ORDER BY d.Code, d.Name, s.Name, SUBSTRING(h.Num FROM E'\d+')::INT, h.Num
;

--SELECT * FROM heat_objects;



