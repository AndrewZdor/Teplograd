/**
 * sys_list state changing implementation for TEXT data type.
 */
CREATE OR REPLACE FUNCTION sys_list_text(state TEXT, nextValue TEXT, delimiter TEXT = ',')
RETURNS TEXT AS
$BODY$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || $3 END
		|| COALESCE($2, '');
$BODY$
LANGUAGE SQL
IMMUTABLE;

CREATE OR REPLACE FUNCTION sys_list_text(state TEXT, nextValue TEXT)
RETURNS TEXT AS
$BODY$
	SELECT CASE WHEN $1 = '' THEN '' ELSE $1 || ',' END
		|| COALESCE($2, '');
$BODY$
LANGUAGE SQL
IMMUTABLE;

DROP AGGREGATE IF EXISTS sys_list(TEXT);
DROP AGGREGATE IF EXISTS sys_list(TEXT, TEXT);
/**
 * Aggregate function producing delimiter-separated list.
 * NULL are threted as empty atrings.
 */
CREATE AGGREGATE sys_list(TEXT, /*delimiter*/ TEXT) (
	sfunc = sys_list_text,
	stype = TEXT,
	initcond = ''
);
CREATE AGGREGATE sys_list(TEXT) (
	sfunc = sys_list_text,
	stype = TEXT,
	initcond = ''
);