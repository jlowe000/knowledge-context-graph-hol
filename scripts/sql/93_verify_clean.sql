-- ADMIN: clean project checkpoint. Does not claim unrelated schemas were removed.
DECLARE
 n NUMBER; s VARCHAR2(30);
BEGIN
 SELECT COUNT(*) INTO n FROM dba_users WHERE username='KCV_LAB';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20220,'KCV_LAB still exists'); END IF;
 SELECT COUNT(*) INTO n FROM dba_objects WHERE owner='KCV_LAB' OR object_name LIKE 'KCV\_%' ESCAPE '\';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20221,'Project objects still exist'); END IF;
 SELECT COUNT(*) INTO n FROM apex_workspaces WHERE workspace='KCV_KNOWLEDGE';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20222,'Project workspace still exists'); END IF;
 SELECT COUNT(*) INTO n FROM apex_applications WHERE owner='KCV_LAB' OR workspace='KCV_KNOWLEDGE';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20223,'Project application still exists'); END IF;
 SELECT COUNT(*) INTO n FROM dba_cloud_ai_profiles WHERE owner='KCV_LAB';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20224,'Project model profile still exists'); END IF;
 SELECT status INTO s FROM dba_registry WHERE comp_id='JAVAVM';
 IF s<>'VALID' THEN RAISE_APPLICATION_ERROR(-20225,'JAVAVM was not retained as VALID'); END IF;
 DBMS_OUTPUT.PUT_LINE('PASS: clean project checkpoint; lab schema, objects, app, workspace and model profile absent; JAVAVM remains VALID');
END;
/
