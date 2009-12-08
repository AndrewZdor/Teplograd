/**
Returns criteria for connecting two tied Entities based on hierarchies.
For object entities SELECTed from rcp_getFolders only.
*/
CREATE OR REPLACE FUNCTION sys_getCriteriaSQL(
	IN HFolderIdIn INTEGER, -- Id of child Hierarchy folder.
	IN ParentObjIdIn INTEGER
)
RETURNS TEXT AS

$BODY$
DECLARE
     _Result TEXT;
	 _ParentField TEXT;
	 _ChildField TEXT;
	 _CriteriaSQL TEXT;
	 _ParentEntityType TEXT;
	 _ChildEntityType TEXT;
	 _ChildTableName TEXT;
	 _ChildPropertyId INTEGER;
	 _ParentEntityId INTEGER;
	 _ChildEntityId INTEGER;
	 _ParentTableName TEXT;
	 _D String;
	 _ParentFieldValue TEXT;
	 _ChildFieldValue TEXT;
	 _PropertyId INTEGER;
	 _SQL TEXT;
	 _WorkingDate DATE := sys_getWorkingDate();

BEGIN
	SELECT Value INTO _D FROM sys_getPrefValue('System.SQL.Delimiter');

	SELECT hf.ParentField, hf.ChildField, hf.CriteriaSQL, pe.Type, e.Type,
		sys_getTableName(hf.ParentEntityId) AS ParentTableName,
		sys_getTableName(hf.EntityId) AS ChildTableName,
		hf.ParentEntityId, hf.EntityId
	INTO _ParentField, _ChildField, _CriteriaSQL, _ParentEntityType, _ChildEntityType,
		_ParentTableName, _ChildTableName, _ParentEntityId, _ChildEntityId
	FROM HierarchyFolders hf
	JOIN Entities e ON e.Id = hf.EntityId
	JOIN Entities pe ON pe.Id = hf.ParentEntityId
	WHERE hf.Id = HFolderIdIn;

	-- Default simple criteria.
	IF _CriteriaSQL IS NULL AND _ParentField IS NOT NULL THEN
		_CriteriaSQL := '%ParentField = %ChildField';
	END IF;

	-- Simple case.
	IF _CriteriaSQL IS NULL THEN -- No criteria.
		_Result := ' AND 1 = 1 ';

	ELSEIF _ParentField IS NULL AND _ChildField IS NULL THEN -- Simple Criteria.
		_Result := ' AND ' || _CriteriaSQL;

	ELSE -- Parent field value estimation.

		_ParentFieldValue := sys_getAttrValue(_ParentEntityId, ParentObjIdIn, _ParentField, _WorkingDate);

		IF _ChildField IS NOT NULL THEN-- Child field value estimation.
			IF _ChildEntityType IN ('HARD', 'VIEW') THEN -- Table Child Entities.
				_ChildFieldValue := _ChildTableName || '.' || _ChildField;

			ELSEIF _ChildEntityType = 'SOFT' THEN -- Object Child Entities.
				SELECT Id
				INTO _ChildPropertyId
				FROM EntityProperties
				WHERE EntityId = _ChildEntityId
					AND Code = _ChildField;

				-- Validate EntityProperties table content.
				IF _ChildPropertyId IS NULL THEN
					PERFORM sys_SignalException('InvalidMetadata', 'HierarchyFolders.ChildField' || '_HFolderId=' || HFolderIdIn || 'calculating _ChildPropertyId');
				END IF;

				-- _ParentFieldValue := _ParentTableName || '.' || _ParentField;
				-- FIXME: works for integer references only!!!
				_ChildFieldValue := $sql$
					(SELECT op.Value
					 FROM ObjectProperties op
					 WHERE op.ObjectId = Objects.Id
					   AND op.PropertyId = %_ChildPropertyId
					   AND op.DateFrom <= %_WorkingDate
					 ORDER BY op.DateFrom
					 DESC LIMIT 1)::INTEGER
				$sql$;
			END IF;
		END IF;

		_Result := _CriteriaSQL;
		_Result := REPLACE(_Result, '%ParentField', _ParentFieldValue);
		_Result := REPLACE(_Result, '%ChildField', COALESCE(_ChildFieldValue, ''));
		_Result := REPLACE(_Result, '%_ChildPropertyId', COALESCE(_ChildPropertyId::TEXT,''));
		_Result := REPLACE(_Result, '%_WorkingDate', '''' || _WorkingDate || '''');
		_Result := ' AND ' || _Result || E'\n';
	END IF;

	IF sys_ifTableHasField(_ChildTableName, 'DelDate') != 0 THEN
		_Result := _Result || ' AND (DelDate IS NULL OR DelDate > sys_getWorkingDate()) '
			|| E' AND InsDate <= sys_getWorkingDate() \n';
	END IF;

	PERFORM sys_DebugMessage('sys_getCriteriaSQL (HFolderIdIn=' || HFolderIdIn || ', ParentObjIdIn=' || ParentObjIdIn || E')\n'
		|| 'Result: ' || COALESCE(_Result, '<NULL>'));
	RETURN _Result;
END;
$BODY$

LANGUAGE PLPGSQL
IMMUTABLE
SECURITY DEFINER;