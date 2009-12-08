/**
Returns All possible parents (by service) with levels for Places and Houses.
*/
CREATE OR REPLACE FUNCTION sys_view_HeatObjectParents()
RETURNS TABLE (
    ServiceId INT,
	ObjectId INT,
	ParentId INT,
	Level INT,
	Tie TEXT
) AS

$BODY$
DECLARE
    _WD DATE := sys_getWorkingDate();

BEGIN
	EXECUTE 'DROP TABLE IF EXISTS tmpParents0';
	CREATE TEMPORARY TABLE tmpParents0 ("ObjectId" INT PRIMARY KEY); -- Lower level nodes.
	EXECUTE 'DROP TABLE IF EXISTS tmpParents1';
	CREATE TEMPORARY TABLE tmpParents1  ("ServiceId" INT, "ParentId" INT, "ObjectId" INT, "Tie" TEXT);

	-- Fill initial obejcts.
    INSERT INTO tmpParents0("ObjectId")
    SELECT o.ObjectId
	FROM sys_view_HeatObjects() o; -- Places and Houses.

	-- Now Fill temp table.
	INSERT INTO tmpParents1("ServiceId", "ParentId", "ObjectId", "Tie")
	SELECT s.Id, ttt."ParentId", ttt.ObjectId, ttt."Tie"
	FROM (
        SELECT DISTINCT ON (op.ObjectId, ep.Code)
            op.ObjectId, ep.Code AS "Tie", op.Value::INT AS "ParentId"
		FROM Objects o
		JOIN ObjectProperties op ON op.ObjectId = o.Id
	    JOIN EntityProperties ep ON ep.Id = op.PropertyId
	        AND ep.Code LIKE '%ParentId'
	    WHERE op.DateFrom <= _WD
	    ORDER BY op.ObjectId, ep.Code, op.DateFrom DESC
	    )  AS ttt
    LEFT JOIN Services s ON 'Svc' || s.Id || 'ParentId' = ttt."Tie"
    WHERE COALESCE(s.Ignore, FALSE) != TRUE;

    -- Correct records with null ServiceId for all services.
    INSERT INTO tmpParents1("ServiceId", "ParentId", "ObjectId", "Tie")
    SELECT DISTINCT s.Id, t1."ParentId", t1."ObjectId", '?'
    FROM tmpParents1 t1
    CROSS JOIN Services s
    WHERE t1."ServiceId" IS NULL
        AND COALESCE(s.Ignore, FALSE) != TRUE
    ;
    DELETE FROM tmpParents1 t1
    WHERE t1."ServiceId" IS NULL;

    -- Insert Objects without parents for completeness.
    INSERT INTO tmpParents1("ServiceId", "ParentId", "ObjectId", "Tie")
    SELECT t1."ServiceId", NULL::INT, t1."ParentId", NULL
    FROM tmpParents1 t1 -- Objects.
    WHERE NOT EXISTS (
        SELECT 1 FROM tmpParents1 t2
        WHERE t2."ServiceId" = t1."ServiceId"
            AND t2."ObjectId" = t1."ParentId");


    -- TODO:Insert 'Places without service' as houses children.
    INSERT INTO tmpParents1("ServiceId", "ObjectId", "Tie", "ParentId")
    SELECT s.Id, o.Id, 'HouseId'
        (SELECT op.Value::INT FROM ObjectProperties op
        WHERE op.ObjectId = o.Id AND op.DateFrom <= _WD
            AND op.PropertyId = sys_getPropId('Places', 'HouseId')
        ORDER BY op.DateFrom DESC LIMIT 1) AS HouseId
    FROM Objects o -- Places and Houses.
    JOIN Entities e ON e.Id = o.EntityId
    CROSS JOIN Services s
    WHERE e.Code = 'Places'
        AND (o.DelDate IS NULL OR o.DelDate > _WD)
        AND (o.InsDate IS NULL OR o.InsDate <= _WD)
        AND NOT EXISTS (SELECT 1 FROM tmpParents1 t1 WHERE t1."ObjectId" = o.Id AND t1."ServiceId" = s.Id)
        AND COALESCE(s.Ignore, FALSE) != TRUE;

    -- Final recursive query.
    RETURN QUERY (
        WITH RECURSIVE r AS (
	        -- Initial part - lower-level objects.
	        SELECT t1."ObjectId" AS ObjectId0, t1."ServiceId", t1."ObjectId", t1."ParentId", 1 AS "Level", t1."Tie"
	        FROM tmpParents1 t1
	        WHERE EXISTS (SELECT 1 FROM tmpParents0 t0 WHERE t0."ObjectId" = t1."ObjectId")
	        UNION ALL
	        -- Recursive part.
	        SELECT r.ObjectId0, t1."ServiceId", t1."ObjectId", t1."ParentId", r."Level" + 1 AS "Level", t1."Tie"
	        FROM tmpParents1 t1
	        JOIN r ON r."ParentId" = t1."ObjectId" AND r."ServiceId" = t1."ServiceId"
        )
        -- Original objects.
        SELECT s.Id AS "ServiceId", t0."ObjectId", t0."ObjectId" AS "ParentId", 0 AS "Level", 'Self' AS "Tie"
        FROM tmpParents0 t0, Services s
        WHERE COALESCE(s.Ignore, FALSE) != TRUE
        UNION ALL
        -- Objects from the tree.
        SELECT r."ServiceId", r.ObjectId0 AS "ObjectId", r."ParentId", r."Level", r."Tie"
        FROM r
    );
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;