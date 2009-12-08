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