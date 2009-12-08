/**
	Checks if the object can be edited by its DateFrom and DelDates.
	Returns NULL if editable.
	If one of dates is not specified - it is NOT used.
*/

CREATE OR REPLACE FUNCTION sys_ObjectIsEditable (
	IN _EntityIdIn INTEGER,
	IN _ObjIdIn INTEGER,
	IN _WorkingDateIn DATE,
	IN _DateFromIn DATE,
	IN _InsDateIn DATE,
	IN _DelDateIn DATE
)
RETURNS String AS

$BODY$
DECLARE
    _CalcDate DATE;
BEGIN

	-- Allow editing calculations.
	IF (SELECT Code FROM Entities WHERE Id = _EntityIdIn) = 'Calculations' THEN
		RETURN NULL;
	END IF;

	IF _InsDateIn > _WorkingDateIn THEN
		RETURN 'Object is not inserted yet.';
	END IF;

	IF _DelDateIn <= _WorkingDateIn THEN
		RETURN 'Object is already deleted.';
	END IF;

	IF _DateFromIn IS NOT NULL THEN
        SELECT c.DateFrom
        INTO _CalcDate c
        FROM Calculations c
        WHERE c.DateTo > _DateFromIn;

		IF _CalcDate IS NOT NULL THEN
			RETURN 'There are calculation on ' || _CalcDate::TEXT
                || ', blocking the object (Date = ' || _DateFromIn::TEXT || '.';
		END IF;
	END IF;

	RETURN NULL;
END;

$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;
