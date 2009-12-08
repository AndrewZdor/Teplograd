--SHOW CLIENT_ENCODING;
--SET CLIENT_ENCODING TO 'WIN1251';

/*==============================================================*/
/* User: tnd                                                    */
/*==============================================================*/

DROP ROLE IF EXISTS tnd ;
CREATE ROLE tnd LOGIN PASSWORD 'letmecomein' SUPERUSER CREATEDB CREATEROLE;

/*==============================================================*/
/* Groups                                                       */
/*==============================================================*/

DROP ROLE IF EXISTS Tornado ;
CREATE ROLE Tornado NOLOGIN SUPERUSER ;

DROP ROLE IF EXISTS cf_admins ;
CREATE ROLE cf_admins NOLOGIN  ;

DROP ROLE IF EXISTS cf_users ;
CREATE ROLE cf_users NOLOGIN  ;

/*==============================================================*/
/* Users                                                        */
/*==============================================================*/

DROP ROLE IF EXISTS Andrey ;
CREATE ROLE Andrey LOGIN PASSWORD 'andrey' CONNECTION LIMIT 2 IN ROLE Tornado ;
COMMENT ON ROLE Andrey IS 'Андрей Здоровцов';

DROP ROLE IF EXISTS Ant ;
CREATE ROLE Ant LOGIN PASSWORD 'ant' CONNECTION LIMIT 2 IN ROLE Tornado;
COMMENT ON ROLE Ant IS 'Юра Антихович';

DROP ROLE IF EXISTS dba	;
CREATE ROLE dba LOGIN PASSWORD 'sql' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE dba IS 'Database Administrator';

DROP ROLE IF EXISTS Larisa ;
CREATE ROLE Larisa LOGIN PASSWORD 'larisa' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE Larisa IS 'Лариса';

DROP ROLE IF EXISTS Litira ;
CREATE ROLE Litira LOGIN PASSWORD 'litira' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE Litira IS 'Ирина Литвин';

DROP ROLE IF EXISTS Olga ;
CREATE ROLE Olga LOGIN PASSWORD 'olga' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE Olga IS 'Ольга Алексеевна Прокофьева';

DROP ROLE IF EXISTS Sasha ;
CREATE ROLE Sasha LOGIN PASSWORD 'sasha' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE Sasha IS 'Саша СУТ';

DROP ROLE IF EXISTS naladka ;
CREATE ROLE naladka LOGIN PASSWORD 'naladka' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE naladka IS 'служба наладки';

DROP ROLE IF EXISTS dogovor ;
CREATE ROLE dogovor LOGIN PASSWORD 'dogovor' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE dogovor IS 'Договорной отдел';

DROP ROLE IF EXISTS "Гость" ;
CREATE ROLE "Гость" LOGIN PASSWORD 'гость' CONNECTION LIMIT 2 IN ROLE cf_users;
COMMENT ON ROLE "Гость" IS 'Гость';
