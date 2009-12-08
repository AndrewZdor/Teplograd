TRUNCATE TABLE auditlog CASCADE;
TRUNCATE TABLE benefits CASCADE;
TRUNCATE TABLE benefittypes CASCADE;
TRUNCATE TABLE contracts CASCADE;
TRUNCATE TABLE consumers CASCADE;
TRUNCATE TABLE countcalculators CASCADE;
TRUNCATE TABLE countdata CASCADE;
TRUNCATE TABLE counters CASCADE;
TRUNCATE TABLE countnodes CASCADE;
TRUNCATE TABLE departments CASCADE;
TRUNCATE TABLE entrances CASCADE;
TRUNCATE TABLE eventlog CASCADE;
TRUNCATE TABLE objects CASCADE;
TRUNCATE TABLE objectproperties CASCADE;
TRUNCATE TABLE objectcapacities CASCADE;
TRUNCATE TABLE persons CASCADE;
TRUNCATE TABLE servicelog CASCADE;
TRUNCATE TABLE tariffvalues CASCADE;
TRUNCATE TABLE tariffs CASCADE;

DELETE FROM usergroups
WHERE UserId IN (
	SELECT Id FROM users
	WHERE name NOT IN ('DBA', 'Andrey', 'Ant', 'Гость', 'postgres', 'tnd')
);

DELETE FROM prefvalues
WHERE UserId IN (
	SELECT Id FROM users
	WHERE name NOT IN ('DBA', 'Andrey', 'Ant', 'Гость', 'postgres', 'tnd')
);

DELETE FROM users
WHERE name NOT IN ('DBA', 'Andrey', 'Ant', 'Гость', 'postgres', 'tnd');

DROP TABLE IF EXISTS z_ext_dept;
DROP TABLE IF EXISTS z_ext_kotel;
DROP TABLE IF EXISTS z_ext_lgoty;
DROP TABLE IF EXISTS z_ext_objects;
DROP TABLE IF EXISTS z_ext_region;
DROP TABLE IF EXISTS z_ext_splat;
DROP TABLE IF EXISTS z_ext_tarif;
DROP TABLE IF EXISTS z_ext_trp;

DELETE FROM Regions WHERE Code = '0';


-- TODO: Перед архивацией базы сделать ей VACUUM и ANALIZE