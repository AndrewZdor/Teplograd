/**
Returns db objects to client app.
*/

CREATE OR REPLACE FUNCTION rcp_getObjects (   -- |Table-many |Table-1 | Lookup |Objects-many | Objects-1 | Tags
    IN HFolderIdIn INTEGER, 		-- | >0        | >0     | 0      | >0          | >0		   | < 0
    IN ParentEntityIdIn INTEGER,   -- Used when HFolderIdIn <=0 (unknown), e.g. for Tags, etc.
    IN ParentObjIdIn INTEGER,      -- | >0        | ignore | ignore | >0          | ignore
	IN EntityIdIn INTEGER,         -- | >0        | >0     | >0     | >0          | >0
	IN ObjIdIn INTEGER,            -- | 0         | >0     | 0, >0  | 0           | >0
	IN ParentValuesIn TEXT   -- | yes       | no     | no	 | no	       | no
	-- If ObjIdIn > 0 - single object returned.
	-- ParentValuesIn: <EntityCode>.Id=<Value><Delimiter>...
)
RETURNS REFCURSOR AS
/*
RETURNS TABLE (
	Id INTEGER,
	AttrStr TEXT,
	HasChildren BOOLEAN,
	Revision INTEGER,
	IsEditable String,
	InsDate Date,
	DelDate DATE ) */

$BODY$

DECLARE

	 result REFCURSOR = 'rcp_getObjects';

	 _SQLState String;
     _ErrorMsg LongString;
     _ProcId INTEGER;

     _TableName String := sys_getTableName(EntityIdIn);
	 _OrderBy LongestString;
     _ParentEntityId INTEGER;
	 _EntityCode String;
	 _EntityType TEXT;
	 _CriteriaSQL LongestString;
     _SQL CITEXT;
     _Conditions LongestString;
     _D String;
     _LastPos INTEGER;
     _CurPos INTEGER;
     _Str LongestString;
     _ParentEntityCode String;
     _ParentEntityType String;
     _ParentTableName String := sys_getTableName(ParentEntityIdIn);
     _ParentId INTEGER;
     _ParentFieldName String;
	 _ChildFieldName String;
     _ChildPropertyId INTEGER;
     _HintedRefEntityId INTEGER;
     _HintedPropertyId INTEGER;
     _HintedValue LongString;
     _HasChildren BOOLEAN;
     _ParentField String;
     _ChildField String;
	 _WorkingDate DATE := sys_getWorkingDate();
	 _ParentFieldValue String;
	 _Condition String;

BEGIN

	-- TODO: Add security handling here!!!

	SELECT e.Type, REPLACE(e.OrderBy, '%t', _TableName::text)
    INTO _EntityType, _OrderBy
    FROM Entities e WHERE e.Id = EntityIdIn ;

    SELECT e.Type INTO _ParentEntityType
    FROM Entities e WHERE e.Id = ParentEntityIdIn;

    SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	/*
	======================================
     From Now - For Tags and History.
     They are not working-date dependant.
	======================================
	*/
	IF HFolderIdIn < 0 THEN

		-- Dynamic SQL for getting ObjectProperties by ObjectId or RowId.
		_SQL :=
		$sql$
			SELECT op.Id,
			COALESCE(op.ObjectId::TEXT, '') || %D% || COALESCE(op.RowId::TEXT, '') || %D% || op.DateFrom || %D% || op.PropertyId::TEXT || %D% || COALESCE(op.Value, '') || %D% AS AttrStr,
			FALSE AS HasChildren, op.Revision,
			sys_ObjectIsEditable(o.EntityId, o.Id, _WorkingDate, op.DateFrom, o.InsDate, o.DelDate) AS IsEditable,
			o.InsDate, (CASE WHEN o.DelDate <= _WorkingDate THEN o.DelDate ELSE NULL::DATE END) AS DelDate
			FROM ObjectProperties op
			JOIN %ParentTable o ON o.Id = op.%RowId
			WHERE op.%RowId = ParentObjIdIn
			%Condition
			ORDER BY op.DateFrom, op.Id
		$sql$ ;

		IF _ParentEntityType = 'SOFT' THEN
			_SQL := REPLACE(_SQL, '%RowId', 'ObjectId');
		ELSIF _ParentEntityType IN ('HARD', 'VIEW') THEN
			_SQL := REPLACE(_SQL, '%RowId', 'RowId');
			_SQL := REPLACE(_SQL, '%ParentTable',
				'(SELECT ParentEntityIdIn AS EntityId, Id, %InsDate, %DelDate FROM %ParentTable WHERE Id = ParentObjIdIn) ');

			IF sys_ifTableHasField(_TableName, 'DelDate') != 0 THEN
				_SQL := REPLACE(_SQL, '%InsDate', 'InsDate');
				_SQL := REPLACE(_SQL, '%DelDate', 'DelDate');
			ELSE
				_SQL := REPLACE(_SQL, '%InsDate', 'NULL::DATE AS InsDate');
				_SQL := REPLACE(_SQL, '%DelDate', 'NULL::DATE AS DelDate');
			END IF;
		END IF;

		IF HFolderIdIn = -1 THEN -- Tags.
			_Condition := 'AND op.PropertyId IN (SELECT Id FROM EntityProperties WHERE EntityId = ParentEntityIdIn AND PropGroup = ''Tags'')' ;
		ELSE -- History.
			_Condition := '';
		END IF;

		_SQL := REPLACE(_SQL, '%ParentTable', _ParentTableName);
		_SQL := REPLACE(_SQL, '%D%', '''' || _D || '''');
		_SQL := REPLACE(_SQL, 'ParentObjIdIn', ParentObjIdIn::TEXT);
		_SQL := REPLACE(_SQL, '%Condition', _Condition);
		_SQL := REPLACE(_SQL, 'ParentEntityIdIn', ParentEntityIdIn::TEXT);
		_SQL := REPLACE(_SQL, '_WorkingDate', '''' || _WorkingDate || '''');

		PERFORM sys_DebugMessage('rcp_getObjects: ' || COALESCE(_SQL, '') );
    	OPEN result FOR EXECUTE _SQL;
		RETURN result;
	END IF;

	/*
	================================================
     From Now - Common for NOT (Tags and History).
	================================================
	*/

	-- Determine HasChildren.
	IF EXISTS(SELECT 1 FROM HierarchyFolders hf -- Current folder.
				JOIN HierarchyFolders hf2 ON hf.HierarchyId = hf2.HierarchyId -- Child folders.
					AND hf2.ParentEntityId = hf.EntityId
					AND hf2.Type = 'TREE'
				WHERE hf.Id = HFolderIdIn) THEN
		_HasChildren := TRUE;
	ELSE
		_HasChildren := FALSE;
	END IF;

	/*
	================================================
     From Now - For Object and Table entities.
	================================================
	*/
	_SQL :=
	$sql$
		SELECT Id, %AttrStr AS AttrStr,
			   _HasChildren AS HasChildren, Revision,
			   sys_ObjectIsEditable(EntityIdIn, Id, _WorkingDate, NULL, %InsDate, %DelDate) AS IsEditable,
			   %InsDate::Date AS InsDate, %DelDate::Date AS DelDate
		FROM %TableName
		WHERE 1=1 %Conditions
		ORDER BY %OrderBy
	$sql$;
	_Conditions := '';

	IF COALESCE(ObjIdIn,0) > 0 THEN -- One object.
		_Conditions := ' AND Id = ObjIdIn';
	ELSE -- Many objects.
		IF _EntityType = 'SOFT' THEN
			_Conditions := ' AND EntityId = EntityIdIn';
		END IF;

    	IF HFolderIdIn > 0 THEN -- non-lookup (conditional) queries.
			_Conditions := _Conditions || sys_getCriteriaSQL(HFolderIdIn, ParentObjIdIn);
            IF COALESCE(ParentValuesIn, '') != '' THEN -- Hierarhic SQL.
				_Conditions := _Conditions || sys_getHierConditions(EntityIdIn, ParentValuesIn);
            END IF;
        END IF;
    END IF;

	-- Final SQL preparation.
	_SQL := REPLACE(_SQL, '_HasChildren', _HasChildren::CITEXT);
	_SQL := REPLACE(_SQL, '%AttrStr', sys_getAttrList(EntityIdIn, NULL));
	IF sys_ifTableHasField(_TableName, 'DelDate') != 0 THEN
		_SQL := REPLACE(_SQL, '%InsDate', 'InsDate');
		_SQL := REPLACE(_SQL, '%DelDate', 'CASE WHEN DelDate <= _WorkingDate THEN DelDate ELSE NULL END');
	ELSE
		_SQL := REPLACE(_SQL, '%InsDate', 'NULL');
		_SQL := REPLACE(_SQL, '%DelDate', 'NULL');
	END IF;
	_SQL := REPLACE(_SQL, '%TableName', _TableName);
	_SQL := REPLACE(_SQL, '%Conditions', _Conditions);
	_SQL := REPLACE(_SQL, '%OrderBy', COALESCE(_OrderBy, '1'));
	_SQL := REPLACE(_SQL, '_WorkingDate', '''' || _WorkingDate || '''');
	_SQL := REPLACE(_SQL, 'EntityIdIn', EntityIdIn::text);
	_SQL := REPLACE(_SQL, 'ObjIdIn', COALESCE(ObjIdIn,0)::text);

	PERFORM sys_DebugMessage('rcp_getObjects: ' || coalesce(_SQL,'') );
    OPEN result FOR EXECUTE _SQL;
    RETURN result;

END;

$BODY$

LANGUAGE 'PLPGSQL'
SECURITY DEFINER
;

-- TEST CASES

--HARD

-- select * from rcp_getObjects(1, NULL, NULL, 10, NULL, NULL); -- Departments
-- select * from rcp_getObjects(0, NULL, NULL, 10, NULL, NULL); -- Departments LookUp
-- select * from rcp_getObjects(1, NULL, NULL, 10, 1, NULL); -- Departments Id = 1
-- select * from rcp_getObjects(0, NULL, NULL, 10, 1, NULL); -- Departments Id = 1 LookUp
-- select * from rcp_getObjects(-1, 18, 1, 35, NULL, NULL); -- Consumers get Tags

-- SOFT

-- select * from rcp_getObjects(1, 12, 36, 13, NULL, NULL); -- Houses
-- select * from rcp_getObjects(0, 12, 36, 13, NULL, NULL); --  Houses LookUp
-- select * from rcp_getObjects(1, 12, 36, 13, 16180, NULL); -- Houses id = 16180
-- select * from rcp_getObjects(0, 12, 36, 13, 16180, NULL); -- Houses id = 16180 LookUp
-- select * from rcp_getObjects(-1, 14, 6185, 35, NULL, NULL); -- Places get Tags
-- select * from rcp_getObjects(-2, 13, 16180, 35, NULL, NULL); -- Houses Id = 1 get History
