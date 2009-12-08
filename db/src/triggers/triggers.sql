/*==============================================================*/
/* DBMS name:      PostgreSQL 8                                 */
/* Created on:     17.06.2009 20:51:54                          */
/*==============================================================*/

SET client_min_messages TO warning;

drop trigger if exists updUsTS_benefits on Benefits;

drop trigger if exists updUsTS_calctypedefs on CalcTypeDefs;

drop trigger if exists updUsTS_calctypes on CalcTypes;

drop trigger if exists updUsTS_calculations on Calculations;

drop trigger if exists updUsTS_cities on Cities;

drop trigger if exists updUsTS_consumers on Consumers;

drop trigger if exists updUsTS_countcalctypes on CountCalcTypes;

drop trigger if exists updUsTS_countcalculators on CountCalculators;

drop trigger if exists updUsTS_countdata on CountData;

drop trigger if exists updUsTS_countnodes on CountNodes;

drop trigger if exists updUsTS_countpprtypes on CountPPRTypes;

drop trigger if exists updUsTS_counttsptypes on CountTSPTypes;

drop trigger if exists updUsTS_counters on Counters;

drop trigger if exists updUsTS_departments on Departments;

drop trigger if exists updUsTS_dictionary on Dictionary;

drop trigger if exists updUsTS_entities on Entities;

drop trigger if exists updUsTS_entityproperties on EntityProperties;

drop trigger if exists updUsTS_entrances on Entrances;

drop trigger if exists updUsTS_eventlog on EventLog;

drop trigger if exists updUsTS_formcontrols on FormControls;

drop trigger if exists updUsTS_forms on Forms;

drop trigger if exists updUsTS_groups on Groups;

drop trigger if exists updUsTS_hierarchies on Hierarchies;

drop trigger if exists updUsTS_hierarchyfolders on HierarchyFolders;

drop trigger if exists updUsTS_houseowners on HouseOwners;

drop trigger if exists updUsTS_languages on Languages;

drop trigger if exists updUsTS_objectproperties on ObjectProperties;

drop trigger if exists updUsTS_objects on Objects;

drop trigger if exists updUsTS_persons on Persons;

drop trigger if exists updUsTS_prefvalues on PrefValues;

drop trigger if exists updUsTS_prefs on Prefs;

drop trigger if exists updUsTS_regions on Regions;

drop trigger if exists updUsTS_reports on Reports;

drop trigger if exists updUsTS_servicelog on ServiceLog;

drop trigger if exists updUsTS_services on Services;

drop trigger if exists updUsTS_streettypes on StreetTypes;

drop trigger if exists updUsTS_streets on Streets;

drop trigger if exists updUsTS_tariffvalues on TariffValues;

drop trigger if exists updUsTS_tariffs on Tariffs;

drop trigger if exists updUsTS_tasktypes on TaskTypes;

drop trigger if exists updUsTS_tasks on Tasks;

drop trigger if exists updUsTS_testtable on TestTable;

drop trigger if exists updUsTS_users on Users;

drop trigger if exists updUsTS_z_ext_dept on z_ext_dept;

drop trigger if exists updUsTS_z_ext_kotel on z_ext_kotel;

drop trigger if exists updUsTS_z_ext_objects on z_ext_objects;

drop trigger if exists updUsTS_z_ext_region on z_ext_region;

drop trigger if exists updUsTS_z_ext_splat on z_ext_splat;

drop trigger if exists updUsTS_z_ext_streets_ispolkom on z_ext_streets_ispolkom;

drop trigger if exists updUsTS_z_ext_tarif on z_ext_tarif;

drop trigger if exists updUsTS_z_ext_trp on z_ext_trp;


CREATE TRIGGER updUsTS_benefits BEFORE UPDATE ON Benefits
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_calctypedefs BEFORE UPDATE ON CalcTypeDefs
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_calctypes BEFORE UPDATE ON CalcTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_calculations BEFORE UPDATE ON Calculations
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_cities BEFORE UPDATE ON Cities
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_consumers BEFORE UPDATE ON Consumers
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_countcalctypes BEFORE UPDATE ON CountCalcTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_countcalculators BEFORE UPDATE ON CountCalculators
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_countdata BEFORE UPDATE ON CountData
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_countnodes BEFORE UPDATE ON CountNodes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_countpprtypes BEFORE UPDATE ON CountPPRTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_counttsptypes BEFORE UPDATE ON CountTSPTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_counters BEFORE UPDATE ON Counters
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_departments BEFORE UPDATE ON Departments
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_dictionary BEFORE UPDATE ON Dictionary
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_entities BEFORE UPDATE ON Entities
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_entityproperties BEFORE UPDATE ON EntityProperties
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_entrances BEFORE UPDATE ON Entrances
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_eventlog BEFORE UPDATE ON EventLog
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_formcontrols BEFORE UPDATE ON FormControls
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_forms BEFORE UPDATE ON Forms
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_groups BEFORE UPDATE ON Groups
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_hierarchies BEFORE UPDATE ON Hierarchies
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_hierarchyfolders BEFORE UPDATE ON HierarchyFolders
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_houseowners BEFORE UPDATE ON HouseOwners
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_languages BEFORE UPDATE ON Languages
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_objectproperties BEFORE UPDATE ON ObjectProperties
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_objects BEFORE UPDATE ON Objects
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_persons BEFORE UPDATE ON Persons
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_prefvalues BEFORE UPDATE ON PrefValues
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_prefs BEFORE UPDATE ON Prefs
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_regions BEFORE UPDATE ON Regions
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_reports BEFORE UPDATE ON Reports
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_servicelog BEFORE UPDATE ON ServiceLog
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_services BEFORE UPDATE ON Services
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_streettypes BEFORE UPDATE ON StreetTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_streets BEFORE UPDATE ON Streets
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_tariffvalues BEFORE UPDATE ON TariffValues
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_tariffs BEFORE UPDATE ON Tariffs
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_tasktypes BEFORE UPDATE ON TaskTypes
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_tasks BEFORE UPDATE ON Tasks
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_testtable BEFORE UPDATE ON TestTable
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_users BEFORE UPDATE ON Users
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_dept BEFORE UPDATE ON z_ext_dept
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_kotel BEFORE UPDATE ON z_ext_kotel
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_objects BEFORE UPDATE ON z_ext_objects
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_region BEFORE UPDATE ON z_ext_region
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_splat BEFORE UPDATE ON z_ext_splat
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_streets_ispolkom BEFORE UPDATE ON z_ext_streets_ispolkom
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_tarif BEFORE UPDATE ON z_ext_tarif
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();


CREATE TRIGGER updUsTS_z_ext_trp BEFORE UPDATE ON z_ext_trp
    FOR EACH ROW EXECUTE PROCEDURE updateUsTS();

