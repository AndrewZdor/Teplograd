/*==============================================================*/
/* DBMS name:      PostgreSQL 8                                 */
/* Created on:     18.06.2009 17:27:39                          */
/*==============================================================*/

SET client_min_messages TO warning;

drop type if exists BoolNotNull;

drop type if exists BoolNull;

drop type if exists HugeString;

drop type if exists Ident;

drop type if exists LongString;

drop type if exists LongestString;

drop type if exists NString;

drop type if exists Number;

drop type if exists SmallString;

drop type if exists String;

drop type if exists TinyString;

/*==============================================================*/
/* Domain: BoolNotNull                                          */
/*==============================================================*/
create domain BoolNotNull as BOOL;

/*==============================================================*/
/* Domain: BoolNull                                             */
/*==============================================================*/
create domain BoolNull as BOOL;

/*==============================================================*/
/* Domain: HugeString                                           */
/*==============================================================*/
create domain HugeString as CITEXT;

/*==============================================================*/
/* Domain: Ident                                                */
/*==============================================================*/
create domain Ident as INT4;

/*==============================================================*/
/* Domain: LongString                                           */
/*==============================================================*/
create domain LongString as CITEXT;

/*==============================================================*/
/* Domain: LongestString                                        */
/*==============================================================*/
create domain LongestString as CITEXT;

/*==============================================================*/
/* Domain: NString                                              */
/*==============================================================*/
create domain NString as CITEXT;

/*==============================================================*/
/* Domain: Number                                               */
/*==============================================================*/
create domain Number as DECIMAL(18,8);

/*==============================================================*/
/* Domain: SmallString                                          */
/*==============================================================*/
create domain SmallString as CITEXT;

/*==============================================================*/
/* Domain: String                                               */
/*==============================================================*/
create domain String as CITEXT;

/*==============================================================*/
/* Domain: TinyString                                           */
/*==============================================================*/
create domain TinyString as CITEXT;

