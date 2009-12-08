/**
Get queries used by client app.
*/
CREATE OR REPLACE FUNCTION rcp_getRCPQueries()
RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getRCPQueries';
	procs RECORD;
	paramz RECORD;
	_paramList TEXT;

BEGIN

	CREATE TEMPORARY TABLE tmp (procName TEXT, paramList TEXT, returnType TEXT) ON COMMIT DROP;

	FOR procs IN
		SELECT r.specific_schema, r.specific_name, r.routine_name AS procName, r.data_type AS returnType
		FROM information_schema.routines r
		WHERE r.specific_schema = 'public'
			AND r.routine_name LIKE 'rcp%'
		ORDER BY r.routine_name
	LOOP
		_paramList := NULL;

		FOR paramz IN
			SELECT p.parameter_mode, p.parameter_name, p.udt_name
			FROM information_schema.parameters p
			WHERE p.specific_schema = procs.specific_schema
				AND p.specific_name = procs.specific_name
			ORDER BY p.ordinal_position
		LOOP
			_paramList := COALESCE(_paramList, '')
				|| '{mode=' || paramz.parameter_mode
				|| ', name=' || paramz.parameter_name
				|| ', type=' || paramz.udt_name
				|| '} ';
		END LOOP;

		INSERT INTO tmp(procName, paramList, returnType)
		VALUES (procs.procName, _paramList, procs.returnType);
	END LOOP;

	OPEN result FOR
	SELECT * FROM tmp
	;
	RETURN result;

EXCEPTION WHEN OTHERS THEN
	PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_getRCPQueries');
	RAISE;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;

/*
BEGIN;
SELECT rcp_getRCPQueries();
FETCH ALL IN "rcp_getRCPQueries";
END;
*/

