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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-016-kcv_trace-package-body'
  AND payload_sha256='57cf655b2276cc3cb1142151a4a381314951b2936e57519e8e2730907c154f7d' AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_trace AS
 PROCEDURE own_session(p_session VARCHAR2) IS BEGIN kcv_access.assert_session(p_session);END;
 PROCEDURE assert_run(p_request CLOB) IS sid VARCHAR2(40);eid VARCHAR2(40);n NUMBER;BEGIN
  sid:=JSON_VALUE(p_request,''$.scenario_session'');eid:=JSON_VALUE(p_request,''$.execution_id'');own_session(sid);
  SELECT COUNT(*) INTO n FROM kcv_response_runs r JOIN kcv_chat_sessions s ON s.session_id=r.session_id
   WHERE r.execution_id=eid AND r.session_id=sid AND r.status=''RUNNING''
   AND s.mutation_token=eid AND s.revision_id=r.revision_id
   AND r.request_mode=JSON_VALUE(p_request,''$.task'')
   AND DBMS_LOB.COMPARE(r.question,TO_CLOB(JSON_VALUE(p_request,''$.question'' RETURNING VA');
 l_expected:=l_expected||TO_CLOB('RCHAR2(8000))))=0;
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20170,''Invalid or inactive response execution'');END IF;
 END;
 PROCEDURE record_tool(p_request CLOB,p_tool VARCHAR2,p_output CLOB,p_started TIMESTAMP WITH TIME ZONE,p_error NUMBER DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;eid VARCHAR2(40);j JSON_ELEMENT_T;
 BEGIN
  assert_run(p_request);eid:=JSON_VALUE(p_request,''$.execution_id'');
  IF p_tool NOT IN (''EVIDENCE'',''PROPOSAL'') THEN RAISE_APPLICATION_ERROR(-20171,''Unknown trace tool'');END IF;
  IF p_output IS NOT NULL THEN
   IF DBMS_LOB.GETLENGTH(p_output)>1000000 THEN RAISE_APPLICATION_ERROR(-20172,''Evidence trace exceeds capture limit'');END IF;
   j:=JSON_ELEMENT_T.parse(p_outpu');
 l_expected:=l_expected||TO_CLOB('t);
  END IF;
  INSERT INTO kcv_response_tool_calls(execution_id,tool_name,input_json,output_json,status,error_code,started_at)
   VALUES(eid,p_tool,p_request,p_output,CASE WHEN p_error IS NULL THEN ''SUCCEEDED'' ELSE ''FAILED'' END,p_error,p_started);
  COMMIT;
 EXCEPTION WHEN OTHERS THEN ROLLBACK;RAISE;
 END;
 FUNCTION response_trace(p_session VARCHAR2,p_turn NUMBER) RETURN CLOB IS
  r kcv_response_runs%ROWTYPE;result JSON_OBJECT_T:=JSON_OBJECT_T();obj JSON_OBJECT_T;
  calls JSON_ARRAY_T:=JSON_ARRAY_T();cites JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T;
  ev JSON_ARRAY_T;cit JSON_ARRAY_T;packet JSON_OBJECT_T;row_j JSON_OBJECT_T;
  TYPE seen_t IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(4000);su');
 l_expected:=l_expected||TO_CLOB('pplied seen_t;seen seen_t;
  answer CLOB;clean CLOB;cid VARCHAR2(4000);rev VARCHAR2(40);last_pos NUMBER;parse_state VARCHAR2(32):=''UNAVAILABLE'';
  PROCEDURE visit(p_node JSON_ELEMENT_T,p_depth PLS_INTEGER DEFAULT 0) IS
   o JSON_OBJECT_T;a JSON_ARRAY_T;ks JSON_KEY_LIST;v JSON_ELEMENT_T;id_text VARCHAR2(4000);entry JSON_OBJECT_T;citation_obj JSON_OBJECT_T;
   id_keys JSON_KEY_LIST:=JSON_KEY_LIST(''id'',''passage_id'',''evidence_id'');candidate VARCHAR2(4000);invalid_id BOOLEAN;
  BEGIN
   IF p_depth>32 THEN parse_state:=''PARTIAL'';RETURN;END IF;
   IF p_node.is_object THEN
    o:=TREAT(p_node AS JSON_OBJECT_T);ks:=o.get_keys;
    FOR k IN 1..ks.COUNT LOOP
     v:=o.get(ks(k));
     IF LOWER(ks(k))=''');
 l_expected:=l_expected||TO_CLOB('citations'' THEN
      IF v.is_array THEN
       a:=TREAT(v AS JSON_ARRAY_T);IF parse_state<>''PARTIAL'' THEN parse_state:=''PARSED'';END IF;
       FOR x IN 0..a.get_size-1 LOOP
        id_text:=NULL;v:=a.get(x);
        IF v.is_string THEN id_text:=a.get_string(x);
        ELSIF v.is_object THEN
         citation_obj:=TREAT(v AS JSON_OBJECT_T);invalid_id:=FALSE;
         FOR key_i IN 1..id_keys.COUNT LOOP
          IF citation_obj.has(id_keys(key_i)) THEN
           IF citation_obj.get(id_keys(key_i)).is_string THEN
            candidate:=citation_obj.get_string(id_keys(key_i));
            IF candidate IS NULL OR (id_text IS NOT NULL AND candidate<>id_text) THEN invalid_id:=TRUE;
            E');
 l_expected:=l_expected||TO_CLOB('LSE id_text:=candidate;END IF;
           ELSE invalid_id:=TRUE;END IF;
          END IF;
         END LOOP;
         IF invalid_id THEN id_text:=NULL;END IF;
        END IF;
        IF id_text IS NULL THEN parse_state:=''PARTIAL'';
        ELSIF NOT seen.EXISTS(id_text) THEN
          entry:=JSON_OBJECT_T();entry.put(''id'',id_text);entry.put(''matched'',supplied.EXISTS(id_text));cites.append(entry);seen(id_text):=1;
        END IF;
       END LOOP;
      ELSE parse_state:=''PARTIAL'';END IF;
     ELSE visit(v,p_depth+1);END IF;
    END LOOP;
   ELSIF p_node.is_array THEN
    a:=TREAT(p_node AS JSON_ARRAY_T);FOR x IN 0..a.get_size-1 LOOP visit(a.get(x),p_depth+1);END LOOP;
   END IF;
  END;
 BEGIN
');
 l_expected:=l_expected||TO_CLOB('  own_session(p_session);
  SELECT body,revision_id INTO answer,rev FROM kcv_chat_turns WHERE turn_id=p_turn AND session_id=p_session AND role=''assistant'';
  BEGIN SELECT * INTO r FROM kcv_response_runs WHERE session_id=p_session AND assistant_turn_id=p_turn;
  EXCEPTION WHEN NO_DATA_FOUND THEN
   result.put(''availability'',''LEGACY'');result.put(''revision_id'',rev);
   result.put(''message'',''Saved process details are unavailable for this earlier response. Current evidence is not a historical trace.'');RETURN result.to_clob();END;
  result.put(''availability'',''RECORDED'');result.put(''execution_id'',r.execution_id);result.put(''revision_id'',r.revision_id);
  result.put(''question'',r.question);result.put');
 l_expected:=l_expected||TO_CLOB('(''mode'',r.request_mode);result.put(''status'',r.status);result.put(''conversation_id'',r.conversation_id);
  result.put(''context'',JSON_OBJECT_T.parse(r.context_json));result.put(''sources'',JSON_ARRAY_T.parse(r.sources_json));
  result.put(''history_turn_ids'',JSON_ARRAY_T.parse(r.history_json));result.put(''profile_name'',r.profile_name);
  IF r.continuation_json IS NOT NULL THEN result.put(''supplied_continuation'',JSON_OBJECT_T.parse(r.continuation_json));END IF;
  DECLARE selection JSON_OBJECT_T:=JSON_OBJECT_T();framing JSON_OBJECT_T:=JSON_OBJECT_T.parse(r.context_json);g VARCHAR2(128);BEGIN
   SELECT base_graph INTO g FROM kcv_scenario_revisions WHERE revision_id=r.revision_id;
   selection.put(''co');
 l_expected:=l_expected||TO_CLOB('llection'',g);selection.put(''topics'',framing.get_object(''topic_preferences''));selection.put(''match'',''any selected topic'');selection.put(''weights_used_for_ranking'',FALSE);
   framing.remove(''topic_preferences'');result.put(''selection_context'',selection);result.put(''interpretation_context'',framing);
  END;
  result.put(''started_at'',TO_CHAR(r.started_at,''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''));
  IF r.finished_at IS NOT NULL THEN result.put(''finished_at'',TO_CHAR(r.finished_at,''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''));END IF;
  result.put(''trace_version'',r.trace_version);result.put(''retrieval_policy'',r.retrieval_policy);
  FOR t IN (SELECT * FROM kcv_response_tool_calls WHERE execution_id=r.execution_i');
 l_expected:=l_expected||TO_CLOB('d ORDER BY call_id) LOOP
   obj:=JSON_OBJECT_T();obj.put(''call_id'',t.call_id);obj.put(''tool'',t.tool_name);obj.put(''status'',t.status);
   obj.put(''started_at'',TO_CHAR(t.started_at,''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''));
   obj.put(''finished_at'',TO_CHAR(t.finished_at,''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''));
   IF t.output_json IS NOT NULL THEN
    packet:=JSON_OBJECT_T.parse(t.output_json);obj.put(''output'',packet);
    IF t.tool_name=''EVIDENCE'' AND t.status=''SUCCEEDED'' THEN
     ev:=packet.get_array(''evidence'');FOR i IN 0..ev.get_size-1 LOOP j:=TREAT(ev.get(i) AS JSON_OBJECT_T);supplied(j.get_string(''id'')):=1;END LOOP;
    END IF;
   END IF;
   IF t.error_code IS NOT NULL THEN obj.put(''error_co');
 l_expected:=l_expected||TO_CLOB('de'',t.error_code);END IF;calls.append(obj);
  END LOOP;
  BEGIN
   clean:=REGEXP_REPLACE(answer,''^[[:space:]]+|[[:space:]]+$'','''');
   clean:=REGEXP_REPLACE(clean,''^```(json)?[[:space:]]*'','''',1,1,''i'');
   clean:=REGEXP_REPLACE(clean,''[[:space:]]*```[[:space:]]*$'','''');
   j:=JSON_OBJECT_T.parse(clean);
   visit(j);
  EXCEPTION WHEN OTHERS THEN parse_state:=''UNAVAILABLE'';END;
  result.put(''tool_calls'',calls);result.put(''citations'',cites);result.put(''citation_parse_status'',parse_state);result.put(''citation_parser_version'',''4-explicit-citation-ids'');
  result.put(''notice'',''Recorded application inputs and tool returns, not private reasoning. Citation matches establish traceability, not claim corre');
 l_expected:=l_expected||TO_CLOB('ctness. Prior conversation may influence the answer; this is not a provider prompt archive.'');
  RETURN result.to_clob();
 END;
END;
');
 check_program('KCV_TRACE','PACKAGE BODY',l_expected);
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id='2.0.0-c3-016-kcv_trace-package-body' AND payload_sha256='57cf655b2276cc3cb1142151a4a381314951b2936e57519e8e2730907c154f7d';
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/
