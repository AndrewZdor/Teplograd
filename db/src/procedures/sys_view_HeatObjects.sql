/**
Places and Houses for which heat calculations take place.
*/
CREATE OR REPLACE FUNCTION sys_view_HeatObjects()
RETURNS TABLE (
    ObjectId INT,
	EntityId INT
) AS

$BODY$

SELECT o.Id, o.EntityId
FROM Objects o -- Places and Houses.
JOIN Entities e ON e.Id = o.EntityId
WHERE (e.Code = 'Places'
        OR (e.Code = 'Houses' AND NOT EXISTS -- Don't show houses with places.
            (SELECT 1 FROM Objects p -- Places.
            WHERE o.EntityId = (SELECT Id FROM Entities WHERE Code = 'Places')
                AND o.Id = (SELECT op.Value::INT FROM ObjectProperties op
                            WHERE op.ObjectId = p.Id
                               AND op.DateFrom <= sys_getWorkingDate()
                               AND op.PropertyId = sys_getPropId('Places', 'HouseId')
                            ORDER BY op.DateFrom DESC LIMIT 1)
       ) ) )
    AND (o.DelDate IS NULL OR o.DelDate > sys_getWorkingDate() )
    AND (o.InsDate IS NULL OR o.InsDate <= sys_getWorkingDate() );

$BODY$

LANGUAGE SQL
SECURITY DEFINER;