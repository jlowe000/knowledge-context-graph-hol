-- Read-only native authorization check. Run as the actual isolated project owner,
-- directly or through its approved database proxy; no APEX session is attached.
-- Bind KCV_TEST_SCHEMA and KCV_TEST_APP_ID to that installed test application.
-- Does not create credentials, change setup/maintenance, call a model or load data.
-- A successful test is owner authorization, not application/runtime readiness.
SET SERVEROUTPUT ON
DECLARE
 expected_owner VARCHAR2(128):=UPPER(TRIM(:KCV_TEST_SCHEMA));
 expected_app NUMBER:=:KCV_TEST_APP_ID;
 bound_app NUMBER;n NUMBER;before_runs NUMBER;result CLOB;j JSON_OBJECT_T;
 PROCEDURE require(ok BOOLEAN,message VARCHAR2) IS BEGIN
  IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,message);END IF;
 END;
BEGIN
 require(REGEXP_LIKE(expected_owner,'^KCV_V[0-9]+_[0-9]+$','c')
   AND SYS_CONTEXT('USERENV','SESSION_USER')=expected_owner
   AND SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=expected_owner,
   'Use the explicitly selected isolated project owner; changing CURRENT_SCHEMA is insufficient');
 require(SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL AND SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL,
   'Detach the native test APEX session before the owner-path check');
 SELECT application_id INTO bound_app FROM kcv_deploy_state WHERE singleton_id=1 AND schema_owner=expected_owner;
 require(bound_app=expected_app,'The test application must be the trusted bound installation');
 SELECT COUNT(*) INTO before_runs FROM kcv_deploy_runs;
 require(kcv_deploy.is_installer,'The authenticated owner was not authorized for setup');
 result:=kcv_deploy.status_json;j:=JSON_OBJECT_T.parse(result);
 require(j.has('steps') AND j.has('ready_for_learners'),'Owner setup status is incomplete');
 -- Authorization must succeed before bounded input validation. The short token
 -- is rejected before a journal row, maintenance change or native RDF operation.
 BEGIN
  kcv_deploy.ensure_network('short');
  RAISE_APPLICATION_ERROR(-20991,'An invalid owner action token was accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20301 THEN RAISE;END IF;END;
 -- The authentication callback does not acquire an owner-session shortcut.
 BEGIN
  kcv_deploy.capture_identity;
  RAISE_APPLICATION_ERROR(-20991,'Post-login identity capture accepted a database owner session');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20300 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_deploy_runs;
 require(n=before_runs,'Read-only owner checks or invalid input created a setup request');
 DBMS_OUTPUT.PUT_LINE('PASS: authenticated owner setup access and application binding');
 DBMS_OUTPUT.PUT_LINE('PASS: invalid owner token rejected before mutation; post-login callback remains APEX-only');
 DBMS_OUTPUT.PUT_LINE('PASS: owner status and rejected actions created no setup request');
END;
/
