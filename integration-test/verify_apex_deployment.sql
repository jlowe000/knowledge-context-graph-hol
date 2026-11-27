-- Native APEX setup-authorisation harness; not an HTTP sign-in or installer test.
-- Run only in the named, idle, isolated owner after the app is trusted-bound.
-- Supply existing native workspace account names; never supply passwords.
-- This script makes no model/network request and performs no setup mutation.
-- It creates and deletes only its own native APEX sessions. Positive install,
-- upgrade/recovery/concurrency and cross-workspace calls need separate rehearsals.
DECLARE
 expected_owner VARCHAR2(128):=UPPER(:KCV_TEST_SCHEMA);
 app_id NUMBER:=:KCV_TEST_APP_ID;
 installer VARCHAR2(255):=:KCV_TEST_INSTALLER;
 learner_a VARCHAR2(255):=:KCV_TEST_LEARNER_A;
 learner_b VARCHAR2(255):=:KCV_TEST_LEARNER_B;
 confirmation VARCHAR2(80):=:KCV_TEST_CONFIRMATION;
 TYPE ids_t IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
 sessions ids_t;session_count PLS_INTEGER:=0;
 before_hash VARCHAR2(64);after_hash VARCHAR2(64);token VARCHAR2(32):=RAWTOHEX(SYS_GUID());
 payload CLOB;items JSON_ARRAY_T;doc JSON_OBJECT_T;keys JSON_KEY_LIST;
 local_credential VARCHAR2(128);n NUMBER;
 account_a NUMBER;account_b NUMBER;account_installer NUMBER;

 PROCEDURE ok(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
 FUNCTION fingerprint RETURN VARCHAR2 IS
  material CLOB;row_json CLOB;cur SYS_REFCURSOR;result VARCHAR2(64);
  PROCEDURE add_rows(p_table VARCHAR2,p_order VARCHAR2) IS BEGIN
   -- Table/order names are fixed below, never supplied through browser/test binds.
   DBMS_LOB.APPEND(material,TO_CLOB(p_table||CHR(10)));
   OPEN cur FOR 'SELECT JSON_OBJECT(* RETURNING CLOB) FROM '||p_table||' ORDER BY '||p_order;
   LOOP FETCH cur INTO row_json;EXIT WHEN cur%NOTFOUND;
    DBMS_LOB.APPEND(material,TO_CLOB(TO_CHAR(DBMS_LOB.GETLENGTH(row_json),'TM9')||':'));
    DBMS_LOB.APPEND(material,row_json);DBMS_LOB.APPEND(material,TO_CLOB(CHR(10)));
   END LOOP;CLOSE cur;
  END;
 BEGIN
  DBMS_LOB.CREATETEMPORARY(material,TRUE);
  add_rows('KCV_DEPLOY_STATE','singleton_id');
  add_rows('KCV_DEPLOY_RUNS','run_id');
  add_rows('KCV_SETTINGS','setting_key');
  add_rows('KCV_PERSONAL_CONTEXTS','context_id');
  add_rows('KCV_SCENARIO_REVISIONS','revision_id');
  add_rows('KCV_CHAT_SESSIONS','session_id');
  add_rows('KCV_CHAT_TURNS','turn_id');
  add_rows('KCV_RESPONSE_RUNS','execution_id');
  add_rows('KCV_RESPONSE_TOOL_CALLS','call_id');
  add_rows('KCV_SCENARIO_OBSERVATIONS','observation_id');
  add_rows('KCV_GRAPH_RUNS','graph_name');
  add_rows('KCV_SOURCES','version_id');
  add_rows('KCV_PASSAGES','passage_id');
  add_rows('KCV_CONTEXTS','snapshot_id');
  result:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(material,DBMS_CRYPTO.HASH_SH256)));
  DBMS_LOB.FREETEMPORARY(material);RETURN result;
 EXCEPTION WHEN OTHERS THEN
  IF cur%ISOPEN THEN CLOSE cur;END IF;
  IF DBMS_LOB.ISTEMPORARY(material)=1 THEN DBMS_LOB.FREETEMPORARY(material);END IF;
  RAISE;
 END;
 PROCEDURE enter_account(p_name VARCHAR2,p_capture BOOLEAN DEFAULT TRUE) IS BEGIN
  apex_session.create_session(p_app_id=>app_id,p_page_id=>901,p_username=>p_name);
  session_count:=session_count+1;
  sessions(session_count):=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
  -- CREATE_SESSION is a privileged harness, not a browser password check.
  IF p_capture THEN kcv_deploy.capture_identity;END IF;
 END;
 PROCEDURE expect_forbidden(p_operation VARCHAR2) IS result CLOB;BEGIN
  BEGIN
   CASE p_operation
    WHEN 'STATUS' THEN result:=kcv_deploy.status_json;
    WHEN 'CREDENTIALS' THEN result:=kcv_deploy.credential_options;
    WHEN 'CONFIGURE_PROFILE' THEN kcv_deploy.configure_profile('NOT_A_CREDENTIAL','invalid','invalid','invalid',token);
    WHEN 'TEST_MODEL' THEN kcv_deploy.test_model(token);
    WHEN 'ENSURE_NETWORK' THEN kcv_deploy.ensure_network(token);
    WHEN 'REGISTER_RUNTIME' THEN kcv_deploy.register_runtime(token);
    WHEN 'LOAD_DATASET' THEN kcv_deploy.load_dataset(token);
    WHEN 'ENABLE_LEARNING' THEN kcv_deploy.enable_learning(token);
    ELSE RAISE_APPLICATION_ERROR(-20992,'Unknown fixture operation');
   END CASE;
   RAISE_APPLICATION_ERROR(-20991,'Unauthorised setup operation was accepted: '||p_operation);
  EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20300 THEN RAISE;END IF;END;
 END;
 PROCEDURE check_learner(p_name VARCHAR2) IS BEGIN
  enter_account(p_name);
  ok(NOT kcv_deploy.is_installer,'App-only learner was treated as installer');
  expect_forbidden('STATUS');expect_forbidden('CREDENTIALS');
  expect_forbidden('CONFIGURE_PROFILE');expect_forbidden('TEST_MODEL');
  expect_forbidden('ENSURE_NETWORK');expect_forbidden('REGISTER_RUNTIME');
  expect_forbidden('LOAD_DATASET');expect_forbidden('ENABLE_LEARNING');
 END;
 PROCEDURE expect_invalid(p_credential VARCHAR2,p_region VARCHAR2,p_compartment VARCHAR2,p_model VARCHAR2) IS BEGIN
  BEGIN
   kcv_deploy.configure_profile(p_credential,p_region,p_compartment,p_model,token);
   RAISE_APPLICATION_ERROR(-20991,'Invalid configuration was accepted');
  EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20301 THEN RAISE;END IF;END;
 END;
 PROCEDURE cleanup IS BEGIN
  FOR i IN REVERSE 1..session_count LOOP apex_session.delete_session(p_session_id=>sessions(i));END LOOP;
  session_count:=0;
 END;
BEGIN
 ok(confirmation='ISOLATED_APEX_DEPLOYMENT_TEST','Explicit isolated-test confirmation required');
 ok(REGEXP_LIKE(expected_owner,'^KCV_V[0-9]+_[0-9]{3}$','c')
   AND SYS_CONTEXT('USERENV','SESSION_USER')=expected_owner
   AND SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=expected_owner,'Use the exact isolated schema owner');
 ok(SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL AND SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL,
   'Start outside an existing APEX session');
 ok(app_id IS NOT NULL AND installer IS NOT NULL AND learner_a IS NOT NULL AND learner_b IS NOT NULL
   AND UPPER(installer)<>UPPER(learner_a) AND UPPER(installer)<>UPPER(learner_b)
   AND UPPER(learner_a)<>UPPER(learner_b),'Three distinct existing workspace accounts are required');
 SELECT COUNT(*) INTO n FROM kcv_deploy_state
  WHERE singleton_id=1 AND schema_owner=expected_owner AND application_id=app_id;
 ok(n=1,'App is not trusted-bound to this owner');
 SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE status='RUNNING';ok(n=0,'Wait for setup to become idle');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL;
 ok(n=0,'Wait for conversations to become idle');
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE status IN ('RUNNING','UNCERTAIN');
 ok(n=0,'Wait for answer operations to finish or be recovered');
 before_hash:=fingerprint;

 enter_account(installer);
 ok(kcv_deploy.is_installer,'Prepared administrator account is not an installer');
 account_installer:=apex_util.get_user_id(p_username=>installer);
 payload:=kcv_deploy.status_json;payload:=kcv_deploy.status_json;
 doc:=JSON_OBJECT_T.parse(payload);keys:=doc.get_keys;
 ok(doc.has('steps') AND doc.has('ready_for_learners'),'Readiness JSON contract missing');
 FOR i IN 1..keys.COUNT LOOP
  ok(keys(i) IN ('target_version','target_checkpoint','maintenance','required_checks_ready',
    'ready_for_learners','steps','collection_counts','dataset_progress','context_search','runs'),
    'Readiness JSON includes an unreviewed top-level field');
 END LOOP;
 items:=JSON_ARRAY_T.parse(kcv_deploy.credential_options);
 FOR i IN 0..items.get_size-1 LOOP
  ok(items.get(i).is_string,'Credential selector returned something other than a name');
  IF local_credential IS NULL THEN local_credential:=items.get_string(i);END IF;
 END LOOP;
 -- Invalid inputs must fail before entering maintenance, journalling or inference.
 expect_invalid('OTHER_OWNER.OCI_USER_CRED','invalid','invalid','invalid');
 expect_invalid('OTHER_OWNER.OCI_USER_CRED','invalid','invalid','invalid');
 IF local_credential IS NOT NULL THEN
  expect_invalid(local_credential,'https://example.invalid','ocid1.compartment.oc1..synthetic','model-name');
  expect_invalid(local_credential,'us-chicago-1','not-an-ocid','model-name');
  expect_invalid(local_credential,'us-chicago-1','ocid1.compartment.oc1..synthetic','https://example.invalid/model');
  expect_invalid(local_credential,'us-chicago-1','ocid1.compartment.oc1..synthetic','ocid1.generativeaimodel.oc1.test');
  DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_INVALID_PROFILE_INPUTS=PASS');
 ELSE DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_INVALID_PROFILE_INPUTS=PENDING_LOCAL_CREDENTIAL');END IF;
 apex_util.set_session_state(p_name=>'KCV_AUTH_ACCOUNT_ID',p_value=>NULL,p_commit=>FALSE);
 ok(NOT kcv_deploy.is_installer,'Installer without the account pin was accepted');
 expect_forbidden('STATUS');expect_forbidden('ENABLE_LEARNING');
 ok(apex_util.get_session_state('KCV_AUTH_ACCOUNT_ID') IS NULL,'A read silently populated the missing identity pin');
 kcv_deploy.capture_identity;ok(kcv_deploy.is_installer,'Post-login callback did not restore valid installer identity');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_ADMIN_READ_AND_PIN=PASS');

 check_learner(learner_a);account_a:=apex_util.get_user_id(p_username=>learner_a);
 check_learner(learner_b);account_b:=apex_util.get_user_id(p_username=>learner_b);
 ok(account_a>0 AND account_b>0 AND account_a<>account_b AND account_a<>account_installer
   AND account_b<>account_installer,'Accounts did not resolve to distinct native identities');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_TWO_LEARNERS_DENIED=PASS');

 enter_account('NOBODY',FALSE);
 ok(NOT kcv_deploy.is_installer AND NOT kcv_deploy.learner_ready,'Anonymous APEX principal was accepted');
 expect_forbidden('STATUS');expect_forbidden('TEST_MODEL');expect_forbidden('ENABLE_LEARNING');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_ANONYMOUS_DENIED=PASS');

 cleanup;after_hash:=fingerprint;
 ok(after_hash=before_hash,'Negative/read-only checks changed protected runtime rows');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_FOURTEEN_TABLE_PRESERVATION=PASS');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_FIXTURE_SESSIONS_REMOVED=PASS');
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_EXTERNAL_MODEL_REQUESTS=0');
 DBMS_OUTPUT.PUT_LINE('PENDING: browser sign-in, cross-workspace calls, clean/upgrade, missing infrastructure, interrupted/concurrent work and successful action replay require separate acceptance');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('KCV_APEX_DEPLOY_SESSION_CLEANUP_ERROR='||TO_CHAR(SQLCODE));
 END;
 RAISE;
END;
/
