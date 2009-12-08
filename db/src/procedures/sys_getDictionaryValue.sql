/**
	Get translation from Dictionary
*/

CREATE OR REPLACE FUNCTION sys_getDictionaryValue(
	CodeIn TEXT,
	FieldIn TEXT DEFAULT NULL
)
RETURNS TEXT AS

$BODY$
DECLARE
    _SQL LongestString;

    _Lang CHAR(3);
	_Name String;
	_Code String;
	_Field String;
	_i INTEGER;
	_NotTranslatable String;
BEGIN
	-- Во View можно писать алиас по русски и он не будет переводиться
	_NotTranslatable := replace(CodeIn, substring(CodeIn, E'[0-9|a-z|A-Z|_|\.]*'), '' ) ;
	IF COALESCE(_NotTranslatable, '') <> '' THEN
		RETURN _NotTranslatable;
	END IF;

	IF lower(FieldIn) IN ('names', 'abbr', 'rem') THEN
		_Field := FieldIn;
	ELSE
		_Field := 'name';
	END IF ;

    SELECT Value INTO _Lang
	FROM sys_getPrefValue('GUI.General.Language');

	_Code := CodeIn ;
	_i := 0;
	WHILE _Name IS NULL AND _i < 2 LOOP

		_SQL :=
		$sql$
			SELECT _Field
			FROM Dictionary
			WHERE lower(Code) = lower($1)
			  AND lower(LanguageCode) = lower($2)
		$sql$ ;

		_SQL := REPLACE(_SQL, '_Field', _Field) ;

		EXECUTE _SQL INTO _Name USING _Code, _Lang;

		_i := _i + 1;
		_Code := 'Common' || SUBSTRING(CodeIn from '%#".%#"' for '#');
	END LOOP;

	_Code := CASE WHEN FieldIn IS NULL THEN CodeIn ELSE CodeIn || '(' || FieldIn || ')' END ;
	_Name := COALESCE(_Name, _Code) ;

	RETURN _Name;

END;
$BODY$

LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER;
