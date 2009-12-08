/**
Returns parent objects for current one (including that one).
Level = 0 for callee object.
Uses 'ParentId' as "parent" attribute.
*/

CREATE OR REPLACE FUNCTION sys_getParentObjects(
	ObjectIdIn INTEGER,
	DateFromIn DATE
)
RETURNS TABLE (
	ObjectId INTEGER,
	ParentId INTEGER,
	Level INTEGER,
	DateFrom DATE
) AS

$BODY$
DECLARE

	_ObjectId INTEGER := ObjectIdIn;
	_ParentId INTEGER := 0;
	_Level INTEGER := 0;
	_DateFrom DATE;

	_resultObjectIds INTEGER[];
	_resultParentIds INTEGER[];
	_resultLevels INTEGER[];
	_resultDateFroms DATE[];

BEGIN

	WHILE _ParentId IS NOT NULL LOOP
		_ParentId := NULL;

		SELECT op.DateFrom, CAST(op.Value AS INTEGER)
		INTO _DateFrom, _ParentId
		FROM Objects o
		JOIN ObjectProperties op ON op.ObjectId = o.Id
			AND op.DateFrom <= DateFromIn
		JOIN EntityProperties ep ON ep.Id = op.PropertyId
			AND ep.EntityId = o.EntityId
			AND ep.Code = 'ParentId'
		WHERE o.Id = _ObjectId
			AND (o.DelDate IS NULL OR o.DelDate > DateFromIn)
			AND o.InsDate <= DateFromIn
		ORDER BY op.DateFrom DESC
		LIMIT 1;

		_resultObjectIds := _resultObjectIds || _ObjectId;
		_resultParentIds := _resultParentIds || _ParentId;
		_resultLevels    := _resultLevels || _Level;
		_resultDateFroms := _resultDateFroms || _DateFrom;

		_Level := _Level + 1;
		_ObjectId := _ParentId;
	END LOOP;

	RETURN QUERY(
	SELECT o.ObjectId_ AS "ObjectId", p.ParentId_ AS "ParentId", l.Level_ AS "Level", d.DateFrom_ AS "DateFrom"
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId_ FROM UNNEST(_resultObjectIds) AS A(ObjectId_)) o
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ParentId_ FROM UNNEST(_resultParentIds) AS A(ParentId_)) p
		ON o.RowNum = p.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.Level_ FROM UNNEST(_resultLevels) AS A(Level_)) l
		ON o.RowNum = l.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.DateFrom_ FROM UNNEST(_resultDateFroms) AS A(DateFrom_)) d
		ON o.RowNum = d.RowNum
	ORDER BY l.Level_);

END;

$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;

