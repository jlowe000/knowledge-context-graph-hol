-- DESTRUCTIVE: ADMIN, only after 91_teardown_runtime.sql printed PASS.
-- Removes the dedicated project app/workspace/accounts, ORDS mapping and schema.
-- No JAVAVM, OCI instance, external API key or unrelated schema is removed.
DECLARE
 n NUMBER; done VARCHAR2(64);
BEGIN
 IF USER<>'ADMIN' THEN RAISE_APPLICATION_ERROR(-20210,'Run as ADMIN'); END IF;
 EXECUTE IMMEDIATE 'SELECT setting_value FROM KCV_LAB.KCV_SETTINGS WHERE setting_key=''TEARDOWN_RUNTIME'''
  INTO done;
 IF done<>'COMPLETE' THEN RAISE_APPLICATION_ERROR(-20211,'Runtime teardown did not complete'); END IF;
 SELECT COUNT(*) INTO n FROM apex_workspace_schemas
  WHERE workspace_name='KCV_KNOWLEDGE' AND schema<>'KCV_LAB';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20212,'Workspace contains another schema; inspect before deletion'); END IF;
 SELECT COUNT(*) INTO n FROM apex_applications WHERE workspace='KCV_KNOWLEDGE' AND owner<>'KCV_LAB';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20213,'Workspace contains an unrelated application'); END IF;
 FOR r IN (SELECT application_id FROM apex_applications WHERE workspace='KCV_KNOWLEDGE' AND owner='KCV_LAB') LOOP
  APEX_INSTANCE_ADMIN.REMOVE_APPLICATION(p_application_id=>r.application_id);
 END LOOP;
 SELECT COUNT(*) INTO n FROM apex_workspaces WHERE workspace='KCV_KNOWLEDGE';
 IF n=1 THEN APEX_INSTANCE_ADMIN.REMOVE_WORKSPACE(p_workspace=>'KCV_KNOWLEDGE',p_drop_users=>'N',p_drop_tablespaces=>'N'); END IF;
 ORDS_ADMIN.DROP_REST_FOR_SCHEMA(p_schema=>'KCV_LAB');
 EXECUTE IMMEDIATE 'DROP USER KCV_LAB CASCADE';
 DBMS_OUTPUT.PUT_LINE('PASS: project APEX application/workspace/accounts, REST mapping and lab owner removed; JAVAVM retained');
END;
/
