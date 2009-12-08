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