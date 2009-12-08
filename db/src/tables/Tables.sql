/*==============================================================*/
/* DBMS name:      PostgreSQL 8                                 */
/* Created on:     18.06.2009 18:24:00                          */
/*==============================================================*/

drop table if exists AuditLog;

drop table if exists Benefits;

drop table if exists CalcTypeDefs;

drop table if exists CalcTypes;

drop table if exists Calculations;

drop table if exists Cities;

drop table if exists Consumers;

drop table if exists CountCalcTypes;

drop table if exists CountCalculators;

drop table if exists CountData;

drop table if exists CountNodes;

drop table if exists CountPPRTypes;

drop table if exists CountTSPTypes;

drop table if exists Counters;

drop table if exists Departments;

drop table if exists Dictionary;

drop table if exists Entities;

drop table if exists EntityProperties;

drop table if exists EntityValidation;

drop table if exists Entrances;

drop table if exists Errors;

drop table if exists EventLog;

drop table if exists FormControls;

drop table if exists Forms;

drop table if exists Groups;

drop table if exists Hierarchies;

drop table if exists HierarchyFolders;

drop table if exists HouseOwners;

drop table if exists Languages;

drop table if exists ObjectCapacities;

drop table if exists ObjectProperties;

drop table if exists Objects;

drop table if exists Persons;

drop table if exists PrefValues;

drop table if exists Prefs;

drop table if exists Regions;

drop table if exists Reports;

drop table if exists ServiceLog;

drop table if exists Services;

drop table if exists StreetTypes;

drop table if exists Streets;

drop table if exists TariffValues;

drop table if exists Tariffs;

drop table if exists TaskTypes;

drop table if exists Tasks;

drop table if exists TestTable;

drop table if exists Users;

drop table if exists z_ext_dept;

drop table if exists z_ext_kotel;

drop table if exists z_ext_objects;

drop table if exists z_ext_region;

drop table if exists z_ext_splat;

drop table if exists z_ext_streets_ispolkom;

drop table if exists z_ext_tarif;

drop table if exists z_ext_trp;

/*==============================================================*/
/* Table: AuditLog                                              */
/*==============================================================*/
create table AuditLog (
   Id                   SERIAL not null,
   EventTS              TIMESTAMP            not null default LOCALTIMESTAMP,
   UserId               INT4                 not null,
   EntityId             INT4                 not null,
   RowId                INT4                 not null,
   FieldValues          CITEXT               null,
   FieldValuesFull      CITEXT               null,
   Revision             INT4                 null default 0,
   constraint PK_AUDITLOG primary key (Id)
);

/*==============================================================*/
/* Table: Benefits                                              */
/*==============================================================*/
create table Benefits (
   Id                   SERIAL not null,
   ObjectId             INT4                 null,
   LgotSpravId          CITEXT               null,
   LgotCatCode          CITEXT               null,
   Doc                  CITEXT               null,
   CART_LGT             INT4                 null,
   FileNum              INT4                 null,
   Rem                  LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_BENEFITS primary key (Id)
);

comment on table Benefits is
'Льготы';

comment on column Benefits.ObjectId is
'Указатель на помещение в котором проживает льготчик';

comment on column Benefits.Doc is
'Документ подтверждающий льготу';

comment on column Benefits.FileNum is
'Номер дела';

/*==============================================================*/
/* Table: CalcTypeDefs                                          */
/*==============================================================*/
create table CalcTypeDefs (
   Id                   SERIAL not null,
   CalcTypeId           INT4                 not null,
   OrderNo              INT4                 not null,
   EntityId             INT4                 not null,
   FieldName            String               not null,
   QuerySQL             LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_CALCTYPEDEFS primary key (Id)
);

/*==============================================================*/
/* Table: CalcTypes                                             */
/*==============================================================*/
create table CalcTypes (
   Id                   SERIAL not null,
   Code                 String               not null,
   Rem                  LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InputFields          LongString           null,
   InputSQL             LongestString        null,
   constraint PK_CALCTYPES primary key (Id)
);

/*==============================================================*/
/* Table: Calculations                                          */
/*==============================================================*/
create table Calculations (
   Id                   SERIAL not null,
   CalcTypeId           INT4                 not null,
   DateFrom             DATE                 not null,
   DateTo               DATE                 not null,
   State                String               not null default 'PRISTINE',
   Rem                  LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_CALCULATIONS primary key (Id)
);

/*==============================================================*/
/* Table: Cities                                                */
/*==============================================================*/
create table Cities (
   Id                   SERIAL not null,
   Name                 CITEXT               not null,
   Zip                  INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_CITIES primary key (Id)
);

comment on table Cities is
'Города';

comment on column Cities.Zip is
'Индекс';

/*==============================================================*/
/* Table: Consumers                                             */
/*==============================================================*/
create table Consumers (
   Id                   SERIAL not null,
   Code                 String               null,
   Nam                  CITEXT               not null,
   Name                 String               null,
   Rem                  LongString           null,
   TaxCode              CITEXT               null,
   NdsCode              CITEXT               null,
   NdsSvidet            CITEXT               null,
   Phone                CITEXT               null,
   Address              String               null,
   Email                CITEXT               null,
   TaxMode              INT2                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_CONSUMERS primary key (Id)
);

comment on table Consumers is
'Юр.лица';

comment on column Consumers.Nam is
'Краткое назв.';

comment on column Consumers.TaxCode is
'Код ЕГРПОУ';

comment on column Consumers.NdsCode is
'Налоговый ном.';

comment on column Consumers.NdsSvidet is
'Номер свид-ва';

comment on column Consumers.Phone is
'Телефон';

comment on column Consumers.Address is
'Адрес';

comment on column Consumers.Email is
'E-mail';

comment on column Consumers.TaxMode is
'Вид налогообложения';

/*==============================================================*/
/* Table: CountCalcTypes                                        */
/*==============================================================*/
create table CountCalcTypes (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_COUNTCALCTYPES primary key (Id)
);

comment on table CountCalcTypes is
'Типы вычислителей';

/*==============================================================*/
/* Table: CountCalculators                                      */
/*==============================================================*/
create table CountCalculators (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   CalcTypeId           INT4                 null,
   Num                  CITEXT               null,
   NodeId               INT4                 not null,
   Combined             BOOLEAN              not null default false,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_COUNTCALCULATORS primary key (Id)
);

comment on table CountCalculators is
'Вычислители';

/*==============================================================*/
/* Table: CountData                                             */
/*==============================================================*/
create table CountData (
   Id                   SERIAL not null,
   CounterId            INT4                 not null,
   DateFrom             DATE                 not null,
   Value                Number               not null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   DateTo               DATE                 not null,
   constraint PK_COUNTDATA primary key (Id)
);

comment on table CountData is
'Показания приборов учета';

/*==============================================================*/
/* Table: CountNodes                                            */
/*==============================================================*/
create table CountNodes (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   OwnerId              INT4                 null,
   HouseObjectId        INT4                 null,
   InsDate              DATE                 null,
   constraint PK_COUNTNODES primary key (Id)
);

comment on table CountNodes is
'Узлы учета';

/*==============================================================*/
/* Table: CountPPRTypes                                         */
/*==============================================================*/
create table CountPPRTypes (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_COUNTPPRTYPES primary key (Id)
);

/*==============================================================*/
/* Table: CountTSPTypes                                         */
/*==============================================================*/
create table CountTSPTypes (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_COUNTTSPTYPES primary key (Id)
);

/*==============================================================*/
/* Table: Counters                                              */
/*==============================================================*/
create table Counters (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   CalcId               INT4                 null,
   ServiceId            INT4                 not null,
   ObjectId             INT4                 null,
   PPRTypeId            INT4                 null,
   PPRNum               CITEXT               null,
   TSPTypeId            INT4                 null,
   TSPNum               CITEXT               null,
   RegDate              DATE                 null,
   UnregDate            DATE                 null,
   CheckDate            DATE                 null,
   Rem                  String               null,
   DelDate              DATE                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 not null,
   PPRTypeId2           INT4                 null,
   PPRNum2              CITEXT               null,
   TSPTypeId2           INT4                 null,
   TSPNum2              CITEXT               null,
   constraint PK_COUNTERS primary key (Id)
);

comment on table Counters is
'Счетчики/датчики';

comment on column Counters.ObjectId is
'Ссылка на узел топологии';

comment on column Counters.RegDate is
'Дата постановки на коммерческий учет';

comment on column Counters.UnregDate is
'Дата снятия с коммерческого учета';

comment on column Counters.CheckDate is
'Дата проверки';

/*==============================================================*/
/* Table: Departments                                           */
/*==============================================================*/
create table Departments (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Name                 CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   DelDate              DATE                 null,
   InsDate              DATE                 null default '1900-01-01',
   constraint PK_DEPARTMENTS primary key (Id)
);

/*==============================================================*/
/* Table: Dictionary                                            */
/*==============================================================*/
create table Dictionary (
   Id                   SERIAL not null,
   LanguageCode         CITEXT               not null,
   Code                 String               not null,
   Name                 NString              not null,
   Names                NString              null,
   Abbr                 NString              null,
   Rem                  NString              null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_DICTIONARY primary key (Id)
);

/*==============================================================*/
/* Table: Entities                                              */
/*==============================================================*/
create table Entities (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Rem                  CITEXT               null,
   Decorator            CITEXT               null,
   OrderBy              CITEXT               null,
   Table_Id_            INT4                 null,
   LookUpCategory       String               null,
   Priority             INT4                 null,
   Type                 String               not null,
   ValidateProc         String               null,
   UpdateProc           String               null,
   RevisionThreshold    INT4                 null default 1000,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   LookupHierarchyId    INT4                 null,
   IsTranslatable       BOOLEAN              not null default false,
   UniqueFields         LongString           null,
   constraint PK_ENTITIES primary key (Id)
);

comment on column Entities.ValidateProc is
'Процедура валидации перед insert/update';

/*==============================================================*/
/* Table: EntityProperties                                      */
/*==============================================================*/
create table EntityProperties (
   Id                   SERIAL not null,
   EntityId             INT4                 null,
   OrderNo              INT2                 not null,
   RefEntityId          INT4                 null,
   DataType             SmallString          not null,
   DataLength           INT2                 null,
   Mandatory            BOOLEAN              not null default false,
   IsTemporal           BOOLEAN              not null default false,
   Code                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   PropGroup            String               null,
   ValidationSQL        LongString           null,
   RetrieveSQL          LongestString        null,
   Editable             String               null,
   constraint PK_ENTITYPROPERTIES primary key (Id)
);

/*==============================================================*/
/* Table: EntityValidation                                      */
/*==============================================================*/
create table EntityValidation (
   ID                   SERIAL not null,
   EntityId             INT4                 not null,
   Code                 String               not null,
   CheckMode            String               not null,
   RuleSQL              LongestString        not null,
   ErrorCode            String               not null,
   Rem                  LongString           null,
   constraint PK_ENTITYVALIDATION primary key (ID),
   constraint UN_EntityValidation_EntityId_Code unique (EntityId, Code)
);

/*==============================================================*/
/* Table: Entrances                                             */
/*==============================================================*/
create table Entrances (
   Id                   SERIAL not null,
   HouseObjectId        INT4                 not null,
   Num                  INT2                 not null,
   Code                 TinyString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_ENTRANCES primary key (Id)
);

comment on table Entrances is
'Подъезды';

comment on column Entrances.HouseObjectId is
'Указатель адреса';

comment on column Entrances.Num is
'Номер подъезда';

comment on column Entrances.Code is
'Код замка';

/*==============================================================*/
/* Table: Errors                                                */
/*==============================================================*/
create table Errors (
   Code                 String               not null,
   State                String               not null,
   LegacyState          String               null,
   Rem                  LongString           null,
   constraint PK_ERRORS primary key (Code),
   constraint UN_Errors_State unique (State)
);

/*==============================================================*/
/* Table: EventLog                                              */
/*==============================================================*/
create table EventLog (
   Id                   SERIAL not null,
   TS                   TIMESTAMP            null default LOCALTIMESTAMP,
   UserId               INT4                 null,
   ProcedureName        String               null,
   Data                 LongString           null,
   Event                LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_EVENTLOG primary key (Id)
);

/*==============================================================*/
/* Table: FormControls                                          */
/*==============================================================*/
create table FormControls (
   Id                   SERIAL not null,
   FormId               INT4                 not null,
   OrderNo              INT2                 not null,
   Column_Id_           INT4                 null,
   EntityId             INT4                 not null,
   FieldName            CITEXT               not null,
   IsEditable           BOOLEAN              not null default true,
   ControlTypeId        INT4                 null,
   Style                CITEXT               null,
   Misc                 CITEXT               null,
   Rem                  CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_FORMCONTROLS primary key (Id)
);

/*==============================================================*/
/* Table: Forms                                                 */
/*==============================================================*/
create table Forms (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Name                 CITEXT               not null,
   Rem                  CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_FORMS primary key (Id)
);

/*==============================================================*/
/* Table: Groups                                                */
/*==============================================================*/
create table Groups (
   Id                   SERIAL not null,
   Code                 String               null,
   Rem                  LongString           null,
   IsAdmin              BOOLEAN              not null default false,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_GROUPS primary key (Id)
);

/*==============================================================*/
/* Table: Hierarchies                                           */
/*==============================================================*/
create table Hierarchies (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Priority             INT2                 null,
   Rem                  CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   Type                 String               null,
   constraint PK_HIERARCHIES primary key (Id)
);

comment on column Hierarchies.Priority is
'Порядок сортировки';

/*==============================================================*/
/* Table: HierarchyFolders                                      */
/*==============================================================*/
create table HierarchyFolders (
   Id                   SERIAL not null,
   EntityId             INT4                 not null,
   Code                 CITEXT               null,
   CriteriaSQL          LongestString        null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   Type                 String               not null default 'Tree',
   Hint                 LongString           null,
   ParentField          LongString           null,
   ChildField           LongString           null,
   Priority             INT4                 null,
   HierarchyId          INT4                 not null,
   ParentEntityId       INT4                 not null,
   Action               String               null,
   constraint PK_HIERARCHYFOLDERS primary key (Id)
);

/*==============================================================*/
/* Table: HouseOwners                                           */
/*==============================================================*/
create table HouseOwners (
   Id                   SERIAL not null,
   DateFrom             DATE                 null,
   HouseObjectId        INT4                 not null,
   ConsumerId           INT4                 not null,
   Area                 Number               null,
   FlatRange            String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_HOUSEOWNERS primary key (Id)
);

comment on table HouseOwners is
'Балансосодержатели';

comment on column HouseOwners.HouseObjectId is
'Указатель на здание';

comment on column HouseOwners.ConsumerId is
'ссылка на балансосодержателя здания';

comment on column HouseOwners.Area is
'площадь';

comment on column HouseOwners.FlatRange is
'диапазон квартир';

/*==============================================================*/
/* Table: Languages                                             */
/*==============================================================*/
create table Languages (
   Code                 CITEXT               not null,
   Name                 String               not null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_LANGUAGES primary key (Code)
);

/*==============================================================*/
/* Table: ObjectCapacities                                      */
/*==============================================================*/
create table ObjectCapacities (
   Id                   SERIAL not null,
   ObjectId             INT4                 not null,
   DateFrom             DATE                 not null,
   ServiceId            INT4                 not null,
   Value1               Number               null,
   Value2               Number               null,
   Value3               Number               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_OBJECTCAPACITIES primary key (Id)
);

comment on column ObjectCapacities.ObjectId is
'Указатель на помещение';

comment on column ObjectCapacities.DateFrom is
'Период начала валидности';

/*==============================================================*/
/* Table: ObjectProperties                                      */
/*==============================================================*/
create table ObjectProperties (
   Id                   SERIAL not null,
   ObjectId             INT4                 null,
   PropertyId           INT4                 not null,
   DateFrom             DATE                 not null default '1900-01-01',
   Value                String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   RowId                INT4                 null,
   constraint PK_OBJECTPROPERTIES primary key (Id)
);

/*==============================================================*/
/* Table: Objects                                               */
/*==============================================================*/
create table Objects (
   Id                   SERIAL not null,
   EntityId             INT4                 not null,
   Code                 String               not null,
   Name                 String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   DelDate              DATE                 null,
   InsDate              DATE                 not null,
   OldId                INT4                 null,
   constraint PK_OBJECTS primary key (Id)
);

/*==============================================================*/
/* Table: Persons                                               */
/*==============================================================*/
create table Persons (
   Id                   SERIAL not null,
   FirstName            String               not null,
   MiddleName           String               null,
   LastName             String               null,
   INN                  CITEXT               null,
   GekId                INT4                 null,
   Account              INT4                 null,
   BirthDate            DATE                 null,
   Passport             CITEXT               null,
   BenefitId            INT4                 null,
   ExcludeDate          DATE                 null,
   Rem                  LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_PERSONS primary key (Id)
);

comment on table Persons is
'Физ. лица';

comment on column Persons.Account is
'Лицевой счет';

comment on column Persons.ExcludeDate is
'Дата снятия с учета';

/*==============================================================*/
/* Table: PrefValues                                            */
/*==============================================================*/
create table PrefValues (
   Id                   SERIAL not null,
   PrefId               INT4                 not null,
   UserId               INT4                 null,
   SessionId            INT4                 null,
   DateFrom             DATE                 null,
   Value                LongString           not null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_PREFVALUES primary key (Id)
);

/*==============================================================*/
/* Table: Prefs                                                 */
/*==============================================================*/
create table Prefs (
   Id                   SERIAL not null,
   Code                 String               not null,
   DataType             SmallString          not null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   Type                 String               not null default USER,
   constraint PK_PREFS primary key (Id)
);

/*==============================================================*/
/* Table: Regions                                               */
/*==============================================================*/
create table Regions (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Name                 CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_REGIONS primary key (Id)
);

/*==============================================================*/
/* Table: Reports                                               */
/*==============================================================*/
create table Reports (
   Id                   SERIAL not null,
   Code                 String               not null,
   CalcTypeId           INT4                 null,
   Rem                  LongString           null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   ReportSQL            LongestString        null,
   constraint PK_REPORTS primary key (Id)
);

/*==============================================================*/
/* Table: ServiceLog                                            */
/*==============================================================*/
create table ServiceLog (
   Id                   SERIAL not null,
   ObjectId             INT4                 null,
   DateFrom             DATE                 null,
   ServiceId            INT4                 null,
   State                BOOLEAN              not null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_SERVICELOG primary key (Id),
   constraint AK_KEY_1_SERVICEL unique (Id)
);

comment on table ServiceLog is
'Подача неподача услуг (Журнал отключений)';

comment on column ServiceLog.ObjectId is
'узел топологии';

comment on column ServiceLog.State is
'Состояние (вкл/выкл)';

/*==============================================================*/
/* Table: Services                                              */
/*==============================================================*/
create table Services (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               null,
   Value1               String               null,
   Value2               String               null,
   Value3               String               null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_SERVICES primary key (Id)
);

comment on table Services is
'Виды услуг';

/*==============================================================*/
/* Table: StreetTypes                                           */
/*==============================================================*/
create table StreetTypes (
   Id                   SERIAL not null,
   Code                 CITEXT               not null,
   Name                 CITEXT               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_STREETTYPES primary key (Id)
);

/*==============================================================*/
/* Table: Streets                                               */
/*==============================================================*/
create table Streets (
   Id                   SERIAL not null,
   CityId               INT4                 not null,
   StreetTypeId         INT4                 null,
   Code                 CITEXT               null,
   Name                 CITEXT               not null,
   Spec                 CITEXT               null default '',
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_STREETS primary key (Id)
);

/*==============================================================*/
/* Table: TariffValues                                          */
/*==============================================================*/
create table TariffValues (
   Id                   SERIAL not null,
   DateFrom             DATE                 not null,
   TariffId             INT4                 not null,
   ServiceId            INT4                 not null,
   Value1               Number               null,
   Value2               Number               null,
   Value3               Number               null,
   Rem                  LongString           null,
   InsertUserId         String               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         String               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_TARIFFVALUES primary key (Id)
);

/*==============================================================*/
/* Table: Tariffs                                               */
/*==============================================================*/
create table Tariffs (
   Id                   SERIAL not null,
   Code                 String               null,
   Name                 String               not null,
   Rem                  String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   InsDate              DATE                 null,
   constraint PK_TARIFFS primary key (Id)
);

comment on table Tariffs is
'Тарифы';

/*==============================================================*/
/* Table: TaskTypes                                             */
/*==============================================================*/
create table TaskTypes (
   Id                   SERIAL not null,
   Code                 String               not null,
   ProgressMax          INT4                 null,
   Rem                  LongestString        null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   EntityId             INT4                 not null,
   constraint PK_TASKTYPES primary key (Id)
);

/*==============================================================*/
/* Table: Tasks                                                 */
/*==============================================================*/
create table Tasks (
   Id                   SERIAL not null,
   TypeId               INT4                 null,
   SubjectId            INT4                 null,
   Description          LongString           null,
   State                String               null,
   Progress             INT4                 null default -1,
   ProgressRem          LongestString        null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_TASKS primary key (Id)
);

/*==============================================================*/
/* Table: TestTable                                             */
/*==============================================================*/
create table TestTable (
   Id                   SERIAL not null,
   VarCharField         String               null,
   IntField             INT4                 null,
   FloatField           INT4                 null,
   BitField             BoolNull             null,
   DateField            DATE                 null default CURRENT_DATE,
   DateTimeField        TIMESTAMP            null,
   TimeField            TIME                 null,
   TSField              TIMESTAMP            null,
   ParentId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_TESTTABLE primary key (Id)
);

/*==============================================================*/
/* Table: Users                                                 */
/*==============================================================*/
create table Users (
   Id                   SERIAL not null,
   Name                 String               null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0,
   constraint PK_USERS primary key (Id)
);

/*==============================================================*/
/* Table: z_ext_dept                                            */
/*==============================================================*/
create table z_ext_dept (
   DEPT                 CITEXT               null,
   DEPT_NM              CITEXT               null,
   RegionId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_kotel                                           */
/*==============================================================*/
create table z_ext_kotel (
   VID_KOT              CITEXT               null,
   N_KOT_COD            CITEXT               null,
   KOT_COD              CITEXT               null,
   TRP_NM               CITEXT               null,
   OT_PL                DECIMAL(30,6)        null,
   OT_GKAL              DECIMAL(30,6)        null,
   G_W_CEL              DECIMAL(30,6)        null,
   G_W_KUBM             DECIMAL(30,6)        null,
   G_W_GKAL             DECIMAL(30,6)        null,
   OT_VENTIL            DECIMAL(30,6)        null,
   OT_TEXNOL            DECIMAL(30,6)        null,
   MARK                 CITEXT               null,
   ObjectId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_objects                                         */
/*==============================================================*/
create table z_ext_objects (
   KN                   CITEXT               null,
   N_OBJ                DECIMAL(30,6)        null,
   VID_RS               CITEXT               null,
   VID_POTR             CITEXT               null,
   N_KOR                CITEXT               null,
   KOR                  CITEXT               null,
   DOP_PR               CITEXT               null,
   N_DOM                DECIMAL(30,6)        null,
   ADRES_VID            CITEXT               null,
   ADRES_COD            CITEXT               null,
   KOD_UL               DECIMAL(30,6)        null,
   ADRES                CITEXT               null,
   A                    DECIMAL(30,6)        null,
   OBJ_ADR              CITEXT               null,
   P_COD                CITEXT               null,
   OBJ_COD              CITEXT               null,
   SNAT                 CITEXT               null,
   DATE_DO              DATE                 null,
   REG_COD              CITEXT               null,
   DEPT                 CITEXT               null,
   COD_TAR              CITEXT               null,
   KOT_COD              CITEXT               null,
   OT_PL                DECIMAL(30,6)        null,
   OT_GKAL              DECIMAL(30,6)        null,
   G_W_CEL              DECIMAL(30,6)        null,
   G_W_KUBM             DECIMAL(30,6)        null,
   G_W_GKAL             DECIMAL(30,6)        null,
   OT_VENTIL            DECIMAL(30,6)        null,
   OT_TEXNOL            DECIMAL(30,6)        null,
   WED                  CITEXT               null,
   GEK                  CITEXT               null,
   TRP_COD              CITEXT               null,
   PL_SPRAV             DECIMAL(30,6)        null,
   WEIGHT               CITEXT               null,
   VID_TH               CITEXT               null,
   GKAL                 DECIMAL(30,6)        null,
   BANK                 DECIMAL(30,6)        null,
   BART                 DECIMAL(30,6)        null,
   VZ                   DECIMAL(30,6)        null,
   N_COD                CITEXT               null,
   TRP_COD1             CITEXT               null,
   S_PCOD               CITEXT               null,
   NAME                 CITEXT               null,
   DOG                  CITEXT               null,
   N_23                 DECIMAL(30,6)        null,
   VID_P                CITEXT               null,
   KOT_NAME             CITEXT               null,
   VVOD                 CITEXT               null,
   MARK                 CITEXT               null,
   StreetTypeId         INT4                 null,
   StreetId             INT4                 null,
   HouseId              INT4                 null,
   PlaceId              INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_region                                          */
/*==============================================================*/
create table z_ext_region (
   REG_COD              CITEXT               null,
   REG_NM               CITEXT               null,
   OT_PL                DECIMAL(30,6)        null,
   OT_GKAL              DECIMAL(30,6)        null,
   G_W_CEL              DECIMAL(30,6)        null,
   G_W_KUBM             DECIMAL(30,6)        null,
   G_W_GKAL             DECIMAL(30,6)        null,
   OT_VENTIL            DECIMAL(30,6)        null,
   OT_TEXNOL            DECIMAL(30,6)        null,
   MARK                 CITEXT               null,
   DepartmentId         INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_splat                                           */
/*==============================================================*/
create table z_ext_splat (
   KN                   CITEXT               null,
   KN1                  CITEXT               null,
   P_COD                CITEXT               null,
   VR                   CITEXT               null,
   P_NM                 CITEXT               null,
   SNAT                 CITEXT               null,
   DATE_DO              DATE                 null,
   VID_P                CITEXT               null,
   RS                   CITEXT               null,
   MFO                  CITEXT               null,
   KODPLATEL            CITEXT               null,
   DOGOVOR              CITEXT               null,
   OT_PL                DECIMAL(30,6)        null,
   OT_GKAL              DECIMAL(30,6)        null,
   G_W_CEL              DECIMAL(30,6)        null,
   G_W_KUBM             DECIMAL(30,6)        null,
   G_W_GKAL             DECIMAL(30,6)        null,
   OT_VENTIL            DECIMAL(30,6)        null,
   OT_TEXNOL            DECIMAL(30,6)        null,
   DEPT                 CITEXT               null,
   WED                  CITEXT               null,
   MARK                 CITEXT               null,
   GOROD                CITEXT               null,
   ADRESS               CITEXT               null,
   YLICA                CITEXT               null,
   INDEKS               CITEXT               null,
   FAKS                 CITEXT               null,
   FIO_DIR              CITEXT               null,
   TEL_DIR              CITEXT               null,
   FIO_GLBUH            CITEXT               null,
   TEL_GLBUH            CITEXT               null,
   FIO_RASCH            CITEXT               null,
   TEL_RASCH            CITEXT               null,
   K_NALOG              CITEXT               null,
   N_NALOG              CITEXT               null,
   CK                   DECIMAL(30,6)        null,
   GKAL                 DECIMAL(30,6)        null,
   NALOG                CITEXT               null,
   "LIMIT"              DECIMAL(30,6)        null,
   OSN_LIMIT            CITEXT               null,
   POKUP                CITEXT               null,
   OLD_PCOD             CITEXT               null,
   ADRESS1              CITEXT               null,
   S_PCOD               CITEXT               null,
   ZD                   CITEXT               null,
   AR                   CITEXT               null,
   REM_F1               CITEXT               null,
   H_IN_N_F1            CITEXT               null,
   ConsumerId           INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_streets_ispolkom                                */
/*==============================================================*/
create table z_ext_streets_ispolkom (
   CODE                 DECIMAL(30,6)        null,
   TYPE                 CITEXT               null,
   NAME                 CITEXT               null,
   StreetTypeId         INT4                 null,
   StreetId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);

/*==============================================================*/
/* Table: z_ext_tarif                                           */
/*==============================================================*/
create table z_ext_tarif (
   COD_TAR              String               null,
   T_NM                 String               null,
   T_OT_MKB             String               null,
   T_OT_GKAL            String               null,
   T_GW_CEL             String               null,
   T_GW_GKAL            String               null,
   T_GW_KUBM            String               null,
   T_XW_CEL             String               null,
   T_XW_KUBM            String               null,
   T_TEX_GKAL           String               null,
   T_VEN_GKAL           String               null,
   TariffId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP
);

/*==============================================================*/
/* Table: z_ext_trp                                             */
/*==============================================================*/
create table z_ext_trp (
   TRP_COD              CITEXT               null,
   TRP_COD1             CITEXT               null,
   TRP_NM               CITEXT               null,
   OT_PL                DECIMAL(30,6)        null,
   OT_GKAL              DECIMAL(30,6)        null,
   G_W_CEL              DECIMAL(30,6)        null,
   G_W_KUBM             DECIMAL(30,6)        null,
   G_W_GKAL             DECIMAL(30,6)        null,
   OT_VENTIL            DECIMAL(30,6)        null,
   OT_TEXNOL            DECIMAL(30,6)        null,
   MARK                 CITEXT               null,
   ObjectId             INT4                 null,
   InsertUserId         CITEXT               null default CURRENT_USER,
   InsertTS             TIMESTAMP            null default LOCALTIMESTAMP,
   UpdateUserId         CITEXT               null default CURRENT_USER,
   UpdateTS             TIMESTAMP            null default LOCALTIMESTAMP,
   Revision             INT4                 null default 0
);