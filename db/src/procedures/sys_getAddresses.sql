/**
 * Return Table of Addresses for all heat objects (Houses and Places).
 */
CREATE OR REPLACE FUNCTION sys_getAddresses(
	IN DateIn DATE DEFAULT sys_getWorkingDate()
)
RETURNS TABLE (
	ObjectId INTEGER,
	Address TEXT,
	PlaceCode TEXT
) AS

$BODY$

    -- Houses.
    SELECT o.Id AS ObjectId,
        st.code || ' ' || s.name || ', ' || COALESCE(o.Code, '') AS Address, '' AS PlaceCode
    FROM Objects o -- Houses.
    JOIN Entities e ON e.Id = o.EntityId
    LEFT JOIN Streets s ON s.Id = ( --sys_getAttrValue(NULL, o.Id, 'StreetId', $1)::INT
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = o.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Houses' AND ep.Code = 'StreetId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    LEFT JOIN StreetTypes st ON st.Id = s.StreetTypeId
    WHERE e.Code = 'Houses'

    -- Places
    UNION ALL
    SELECT o.Id AS ObjectId,
        st.code || ' ' || s.name || ', ' || COALESCE(h.Code, '') AS Address,
        COALESCE(o.Name, '') || ' ' || COALESCE(o.Code, '') AS PlaceCode
    FROM Objects o -- Places.
    JOIN Entities e ON e.Id = o.EntityId
    JOIN Objects h ON h.Id = ( --sys_getAttrValue(NULL, o.Id, 'HouseId', $1)::INT -- Houses.
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = o.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Places' AND ep.Code = 'HouseId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    JOIN Streets s ON s.Id = ( --sys_getAttrValue(NULL, h.id, 'StreetId', $1)::INT
        SELECT op.Value::INT
        FROM ObjectProperties op
        WHERE op.ObjectId = h.Id
            AND op.DateFrom <= $1
            AND op.PropertyId = (SELECT ep.Id FROM EntityProperties ep, Entities e WHERE e.Id = ep.EntityId AND e.Code = 'Houses' AND ep.Code = 'StreetId')
        ORDER BY op.DateFrom DESC LIMIT 1)
    JOIN StreetTypes st ON st.Id = s.StreetTypeId
    WHERE e.Code = 'Places';

$BODY$

LANGUAGE SQL
SECURITY DEFINER
COST 10;
