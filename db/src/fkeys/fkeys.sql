/*==============================================================*/
/* DBMS name:      PostgreSQL 8                                 */
/* Created on:     17.06.2009 20:48:55                          */
/*==============================================================*/

SET client_min_messages TO warning;

alter table AuditLog
   add constraint FK_AuditLog_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table AuditLog
   add constraint FK_AuditLog_Users foreign key (UserId)
      references Users (Id)
      on delete restrict on update restrict;

alter table Benefits
   add constraint FK_Benefits_Objects foreign key (ObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table CalcTypeDefs
   add constraint FK_CalcLockDefs_CalcTypes foreign key (CalcTypeId)
      references CalcTypes (Id)
      on delete restrict on update restrict;

alter table CalcTypeDefs
   add constraint FK_CalcLockDefs_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table Calculations
   add constraint FK_Calculations_CalcTypes foreign key (CalcTypeId)
      references CalcTypes (Id)
      on delete restrict on update restrict;

alter table CountCalculators
   add constraint FK_CountCalculators_CountCalcTypes foreign key (CalcTypeId)
      references CountCalcTypes (Id)
      on delete restrict on update restrict;

alter table CountCalculators
   add constraint FK_CountCalculators_CountNodes foreign key (NodeId)
      references CountNodes (Id)
      on delete restrict on update restrict;

alter table CountData
   add constraint FK_CountData_Counters foreign key (CounterId)
      references Counters (Id)
      on delete restrict on update restrict;

alter table CountNodes
   add constraint FK_CountNodes_Consumers foreign key (OwnerId)
      references Consumers (Id)
      on delete restrict on update restrict;

alter table CountNodes
   add constraint FK_CountNodes_HouseObjects foreign key (HouseObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_CountCalculators foreign key (CalcId)
      references CountCalculators (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_CountPPRTypes foreign key (PPRTypeId)
      references CountPPRTypes (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_CountPPRTypes2 foreign key (PPRTypeId2)
      references CountPPRTypes (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_CountTSPTypes foreign key (TSPTypeId)
      references CountTSPTypes (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_CountTSPTypes2 foreign key (TSPTypeId2)
      references CountTSPTypes (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_Objects foreign key (ObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table Counters
   add constraint FK_Counters_Services foreign key (ServiceId)
      references Services (Id)
      on delete restrict on update restrict;

alter table Dictionary
   add constraint FK_Dictionary_Languages foreign key (LanguageCode)
      references Languages (Code)
      on delete restrict on update restrict;

alter table EntityProperties
   add constraint FK_ENTITYPROPERTIES_ENTITIES_REF foreign key (RefEntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table EntityProperties
   add constraint FK_EntityProperties_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table EntityValidation
   add constraint Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table EntityValidation
   add constraint Errors foreign key (ErrorCode)
      references Errors (Code)
      on delete restrict on update restrict;

alter table Entrances
   add constraint FK_Entrances_HouseObjects foreign key (HouseObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table FormControls
   add constraint FK_FormControls_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table FormControls
   add constraint FK_FormControls_Forms foreign key (FormId)
      references Forms (Id)
      on delete restrict on update restrict;

alter table HierarchyFolders
   add constraint FK_HierarchyFolders_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table HierarchyFolders
   add constraint FK_HierarchyFolders_Entities_Parent foreign key (ParentEntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table HierarchyFolders
   add constraint FK_HierarchyFolders_Hierarchies foreign key (HierarchyId)
      references Hierarchies (Id)
      on delete restrict on update restrict;

alter table HouseOwners
   add constraint FK_HouseOwners_Consumers foreign key (ConsumerId)
      references Consumers (Id)
      on delete restrict on update restrict;

alter table HouseOwners
   add constraint FK_HouseOwners_HouseObjects foreign key (HouseObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table ObjectCapacities
   add constraint FK_ObjectCapacities_Objects foreign key (ObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table ObjectCapacities
   add constraint FK_PlaceCapacities_Services foreign key (ServiceId)
      references Services (Id)
      on delete restrict on update restrict;

alter table ObjectProperties
   add constraint FK_ObjectProperties_ObjectTypeProperties foreign key (PropertyId)
      references EntityProperties (Id)
      on delete restrict on update restrict;

alter table ObjectProperties
   add constraint FK_ObjectProperties_Objects foreign key (ObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table Objects
   add constraint FK_Objects_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table PrefValues
   add constraint FK_PrefValues_Prefs foreign key (PrefId)
      references Prefs (Id)
      on delete restrict on update restrict;

alter table PrefValues
   add constraint FK_UserPrefs_Users foreign key (UserId)
      references Users (Id)
      on delete restrict on update restrict;

alter table Reports
   add constraint FK_Reports_CalcTypes foreign key (CalcTypeId)
      references CalcTypes (Id)
      on delete restrict on update restrict;

alter table ServiceLog
   add constraint FK_ServiceLog_Objects foreign key (ObjectId)
      references Objects (Id)
      on delete restrict on update restrict;

alter table ServiceLog
   add constraint FK_ServiceLog_Services foreign key (ServiceId)
      references Services (Id)
      on delete restrict on update restrict;

alter table Streets
   add constraint FK_Streets_Cities foreign key (CityId)
      references Cities (Id)
      on delete restrict on update restrict;

alter table Streets
   add constraint FK_Streets_StreetTypes foreign key (StreetTypeId)
      references StreetTypes (Id)
      on delete restrict on update restrict;

alter table TariffValues
   add constraint Services foreign key (ServiceId)
      references Services (Id)
      on delete restrict on update restrict;

alter table TariffValues
   add constraint Tariffs foreign key (TariffId)
      references Tariffs (Id)
      on delete restrict on update restrict;

alter table TaskTypes
   add constraint FK_TaskTypes_Entities foreign key (EntityId)
      references Entities (Id)
      on delete restrict on update restrict;

alter table Tasks
   add constraint FK_Tasks_TaskTypes foreign key (TypeId)
      references TaskTypes (Id)
      on delete restrict on update restrict;

alter table TestTable
   add constraint FK_TestTable_TestTable foreign key (ParentId)
      references TestTable (Id)
      on delete restrict on update restrict;

