-- Generated from immutable local SQL; do not edit this wrapper.
DECLARE
 l_sql CLOB; l_hash VARCHAR2(64); l_phase VARCHAR2(16); l_started BOOLEAN:=FALSE;
 l_lock VARCHAR2(128); l_lock_result PLS_INTEGER; l_error NUMBER;

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
 l_lock_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_lock_result=0,'Another schema migration is active');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-r4-001-kcv_response_tool_calls-origin' AND payload_sha256='10e54281cf392ceb2416cd06ac52d5431710851e514fd2902f174ad0518e8814' AND phase='COMPLETE';
 require(l_n=1,'Required prior migration is incomplete: 2.0.0-c3-r4-001-kcv_response_tool_calls-origin');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-r4-002-kcv_response_runs-model-start';
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash='ad5b37015af153bcf94d1d928560db9c6f52e5dedc8e27559ad95ef5282cf880','Migration payload/verification changed: 2.0.0-c3-r4-002-kcv_response_runs-model-start');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: 2.0.0-c3-r4-002-kcv_response_runs-model-start');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_RESPONSE_RUNS","temporary":"N","columns":[{"name":"EXECUTION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"SESSION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"REVISION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"CONVERSATION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"USER_TURN_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"ASSISTANT_TURN_ID","type":"NUMBER","nullable":"Y","iden');
 l_expected:=l_expected||TO_CLOB('tity":"NO","default":null,"precision":null,"scale":null},{"name":"REQUEST_MODE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"QUESTION","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"CONTEXT_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"SOURCES_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"HISTORY_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"PROFILE_NAME","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":nu');
 l_expected:=l_expected||TO_CLOB('ll,"length":32,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"FINISHED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"TRACE_VERSION","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''1.0''","length":32,"char_used":"B"},{"name":"RETRIEVAL_POLICY","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''topic-join-v1;6-pages;2-per-source;40-paths''","length":128,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullab');
 l_expected:=l_expected||TO_CLOB('le":"Y","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"REQUEST_SHA256","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"CONTINUATION_JSON","type":"CLOB","nullable":"Y","identity":"NO","default":null},{"name":"MODEL_STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"EXECUTION_ID"},{"type":"R","columns":"SESSION_ID","reference_table":"KCV_CHAT_SESSIONS","reference_columns":"SESSION_ID"},{"type":"R","columns":"REVISION_ID","reference_table":"KCV_SCENARIO_REVISIONS","reference_columns":"REVISION_ID"},{"type":"R","columns":"USER_TURN_ID","r');
 l_expected:=l_expected||TO_CLOB('eference_table":"KCV_CHAT_TURNS","reference_columns":"TURN_ID"},{"type":"U","columns":"ASSISTANT_TURN_ID"},{"type":"R","columns":"ASSISTANT_TURN_ID","reference_table":"KCV_CHAT_TURNS","reference_columns":"TURN_ID"},{"type":"C","expression":"context_json IS JSON"},{"type":"C","expression":"sources_json IS JSON"},{"type":"C","expression":"history_json IS JSON"},{"type":"C","expression":"continuation_json IS JSON"}]}');
 check_table(l_expected);
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES('2.0.0-c3-r4-002-kcv_response_runs-model-start','ad5b37015af153bcf94d1d928560db9c6f52e5dedc8e27559ad95ef5282cf880','2.0.0','RUNNING');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('');
 l_sql:=l_sql||TO_CLOB('ALTER TABLE kcv_response_runs ADD (
 model_started_at TIMESTAMP WITH TIME ZONE
)');
  EXECUTE IMMEDIATE l_sql;
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_RESPONSE_RUNS","temporary":"N","columns":[{"name":"EXECUTION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"SESSION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"REVISION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"CONVERSATION_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"USER_TURN_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"ASSISTANT_TURN_ID","type":"NUMBER","nullable":"Y","iden');
 l_expected:=l_expected||TO_CLOB('tity":"NO","default":null,"precision":null,"scale":null},{"name":"REQUEST_MODE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"QUESTION","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"CONTEXT_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"SOURCES_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"HISTORY_JSON","type":"CLOB","nullable":"N","identity":"NO","default":null},{"name":"PROFILE_NAME","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":nu');
 l_expected:=l_expected||TO_CLOB('ll,"length":32,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"FINISHED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"TRACE_VERSION","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''1.0''","length":32,"char_used":"B"},{"name":"RETRIEVAL_POLICY","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''topic-join-v1;6-pages;2-per-source;40-paths''","length":128,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullab');
 l_expected:=l_expected||TO_CLOB('le":"Y","identity":"NO","default":null,"length":40,"char_used":"B"},{"name":"REQUEST_SHA256","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"CONTINUATION_JSON","type":"CLOB","nullable":"Y","identity":"NO","default":null},{"name":"MODEL_STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"EXECUTION_ID"},{"type":"R","columns":"SESSION_ID","reference_table":"KCV_CHAT_SESSIONS","reference_columns":"SESSION_ID"},{"type":"R","columns":"REVISION_ID","reference_table":"KCV_SCENARIO_REVISIONS","reference_columns":"REVISION_ID"},{"type":"R","columns":"USER_TURN_ID","r');
 l_expected:=l_expected||TO_CLOB('eference_table":"KCV_CHAT_TURNS","reference_columns":"TURN_ID"},{"type":"U","columns":"ASSISTANT_TURN_ID"},{"type":"R","columns":"ASSISTANT_TURN_ID","reference_table":"KCV_CHAT_TURNS","reference_columns":"TURN_ID"},{"type":"C","expression":"context_json IS JSON"},{"type":"C","expression":"sources_json IS JSON"},{"type":"C","expression":"history_json IS JSON"},{"type":"C","expression":"continuation_json IS JSON"}]}');
 check_table(l_expected);
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id='2.0.0-c3-r4-002-kcv_response_runs-model-start';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id='2.0.0-c3-r4-002-kcv_response_runs-model-start';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;
