CREATE OR REPLACE FUNCTION set_tbl_seq ()
RETURNS integer AS

$body$

DECLARE
    mviews RECORD;
    nlast INT;
    seq VARCHAR;
    tbl VARCHAR;
BEGIN

    FOR seq IN SELECT relname FROM pg_class where  relkind = 'S' LOOP

		tbl := SUBSTRING (seq,1,char_length(seq)-7);
 		SELECT relname INTO tbl FROM pg_class where  relkind = 'r' AND relname = tbl;

        IF FOUND THEN
          --PERFORM cs_log('Refreshing materialized view ' || quote_ident(mviews.mv_name) || ' ...');
          EXECUTE 'SELECT max(id) FROM  ' || quote_ident(tbl) INTO nlast ;

          IF nlast>0 THEN
          	PERFORM setval(quote_ident(seq), nlast+1);
          END IF;

          RAISE INFO 'tbl=% , nlast=%', tbl, nlast+1;

        END IF;

      END LOOP;

      RETURN 111;

END;

$body$

LANGUAGE 'plpgsql'
SECURITY DEFINER
COST 10;

