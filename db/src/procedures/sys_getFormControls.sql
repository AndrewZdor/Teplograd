/**
Gets list of controls and their values for given form (Entity) id.
For negative FormIdIn returns virtual forms - attributes.
Processes Object entities as well.';
*/
CREATE OR REPLACE FUNCTION sys_getFormControls (
    IN FormIdIn INTEGER
)
RETURNS TABLE (
	Id INTEGER,
	EntityId INTEGER,
	FieldName TEXT,
	Label TEXT,
	IsEditable TEXT,
	Type TEXT,
	Length INTEGER,
	Mandatory BOOLEAN,
	RefEntityId INTEGER,
	Style TEXT,
	Misc TEXT,
	Rem TEXT,
	OrderNo INTEGER,
	doNumSort BOOLEAN,
	LookupHierarchyId INTEGER
) AS

$BODY$
DECLARE
	 _SQLState String;
     _ErrorMsg LongString;
     _ProcId INTEGER;

	 EntityTypeTemp String;
	 EntityCodeTemp String;
	 _ObjectsEntityId INTEGER;
	 _UniqueFields LongString;

BEGIN
	-- Positive FormId for Real Forms.
	IF SIGN(FormIdIn) >= 0 THEN
		RETURN;

	-- Negative FormId for Virtual Forms (i.e. EntityId).
	ELSE
		SELECT e.Code, e.Type, e.UniqueFields
		INTO EntityCodeTemp, EntityTypeTemp, _UniqueFields
		FROM Entities e
		WHERE e.Id = -FormIdIn;

		SELECT Id INTO _ObjectsEntityId
		FROM Entities WHERE Code = 'Objects';

		IF EntityCodeTemp = 'ObjectProperties' THEN -- Tags and History forms.
			RETURN QUERY(
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'ObjectId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.ObjectId') AS "Label",
					sys_getDictionaryValue('GUI.Editor.ThisColumnCannotBeEdited') AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", _ObjectsEntityId AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 10 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'RowId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.RowId') AS "Label",
					sys_getDictionaryValue('GUI.Editor.ThisColumnCannotBeEdited') AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", -1 AS "RefEntityId", NULL AS "Style", -- -1 as Reference to any Entity.
					NULL AS "Misc", NULL AS "Rem", 20 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'DateFrom' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.DateFrom') AS "Label",
					NULL AS "IsEditable", 'DATE' AS "Type", 128 AS "Length",
					TRUE AS "Mandatory", NULL AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 30 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'PropertyId' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.PropertyId') AS "Label",
					NULL AS "IsEditable", 'INTEGER' AS "Type", 128 AS "Length",
					TRUE AS "Mandatory", e.Id AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 40 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				FROM Entities e
				WHERE Code = 'EntityProperties'
				UNION ALL
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", 'Value' AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.Value') AS "Label",
					NULL AS "IsEditable", 'NVARCHAR' AS "Type", 128 AS "Length",
					FALSE AS "Mandatory", NULL AS "RefEntityId", NULL AS "Style",
				    NULL AS "Misc", NULL AS "Rem", 50 AS "OrderNo", FALSE AS "doNumSort", NULL::INT AS "LookupHierarchyId"
				ORDER BY "OrderNo"
			);

		ELSEIF EntityTypeTemp = 'SOFT' THEN -- Property-based forms.
			RETURN QUERY(
				-- Code, Name, Rem.
				SELECT 0 AS "Id", -FormIdIn AS "EntityId", t.fn AS "FieldName",
					sys_getDictionaryValue('Table.' || EntityCodeTemp || '.' || t.fn) AS "Label",
					NULL AS "IsEditable", 'NVARCHAR'::TEXT AS "Type", NULL::INT AS "Length",
					CASE t.fn WHEN 'Code' THEN TRUE ELSE FALSE END AS "Mandatory",
					NULL::INTEGER AS "RefEntityId", NULL AS "Style",
					NULL AS "Misc", NULL::TEXT AS "Rem",
					CASE t.fn WHEN 'Code' THEN -10 WHEN 'Name' THEN -9 ELSE 9999 END AS "OrderNo",
					COALESCE((SELECT ep.doNumSort FROM EntityProperties ep WHERE ep.EntityId = -FormIdIn AND ep.Code = t.fn), FALSE) AS "doNumSort",
					NULL::INT AS "LookupHierarchyId"
				FROM (VALUES ('Code'), ('Name'), ('Rem')) t(fn)
				UNION ALL
				-- Main query.
				SELECT ep.Id, ep.EntityId AS "EntityId", ep.Code AS "FieldName",
				    sys_getDictionaryValue('Table.' || EntityCodeTemp || '.' || ep.Code) AS "Label",
				    NULL AS "IsEditable", ep.DataType AS "Type", ep.DataLength AS "Length",
				    CASE WHEN uf.row_value IS NULL THEN ep.Mandatory ELSE TRUE END AS "Mandatory",
				    ep.RefEntityId AS "RefEntityId", NULL AS "Style", NULL AS "Misc", ep.Rem, ep.OrderNo,
				    COALESCE(ep.doNumSort, FALSE) AS "doNumSort",
				    COALESCE(ep.LookupHierarchyId, re.LookupHierarchyId) AS "LookupHierarchyId"
			    FROM EntityProperties ep
			    LEFT JOIN Entities re ON re.Id = ep.RefEntityId
			    LEFT JOIN regexp_split_to_table(_UniqueFields, ',') uf(row_value) ON uf.row_value = ep.Code
			    WHERE ep.EntityId = -FormIdIn
			    	AND ep.PropGroup IS NULL
			    	AND LOWER(ep.Code) NOT IN ('code', 'name', 'rem')
				ORDER BY "OrderNo"
			);

		ELSEIF EntityTypeTemp IN ('HARD', 'VIEW') THEN -- Table-based forms.
			RETURN QUERY(
				SELECT
					CAST(-(t.Id * 1000 + sc.ordinal_position) AS INTEGER) AS "Id", -- ControlId = -(EntityId * 1000 + ColNo)
					t.Id AS "EntityId",
					quote_ident(sc.column_name)::TEXT AS "FieldName",
					sys_getDictionaryValue('Table.' || t.Code || '.' || sc.column_name)::text AS "Label",
					COALESCE(ep.Editable, CASE WHEN ccu.constraint_name like 'pk_%' THEN 'in_primary_key' END)::text AS "IsEditable",
					COALESCE(tm.JavaSQLType, 'UNKNOWN:' || sc.udt_name)::TEXT AS "Type",
					sc.character_maximum_length::INTEGER AS "Length",
					COALESCE(ep.Mandatory, CAST(CASE WHEN sc.is_nullable = 'NO' THEN 1 ELSE 0 END AS boolean)) AS "Mandatory",
					COALESCE(ep.RefEntityId, t2.Id) AS "RefEntityId",
					NULL::TEXT AS "Style",
					NULL::TEXT AS "Misc",
					sys_getDictionaryValue('Table.' || t.Code || '.' || sc.column_name, 'rem')::TEXT AS "Rem",
					COALESCE(ep.OrderNo, sc.ordinal_position) AS "OrderNo",
					COALESCE(ep.doNumSort, FALSE) AS "doNumSort",
					COALESCE(ep.LookupHierarchyId, re.LookupHierarchyId) AS "LookupHierarchyId"
				FROM Entities t
				JOIN information_schema.columns sc ON sc.table_schema = 'public'
					AND LOWER(t.Code) = sc.table_name
				LEFT JOIN TypeMapping tm ON tm.SQLType = sc.udt_name
				LEFT JOIN information_schema.constraint_column_usage ccu
					ON ccu.table_schema = 'public'
					AND sc.table_name = ccu.table_name AND sc.column_name = ccu.column_name
				LEFT JOIN EntityProperties ep ON ep.EntityId = t.Id AND LOWER(ep.Code) = LOWER(sc.column_name)
				LEFT JOIN (select tname.relname as table_name, col.attname as column_name, ftname.relname as ftable_name
				           from pg_constraint con
				           join pg_class tname  on tname.oid  = con.conrelid
				           join pg_class ftname on ftname.oid = con.confrelid
				           join pg_attribute col  on col.attnum  = any(con.conkey)  and col.attrelid  = con.conrelid
				           where con.contype = 'f'
				           ) sfc ON sc.table_name = sfc.table_name AND sc.column_name = sfc.column_name
				LEFT JOIN Entities t2 ON LOWER(t2.Code) = sfc.ftable_name
				LEFT JOIN Entities re ON LOWER(re.Code) = LOWER(t2.Code)
				WHERE t.Id = -FormIdIn
				--AND Creator = sys_getTableOwner()
		          AND sys_isSystemField(sc.column_name) = FALSE
				ORDER BY "OrderNo", "Id"
			);

		END IF;
	END IF;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;