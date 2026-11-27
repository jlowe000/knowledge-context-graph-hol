-- Maintained template; use generated sql/install/03_bind_deployment_owner.sql.
-- The generated script embeds the complete canonical read-only schema verifier.
-- Run as the authenticated project owner after importing the matching app.
-- In Worksheet select DECLARE through END; without the final slash, then Run Statement.
-- Bind KCV_APPLICATION_ID and KCV_WORKSPACE; neither value is a credential.
-- This creates no account, credential, profile, graph, grant or application.
DECLARE
 l_app_text VARCHAR2(40):=TRIM(:KCV_APPLICATION_ID);
 l_workspace VARCHAR2(255):=TRIM(:KCV_WORKSPACE);
 l_owner VARCHAR2(128):=SYS_CONTEXT('USERENV','SESSION_USER');
 l_app NUMBER;l_workspace_id NUMBER;l_n NUMBER;l_result PLS_INTEGER;
 l_setup_handle VARCHAR2(128);l_admission PLS_INTEGER;
 l_setup_locked BOOLEAN:=FALSE;l_admission_locked BOOLEAN:=FALSE;
 l_existing kcv_deploy_state%ROWTYPE;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20300,p_message);END IF;
 END;
 PROCEDURE allocate_setup_lock IS PRAGMA AUTONOMOUS_TRANSACTION;BEGIN
  DBMS_LOCK.ALLOCATE_UNIQUE('KCV_DEPLOY_'||l_owner,l_setup_handle);COMMIT;
 END;
 PROCEDURE release_locks IS BEGIN
  IF l_admission_locked THEN l_result:=DBMS_LOCK.RELEASE(l_admission);l_admission_locked:=FALSE;END IF;
  IF l_setup_locked THEN l_result:=DBMS_LOCK.RELEASE(l_setup_handle);l_setup_locked:=FALSE;END IF;
 END;
 PROCEDURE no_active_work IS BEGIN
  SELECT COUNT(*) INTO l_n FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL;
  require(l_n=0,'Complete or recover the active answer or refinement before binding');
  SELECT COUNT(*) INTO l_n FROM kcv_response_runs WHERE status IN('RUNNING','UNCERTAIN');
  require(l_n=0,'Complete or recover the active answer before binding');
  SELECT COUNT(*) INTO l_n FROM kcv_personal_operations WHERE phase IN('BUILDING','READY');
  require(l_n=0,'Complete or recover the personal-context operation before binding');
  SELECT COUNT(*) INTO l_n FROM kcv_context_deletions WHERE status='PENDING';
  require(l_n=0,'Complete or recover the pending context deletion before binding');
  SELECT COUNT(*) INTO l_n FROM kcv_deploy_runs WHERE status='RUNNING';
  require(l_n=0,'Review the incomplete deployment operation before binding');
 END;
BEGIN
 require(l_owner=SYS_CONTEXT('USERENV','CURRENT_USER')
   AND l_owner=SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
   AND l_owner NOT IN('ADMIN','SYS','SYSTEM')
   AND SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL
   AND SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL,
   'Use an authenticated project owner session, outside APEX');
 require(REGEXP_LIKE(l_app_text,'^[0-9]{1,10}$','c'), 'Enter the imported application ID');
 l_app:=TO_NUMBER(l_app_text);require(l_app>0,'Enter the imported application ID');
 require(l_workspace IS NOT NULL AND LENGTH(l_workspace)<=128
   AND REGEXP_LIKE(l_workspace,'^[A-Z][A-Z0-9_]*$','c'),
   'Enter the exact upper-case project workspace name');
 SELECT COUNT(*) INTO l_n FROM apex_applications
  WHERE application_id=l_app AND owner=l_owner AND workspace=l_workspace;
 require(l_n=1,'Application, parsing schema and workspace must match');
 SELECT COUNT(*) INTO l_n FROM apex_workspace_schemas
  WHERE workspace_name=l_workspace AND schema=l_owner;
 require(l_n=1,'Workspace must map to the authenticated project owner');
 l_workspace_id:=apex_util.find_security_group_id(p_workspace=>l_workspace);
 require(l_workspace_id>0,'The project workspace is unavailable');
 SELECT COUNT(*) INTO l_n FROM user_tablespaces WHERE tablespace_name='DATA';
 require(l_n=1,'The prepared DATA tablespace is unavailable');
 allocate_setup_lock;
 l_result:=DBMS_LOCK.REQUEST(l_setup_handle,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_result=0,'Another deployment operation is active');l_setup_locked:=TRUE;
 l_admission:=DBMS_UTILITY.GET_HASH_VALUE('KCV_WRITE_ADMISSION:'||l_owner,1,1073741823);
 l_result:=DBMS_LOCK.REQUEST(id=>l_admission,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
 require(l_result=0,'A write is active; complete it before binding');l_admission_locked:=TRUE;
 -- KCV_FULL_SCHEMA_VERIFICATION
 RAISE_APPLICATION_ERROR(-20300,'Use generated sql/install/03_bind_deployment_owner.sql');
 SELECT COUNT(*) INTO l_n FROM kcv_deploy_state;
 IF l_n>0 THEN
  require(l_n=1,'Deployment binding requires owner review');
  SELECT * INTO l_existing FROM kcv_deploy_state WHERE singleton_id=1;
  require(l_existing.schema_owner=l_owner AND l_existing.workspace_id=l_workspace_id
    AND l_existing.application_id=l_app AND l_existing.network_tablespace='DATA',
    'A different deployment binding already exists; nothing was changed');
  release_locks;
  DBMS_OUTPUT.PUT_LINE('KCV_DEPLOYMENT_BINDING=ALREADY_VERIFIED');
  RETURN;
 END IF;
 no_active_work;
 INSERT INTO kcv_deploy_state(singleton_id,schema_owner,workspace_id,application_id,network_tablespace,maintenance)
  VALUES(1,l_owner,l_workspace_id,l_app,'DATA','ON');
 MERGE INTO kcv_settings t USING(SELECT 'APP_MAINTENANCE' k FROM dual)s ON(t.setting_key=s.k)
  WHEN MATCHED THEN UPDATE SET setting_value='ON'
  WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,'ON');
 COMMIT;
 release_locks;
 DBMS_OUTPUT.PUT_LINE('KCV_DEPLOYMENT_BINDING=READY_FOR_SETUP');
EXCEPTION WHEN OTHERS THEN
 ROLLBACK;release_locks;RAISE;
END;
/
