l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_access AS
 PROCEDURE native_identity(p_scope OUT VARCHAR2,p_subject OUT VARCHAR2,p_account OUT VARCHAR2) IS
   app_id VARCHAR2(64):=SYS_CONTEXT(''APEX$SESSION'',''APP_ID'');
   app_user VARCHAR2(255):=SYS_CONTEXT(''APEX$SESSION'',''APP_USER'');
   account_id NUMBER;workspace_id NUMBER;authenticated BOOLEAN;
 BEGIN
   authenticated:=apex_authentication.is_authenticated;
   IF app_id IS NULL OR app_user IS NULL OR UPPER(app_user) IN (''NOBODY'',''APEX_PUBLIC_USER'')
     OR authenticated IS NULL OR NOT authenticated THEN
     RAISE_APPLICATION_ERROR(-20240,''NOT_AUTHENTICATED: Sign in to use My Contexts'');
   END IF;
   workspace_id:=apex_custom_auth.get_security_group_id;
   account_id:=a');
 l_expected:=l_expected||TO_CLOB('pex_util.get_user_id(p_username=>app_user);
   IF workspace_id IS NULL OR workspace_id<=0 OR account_id IS NULL OR account_id<=0 THEN
     RAISE_APPLICATION_ERROR(-20240,''NOT_AUTHENTICATED: An Oracle APEX account is required'');
   END IF;
   p_account:=TO_CHAR(account_id,''TM9'');p_scope:=''APEX:''||TO_CHAR(workspace_id,''TM9'')||'':''||app_id;
   p_subject:=''ACCOUNT:''||p_account;
 END;
 PROCEDURE capture_identity IS s VARCHAR2(128);u VARCHAR2(128);account VARCHAR2(128);pinned VARCHAR2(128);BEGIN
   native_identity(s,u,account);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
   IF pinned IS NOT NULL AND pinned<>account THEN
     RAISE_APPLICATION_ERROR(-20240,''NOT_AUTHENTICATED: Sign out');
 l_expected:=l_expected||TO_CLOB(' and sign in again to refresh your account identity'');
   END IF;
   IF pinned IS NULL THEN apex_util.set_session_state(p_name=>''KCV_AUTH_ACCOUNT_ID'',p_value=>account,p_commit=>FALSE);END IF;
 END;
 PROCEDURE identity(p_scope OUT VARCHAR2,p_subject OUT VARCHAR2) IS
   app_id VARCHAR2(64):=SYS_CONTEXT(''APEX$SESSION'',''APP_ID'');
   app_user VARCHAR2(255):=SYS_CONTEXT(''APEX$SESSION'',''APP_USER'');
   account VARCHAR2(128);pinned VARCHAR2(128);
 BEGIN
   IF app_id IS NOT NULL OR app_user IS NOT NULL THEN
     native_identity(p_scope,p_subject,account);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
     IF pinned IS NULL OR pinned<>account THEN
       RAISE_APPLICATION_ERROR(-20240,''NOT');
 l_expected:=l_expected||TO_CLOB('_AUTHENTICATED: Sign out and sign in again to refresh your account identity'');
     END IF;
   ELSE
     IF SYS_CONTEXT(''USERENV'',''SESSION_USER'')<>$$PLSQL_UNIT_OWNER THEN
       RAISE_APPLICATION_ERROR(-20240,''NOT_AUTHENTICATED: Use the lab owner Worksheet'');
     END IF;
     p_scope:=''DB:''||$$PLSQL_UNIT_OWNER;
     p_subject:=''DBUSER:''||SYS_CONTEXT(''USERENV'',''SESSION_USER'');
   END IF;
 END;
 FUNCTION owner_scope RETURN VARCHAR2 IS s VARCHAR2(128);u VARCHAR2(128);BEGIN identity(s,u);RETURN s;END;
 FUNCTION owner_subject RETURN VARCHAR2 IS s VARCHAR2(128);u VARCHAR2(128);BEGIN identity(s,u);RETURN u;END;
 PROCEDURE assert_context(p_context VARCHAR2) IS s VARCHAR2(128);u VARCHAR2(128);n NUMB');
 l_expected:=l_expected||TO_CLOB('ER;BEGIN
   identity(s,u);
   SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   IF n<>1 THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');END IF;
 END;
END;
');
 check_program('KCV_ACCESS','PACKAGE BODY',l_expected);
