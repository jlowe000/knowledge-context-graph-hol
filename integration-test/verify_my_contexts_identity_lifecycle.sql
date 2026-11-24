-- ADMIN ONLY; destructive to the disposable KCV_V2_A TEST account in KCV_V2_TEST.
-- Never run against a learner workspace/account. This replaces only that test
-- account's password with an unprinted database-generated value. It does not
-- read any password, touch KCV_V2_UI/KCV_V2_B or change KCV_LAB.
-- Bind the already imported isolated test application ID.
DECLARE
 app_id NUMBER:=:KCV_TEST_APP_ID;ws_id NUMBER;n NUMBER;old_user NUMBER;new_user NUMBER;
 original_session NUMBER;renamed_session NUMBER;new_session NUMBER;
 old_subject VARCHAR2(128);old_scope VARCHAR2(128);new_subject VARCHAR2(128);
 old_context VARCHAR2(32);new_context VARCHAR2(32);token VARCHAR2(32):=RAWTOHEX(SYS_GUID());
 result CLOB;j JSON_OBJECT_T;temporary_password VARCHAR2(100);
 PROCEDURE check_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
 PROCEDURE admin_context IS BEGIN
   apex_session.detach;apex_util.set_security_group_id(ws_id);
 END;
BEGIN
 check_true(SYS_CONTEXT('USERENV','SESSION_USER')='ADMIN','ADMIN is required for the disposable account lifecycle test');
 SELECT workspace_id INTO ws_id FROM apex_workspaces WHERE workspace='KCV_V2_TEST';
 SELECT COUNT(*) INTO n FROM apex_applications WHERE application_id=app_id AND workspace='KCV_V2_TEST' AND owner='KCV_V2_TEST';
 check_true(n=1,'Use the isolated test application only');
 apex_util.set_security_group_id(ws_id);
 old_user:=apex_util.get_user_id('KCV_V2_A');
 check_true(old_user IS NOT NULL AND old_user>0,'The disposable KCV_V2_A account must exist');
 check_true(apex_util.get_user_id('KCV_V2_A_RENAMED') IS NULL,'Rename target must not already exist');
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>'KCV_V2_A');
 KCV_V2_TEST.kcv_access.capture_identity;
 original_session:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
 old_subject:=KCV_V2_TEST.kcv_access.owner_subject;old_scope:=KCV_V2_TEST.kcv_access.owner_scope;
 result:=KCV_V2_TEST.kcv_personal_context_api.save_draft(NULL,'Disposable rename identity check',TO_CLOB('{}'),NULL,token||'_old');
 j:=JSON_OBJECT_T.parse(result);old_context:=j.get_string('context_id');
 admin_context;
 apex_util.set_username(p_userid=>old_user,p_username=>'KCV_V2_A_RENAMED');COMMIT;
 check_true(apex_util.get_user_id('KCV_V2_A_RENAMED')=old_user,'Rename changed the native account identity');
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>'KCV_V2_A_RENAMED');
 KCV_V2_TEST.kcv_access.capture_identity;
 renamed_session:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
 check_true(KCV_V2_TEST.kcv_access.owner_subject=old_subject,'Renamed account lost its stable subject');
 result:=KCV_V2_TEST.kcv_personal_context_api.get_context(old_context);
 DBMS_OUTPUT.PUT_LINE('PASS: native account rename retains owned draft access after a new session');
 admin_context;
 apex_util.set_username(p_userid=>old_user,p_username=>'KCV_V2_A');COMMIT;
 apex_util.remove_user(p_user_id=>old_user);COMMIT;
 temporary_password:=RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(24))||'aZ9!';
 apex_util.create_user(p_user_name=>'KCV_V2_A',p_web_password=>temporary_password,
   p_developer_privs=>NULL,p_default_schema=>'KCV_V2_TEST',p_change_password_on_first_use=>'N');
 temporary_password:=NULL;COMMIT;
 new_user:=apex_util.get_user_id('KCV_V2_A');check_true(new_user<>old_user,'Recreated account reused its prior native identity');
 apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>'KCV_V2_A');
 KCV_V2_TEST.kcv_access.capture_identity;
 new_session:=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
 new_subject:=KCV_V2_TEST.kcv_access.owner_subject;check_true(new_subject<>old_subject,'Recreated account inherited its prior subject');
 BEGIN result:=KCV_V2_TEST.kcv_personal_context_api.get_context(old_context);RAISE_APPLICATION_ERROR(-20991,'Recreated account inherited the previous owner draft');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 result:=KCV_V2_TEST.kcv_personal_context_api.save_draft(NULL,'Disposable recreated identity check',TO_CLOB('{}'),NULL,token||'_new');
 j:=JSON_OBJECT_T.parse(result);new_context:=j.get_string('context_id');
 DBMS_OUTPUT.PUT_LINE('PASS: recreated username resolves to a different account and cannot read prior owner data');
 admin_context;
 BEGIN
   apex_session.attach(p_app_id=>app_id,p_page_id=>10,p_session_id=>original_session);
   IF apex_authentication.is_authenticated THEN
     BEGIN
       result:=KCV_V2_TEST.kcv_personal_context_api.get_context(new_context);
       RAISE_APPLICATION_ERROR(-20991,'Old session rebound to the recreated username');
     EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20240 THEN RAISE;END IF;END;
     BEGIN
       KCV_V2_TEST.kcv_access.capture_identity;
       RAISE_APPLICATION_ERROR(-20991,'Old account pin was rebound by capture_identity');
     EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20240 THEN RAISE;END IF;END;
   END IF;
 EXCEPTION WHEN OTHERS THEN
   IF NOT (SQLCODE=-20987 AND INSTR(LOWER(SQLERRM),'session')>0 AND INSTR(LOWER(SQLERRM),'expir')>0) THEN RAISE;END IF;
 END;
 DBMS_OUTPUT.PUT_LINE('PASS: old session does not acquire the recreated account data');
 admin_context;
 DELETE FROM KCV_V2_TEST.kcv_context_requests WHERE request_token IN (token||'_old',token||'_new');
 DELETE FROM KCV_V2_TEST.kcv_personal_contexts WHERE context_id IN (old_context,new_context);COMMIT;
 apex_session.delete_session(p_session_id=>original_session);
 apex_session.delete_session(p_session_id=>renamed_session);
 apex_session.delete_session(p_session_id=>new_session);
 DBMS_OUTPUT.PUT_LINE('PASS: dedicated native identity lifecycle test completed; browser account unchanged');
END;
/
