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
      AND deferrable='NOT DEFERRABLE' AND (constraint_type<>'R' OR (delete_rule='NO ACTION' AND r_owner=USER))
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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-r5-007-kcv_context_delete-package-body'
  AND payload_sha256='12550ec30ce70c7aee4e6d1276f3b96fc62b1215f082942c514ada867964531d' AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_context_delete AS
 TYPE locks_t IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION digest(p_text CLOB) RETURN VARCHAR2 IS BEGIN
  RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(CASE WHEN p_text IS NULL THEN TO_CLOB(''NULL:'') ELSE TO_CLOB(''VALUE:'')||p_text END,DBMS_CRYPTO.HASH_SH256)));
 END;
 FUNCTION owned(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
  r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
  SELECT * IN');
 l_expected:=l_expected||TO_CLOB('TO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');END;
 FUNCTION status(p_context VARCHAR2) RETURN VARCHAR2 IS
  s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;v VARCHAR2(16);r kcv_personal_contexts%ROWTYPE;
 BEGIN
  BEGIN SELECT status INTO v FROM kcv_context_deletions WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;RETURN v;
  EXCEPTION WHEN NO_DATA_FOUND THEN r:=owned(p_context);RETURN ''NONE'';END;
 END;
 FUNCTION receipt(p_context VARCHAR2) RETURN CLOB ');
 l_expected:=l_expected||TO_CLOB('IS
  s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;r kcv_context_deletions%ROWTYPE;j JSON_OBJECT_T:=JSON_OBJECT_T();
 BEGIN
  SELECT * INTO r FROM kcv_context_deletions WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
  j.put(''context_id'',r.context_id);j.put(''status'',r.status);j.put(''title'',r.title);
  j.put(''expected_version'',r.expected_version);j.put(''expected_head'',r.expected_head);j.put(''preview_digest'',r.preview_digest);
  j.put(''request_token'',r.request_token);j.put(''counts'',JSON_OBJECT_T.parse(r.counts_json));j.put(''error_code'',r.error_code);
  RETURN j.to_clob();
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CO');
 l_expected:=l_expected||TO_CLOB('NTEXT_UNAVAILABLE: Deletion is not available to this account'');END;
 PROCEDURE acquire(p_key VARCHAR2,p_locks IN OUT locks_t) IS n PLS_INTEGER;id PLS_INTEGER;BEGIN
  id:=DBMS_UTILITY.GET_HASH_VALUE(p_key,1,1073741823);n:=DBMS_LOCK.REQUEST(id,DBMS_LOCK.X_MODE,0,FALSE);
  require(n=0,''OPERATION_IN_PROGRESS: Finish the current context or conversation action before deleting'',-20246);
  p_locks(p_locks.COUNT+1):=id;
 END;
 PROCEDURE release_all(p_locks IN OUT locks_t) IS n PLS_INTEGER;BEGIN
  FOR i IN REVERSE 1..p_locks.COUNT LOOP n:=DBMS_LOCK.RELEASE(p_locks(i));END LOOP;p_locks.DELETE;
 END;
 PROCEDURE quiet(p_context VARCHAR2) IS n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM kcv_chat_sessions W');
 l_expected:=l_expected||TO_CLOB('HERE personal_context_id=p_context AND mutation_token IS NOT NULL;
  require(n=0,''OPERATION_IN_PROGRESS: Complete or recover the pending answer before deleting'',-20246);
  SELECT COUNT(*) INTO n FROM kcv_response_runs r JOIN kcv_chat_sessions s ON s.session_id=r.session_id
   WHERE s.personal_context_id=p_context AND r.status IN (''RUNNING'',''UNCERTAIN'');
  require(n=0,''OPERATION_IN_PROGRESS: A response is still running'',-20246);
  SELECT COUNT(*) INTO n FROM kcv_personal_operations WHERE context_id=p_context AND phase IN (''BUILDING'',''READY'');
  require(n=0,''OPERATION_IN_PROGRESS: Recover the interrupted context operation before deleting'',-20246);
 END;
 FUNCTION inventory_digest(p_context VAR');
 l_expected:=l_expected||TO_CLOB('CHAR2) RETURN VARCHAR2 IS b CLOB;r kcv_personal_contexts%ROWTYPE:=owned(p_context);
  PROCEDURE append_value(v VARCHAR2) IS BEGIN b:=b||LENGTH(NVL(v,''-''))||'':''||NVL(v,''-'')||CHR(10);END;
 BEGIN
  b:=TO_CLOB(p_context);append_value(r.title);append_value(r.lifecycle);append_value(TO_CHAR(r.draft_version,''TM9''));
  append_value(r.latest_revision);append_value(r.base_graph);append_value(digest(r.draft_json));append_value(digest(r.provenance_json));
  FOR x IN (
   SELECT ''S:''||session_id k,revision_id||'':''||conversation_id||'':''||NVL(model_revision_id,''-'')||'':''||NVL(mutation_token,''-'') v
    FROM kcv_chat_sessions WHERE personal_context_id=p_context
   UNION ALL SELECT ''R:''||revision_id,overlay_gr');
 l_expected:=l_expected||TO_CLOB('aph||'':''||base_graph||'':''||NVL(parent_revision,''-'')||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(context_json,4)))
    FROM kcv_scenario_revisions WHERE context_id=p_context
   UNION ALL SELECT ''O:''||operation_id,phase||'':''||NVL(overlay_graph,''-'')||'':''||NVL(model_conversation_id,''-'')||'':''||NVL(revision_id,''-'')||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(body_json,4)))
    FROM kcv_personal_operations WHERE context_id=p_context
   UNION ALL SELECT ''T:''||TO_CHAR(turn_id,''TM9''),revision_id||'':''||role||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(body,4)))
    FROM kcv_chat_turns WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''A:''||TO_CHAR(obser');
 l_expected:=l_expected||TO_CLOB('vation_id,''TM9''),revision_id||'':''||method||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(observation,4)))||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(NVL(next_step,TO_CLOB(''-'')),4)))
    FROM kcv_scenario_observations WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''E:''||execution_id,status||'':''||revision_id||'':''||conversation_id||'':''||NVL(TO_CHAR(assistant_turn_id,''TM9''),''-'')
    FROM kcv_response_runs WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''C:''||TO_CHAR(call_id,''TM9''),status||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(NVL(output_json,TO_CLOB(''-'')),4)))
    FROM ');
 l_expected:=l_expected||TO_CLOB('kcv_response_tool_calls WHERE execution_id IN (SELECT execution_id FROM kcv_response_runs WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context))
   UNION ALL SELECT ''B:''||TO_CHAR(boundary_id,''TM9''),NVL(old_conversation,''-'')||'':''||new_conversation||'':''||reason
    FROM kcv_model_boundaries WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''P:''||change_token,state||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(plan_json,4)))
    FROM kcv_scenario_changes WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''U:''||TO_CHAR(audit');
 l_expected:=l_expected||TO_CLOB('_id,''TM9''),operation||'':''||NVL(new_revision,''-'')||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(NVL(details,TO_CLOB(''-'')),4)))
    FROM kcv_scenario_audit WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''X:''||session_id||'':''||apex_session_id,owner_scope||'':''||owner_subject
    FROM kcv_context_attachments WHERE session_id IN (SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION ALL SELECT ''Q:''||request_token,action||'':''||payload_sha256||'':''||LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(result_json,4)))
    FROM kcv_context_requests WHERE owner_scope=r.owner_scope AND owner_subject=r.owner_subject AND JSON_VALU');
 l_expected:=l_expected||TO_CLOB('E(result_json,''$.context_id'')=p_context
   ORDER BY k,v
  ) LOOP append_value(x.k);append_value(x.v);END LOOP;
  RETURN digest(b);
 END;
 FUNCTION counts(p_context VARCHAR2) RETURN CLOB IS j JSON_OBJECT_T:=JSON_OBJECT_T();n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM kcv_scenario_revisions WHERE context_id=p_context;j.put(''revisions'',n);
  SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=p_context;j.put(''conversations'',n);
  SELECT COUNT(*) INTO n FROM kcv_chat_turns WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);j.put(''turns'',n);
  SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM');
 l_expected:=l_expected||TO_CLOB(' kcv_chat_sessions WHERE personal_context_id=p_context);j.put(''responses'',n);
  SELECT COUNT(*) INTO n FROM kcv_response_tool_calls WHERE execution_id IN(SELECT execution_id FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context));j.put(''evidence'',n);
  SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);j.put(''observations'',n);
  SELECT COUNT(*) INTO n FROM (SELECT overlay_graph FROM kcv_scenario_revisions WHERE context_id=p_context
   UNION SELECT overlay_graph FROM kcv_personal_operations WHERE context_id=p_context AND overlay');
 l_expected:=l_expected||TO_CLOB('_graph IS NOT NULL);j.put(''overlays'',n);
  SELECT COUNT(*) INTO n FROM (
   SELECT conversation_id FROM kcv_chat_sessions WHERE personal_context_id=p_context
   UNION SELECT model_conversation_id FROM kcv_personal_operations WHERE context_id=p_context AND model_conversation_id IS NOT NULL
   UNION SELECT old_conversation FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context) AND old_conversation IS NOT NULL
   UNION SELECT new_conversation FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION SELECT conversation_id FROM kcv_response_runs WHERE se');
 l_expected:=l_expected||TO_CLOB('ssion_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context));j.put(''model_conversations'',n);
  RETURN j.to_clob();
 END;
 FUNCTION preview(p_context VARCHAR2) RETURN CLOB IS r kcv_personal_contexts%ROWTYPE;j JSON_OBJECT_T:=JSON_OBJECT_T();v VARCHAR2(16);BEGIN
  v:=status(p_context);IF v<>''NONE'' THEN RETURN receipt(p_context);END IF;
  r:=owned(p_context);quiet(p_context);
  j.put(''context_id'',p_context);j.put(''title'',r.title);j.put(''status'',''READY'');j.put(''expected_version'',r.draft_version);j.put(''expected_head'',r.latest_revision);
  j.put(''preview_digest'',inventory_digest(p_context));j.put(''counts'',JSON_OBJECT_T.parse(counts(p_context)));j.put_null(''request_tok');
 l_expected:=l_expected||TO_CLOB('en'');RETURN j.to_clob();
 END;
 PROCEDURE capture_resources(p_context VARCHAR2) IS BEGIN
  INSERT INTO kcv_context_delete_resources(context_id,resource_kind,resource_id)
   SELECT p_context,''OVERLAY'',overlay_graph FROM kcv_scenario_revisions WHERE context_id=p_context
   UNION SELECT p_context,''OVERLAY'',overlay_graph FROM kcv_personal_operations WHERE context_id=p_context AND overlay_graph IS NOT NULL;
  INSERT INTO kcv_context_delete_resources(context_id,resource_kind,resource_id)
   SELECT p_context,''CONVERSATION'',conversation_id FROM kcv_chat_sessions WHERE personal_context_id=p_context
   UNION SELECT p_context,''CONVERSATION'',model_conversation_id FROM kcv_personal_operations WHERE conte');
 l_expected:=l_expected||TO_CLOB('xt_id=p_context AND model_conversation_id IS NOT NULL
   UNION SELECT p_context,''CONVERSATION'',old_conversation FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context) AND old_conversation IS NOT NULL
   UNION SELECT p_context,''CONVERSATION'',new_conversation FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context)
   UNION SELECT p_context,''CONVERSATION'',conversation_id FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
 END;
 PROCEDURE validate_resource(p_context VARCHAR2,p_kind VARCHAR2,');
 l_expected:=l_expected||TO_CLOB('p_id VARCHAR2) IS n NUMBER;BEGIN
  IF p_kind=''OVERLAY'' THEN
   require(REGEXP_LIKE(p_id,''^KCV_O_[A-F0-9]{16}$'',''c''),''DELETE_SCOPE_ERROR: Unexpected private overlay'',-20249);
   SELECT COUNT(*) INTO n FROM (
    SELECT overlay_graph FROM kcv_scenario_revisions WHERE context_id<>p_context AND overlay_graph=p_id
    UNION ALL SELECT base_graph FROM kcv_scenario_revisions WHERE base_graph=p_id
    UNION ALL SELECT overlay_graph FROM kcv_personal_operations WHERE context_id<>p_context AND overlay_graph=p_id
    UNION ALL SELECT target_graph FROM kcv_personal_operations WHERE target_graph=p_id
    UNION ALL SELECT base_graph FROM kcv_personal_contexts WHERE base_graph=p_id
    UNION ALL SELECT gra');
 l_expected:=l_expected||TO_CLOB('ph_name FROM kcv_graph_runs WHERE graph_name=p_id
    UNION ALL SELECT graph_name FROM kcv_graph_sources WHERE graph_name=p_id
    UNION ALL SELECT graph_name FROM kcv_graph_contexts WHERE graph_name=p_id
    UNION ALL SELECT graph_name FROM kcv_domain_runs WHERE graph_name=p_id
    UNION ALL SELECT setting_value FROM kcv_settings WHERE setting_value=p_id
    UNION ALL SELECT resource_id FROM kcv_context_delete_resources WHERE context_id<>p_context AND resource_kind=''OVERLAY'' AND resource_id=p_id);
  ELSE
   SELECT COUNT(*) INTO n FROM (
    SELECT conversation_id FROM kcv_chat_sessions WHERE NVL(personal_context_id,''-'')<>p_context AND conversation_id=p_id
    UNION ALL SELECT model_conversa');
 l_expected:=l_expected||TO_CLOB('tion_id FROM kcv_personal_operations WHERE context_id<>p_context AND model_conversation_id=p_id
    UNION ALL SELECT r.conversation_id FROM kcv_response_runs r JOIN kcv_chat_sessions s ON s.session_id=r.session_id WHERE NVL(s.personal_context_id,''-'')<>p_context AND r.conversation_id=p_id
    UNION ALL SELECT b.new_conversation FROM kcv_model_boundaries b JOIN kcv_chat_sessions s ON s.session_id=b.session_id WHERE NVL(s.personal_context_id,''-'')<>p_context AND (b.new_conversation=p_id OR b.old_conversation=p_id)
    UNION ALL SELECT resource_id FROM kcv_context_delete_resources WHERE context_id<>p_context AND resource_kind=''CONVERSATION'' AND resource_id=p_id);
  END IF;
  require(n=0,''DELETE_S');
 l_expected:=l_expected||TO_CLOB('COPE_ERROR: A resource is referenced outside this context'',-20249);
 END;
 FUNCTION graph_exists(p_id VARCHAR2) RETURN BOOLEAN IS n NUMBER;BEGIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||DBMS_ASSERT.ENQUOTE_NAME($$PLSQL_UNIT_OWNER,FALSE)||''.KCV_NET#SEM_MODEL$ WHERE model_name=:g''
   INTO n USING p_id;
  IF n=0 THEN RETURN FALSE;END IF;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||DBMS_ASSERT.ENQUOTE_NAME($$PLSQL_UNIT_OWNER,FALSE)||''.KCV_NET#SEM_MODEL$ WHERE model_name=:g AND owner=:o AND model_type=''''M''''''
   INTO n USING p_id,$$PLSQL_UNIT_OWNER;
  require(n=1,''DELETE_SCOPE_ERROR: Unexpected native graph owner or type'',-20249);RETURN TRUE;
 END;
 PROCEDURE remove_rows(p_context VARCHAR2,p_');
 l_expected:=l_expected||TO_CLOB('scope VARCHAR2,p_subject VARCHAR2) IS tomb JSON_OBJECT_T:=JSON_OBJECT_T();tomb_json CLOB;BEGIN
  tomb.put(''context_id'',p_context);tomb.put(''status'',''DELETED'');
  tomb_json:=tomb.to_clob();
  UPDATE kcv_context_requests SET result_json=tomb_json WHERE owner_scope=p_scope AND owner_subject=p_subject AND JSON_VALUE(result_json,''$.context_id'')=p_context;
  DELETE FROM kcv_context_attachments WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_response_tool_calls WHERE execution_id IN(SELECT execution');
 l_expected:=l_expected||TO_CLOB('_id FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context));
  DELETE FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_scenario_observations WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_chat_turns WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_scenario_changes WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_scenario_audit WHERE se');
 l_expected:=l_expected||TO_CLOB('ssion_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context);
  DELETE FROM kcv_chat_sessions WHERE personal_context_id=p_context;
  DELETE FROM kcv_personal_operations WHERE context_id=p_context;
  UPDATE kcv_personal_contexts SET latest_revision=NULL,lifecycle=''DRAFT'',prior_lifecycle=NULL WHERE context_id=p_context;
  DELETE FROM kcv_scenario_revisions WHERE context_id=p_context;
  DELETE FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=p_scope AND owner_subject=p_subject;
  require(SQL%ROWCOUNT=1,''DELETE_SCOPE_ERROR: Context owner changed'',-20249);
 END;
 FUNCTION delete_context(p_context VARCHAR2,p_expected_version NUMBER,p_expected_head ');
 l_expected:=l_expected||TO_CLOB('VARCHAR2,p_preview_digest VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
  s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
  r kcv_personal_contexts%ROWTYPE;d kcv_context_deletions%ROWTYPE;locks locks_t;v VARCHAR2(16);n NUMBER;err NUMBER;started BOOLEAN:=FALSE;outcome CLOB;count_json CLOB;
 BEGIN
  kcv_access.assert_writable;
  require(REGEXP_LIKE(p_request_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),''VALIDATION_ERROR: Supply a deletion request token'');
  v:=status(p_context);acquire(''KCV_PERSONAL:''||p_context,locks);v:=status(p_context);
  IF v<>''NONE'' THEN
   SELECT * INTO d FROM kcv_context_deletions WHERE context_id=p_context AND owner_scope=s AND owner_subj');
 l_expected:=l_expected||TO_CLOB('ect=u;
   require(d.request_token=p_request_token AND d.expected_version=p_expected_version AND NVL(d.expected_head,''-'')=NVL(p_expected_head,''-'') AND d.preview_digest=p_preview_digest,
    ''STALE_VERSION: Reload the deletion confirmation before continuing'',-20242);
   IF v=''DELETED'' THEN outcome:=receipt(p_context);release_all(locks);RETURN outcome;END IF;
   started:=TRUE;
  ELSE r:=owned(p_context);END IF;
  FOR x IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=p_context ORDER BY session_id) LOOP acquire(''KCV_CONVERSATION:''||x.session_id,locks);END LOOP;
  IF NOT started THEN
   r:=owned(p_context);quiet(p_context);
   require(r.draft_version=p_expected_version AND NV');
 l_expected:=l_expected||TO_CLOB('L(r.latest_revision,''-'')=NVL(p_expected_head,''-'') AND inventory_digest(p_context)=p_preview_digest,
    ''STALE_VERSION: Context or conversation history changed; review deletion again'',-20242);
   SELECT COUNT(*) INTO n FROM (
    SELECT revision_id FROM kcv_chat_sessions WHERE NVL(personal_context_id,''-'')<>p_context AND revision_id IN(SELECT revision_id FROM kcv_scenario_revisions WHERE context_id=p_context)
    UNION ALL SELECT latest_revision FROM kcv_personal_contexts WHERE context_id<>p_context AND latest_revision IN(SELECT revision_id FROM kcv_scenario_revisions WHERE context_id=p_context)
    UNION ALL SELECT parent_revision FROM kcv_scenario_revisions WHERE context_id<>p_context AND p');
 l_expected:=l_expected||TO_CLOB('arent_revision IN(SELECT revision_id FROM kcv_scenario_revisions WHERE context_id=p_context)
    UNION ALL SELECT r.revision_id FROM kcv_response_runs r JOIN kcv_chat_sessions ss ON ss.session_id=r.session_id WHERE NVL(ss.personal_context_id,''-'')<>p_context AND r.revision_id IN(SELECT revision_id FROM kcv_scenario_revisions WHERE context_id=p_context));
   require(n=0,''DELETE_SCOPE_ERROR: A revision is referenced outside this context'',-20249);
   count_json:=counts(p_context);
   INSERT INTO kcv_context_deletions(context_id,owner_scope,owner_subject,request_token,expected_version,expected_head,preview_digest,title,counts_json)
    VALUES(p_context,s,u,p_request_token,p_expected_version,p_exp');
 l_expected:=l_expected||TO_CLOB('ected_head,p_preview_digest,r.title,count_json);
   capture_resources(p_context);
   FOR x IN(SELECT resource_kind,resource_id FROM kcv_context_delete_resources WHERE context_id=p_context) LOOP validate_resource(p_context,x.resource_kind,x.resource_id);END LOOP;
   COMMIT;started:=TRUE;
  END IF;
  FOR x IN(SELECT resource_kind,resource_id FROM kcv_context_delete_resources WHERE context_id=p_context ORDER BY resource_kind,resource_id) LOOP
   validate_resource(p_context,x.resource_kind,x.resource_id);
   IF x.resource_kind=''OVERLAY'' THEN
    IF graph_exists(x.resource_id) THEN SEM_APIS.DROP_RDF_GRAPH(x.resource_id,network_owner=>$$PLSQL_UNIT_OWNER,network_name=>''KCV_NET'');END IF;
    require');
 l_expected:=l_expected||TO_CLOB('(NOT graph_exists(x.resource_id),''DELETE_PENDING: Private overlay still exists'',-20248);
   ELSE
    DBMS_CLOUD_AI.DROP_CONVERSATION(x.resource_id,force=>TRUE);
    SELECT COUNT(*) INTO n FROM user_cloud_ai_conversations WHERE conversation_id=x.resource_id;
    require(n=0,''DELETE_PENDING: Model conversation still exists'',-20248);
   END IF;
   UPDATE kcv_context_delete_resources SET status=''REMOVED'',finished_at=SYSTIMESTAMP WHERE context_id=p_context AND resource_kind=x.resource_kind AND resource_id=x.resource_id;COMMIT;
  END LOOP;
  remove_rows(p_context,s,u);
  DELETE FROM kcv_context_delete_resources WHERE context_id=p_context;
  UPDATE kcv_context_deletions SET status=''DELETED'',title=N');
 l_expected:=l_expected||TO_CLOB('ULL,error_code=NULL,finished_at=SYSTIMESTAMP WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
  COMMIT;outcome:=receipt(p_context);release_all(locks);RETURN outcome;
 EXCEPTION WHEN OTHERS THEN
  err:=SQLCODE;ROLLBACK;
  IF started THEN
   BEGIN
    UPDATE kcv_context_deletions SET error_code=err WHERE context_id=p_context AND owner_scope=s AND owner_subject=u AND status=''PENDING'';COMMIT;
    outcome:=receipt(p_context);
   EXCEPTION WHEN OTHERS THEN ROLLBACK;release_all(locks);RAISE;END;
   release_all(locks);RETURN outcome;
  END IF;
  release_all(locks);RAISE;
 END;
END;
');
 check_program('KCV_CONTEXT_DELETE','PACKAGE BODY',l_expected);
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id='2.0.0-c3-r5-007-kcv_context_delete-package-body' AND payload_sha256='12550ec30ce70c7aee4e6d1276f3b96fc62b1215f082942c514ada867964531d';
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/
