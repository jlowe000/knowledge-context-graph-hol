-- Native negative authorization check. Run in a separate ADMIN/test-principal
-- connection that already has permission to invoke the isolated owner's package.
-- This script grants nothing. An ORA-01031 is a test-prerequisite failure, not
-- evidence that the package's own authorization gate was exercised.
-- Bind KCV_TEST_SCHEMA to the isolated installed owner. The original session
-- schema is restored on both success and failure. No database rows are written.
SET SERVEROUTPUT ON
DECLARE
 target_owner VARCHAR2(128):=UPPER(TRIM(:KCV_TEST_SCHEMA));
 original_schema VARCHAR2(128):=SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
 qualified_package VARCHAR2(270);result CLOB;allowed BOOLEAN;token VARCHAR2(32):=RAWTOHEX(SYS_GUID());
 PROCEDURE require(ok BOOLEAN,message VARCHAR2) IS BEGIN
  IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,message);END IF;
 END;
 PROCEDURE denied(p_call VARCHAR2) IS BEGIN
  BEGIN
   EXECUTE IMMEDIATE p_call;
   RAISE_APPLICATION_ERROR(-20991,'The wrong database principal was authorized');
  EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20300 THEN RAISE;END IF;END;
 END;
 PROCEDURE restore_schema IS BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA='||DBMS_ASSERT.ENQUOTE_NAME(original_schema,FALSE);
 END;
BEGIN
 require(REGEXP_LIKE(target_owner,'^KCV_V[0-9]+_[0-9]+$','c')
   AND SYS_CONTEXT('USERENV','SESSION_USER')<>target_owner,
   'Use a separate authorized test connection, not the project owner');
 require(SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL AND SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL,
   'Detach the native test APEX session before the wrong-principal check');
 qualified_package:=DBMS_ASSERT.ENQUOTE_NAME(target_owner,FALSE)||'.KCV_DEPLOY';
 EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA='||DBMS_ASSERT.ENQUOTE_NAME(target_owner,FALSE);
 EXECUTE IMMEDIATE 'BEGIN :r:='||qualified_package||'.is_installer;END;' USING OUT allowed;
 require(allowed=FALSE,'Changing CURRENT_SCHEMA granted installer authorization');
 EXECUTE IMMEDIATE 'BEGIN :r:='||qualified_package||'.learner_ready;END;' USING OUT allowed;
 require(allowed=FALSE,'The wrong database principal received learner readiness');
 BEGIN
  EXECUTE IMMEDIATE 'BEGIN :r:='||qualified_package||'.status_json;END;' USING OUT result;
  RAISE_APPLICATION_ERROR(-20991,'The wrong database principal read setup status');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20300 THEN RAISE;END IF;END;
 denied('BEGIN '||qualified_package||'.capture_identity;END;');
 -- Fixed test inputs are never used: principal rejection must precede parameter,
 -- credential, profile, network, graph and model access in every public action.
 denied('BEGIN '||qualified_package||'.configure_profile(''NO_SUCH_CREDENTIAL'',''invalid'',''invalid'',''invalid'','||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 denied('BEGIN '||qualified_package||'.ensure_network('||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 denied('BEGIN '||qualified_package||'.register_runtime('||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 denied('BEGIN '||qualified_package||'.test_model('||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 denied('BEGIN '||qualified_package||'.load_dataset('||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 denied('BEGIN '||qualified_package||'.enable_learning('||DBMS_ASSERT.ENQUOTE_LITERAL(token)||');END;');
 restore_schema;
 DBMS_OUTPUT.PUT_LINE('PASS: CURRENT_SCHEMA does not authorize a different authenticated database principal');
 DBMS_OUTPUT.PUT_LINE('PASS: setup reads, post-login capture and all six setup actions denied before execution');
EXCEPTION WHEN OTHERS THEN restore_schema;RAISE;
END;
/
