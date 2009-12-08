/**
Total parent objects table on given date.
FIXME: Performance is HIGHLY INEFFECTIVE! OPTIMIZE!!!
*/

CREATE OR REPLACE FUNCTION sys_getParentObjectsAll(
	DateFromIn DATE
)
RETURNS TABLE (
	ObjectId INTEGER,
	ParentId INTEGER,
	Level INTEGER
) AS

$BODY$
DECLARE
	_resultObjectIds INTEGER[];
	_resultParentIds INTEGER[];
	_resultLevels INTEGER[];

	Objz RECORD;
	t RECORD;

BEGIN

	FOR Objz IN
		SELECT o.Id AS ObjectIdCur
		FROM Objects o
		WHERE (o.DelDate IS NULL OR o.DelDate > DateFromIn)
		  AND o.InsDate <= DateFromIn
		ORDER BY o.Id
	LOOP
		FOR t IN
			SELECT Objz.ObjectIdCur, s.ObjectId, s.Level
			FROM sys_getParentObjects(Objz.ObjectIdCur, DateFromIn) s
		LOOP
			_resultObjectIds := _resultObjectIds || Objz.ObjectIdCur;
			_resultParentIds := _resultParentIds || t.ObjectId;
			_resultLevels    := _resultLevels || t.Level;
		END LOOP;
	END LOOP;

	RETURN QUERY(
	SELECT o.ObjectId_ AS "ObjectId", p.ParentId_ AS "ParentId", l.Level_ AS "Level"
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId_ FROM UNNEST(_resultObjectIds) AS A(ObjectId_)) o
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ParentId_ FROM UNNEST(_resultParentIds) AS A(ParentId_)) p
		ON o.RowNum = p.RowNum
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.Level_ FROM UNNEST(_resultLevels) AS A(Level_)) l
		ON o.RowNum = l.RowNum
	 );

END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;