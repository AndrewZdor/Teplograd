/**
 * Drop all procedures and functions
 */
CREATE OR REPLACE FUNCTION dropAllProc ()
RETURNS void AS

$BODY$
DECLARE
	_func RECORD;

BEGIN
	FOR _func IN
		SELECT proname || '(' || OIDVECTORTYPES(proargtypes) || ')' AS name
		FROM pg_proc
		WHERE 1 = 1 --proowner = (select oid from pg_authid where rolname = '%username')
			AND SUBSTR(proname,1, 4) in ('sys_', 'rcp_', 'util', 'calc')
			and NOT proisagg
	LOOP
		EXECUTE 'DROP FUNCTION IF EXISTS ' || _func.name || ' CASCADE';
	END LOOP;
END;
$BODY$

LANGUAGE PLPGSQL;

SELECT dropAllProc();
DROP FUNCTION dropAllProc();

