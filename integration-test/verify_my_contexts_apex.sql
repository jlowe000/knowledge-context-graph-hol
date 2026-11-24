-- Native APEX identity harness, not a browser sign-in test.
-- Requires two distinct existing Oracle APEX Accounts in an isolated test workspace.
-- Bind only the test app ID and test account names; no passwords are accepted here.
DECLARE
 app_id NUMBER:=:KCV_TEST_APP_ID;
 user_a VARCHAR2(255):=:KCV_TEST_USER_A;
 user_b VARCHAR2(255):=:KCV_TEST_USER_B;
 scope_a VARCHAR2(128);subject_a VARCHAR2(128);subject_b VARCHAR2(128);
 cid VARCHAR2(32);token VARCHAR2(32):=RAWTOHEX(SYS_GUID());result CLOB;j JSON_OBJECT_T;
 session_a NUMBER;session_b NUMBER;session_a2 NUMBER;
 PROCEDURE check_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 check_true(app_id IS NOT NULL AND user_a IS NOT NULL AND user_b IS NOT NULL AND UPPER(user_a)<>UPPER(user_b),
   'Two distinct existing test accounts and an isolated app ID are required');
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>user_a);
 -- Model a session created before the authentication upgrade: reads must not pin it.
 apex_util.set_session_state(p_name=>'KCV_AUTH_ACCOUNT_ID',p_value=>NULL,p_commit=>FALSE);
 BEGIN subject_a:=kcv_access.owner_subject;RAISE_APPLICATION_ERROR(-20991,'Missing account pin was accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20240 THEN RAISE;END IF;END;
 check_true(apex_util.get_session_state('KCV_AUTH_ACCOUNT_ID') IS NULL,'Read populated the missing account pin');
 -- CREATE_SESSION is a privileged harness; explicitly simulate the post-auth callback.
 kcv_access.capture_identity;
 session_a:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
 scope_a:=kcv_access.owner_scope;subject_a:=kcv_access.owner_subject;
 check_true(SUBSTR(scope_a,1,5)='APEX:','Test did not establish authenticated APEX scope');
 result:=kcv_personal_context_api.save_draft(NULL,'APEX C2 synthetic identity check',TO_CLOB('{}'),NULL,token||'_create');
 j:=JSON_OBJECT_T.parse(result);cid:=j.get_string('context_id');
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>user_b);
 kcv_access.capture_identity;
 session_b:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));subject_b:=kcv_access.owner_subject;
 check_true(subject_b<>subject_a,'Native accounts did not resolve to distinct stable IDs');
 BEGIN result:=kcv_personal_context_api.get_context(cid);RAISE_APPLICATION_ERROR(-20991,'Second account could read first account context');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.save_draft(cid,'tampered',TO_CLOB('{}'),1,token||'_foreign');
   RAISE_APPLICATION_ERROR(-20991,'Second account could update first account context');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>user_a);
 kcv_access.capture_identity;
 session_a2:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
 check_true(session_a2<>session_a,'Expected a new APEX session');
 check_true(kcv_access.owner_subject=subject_a AND kcv_access.owner_scope=scope_a,'Identity changed across APEX sessions');
 result:=kcv_personal_context_api.get_context(cid);j:=JSON_OBJECT_T.parse(result);
 check_true(j.get_string('context_id')=cid,'Owned context could not reopen in a new APEX session');
 DELETE FROM kcv_context_requests WHERE owner_scope=scope_a AND owner_subject=subject_a AND request_token=token||'_create';
 DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
 apex_session.delete_session(p_session_id=>session_a);
 apex_session.delete_session(p_session_id=>session_b);
 apex_session.delete_session(p_session_id=>session_a2);
 DBMS_OUTPUT.PUT_LINE('PASS: native APEX account identity, cross-account rejection and owned draft reopening across new APEX sessions');
 DBMS_OUTPUT.PUT_LINE('PASS: missing account pin fails closed without being populated by a read');
 DBMS_OUTPUT.PUT_LINE('PENDING: HTTP/browser sign-in, account rename/recreation and UI behavior require separate acceptance');
END;
/
