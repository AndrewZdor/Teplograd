--$LastChangedRevision: 1865 $

-- TODO: Превратить ЖСК из помещений в Дома
-- TODO: Сначала удалить ObjectProperties чтоб они не остались болтаться в воздухе

/*
-- Сделать домами только эти объекты !!!
SELECT HouseId, count(*) FROM
(SELECT p.Id, sys_getAttrValue(NULL, p.Id, 'HouseId', sys_getWorkingDate())::INT AS HouseId
FROM Objects p
WHERE p.EntityId = 14
  AND p.Rem like '%ЖФ%' ) s
GROUP BY HouseId
HAVING count(*) = 1

SELECT p.Id, sys_getAttrValue(NULL, p.Id, 'HouseId', sys_getWorkingDate())::INT AS HouseId
INTO
FROM Objects p
WHERE p.EntityId = 14
  AND p.Rem like '%ЖФ%'
;
UPDATE Objects h
SET Name = p.Rem || ' ' || p.Name
FROM Objects p
WHERE h.Id = sys_getAttrValue(NULL, p.Id, 'HouseId', sys_getWorkingDate())::INT
  AND p.EntityId = 14 --Places
  AND p.Rem like '%ЖФ%'
;

delete from ObjectProperties
where .... ;

delete from Objects
where entityId = 14
and rem like '%ЖФ%' ;
*/

-- TODO: Сделать Rake task котрый будет создавать триггеры для всех таблиц у которых есть Audit columns
-- TODO: Изменить тарифы
-- TODO: Сделать ObjectId в Persons датазависимым (затрагивает процедуры getFormControls, getAttrValues, getSQLCriteria, getObjects ?, addObjects)
