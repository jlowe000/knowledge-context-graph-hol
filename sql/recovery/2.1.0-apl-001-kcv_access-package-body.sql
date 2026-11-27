-- Reconcile only physically complete work, after investigating the failure.
-- Acquires the same migration lock. Does not rerun DDL, clear a live lock or skip postconditions.
DECLARE
 l_lock VARCHAR2(128);l_result PLS_INTEGER;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN (' ',CHR(9),CHR(10),CHR(13),'"') THEN r:=r||UPPER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status='VALID';
  require(n=1,'Missing or invalid program: '||p_name||' '||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute='ERROR';
  require(n=0,'Compilation errors: '||p_name||' '||p_type);
  FOR r IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>'--' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||' ')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,'Installed source differs: '||p_name||' '||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_column VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string('name');cols:=t.get_array('columns');cs:=t.get_array('constraints');
  wanted_temp:=t.get_string('temporary');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,'Missing or incompatible table: '||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,'Column count differs: '||name);
  FOR i IN 0..cols.get_size-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string('name');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identity_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,'Missing column: '||name||'.'||c.get_string('name')); END;
   require(actual_type=c.get_string('type'),'Column type differs: '||name||'.'||c.get_string('name'));
   require(actual_nullable=c.get_string('nullable'),'Column nullability differs: '||name||'.'||c.get_string('name'));
   IF c.has('length') THEN
    require(len=c.get_number('length'),'Column length differs: '||name||'.'||c.get_string('name'));
    require(char_semantics=c.get_string('char_used'),'Column character semantics differ: '||name||'.'||c.get_string('name'));
   END IF;
   IF c.get_string('type')='NUMBER' THEN
    require(NVL(prec,-1)=NVL(c.get_number('precision'),-1) AND NVL(sc,-99)=NVL(c.get_number('scale'),-99),'Number precision differs: '||name||'.'||c.get_string('name'));
   END IF;
   require(ident=c.get_string('identity'),'Column identity differs: '||name||'.'||c.get_string('name'));
   IF ident='NO' THEN d:=def;require(NVL(compact(d),'#NULL#')=NVL(compact(c.get_string('default')),'#NULL#'),'Column default differs: '||name||'.'||c.get_string('name'));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;wanted_constraint:=c.get_string('type');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status='ENABLED' AND validated='VALIDATED'
      AND deferrable='NOT DEFERRABLE' AND (constraint_type<>'R' OR (delete_rule='NO ACTION' AND r_owner=SYS_CONTEXT('USERENV','CURRENT_USER')))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_columns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type='C' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string('expression')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_string('columns') THEN
     IF r.constraint_type='R' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string('reference_table') AND refcols=c.get_string('reference_columns') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
   require(found,'Missing or incompatible constraint: '||name||' '||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r.constraint_type<>'C' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),'^[A-Z][A-Z0-9_$]*ISNOTNULL$') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,'Unexpected constraints: '||name);
 END;

BEGIN
 require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM'),'Connect as the intended project schema owner');
 DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);
 l_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_result=0,'Another migration is active');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-001-kcv_access-package-body'
  AND payload_sha256='a6f01f175044a4ce6fd62c5deb8125fc1c72c98d6fa202e6ad6d6e08d26d5407' AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
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
 l_expected:=l_expected||TO_CLOB('ER;deletion_state VARCHAR2(16);BEGIN
   identity(s,u);
   SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   IF n<>1 THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');END IF;
   SELECT MAX(status) INTO deletion_state FROM kcv_context_deletions
    WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   IF deletion_state=''PENDING'' THEN
    RAISE_APPLICATION_ERROR(-20248,''CONTEXT_DELETING: Open the deletion status to complete or retry this deletion'');
   ELSIF deletion_state IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not a');
 l_expected:=l_expected||TO_CLOB('vailable to this account'');
   END IF;
 END;
 PROCEDURE assert_writable IS n NUMBER;admission PLS_INTEGER;result PLS_INTEGER;ignored PLS_INTEGER;acquired BOOLEAN:=FALSE;BEGIN
   admission:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_WRITE_ADMISSION:''||$$PLSQL_UNIT_OWNER,1,1073741823);
   result:=DBMS_LOCK.REQUEST(id=>admission,lockmode=>DBMS_LOCK.S_MODE,timeout=>0,release_on_commit=>TRUE);
   IF result NOT IN(0,4) THEN RAISE_APPLICATION_ERROR(-20246,''OPERATION_IN_PROGRESS: Setup is in progress; retry shortly.'');END IF;
   acquired:=result=0;
   SELECT COUNT(*) INTO n FROM kcv_settings WHERE setting_key=''APP_MAINTENANCE'' AND UPPER(setting_value)=''ON'';
   IF n>0 THEN RAISE_APPLICATION_ERROR(-20246,''OPERA');
 l_expected:=l_expected||TO_CLOB('TION_IN_PROGRESS: Maintenance is in progress; try again shortly'');END IF;
 EXCEPTION WHEN OTHERS THEN
   IF acquired THEN ignored:=DBMS_LOCK.RELEASE(admission);END IF;RAISE;
 END;
 FUNCTION topic_options(p_graph VARCHAR2) RETURN CLOB IS a JSON_ARRAY_T:=JSON_ARRAY_T();BEGIN
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) jt
     WHERE gs.graph_name=p_graph AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
       AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-');
 l_expected:=l_expected||TO_CLOB('v'') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
     ORDER BY jt.label) LOOP a.append(t.label);END LOOP;RETURN a.to_clob();
 END;
 PROCEDURE assert_topic(p_graph VARCHAR2,p_label VARCHAR2) IS n NUMBER;v CLOB:=topic_options(p_graph);BEGIN
   SELECT COUNT(*) INTO n FROM JSON_TABLE(v,''$[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) WHERE label=p_label;
   IF n<>1 THEN RAISE_APPLICATION_ERROR(-20247,''INVALID_TOPIC: Choose an eligible topic in this collection'');END IF;
 END;
 PROCEDURE assert_session(p_session VARCHAR2,p_write BOOLEAN DEFAULT FALSE) IS
   c VARCHAR2(32);n NUMBER;s VARCHAR2(128);u VARCHAR2(128);state VARCHAR2(16);
 BEGIN
   IF p_write THEN assert_writa');
 l_expected:=l_expected||TO_CLOB('ble;END IF;
   BEGIN SELECT personal_context_id INTO c FROM kcv_chat_sessions WHERE session_id=p_session;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20100,''Conversation is not available'');END;
   IF c IS NULL THEN
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE session_id=p_session
       AND owner_name=COALESCE(SYS_CONTEXT(''APEX$SESSION'',''APP_USER''),SYS_CONTEXT(''USERENV'',''SESSION_USER''))
       AND NVL(apex_app_id,''-'')=NVL(SYS_CONTEXT(''APEX$SESSION'',''APP_ID''),''-'')
       AND NVL(apex_session_id,''-'')=NVL(SYS_CONTEXT(''APEX$SESSION'',''APP_SESSION''),''-'');
     IF n<>1 THEN RAISE_APPLICATION_ERROR(-20100,''Conversation is not available'');END IF;
   ELSE
     assert_cont');
 l_expected:=l_expected||TO_CLOB('ext(c);s:=owner_scope;u:=owner_subject;
     SELECT lifecycle INTO state FROM kcv_personal_contexts WHERE context_id=c;
     SELECT COUNT(*) INTO n FROM kcv_context_attachments WHERE session_id=p_session
       AND owner_scope=s AND owner_subject=u AND apex_session_id=NVL(SYS_CONTEXT(''APEX$SESSION'',''APP_SESSION''),''DB'');
     IF n<>1 THEN RAISE_APPLICATION_ERROR(-20100,''Open this conversation from My Contexts first'');END IF;
     IF p_write AND state=''ARCHIVED'' THEN RAISE_APPLICATION_ERROR(-20243,''CONTEXT_ARCHIVED: Restore before making changes'');END IF;
   END IF;
 END;
END;
');
 check_program('KCV_ACCESS','PACKAGE BODY',l_expected);
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id='2.1.0-apl-001-kcv_access-package-body' AND payload_sha256='a6f01f175044a4ce6fd62c5deb8125fc1c72c98d6fa202e6ad6d6e08d26d5407';
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/
