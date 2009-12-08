/**
Backtracks tree for CTreeCombo.
*/
CREATE OR REPLACE FUNCTION rcp_getBackTracking (
    IN HierarchyIdIn INTEGER, -- Lookup hierarchy id.
	IN EntityIdIn INTEGER, -- Entitiy of object, being backtracked.
	IN ObjectIdIn INTEGER -- Id of object, being backtracked.
) RETURNS REFCURSOR AS

$BODY$
DECLARE
	result REFCURSOR = 'rcp_getBackTracking' || '.' || uuid_generate_v1();
	_resultEntityIds INT[];
	_resultObjectIds INT[];
	parentNodez RECORD;
    _curLevel INTEGER;
    _curEntityId INTEGER;
    _newEntityId INTEGER;
    _curObjectId INTEGER;
    _newObjectId INTEGER;
    _SQLTemplate LongString;
    _SQL LongString;
    _curEntityType String;
    _curEntityCode String;
    _MetaEntityId INTEGER;
    _MetaEntityCode String;
    --DECLARE _ParentEntityId INTEGER;


BEGIN
--DELETE FROM EventLog;

    SELECT e.Id, e.Code
    INTO _MetaEntityId, _MetaEntityCode
    FROM Entities e
    WHERE e.Code = 'Objects';
--MESSAGE '_MetaEntityId=' || _MetaEntityId TO CLIENT;

	_curLevel := 0;
	_curEntityId := EntityIdIn;
	_curObjectId := ObjectIdIn;

    SELECT e.Code, e.Type
    INTO _curEntityCode, _curEntityType
    FROM Entities e
    WHERE Id = EntityIdIn;

	-- FIXME: Now implemented only for "Id" ParentField.
	_SQLTemplate := 'SELECT %Field FROM %t WHERE Id = %id';

    <<hierarchyLevelsLoop>>
    LOOP
PERFORM sys_debugMessage('LOOPING: _curLevel=' || _curLevel || ', _curEntityId=' || _curEntityId || ', _curObjectId=' || _curObjectId);
--INSERT INTO EventLog(SQLState, SQLErrM, Data) VALUES ('LOOPING:', '_curLevel=' || _curLevel || ', _curEntityId=' || _curEntityId || ', _curObjectId=' || _curObjectId, NULL);
		_resultEntityIds := _resultEntityIds || _curEntityId;
		_resultObjectIds := _resultObjectIds || _curObjectId;

		_curLevel := _curLevel + 1;
        _newObjectId := NULL; -- if parentNodesLoop: has no iterations.

		<<parentNodesLoop>>
		FOR parentNodez IN
			SELECT CASE WHEN e.Type = 'SOFT' AND hf.ChildField = 'ParentId'
				THEN _MetaEntityId ELSE hf.ParentEntityId END AS ParentEntityId,
                e.Type AS ParentEntityType,
                CASE WHEN e.Type = 'SOFT' AND hf.ChildField = 'ParentId'
                THEN _MetaEntityCode ELSE e.Code END AS ParentEntityCode,
                hf.ParentField, hf.ChildField
		    FROM HierarchyFolders hf -- child.
		    JOIN Entities e ON e.Id = hf.ParentEntityId
			WHERE hf.HierarchyId = HierarchyIdIn
		        AND hf.EntityId = _curEntityId
            -- Optimization: group Object parents together - so current object MUST have childField 'ParentId'.
            	AND hf.ParentField IS NOT NULL
            	AND hf.Type = 'TREE'
            GROUP BY ParentEntityId, ParentEntityType, ParentEntityCode, ParentField, ChildField
		LOOP
--MESSAGE '    ParentEntityCode=' || ParentEntityCode || ', ChildField=' || ChildField TO CLIENT;
			IF parentNodez.ParentField != 'Id' THEN
				PERFORM sys_SignalException('InvalidMetadata', '"Id"-parentField ONLY supported in lookup hierarchies.');
			END IF;

			_newEntityId := parentNodez.ParentEntityId;

			IF _curEntityType = 'SOFT' THEN
				_newObjectId := sys_getAttrValue(NULL, _curObjectId, parentNodez.ChildField, sys_getWorkingDate())::INT;
    			IF _newObjectId IS NOT NULL AND _newEntityId = _MetaEntityId THEN
					SELECT o.EntityId INTO _newEntityId
					FROM Objects o 	WHERE o.Id = _newObjectId;
                END IF;

			ELSEIF _curEntityType IN ('HARD', 'VIEW') THEN
--PERFORM sys_debugMessage('=============> _curEntityCode=' || COALESCE(_curEntityCode, '<NULL>'));
--PERFORM sys_debugMessage('=============> _curObjectId=' || COALESCE(_curObjectId::TEXT, '<NULL>'));
--PERFORM sys_debugMessage('=============> _parentNodez.ChildField=' || COALESCE(parentNodez.ChildField, '<NULL>'));
				_SQL := REPLACE(_SQLTemplate, '%t', _curEntityCode);
				_SQL := REPLACE(_SQL, '%id', _curObjectId::TEXT);
				_SQL := REPLACE(_SQL, '%Field', COALESCE(parentNodez.ChildField, ''));
--MESSAGE '    ' + _SQL TO CLIENT;

--INSERT INTO EventLog(SQLState, SQLErrM, Data) VALUES ('EXECUTE:', _SQL, _newObjectId::TEXT);
				EXECUTE _SQL INTO STRICT _newObjectId;
			END IF;

			IF _newObjectId IS NOT NULL THEN
                _curObjectId := _newObjectId;
                _curEntityId := _newEntityId;
                _curEntityCode := parentNodez.ParentEntityCode;
                _curEntityType := parentNodez.ParentEntityType;

    			EXIT parentNodesLoop;
    		END IF;
		END LOOP parentNodesLoop;

--MESSAGE 'Out of parentNodesLoop: _newObjectId=' || _newObjectId TO CLIENT;
		IF _newObjectId IS NULL THEN
--MESSAGE 'Leaving hierarchyLevelsLoop;' TO CLIENT;
    			EXIT hierarchyLevelsLoop;
    	END IF;
        _curObjectId := _newObjectId;
     END LOOP hierarchyLevelsLoop;

	-- Retrieving final resultset.
	OPEN result FOR
	SELECT e.EntityId, o.ObjectId
	FROM (SELECT ROW_NUMBER() OVER() AS RowNum, A.EntityId FROM UNNEST(_resultEntityIds) AS A(EntityId)) e
	JOIN (SELECT ROW_NUMBER() OVER() AS RowNum, A.ObjectId FROM UNNEST(_resultObjectIds) AS A(ObjectId)) o
		ON e.RowNum = o.RowNum
	ORDER BY e.RowNum DESC;

RETURN result;
END;
$BODY$

LANGUAGE PLPGSQL
SECURITY DEFINER;

