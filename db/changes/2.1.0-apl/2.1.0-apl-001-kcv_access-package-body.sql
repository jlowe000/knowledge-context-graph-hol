CREATE OR REPLACE PACKAGE BODY kcv_access AS
 PROCEDURE native_identity(p_scope OUT VARCHAR2,p_subject OUT VARCHAR2,p_account OUT VARCHAR2) IS
   app_id VARCHAR2(64):=SYS_CONTEXT('APEX$SESSION','APP_ID');
   app_user VARCHAR2(255):=SYS_CONTEXT('APEX$SESSION','APP_USER');
   account_id NUMBER;workspace_id NUMBER;authenticated BOOLEAN;
 BEGIN
   authenticated:=apex_authentication.is_authenticated;
   IF app_id IS NULL OR app_user IS NULL OR UPPER(app_user) IN ('NOBODY','APEX_PUBLIC_USER')
     OR authenticated IS NULL OR NOT authenticated THEN
     RAISE_APPLICATION_ERROR(-20240,'NOT_AUTHENTICATED: Sign in to use My Contexts');
   END IF;
   workspace_id:=apex_custom_auth.get_security_group_id;
   account_id:=apex_util.get_user_id(p_username=>app_user);
   IF workspace_id IS NULL OR workspace_id<=0 OR account_id IS NULL OR account_id<=0 THEN
     RAISE_APPLICATION_ERROR(-20240,'NOT_AUTHENTICATED: An Oracle APEX account is required');
   END IF;
   p_account:=TO_CHAR(account_id,'TM9');p_scope:='APEX:'||TO_CHAR(workspace_id,'TM9')||':'||app_id;
   p_subject:='ACCOUNT:'||p_account;
 END;
 PROCEDURE capture_identity IS s VARCHAR2(128);u VARCHAR2(128);account VARCHAR2(128);pinned VARCHAR2(128);BEGIN
   native_identity(s,u,account);pinned:=apex_util.get_session_state('KCV_AUTH_ACCOUNT_ID');
   IF pinned IS NOT NULL AND pinned<>account THEN
     RAISE_APPLICATION_ERROR(-20240,'NOT_AUTHENTICATED: Sign out and sign in again to refresh your account identity');
   END IF;
   IF pinned IS NULL THEN apex_util.set_session_state(p_name=>'KCV_AUTH_ACCOUNT_ID',p_value=>account,p_commit=>FALSE);END IF;
 END;
 PROCEDURE identity(p_scope OUT VARCHAR2,p_subject OUT VARCHAR2) IS
   app_id VARCHAR2(64):=SYS_CONTEXT('APEX$SESSION','APP_ID');
   app_user VARCHAR2(255):=SYS_CONTEXT('APEX$SESSION','APP_USER');
   account VARCHAR2(128);pinned VARCHAR2(128);
 BEGIN
   IF app_id IS NOT NULL OR app_user IS NOT NULL THEN
     native_identity(p_scope,p_subject,account);pinned:=apex_util.get_session_state('KCV_AUTH_ACCOUNT_ID');
     IF pinned IS NULL OR pinned<>account THEN
       RAISE_APPLICATION_ERROR(-20240,'NOT_AUTHENTICATED: Sign out and sign in again to refresh your account identity');
     END IF;
   ELSE
     IF SYS_CONTEXT('USERENV','SESSION_USER')<>$$PLSQL_UNIT_OWNER THEN
       RAISE_APPLICATION_ERROR(-20240,'NOT_AUTHENTICATED: Use the lab owner Worksheet');
     END IF;
     p_scope:='DB:'||$$PLSQL_UNIT_OWNER;
     p_subject:='DBUSER:'||SYS_CONTEXT('USERENV','SESSION_USER');
   END IF;
 END;
 FUNCTION owner_scope RETURN VARCHAR2 IS s VARCHAR2(128);u VARCHAR2(128);BEGIN identity(s,u);RETURN s;END;
 FUNCTION owner_subject RETURN VARCHAR2 IS s VARCHAR2(128);u VARCHAR2(128);BEGIN identity(s,u);RETURN u;END;
 PROCEDURE assert_context(p_context VARCHAR2) IS s VARCHAR2(128);u VARCHAR2(128);n NUMBER;deletion_state VARCHAR2(16);BEGIN
   identity(s,u);
   SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   IF n<>1 THEN RAISE_APPLICATION_ERROR(-20241,'CONTEXT_UNAVAILABLE: Context is not available to this account');END IF;
   SELECT MAX(status) INTO deletion_state FROM kcv_context_deletions
    WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   IF deletion_state='PENDING' THEN
    RAISE_APPLICATION_ERROR(-20248,'CONTEXT_DELETING: Open the deletion status to complete or retry this deletion');
   ELSIF deletion_state IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20241,'CONTEXT_UNAVAILABLE: Context is not available to this account');
   END IF;
 END;
 PROCEDURE assert_writable IS n NUMBER;admission PLS_INTEGER;result PLS_INTEGER;ignored PLS_INTEGER;acquired BOOLEAN:=FALSE;BEGIN
   admission:=DBMS_UTILITY.GET_HASH_VALUE('KCV_WRITE_ADMISSION:'||$$PLSQL_UNIT_OWNER,1,1073741823);
   result:=DBMS_LOCK.REQUEST(id=>admission,lockmode=>DBMS_LOCK.S_MODE,timeout=>0,release_on_commit=>TRUE);
   IF result NOT IN(0,4) THEN RAISE_APPLICATION_ERROR(-20246,'OPERATION_IN_PROGRESS: Setup is in progress; retry shortly.');END IF;
   acquired:=result=0;
   SELECT COUNT(*) INTO n FROM kcv_settings WHERE setting_key='APP_MAINTENANCE' AND UPPER(setting_value)='ON';
   IF n>0 THEN RAISE_APPLICATION_ERROR(-20246,'OPERATION_IN_PROGRESS: Maintenance is in progress; try again shortly');END IF;
 EXCEPTION WHEN OTHERS THEN
   IF acquired THEN ignored:=DBMS_LOCK.RELEASE(admission);END IF;RAISE;
 END;
 FUNCTION topic_options(p_graph VARCHAR2) RETURN CLOB IS a JSON_ARRAY_T:=JSON_ARRAY_T();BEGIN
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,'$.topics[*]' COLUMNS(label VARCHAR2(200) PATH '$')) jt
     WHERE gs.graph_name=p_graph AND (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER) IS NULL
       AND REGEXP_LIKE(gs.version_id,'^S[0-9]+-v') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
     ORDER BY jt.label) LOOP a.append(t.label);END LOOP;RETURN a.to_clob();
 END;
 PROCEDURE assert_topic(p_graph VARCHAR2,p_label VARCHAR2) IS n NUMBER;v CLOB:=topic_options(p_graph);BEGIN
   SELECT COUNT(*) INTO n FROM JSON_TABLE(v,'$[*]' COLUMNS(label VARCHAR2(200) PATH '$')) WHERE label=p_label;
   IF n<>1 THEN RAISE_APPLICATION_ERROR(-20247,'INVALID_TOPIC: Choose an eligible topic in this collection');END IF;
 END;
 PROCEDURE assert_session(p_session VARCHAR2,p_write BOOLEAN DEFAULT FALSE) IS
   c VARCHAR2(32);n NUMBER;s VARCHAR2(128);u VARCHAR2(128);state VARCHAR2(16);
 BEGIN
   IF p_write THEN assert_writable;END IF;
   BEGIN SELECT personal_context_id INTO c FROM kcv_chat_sessions WHERE session_id=p_session;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20100,'Conversation is not available');END;
   IF c IS NULL THEN
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE session_id=p_session
       AND owner_name=COALESCE(SYS_CONTEXT('APEX$SESSION','APP_USER'),SYS_CONTEXT('USERENV','SESSION_USER'))
       AND NVL(apex_app_id,'-')=NVL(SYS_CONTEXT('APEX$SESSION','APP_ID'),'-')
       AND NVL(apex_session_id,'-')=NVL(SYS_CONTEXT('APEX$SESSION','APP_SESSION'),'-');
     IF n<>1 THEN RAISE_APPLICATION_ERROR(-20100,'Conversation is not available');END IF;
   ELSE
     assert_context(c);s:=owner_scope;u:=owner_subject;
     SELECT lifecycle INTO state FROM kcv_personal_contexts WHERE context_id=c;
     SELECT COUNT(*) INTO n FROM kcv_context_attachments WHERE session_id=p_session
       AND owner_scope=s AND owner_subject=u AND apex_session_id=NVL(SYS_CONTEXT('APEX$SESSION','APP_SESSION'),'DB');
     IF n<>1 THEN RAISE_APPLICATION_ERROR(-20100,'Open this conversation from My Contexts first');END IF;
     IF p_write AND state='ARCHIVED' THEN RAISE_APPLICATION_ERROR(-20243,'CONTEXT_ARCHIVED: Restore before making changes');END IF;
   END IF;
 END;
END;
