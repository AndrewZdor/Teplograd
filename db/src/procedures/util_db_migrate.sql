/**
 * Apply patch file to db, check if patch already applied.
 */

CREATE OR REPLACE FUNCTION util_db_migrate (
    IN StageIn TEXT, -- begin or end
    IN RevisionIn CITEXT
) RETURNS VOID AS

$BODY$
DECLARE
	_LastChangedRevision String := RevisionIn;
	_Revision String;
	_RevisionDate Date := localtimestamp;
	_RevisionPrefId Integer;
BEGIN

	SELECT Id INTO _RevisionPrefId
	FROM Prefs WHERE Code = 'System.Revision' ;

	IF StageIn = 'begin' THEN

		-- TODO: Don't delete - make rake task.
		UPDATE PrefValues pv
		SET Value = 1
		WHERE PrefId = (SELECT Id FROM Prefs WHERE Code = 'GUI.Editor.ShowIdInHeader');

		---------------------------------------------------------------------------------
		-- Revision control block
		---------------------------------------------------------------------------------

		SELECT pv.Value
		INTO _Revision
		FROM Prefs p
		JOIN PrefValues pv ON pv.PrefId = p.Id
		WHERE p.Code = 'System.Revision'
		ORDER BY DateFrom DESC NULLS LAST
		LIMIT 1;

		IF _Revision IS NULL THEN
			IF _RevisionPrefId IS NULL THEN
				INSERT INTO Prefs(Code, DataType, Rem)
				VALUES('System.Revision', 'Varchar', 'Revision of the DB') ;
			END IF;

			INSERT INTO PrefValues(PrefId, DateFrom, Value)
			VALUES(_RevisionPrefId, _RevisionDate, _LastChangedRevision || ' ERROR');
		ELSE
			IF _Revision = (_LastChangedRevision || ' OK') THEN
				PERFORM sys_DebugMessage('Patch stopped - already patched. Exiting.');
				RAISE USING MESSAGE = 'Patch stopped - already patched.' ;
			ELSE
				PERFORM sys_DebugMessage('Updating System.Revision parameter...');
				INSERT INTO PrefValues(PrefId, DateFrom, Value)
			    VALUES(_RevisionPrefId, _RevisionDate, _LastChangedRevision || ' ERROR');

			END IF;
		END IF;

	ELSIF StageIn = 'end' THEN

		---------------------------------------------------------------------------------
		-- End of Script.
		---------------------------------------------------------------------------------
		PERFORM sys_DebugMessage('Patch for revision ' || _LastChangedRevision || ' Finished OK') ;

		SELECT MAX(DateFrom)
		INTO _RevisionDate
		FROM PrefValues
		WHERE PrefId = _RevisionPrefId;

		UPDATE PrefValues
		SET Value = _LastChangedRevision || ' OK'
		WHERE PrefId = _RevisionPrefId
		AND DateFrom = _RevisionDate;

	END IF;

EXCEPTION WHEN OTHERS THEN
	--PERFORM sys_EventLog(SQLSTATE, SQLERRM, 'rcp_addObject');
	RAISE;

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;