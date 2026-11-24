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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='1.0.0-036-kcv_apex-package-body'
  AND payload_sha256='9c0fe96e01d1fe691b880221fc57a94ca88f1db1d29f4372ddabd08ed9143d50' AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_apex AS
 PROCEDURE dispatch IS
   action VARCHAR2(32):=apex_application.g_x01;sid VARCHAR2(40):=apex_application.g_x02;
   result JSON_OBJECT_T:=JSON_OBJECT_T();status_json CLOB;request JSON_OBJECT_T:=JSON_OBJECT_T();
   arr JSON_ARRAY_T:=JSON_ARRAY_T();row_json JSON_OBJECT_T;body CLOB;off_set PLS_INTEGER:=1;
   plan JSON_OBJECT_T;operation VARCHAR2(32);vocabulary JSON_ARRAY_T:=JSON_ARRAY_T();source_rows JSON_ARRAY_T:=JSON_ARRAY_T();
 PROCEDURE emit(p_body CLOB) IS payload CLOB;pos PLS_INTEGER:=1;BEGIN
   SELECT JSON_SERIALIZE(p_body RETURNING CLOB PRETTY ASCII) INTO payload FROM dual;
   WHILE pos<=DBMS_LOB.GETLENGTH(payload) LOOP htp.prn(DBMS_LOB.SUBSTR(payload,1000,pos));');
 l_expected:=l_expected||TO_CLOB('pos:=pos+1000;END LOOP;
 END;
 BEGIN
   IF SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL OR UPPER(SYS_CONTEXT(''APEX$SESSION'',''APP_USER'')) IN (''NOBODY'',''APEX_PUBLIC_USER'') THEN
     RAISE_APPLICATION_ERROR(-20130,''Sign in to use the knowledge explorer'');END IF;
   IF action=''start'' THEN sid:=kcv_scenario.open_session(apex_application.g_x03);
   ELSE status_json:=kcv_scenario.state(sid);END IF; -- validates signed-in owner and APEX session before every action
   IF action=''trace'' THEN
     result.put(''trace'',JSON_OBJECT_T.parse(kcv_trace.response_trace(sid,TO_NUMBER(apex_application.g_x03))));
     result.put(''ok'',TRUE);emit(result.to_clob());RETURN;
   END IF;
   CASE action
     WHEN ''start');
 l_expected:=l_expected||TO_CLOB(''' THEN NULL;
     WHEN ''state'' THEN NULL;
     WHEN ''ask'' THEN result.put(''reply'',kcv_scenario.ask(sid,apex_application.g_x03,apex_application.g_x04));
     WHEN ''stage'' THEN
       plan:=JSON_OBJECT_T();operation:=apex_application.g_x04;plan.put(''operation'',operation);
       IF operation=''SET_OBJECTIVE'' THEN plan.put(''objective'',apex_application.g_x03);
       ELSE plan.put(''topic'',apex_application.g_x03);END IF;
       result.put(''change'',JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,plan.to_clob())));
     WHEN ''apply'' THEN result.put(''change'',JSON_OBJECT_T.parse(kcv_scenario.apply_change(sid,apex_application.g_x03)));
     WHEN ''observe'' THEN kcv_scenario.observe(sid,apex_applicatio');
 l_expected:=l_expected||TO_CLOB('n.g_x04,apex_application.g_x03,apex_application.g_x05);
     WHEN ''evidence'' THEN NULL;
     ELSE RAISE_APPLICATION_ERROR(-20131,''Unknown explorer action'');
   END CASE;
   status_json:=kcv_scenario.state(sid);result.put(''state'',JSON_OBJECT_T.parse(status_json));
   request.put(''scenario_session'',sid);result.put(''packet'',JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(request.to_clob())));
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) jt
      WHERE gs.graph_name=JSON_VALUE(status_json,''$.base_graph'')
      AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING N');
 l_expected:=l_expected||TO_CLOB('UMBER)>0
        OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
          AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'')
          AND EXISTS (SELECT 1 FROM kcv_passages ep WHERE ep.version_id=gs.version_id)))
      ORDER BY jt.label) LOOP vocabulary.append(t.label);END LOOP;
   result.put(''topics'',vocabulary);
    FOR src IN (SELECT gs.metadata_json FROM kcv_graph_sources gs WHERE gs.graph_name=JSON_VALUE(status_json,''$.base_graph'')
      AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
        OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
          AND REGE');
 l_expected:=l_expected||TO_CLOB('XP_LIKE(gs.version_id,''^S[0-9]+-v'')
          AND EXISTS (SELECT 1 FROM kcv_passages ep WHERE ep.version_id=gs.version_id))) ORDER BY gs.version_id) LOOP
     source_rows.append(JSON_OBJECT_T.parse(src.metadata_json));
   END LOOP;
   result.put(''sources'',source_rows);
   FOR r IN (SELECT * FROM (SELECT role,body,turn_id,revision_id FROM kcv_chat_turns WHERE session_id=sid ORDER BY turn_id DESC FETCH FIRST 20 ROWS ONLY) ORDER BY turn_id) LOOP
     row_json:=JSON_OBJECT_T();row_json.put(''role'',r.role);row_json.put(''body'',r.body);row_json.put(''turn_id'',r.turn_id);row_json.put(''revision_id'',r.revision_id);arr.append(row_json);
   END LOOP;
   result.put(''turns'',arr);result.put(''ok'',TRUE);body:=');
 l_expected:=l_expected||TO_CLOB('result.to_clob();
   emit(body);
 EXCEPTION WHEN OTHERS THEN
   ROLLBACK;result:=JSON_OBJECT_T();result.put(''ok'',FALSE);result.put(''error'',SQLERRM);result.put(''diagnostic'',DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);htp.prn(result.to_string());
 END;
END;
');
 check_program('KCV_APEX','PACKAGE BODY',l_expected);
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id='1.0.0-036-kcv_apex-package-body' AND payload_sha256='9c0fe96e01d1fe691b880221fc57a94ca88f1db1d29f4372ddabd08ed9143d50';
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/
