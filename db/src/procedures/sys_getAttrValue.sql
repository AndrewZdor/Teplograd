/**
	SELECTS the value of named attribute for Object entities.
*/

CREATE OR REPLACE FUNCTION sys_getAttrValue (
	IN _EntityIdIn INTEGER, -- NULL hint for Object Entities.
	IN _ObjectIdIn INTEGER, -- Row Id.
	IN _CodeIn TEXT, -- Property(Field) Code.
	IN _DateFromIn DATE
)
RETURNS TEXT AS

$BODY$
DECLARE
	 _Result TEXT;
	 _EntityType TEXT;
	 _SQL TEXT;
	 _Code TEXT;
	 _Name TEXT;
	 _Rem TEXT;
BEGIN

	IF LOWER(_CodeIn) = 'id' THEN
		RETURN _ObjectIdIn;
	END IF;

	IF _EntityIdIn IS NOT NULL THEN
		SELECT Type
		INTO _EntityType
		FROM Entities
		WHERE Id = _EntityIdIn;
	ELSE
		_EntityType := 'SOFT';
	END IF;

	IF _EntityType = 'SOFT' THEN -- Determine enity type.

		IF LOWER(_CodeIn) NOT IN ('code', 'name', 'rem') THEN
			SELECT Value
			INTO _Result
			FROM Objects o
			JOIN ObjectProperties op ON o.Id = op.ObjectId
			WHERE op.ObjectId = _ObjectIdIn
			  AND op.DateFrom <= _DateFromIn
			  AND op.PropertyId = (SELECT Id FROM EntityProperties WHERE LOWER(Code) = LOWER(_CodeIn) AND EntityId = o.EntityId)
			ORDER BY DateFrom DESC
			LIMIT 1;
		ELSE
			SELECT Code, Name, Rem
			INTO _Code, _Name, _Rem
			FROM Objects
			WHERE Id = _ObjectIdIn;

			IF LOWER(_CodeIn) = 'code' THEN
				RETURN _Code;
			ELSEIF LOWER(_CodeIn) = 'name' THEN
				RETURN _Name;
			ELSEIF LOWER(_CodeIn) = 'rem' THEN
				RETURN _Rem;
			END IF;
		END IF;

	ELSE -- Table Entities.

		IF EXISTS(SELECT 1 FROM EntityProperties
		          WHERE EntityId = _EntityIdIn
		            AND LOWER(Code) = LOWER(_CodeIn)) THEN

			SELECT Value
			INTO _Result
			FROM ObjectProperties
			WHERE RowId = _ObjectIdIn
			  AND DateFrom <= _DateFromIn
			  AND PropertyId = (SELECT Id FROM EntityProperties WHERE LOWER(Code) = LOWER(_CodeIn)
			  					AND EntityId = _EntityIdIn)
			ORDER BY DateFrom DESC
			LIMIT 1;

		ELSE
			_SQL :=
			$sql$
				SELECT $1
				FROM %TableName%
				WHERE Id = $2
			$sql$ ;

			_SQL := REPLACE(_SQL, '%TableName%', sys_getTableName(_EntityIdIn));
			PERFORM sys_debugMessage('sys_getAttrValue: ' || _SQL);
			EXECUTE _SQL INTO _Result USING LOWER(_CodeIn), _ObjectIdIn;
			PERFORM sys_debugMessage('sys_getAttrValue: Result=' || _Result);

		END IF;

	END IF;

	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;