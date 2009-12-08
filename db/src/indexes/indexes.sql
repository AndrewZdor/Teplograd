/*==============================================================*/
/* DBMS name:      PostgreSQL 8                                 */
/* Created on:     17.06.2009 21:10:46                          */
/*==============================================================*/

SET client_min_messages TO warning;

drop index if exists UN_CalcLockDefs_CalcTypeId_EntityId_FieldName;

drop index if exists UN_CalcLockDefs_CalcTypeId_OrderNo;

drop index if exists UN_CalcLockDefs_Calc_Ent_Field;

drop index if exists UN_CalcLockDef_CalcTyp_OrdNo;

drop index if exists UN_CalcTypes_Code;

drop index if exists UN_Calculations_CalcType_DateFrom;

drop index if exists UN_Calcul_CalcType_DateFrom;

drop index if exists ix_Cities_nm;

drop index if exists ux_Consumers_Code;

drop index if exists un_CountCalcTypes_Code;

drop index if exists un_CountCalculators_Code;

drop index if exists un_CountData_Id_CounterId_DateFrom;

drop index if exists un_CountData_Id_Count_DatFrom;

drop index if exists un_CountNodes_Code;

drop index if exists un_CountPPRTypes_Code;

drop index if exists un_CountTSPTypes_Code;

drop index if exists un_Counters_Code;

drop index if exists un_Departments_Code;

drop index if exists un_Dictionary_LangCode_Code;

drop index if exists un_Entities_lookupCategory_Priority;

drop index if exists un_Entities_lookCategory_Prioty;

drop index if exists un_EntityProperties_EntityId_Code;

drop index if exists un_EntityPropert_EntityId_Code;

--drop index if exists UN_EntityValidation_EntityId_Code;
ALTER TABLE entityvalidation DROP CONSTRAINT un_entityvalidation_entityid_code;

--drop index if exists UN_Errors_State;
ALTER TABLE errors DROP CONSTRAINT un_errors_state;

drop index if exists UN_Errors_LegacyState;

drop index if exists UN_Groups_Code;

drop index if exists UN_HierarchyFolders_HierarchyId_ParentEntityId_EntityId_Type;

drop index if exists UN_HierarFold_Hier_ParId_EnId_Typ;

drop index if exists ix_HouseOwns_HouseId_ConsumerId;

drop index if exists ux_PlaceCapacities;

drop index if exists UN_ObjectProperties_RowId_PropertyId_DateFrom;

drop index if exists UN_ObjectProperties_ObjectId_PropertyId_DateFrom;

drop index if exists ix_ObjectProperties_ProprtyId_Value;

drop index if exists UN_ObjectProp_RowId_Prop_DatFrom;

drop index if exists UN_ObjectProp_ObjId_Prop_DatFrom;

drop index if exists ix_ObjectProp_ProprtyId_Value;

drop index if exists IX_Objects_EntityId_Code;

drop index if exists ux_Persons_GekId_Account;

drop index if exists ux_Persons_INN;

drop index if exists un_Prefs_Code;

drop index if exists un_Regions_Code;

drop index if exists UN_Reports_Code;

drop index if exists ix_StreetTypes_nm;

drop index if exists ix_StreetTypes_code;

drop index if exists ix_Streets_code;

drop index if exists ix_Streets;

drop index if exists UN_TariffValues_TariffId_ServiceId_DateFrom;

drop index if exists UN_Tariffs_Name;

drop index if exists UN_Tariffs_Code;

drop index if exists un_Tariffs_Dat_ServId_Tag;

drop index if exists UN_TaskTypes_Code;

drop index if exists UN_Tasks_InsertTS;

drop index if exists Ind_z_ext_dept_2;

drop index if exists Ind_z_ext_dept_1;

drop index if exists Ind_z_ext_objects_9;

drop index if exists Ind_z_ext_objects_8;

drop index if exists Ind_z_ext_objects_7;

drop index if exists Ind_z_ext_objects_6;

drop index if exists Ind_z_ext_objects_5;

drop index if exists Ind_z_ext_objects_4;

drop index if exists Ind_z_ext_objects_3;

drop index if exists Ind_z_ext_objects_2;

drop index if exists Ind_z_ext_objects_1;

drop index if exists Ind_z_ext_region_1;

drop index if exists Ind_z_ext_splat_1;

drop index if exists Ind_z_ext_streets_ispolkom_2;

drop index if exists Ind_z_ext_streets_ispolkom_1;

/*==============================================================*/
/* Index: UN_CalcLockDef_CalcTyp_OrdNo                          */
/*==============================================================*/
create unique index UN_CalcLockDef_CalcTyp_OrdNo on CalcTypeDefs (
CalcTypeId,
OrderNo
);

/*==============================================================*/
/* Index: UN_CalcLockDefs_Calc_Ent_Field                        */
/*==============================================================*/
create unique index UN_CalcLockDefs_Calc_Ent_Field on CalcTypeDefs (
CalcTypeId,
EntityId,
FieldName
);

/*==============================================================*/
/* Index: UN_CalcLockDefs_CalcTypeId_OrderNo                    */
/*==============================================================*/
create unique index UN_CalcLockDefs_CalcTypeId_OrderNo on CalcTypeDefs (
CalcTypeId,
OrderNo
);

/*==============================================================*/
/* Index: UN_CalcLockDefs_CalcTypeId_EntityId_FieldName         */
/*==============================================================*/
create unique index UN_CalcLockDefs_CalcTypeId_EntityId_FieldName on CalcTypeDefs (
CalcTypeId,
EntityId,
FieldName
);

/*==============================================================*/
/* Index: UN_CalcTypes_Code                                     */
/*==============================================================*/
create unique index UN_CalcTypes_Code on CalcTypes (
Code
);

/*==============================================================*/
/* Index: UN_Calcul_CalcType_DateFrom                           */
/*==============================================================*/
create unique index UN_Calcul_CalcType_DateFrom on Calculations (
CalcTypeId,
DateFrom
);

/*==============================================================*/
/* Index: UN_Calculations_CalcType_DateFrom                     */
/*==============================================================*/
create unique index UN_Calculations_CalcType_DateFrom on Calculations (
CalcTypeId,
DateFrom
);

/*==============================================================*/
/* Index: ix_Cities_nm                                          */
/*==============================================================*/
create unique index ix_Cities_nm on Cities (
Name
);

/*==============================================================*/
/* Index: ux_Consumers_Code                                     */
/*==============================================================*/
create unique index ux_Consumers_Code on Consumers (
Code
);

/*==============================================================*/
/* Index: un_CountCalcTypes_Code                                */
/*==============================================================*/
create unique index un_CountCalcTypes_Code on CountCalcTypes (
Code
);

/*==============================================================*/
/* Index: un_CountCalculators_Code                              */
/*==============================================================*/
create unique index un_CountCalculators_Code on CountCalculators (
Code
);

/*==============================================================*/
/* Index: un_CountData_Id_Count_DatFrom                         */
/*==============================================================*/
create unique index un_CountData_Id_Count_DatFrom on CountData (
Id,
CounterId,
DateFrom
);

/*==============================================================*/
/* Index: un_CountData_Id_CounterId_DateFrom                    */
/*==============================================================*/
create unique index un_CountData_Id_CounterId_DateFrom on CountData (
Id,
CounterId,
DateFrom
);

/*==============================================================*/
/* Index: un_CountNodes_Code                                    */
/*==============================================================*/
create unique index un_CountNodes_Code on CountNodes (
Code
);

/*==============================================================*/
/* Index: un_CountPPRTypes_Code                                 */
/*==============================================================*/
create unique index un_CountPPRTypes_Code on CountPPRTypes (
Code
);

/*==============================================================*/
/* Index: un_CountTSPTypes_Code                                 */
/*==============================================================*/
create  index un_CountTSPTypes_Code on CountTSPTypes (
Code
);

/*==============================================================*/
/* Index: un_Counters_Code                                      */
/*==============================================================*/
create unique index un_Counters_Code on Counters (
Code
);

/*==============================================================*/
/* Index: un_Departments_Code                                   */
/*==============================================================*/
create unique index un_Departments_Code on Departments (
Code
);

/*==============================================================*/
/* Index: un_Dictionary_LangCode_Code                           */
/*==============================================================*/
create unique index un_Dictionary_LangCode_Code on Dictionary (
LanguageCode,
Code
);

/*==============================================================*/
/* Index: un_Entities_lookCategory_Prioty                       */
/*==============================================================*/
create unique index un_Entities_lookCategory_Prioty on Entities (
LookUpCategory,
Priority
);

/*==============================================================*/
/* Index: un_Entities_lookupCategory_Priority                   */
/*==============================================================*/
create unique index un_Entities_lookupCategory_Priority on Entities (
LookUpCategory,
Priority
);

/*==============================================================*/
/* Index: un_EntityPropert_EntityId_Code                        */
/*==============================================================*/
create unique index un_EntityPropert_EntityId_Code on EntityProperties (
EntityId,
Code
);

/*==============================================================*/
/* Index: un_EntityProperties_EntityId_Code                     */
/*==============================================================*/
create unique index un_EntityProperties_EntityId_Code on EntityProperties (
EntityId,
Code
);

/*==============================================================*/
/* Index: UN_EntityValidation_EntityId_Code                     */
/*==============================================================*/
create unique index UN_EntityValidation_EntityId_Code on EntityValidation (
EntityId,
Code
);

/*==============================================================*/
/* Index: UN_Errors_LegacyState                                 */
/*==============================================================*/
create  index UN_Errors_LegacyState on Errors (
LegacyState
);

/*==============================================================*/
/* Index: UN_Errors_State                                       */
/*==============================================================*/
create  index UN_Errors_State on Errors (
State
);

/*==============================================================*/
/* Index: UN_Groups_Code                                        */
/*==============================================================*/
create unique index UN_Groups_Code on Groups (
Code
);

/*==============================================================*/
/* Index: UN_HierarFold_Hier_ParId_EnId_Typ                     */
/*==============================================================*/
create unique index UN_HierarFold_Hier_ParId_EnId_Typ on HierarchyFolders (
EntityId,
Code,
Type,
HierarchyId,
ParentEntityId
);

/*=====================================================================*/
/* Index: UN_HierarchyFolders_HierarchyId_ParentEntityId_EntityId_Type */
/*=====================================================================*/
create unique index UN_HierarchyFolders_HierarchyId_ParentEntityId_EntityId_Type on HierarchyFolders (
HierarchyId,
ParentEntityId,
EntityId,
Code,
Type
);

/*==============================================================*/
/* Index: ix_HouseOwns_HouseId_ConsumerId                       */
/*==============================================================*/
create unique index ix_HouseOwns_HouseId_ConsumerId on HouseOwners (
ConsumerId
);

/*==============================================================*/
/* Index: ux_PlaceCapacities                                    */
/*==============================================================*/
create unique index ux_PlaceCapacities on ObjectCapacities (
DateFrom,
ObjectId,
ServiceId
);

/*==============================================================*/
/* Index: ix_ObjectProp_ProprtyId_Value                         */
/*==============================================================*/
create  index ix_ObjectProp_ProprtyId_Value on ObjectProperties (
PropertyId,
Value
);

/*==============================================================*/
/* Index: UN_ObjectProp_ObjId_Prop_DatFrom                      */
/*==============================================================*/
create unique index UN_ObjectProp_ObjId_Prop_DatFrom on ObjectProperties (
ObjectId,
PropertyId,
DateFrom
);

/*==============================================================*/
/* Index: UN_ObjectProp_RowId_Prop_DatFrom                      */
/*==============================================================*/
create unique index UN_ObjectProp_RowId_Prop_DatFrom on ObjectProperties (
PropertyId,
DateFrom,
RowId
);

/*==============================================================*/
/* Index: ix_ObjectProperties_ProprtyId_Value                   */
/*==============================================================*/
create  index ix_ObjectProperties_ProprtyId_Value on ObjectProperties (
PropertyId,
Value
);

/*==============================================================*/
/* Index: UN_ObjectProperties_ObjectId_PropertyId_DateFrom      */
/*==============================================================*/
create unique index UN_ObjectProperties_ObjectId_PropertyId_DateFrom on ObjectProperties (
ObjectId,
PropertyId,
DateFrom
);

/*==============================================================*/
/* Index: UN_ObjectProperties_RowId_PropertyId_DateFrom         */
/*==============================================================*/
create unique index UN_ObjectProperties_RowId_PropertyId_DateFrom on ObjectProperties (
RowId,
PropertyId,
DateFrom
);

/*==============================================================*/
/* Index: IX_Objects_EntityId_Code                              */
/*==============================================================*/
create  index IX_Objects_EntityId_Code on Objects (
EntityId,
Code
);

/*==============================================================*/
/* Index: ux_Persons_INN                                        */
/*==============================================================*/
create unique index ux_Persons_INN on Persons (
INN
);

/*==============================================================*/
/* Index: ux_Persons_GekId_Account                              */
/*==============================================================*/
create unique index ux_Persons_GekId_Account on Persons (
GekId,
Account
);

/*==============================================================*/
/* Index: un_Prefs_Code                                         */
/*==============================================================*/
create unique index un_Prefs_Code on Prefs (
Code
);

/*==============================================================*/
/* Index: un_Regions_Code                                       */
/*==============================================================*/
create unique index un_Regions_Code on Regions (
Code
);

/*==============================================================*/
/* Index: UN_Reports_Code                                       */
/*==============================================================*/
create unique index UN_Reports_Code on Reports (
Code
);

/*==============================================================*/
/* Index: ix_StreetTypes_code                                   */
/*==============================================================*/
create unique index ix_StreetTypes_code on StreetTypes (
Code
);

/*==============================================================*/
/* Index: ix_StreetTypes_nm                                     */
/*==============================================================*/
create unique index ix_StreetTypes_nm on StreetTypes (
Name
);

/*==============================================================*/
/* Index: ix_Streets                                            */
/*==============================================================*/
create unique index ix_Streets on Streets (
StreetTypeId,
Name,
Spec
);

/*==============================================================*/
/* Index: ix_Streets_code                                       */
/*==============================================================*/
create unique index ix_Streets_code on Streets (
Code
);

/*==============================================================*/
/* Index: UN_TariffValues_TariffId_ServiceId_DateFrom           */
/*==============================================================*/
create unique index UN_TariffValues_TariffId_ServiceId_DateFrom on TariffValues (
TariffId,
ServiceId,
DateFrom
);

/*==============================================================*/
/* Index: un_Tariffs_Dat_ServId_Tag                             */
/*==============================================================*/
/*
create unique index un_Tariffs_Dat_ServId_Tag on Tariffs (

);
*/

/*==============================================================*/
/* Index: UN_Tariffs_Code                                       */
/*==============================================================*/
create unique index UN_Tariffs_Code on Tariffs (
Code
);

/*==============================================================*/
/* Index: UN_Tariffs_Name                                       */
/*==============================================================*/
create unique index UN_Tariffs_Name on Tariffs (
Name
);

/*==============================================================*/
/* Index: UN_TaskTypes_Code                                     */
/*==============================================================*/
create unique index UN_TaskTypes_Code on TaskTypes (
Code
);

/*==============================================================*/
/* Index: UN_Tasks_InsertTS                                     */
/*==============================================================*/
create unique index UN_Tasks_InsertTS on Tasks (
InsertTS
);

/*==============================================================*/
/* Index: Ind_z_ext_dept_1                                      */
/*==============================================================*/
create  index Ind_z_ext_dept_1 on z_ext_dept (
RegionId
);

/*==============================================================*/
/* Index: Ind_z_ext_dept_2                                      */
/*==============================================================*/
create  index Ind_z_ext_dept_2 on z_ext_dept (
DEPT
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_1                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_1 on z_ext_objects (
StreetTypeId
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_2                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_2 on z_ext_objects (
StreetId
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_3                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_3 on z_ext_objects (
HouseId
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_4                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_4 on z_ext_objects (
ADRES_VID
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_5                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_5 on z_ext_objects (
ADRES
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_6                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_6 on z_ext_objects (
DEPT
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_7                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_7 on z_ext_objects (
REG_COD
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_8                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_8 on z_ext_objects (
N_DOM
);

/*==============================================================*/
/* Index: Ind_z_ext_objects_9                                   */
/*==============================================================*/
create  index Ind_z_ext_objects_9 on z_ext_objects (
DOP_PR
);

/*==============================================================*/
/* Index: Ind_z_ext_region_1                                    */
/*==============================================================*/
create  index Ind_z_ext_region_1 on z_ext_region (
DepartmentId
);

/*==============================================================*/
/* Index: Ind_z_ext_splat_1                                     */
/*==============================================================*/
create  index Ind_z_ext_splat_1 on z_ext_splat (
ConsumerId
);

/*==============================================================*/
/* Index: Ind_z_ext_streets_ispolkom_1                          */
/*==============================================================*/
create  index Ind_z_ext_streets_ispolkom_1 on z_ext_streets_ispolkom (
StreetTypeId
);

/*==============================================================*/
/* Index: Ind_z_ext_streets_ispolkom_2                          */
/*==============================================================*/
create  index Ind_z_ext_streets_ispolkom_2 on z_ext_streets_ispolkom (
StreetId
);

