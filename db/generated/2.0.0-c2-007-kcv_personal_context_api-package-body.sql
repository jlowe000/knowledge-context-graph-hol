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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.0.0-c2-006-kcv_personal_context_api-package' AND payload_sha256='4623e8027a7c1322905c87cc14037327946c8b96e800f6f7dc5cf539f0081700' AND phase='COMPLETE';
 require(l_n=1,'Required prior migration is incomplete: 2.0.0-c2-006-kcv_personal_context_api-package');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id='2.0.0-c2-007-kcv_personal_context_api-package-body';
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash='2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4','Migration payload/verification changed: 2.0.0-c2-007-kcv_personal_context_api-package-body');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: 2.0.0-c2-007-kcv_personal_context_api-package-body');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA');
 l_expected:=l_expected||TO_CLOB('XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''AL32UTF8''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''ACTIVE_GRAPH'';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR');
 l_expected:=l_expected||TO_CLOB('CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE');
 l_expected:=l_expected||TO_CLOB(' context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''OPERATION_IN_PROGRESS: Another edit is being saved'');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''context_id'',p_row.context_id);j.put(''title'',p_row.title);j.put(''lifecycle'',p_row.lifecycle);
   j.put(''draft_version'',p_row.draft_version);j.put(''latest_revision'',p_row.latest_revision);
   j.put');
 l_expected:=l_expected||TO_CLOB('(''updated_at'',TO_CHAR(p_row.updated_at,''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''topic_preferences'');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''label'',keys(i));topic.put(''weight'',prefs.get_number(keys(i)));topics.append(topic);
    ');
 l_expected:=l_expected||TO_CLOB(' END LOOP;
   END IF;
   j:=summary(r);j.put(''base_graph'',r.base_graph);j.put(''draft'',draft);j.put(''selected_topics'',topics);
   IF r.provenance_json IS NOT NULL THEN j.put(''provenance'',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''edit'',r.lifecycle<>''ARCHIVED'');cap.put(''archive'',r.lifecycle<>''ARCHIVED'');cap.put(''restore'',r.lifecycle=''ARCHIVED'');
   cap.put(''activate'',FALSE);cap.put(''start_conversation'',FALSE);cap.put(''duplicate'',TRUE);
   j.put(''capabilities'',cap);j.put(''feature_stage'',''persistent-drafts'');
   j.put(''notice'',''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sample journeys remain ');
 l_expected:=l_expected||TO_CLOB('available.'');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDA');
 l_expected:=l_expected||TO_CLOB('TION_ERROR: Page size must be 1 to 50'');
   require(status_filter IS NULL OR status_filter IN (''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''VALIDATION_ERROR: Search is limited to 200 characters'');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_');
 l_expected:=l_expected||TO_CLOB('at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''contexts'',a);IF more_rows THEN j.put(''next_cursor'',last_id);ELSE j.put_null(''next_cursor'');END IF;
   j.put(''feature_stage'',''persistent-drafts'');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kc');
 l_expected:=l_expected||TO_CLOB('v_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
         AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'')
         AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label) LOOP
     a.append(t.label);
   END LOOP;
   j.');
 l_expected:=l_expected||TO_CLOB('put(''base_graph'',g);j.put(''topics'',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Supply a JSON context object'');E');
 l_expected:=l_expected||TO_CLOB('ND;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''|''||ks(i)||''|'')>0,''VALIDATION_ERROR: Unknown context field'');value:=j.get(ks(i));
     IF ks(i) IN (''unknowns'',''constraints'') THEN
       require(value.is_array,''VALIDATION_ERROR: Unknowns and constraints must be arrays'');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''VALIDATION_ERROR: At most 20 unknowns or constraints'');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''VALIDATION_ERROR: Each unknown or constraint must be text'');
         require(LENGTH(a.get_string(k))<=500,''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'');
    ');
 l_expected:=l_expected||TO_CLOB('     require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''VALIDATION_ERROR: Each unknown or constraint must be a single line'');
       END LOOP;
     ELSIF ks(i)=''topic_preferences'' THEN
       require(value.is_object,''VALIDATION_ERROR: Topic preferences must be an object'');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''VALIDATION_ERROR: At most 20 topics'');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''INVALID_TOPIC: Topic label is too long'',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''VALIDATION_ERROR: ');
 l_expected:=l_expected||TO_CLOB('Topic weights must be numbers'');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''VALIDATION_ERROR: Topic weights must be 1 to 10'');
         SELECT COUNT(*) INTO n FROM kcv_graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
               AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
           AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$''');
 l_expected:=l_expected||TO_CLOB(')) jt WHERE jt.label=topic_label);
         require(n>0,''INVALID_TOPIC: Choose an evidence topic from the pinned collection'',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''VALIDATION_ERROR: Context fields must be text'');
       max_length:=CASE WHEN ks(i) IN (''question'',''objective'') THEN 2000 WHEN ks(i)=''known_situation'' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''VALIDATION_ERROR: Context field is too long'');
     END IF;
   END LOOP;
   IF NOT j.has(''objective_clarity'') OR j.get_string(''objective_clarity'') IS NULL THEN j.put(''objective_clarity'',''unknown'');END IF;
   requir');
 l_expected:=l_expected||TO_CLOB('e(j.get_string(''objective_clarity'') IN (''unknown'',''emerging'',''defined''),''VALIDATION_ERROR: Choose objective clarity'');
   IF NOT j.has(''topic_preferences'') THEN j.put(''topic_preferences'',JSON_OBJECT_T());END IF;
   IF NOT j.has(''unknowns'') THEN j.put(''unknowns'',JSON_ARRAY_T());END IF;
   IF NOT j.has(''constraints'') THEN j.put(''constraints'',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT C');
 l_expected:=l_expected||TO_CLOB('LOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_CONTEXT_REQUEST:''||s||'':''||u||'':''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,re');
 l_expected:=l_expected||TO_CLOB('lease_on_commit=>TRUE);
   require(lock_result=0,''OPERATION_IN_PROGRESS: Retry after the current action finishes'',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''REQUEST_TOKEN_REUSED: Start a new action with a new token'',-20245);
     require(r.result_json IS NOT NULL,''OPERATION_IN_PROGRESS: The prior request has not completed'',-2024');
 l_expected:=l_expected||TO_CLOB('6);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''VALIDATION_ERROR: Supply a context title up to 200 characters'');
 END;
 FUNCTION');
 l_expected:=l_expected||TO_CLOB(' insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''C''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR');
 l_expected:=l_expected||TO_CLOB('2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''context_id'',p_context);request.put(''title'',p_title);request.put(''body'',p_body);request.put(''expected_version'',p_expected_version);
   IF request_begin(''SAVE_DRAFT'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''STALE_VERSION: New contexts have no saved version'',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_context_row(p_context)');
 l_expected:=l_expected||TO_CLOB(';require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Restore before editing'',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''ARCHIVED'';
     require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before editing'',-20242);
   END IF;
   RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2)');
 l_expected:=l_expected||TO_CLOB(' RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''context_id'',p_context);request.put(''title'',p_title);
   IF request_begin(''DUPLICATE'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''kind'',''owned_context_copy'');provenance.put(''context_id'',r.context_id);provenance.put(''draft_version'',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_request_token,cid);');
 l_expected:=l_expected||TO_CLOB('
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''sample_id'',p_sample);request.put(''title'',p_title);
   IF request_begin(''COPY_SAMPLE'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
  ');
 l_expected:=l_expected||TO_CLOB(' g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Choose an available sample'');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''objective_clarity'',''unknown'');
   IF source.has(''question'') THEN draft.put(''question'',source.get_string(''question''));END IF;
   IF source.has(''learning_purpose'') THEN draft.put(''learning_purpose'',source.get_string(''learning_purpose''));END I');
 l_expected:=l_expected||TO_CLOB('F;
   IF source.has(''topic_preferences'') THEN draft.put(''topic_preferences'',source.get_object(''topic_preferences''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''kind'',''sample_suggestions'');provenance.put(''sample_id'',p_sample);provenance.put(''snapshot_id'',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE');
 l_expected:=l_expected||TO_CLOB(';new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''RESTORE'' ELSE ''ARCHIVE'' END;
   request.put(''context_id'',p_context);request.put(''expected_version'',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''ARCHIVED'',''VALIDATION_ERROR: Context is not archived'');new_state:=NVL(r.prior_lifecycle,''DRAFT'');
   ELSE require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Context is already archived'',-20243);new_state:=''ARCHIVED'';END IF;
   UPDATE kcv_personal_c');
 l_expected:=l_expected||TO_CLOB('ontexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''ARCHIVED'' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before changing its status'',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FU');
 l_expected:=l_expected||TO_CLOB('NCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
END;
');
 check_program('KCV_PERSONAL_CONTEXT_API','PACKAGE BODY',l_expected);
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES('2.0.0-c2-007-kcv_personal_context_api-package-body','2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4','2.0.0','RUNNING');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('');
 l_sql:=l_sql||TO_CLOB('CREATE OR REPLACE PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amou');
 l_sql:=l_sql||TO_CLOB('nt=>DBMS_LOB.LOBMAXSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''AL32UTF8''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''ACTIVE_GRAPH'';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context');
 l_sql:=l_sql||TO_CLOB('_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_perso');
 l_sql:=l_sql||TO_CLOB('nal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''OPERATION_IN_PROGRESS: Another edit is being saved'');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''context_id'',p_row.context_id);j.put(''title'',p_row.title);j.put(''lifecycle'',p_row.lifecycle);
   j.put(''draft_version'',p_row.draft_version);j.put(''latest_revision'',p_row.latest_r');
 l_sql:=l_sql||TO_CLOB('evision);
   j.put(''updated_at'',TO_CHAR(p_row.updated_at,''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''topic_preferences'');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''label'',keys(i));topic.put(''weight'',prefs.get_number(keys(i)));topics.a');
 l_sql:=l_sql||TO_CLOB('ppend(topic);
     END LOOP;
   END IF;
   j:=summary(r);j.put(''base_graph'',r.base_graph);j.put(''draft'',draft);j.put(''selected_topics'',topics);
   IF r.provenance_json IS NOT NULL THEN j.put(''provenance'',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''edit'',r.lifecycle<>''ARCHIVED'');cap.put(''archive'',r.lifecycle<>''ARCHIVED'');cap.put(''restore'',r.lifecycle=''ARCHIVED'');
   cap.put(''activate'',FALSE);cap.put(''start_conversation'',FALSE);cap.put(''duplicate'',TRUE);
   j.put(''capabilities'',cap);j.put(''feature_stage'',''persistent-drafts'');
   j.put(''notice'',''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sampl');
 l_sql:=l_sql||TO_CLOB('e journeys remain available.'');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUN');
 l_sql:=l_sql||TO_CLOB('C(p_limit),''VALIDATION_ERROR: Page size must be 1 to 50'');
   require(status_filter IS NULL OR status_filter IN (''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''VALIDATION_ERROR: Search is limited to 200 characters'');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<c');
 l_sql:=l_sql||TO_CLOB('ursor_row.updated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''contexts'',a);IF more_rows THEN j.put(''next_cursor'',last_id);ELSE j.put_null(''next_cursor'');END IF;
   j.put(''feature_stage'',''persistent-drafts'');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128');
 l_sql:=l_sql||TO_CLOB(');
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
         AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'')
         AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label) LOOP
     a.append(t.label);
');
 l_sql:=l_sql||TO_CLOB('   END LOOP;
   j.put(''base_graph'',g);j.put(''topics'',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Supply a JSON ');
 l_sql:=l_sql||TO_CLOB('context object'');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''|''||ks(i)||''|'')>0,''VALIDATION_ERROR: Unknown context field'');value:=j.get(ks(i));
     IF ks(i) IN (''unknowns'',''constraints'') THEN
       require(value.is_array,''VALIDATION_ERROR: Unknowns and constraints must be arrays'');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''VALIDATION_ERROR: At most 20 unknowns or constraints'');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''VALIDATION_ERROR: Each unknown or constraint must be text'');
         require(LENGTH(a.get_string(k))<=500,''VALIDATION_ERROR: Each unknown or constraint must be at most 500 ');
 l_sql:=l_sql||TO_CLOB('characters'');
         require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''VALIDATION_ERROR: Each unknown or constraint must be a single line'');
       END LOOP;
     ELSIF ks(i)=''topic_preferences'' THEN
       require(value.is_object,''VALIDATION_ERROR: Topic preferences must be an object'');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''VALIDATION_ERROR: At most 20 topics'');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''INVALID_TOPIC: Topic label is too long'',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''');
 l_sql:=l_sql||TO_CLOB('VALIDATION_ERROR: Topic weights must be numbers'');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''VALIDATION_ERROR: Topic weights must be 1 to 10'');
         SELECT COUNT(*) INTO n FROM kcv_graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
               AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
           AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARC');
 l_sql:=l_sql||TO_CLOB('HAR2(200) PATH ''$'')) jt WHERE jt.label=topic_label);
         require(n>0,''INVALID_TOPIC: Choose an evidence topic from the pinned collection'',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''VALIDATION_ERROR: Context fields must be text'');
       max_length:=CASE WHEN ks(i) IN (''question'',''objective'') THEN 2000 WHEN ks(i)=''known_situation'' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''VALIDATION_ERROR: Context field is too long'');
     END IF;
   END LOOP;
   IF NOT j.has(''objective_clarity'') OR j.get_string(''objective_clarity'') IS NULL THEN j.put(''objective_clarity'',''unknown'')');
 l_sql:=l_sql||TO_CLOB(';END IF;
   require(j.get_string(''objective_clarity'') IN (''unknown'',''emerging'',''defined''),''VALIDATION_ERROR: Choose objective clarity'');
   IF NOT j.has(''topic_preferences'') THEN j.put(''topic_preferences'',JSON_OBJECT_T());END IF;
   IF NOT j.has(''unknowns'') THEN j.put(''unknowns'',JSON_ARRAY_T());END IF;
   IF NOT j.has(''constraints'') THEN j.put(''constraints'',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJEC');
 l_sql:=l_sql||TO_CLOB('T_T,p_result OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_CONTEXT_REQUEST:''||s||'':''||u||'':''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_');
 l_sql:=l_sql||TO_CLOB('MODE,timeout=>0,release_on_commit=>TRUE);
   require(lock_result=0,''OPERATION_IN_PROGRESS: Retry after the current action finishes'',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''REQUEST_TOKEN_REUSED: Start a new action with a new token'',-20245);
     require(r.result_json IS NOT NULL,''OPERATION_IN_PROGRESS: The prior request has no');
 l_sql:=l_sql||TO_CLOB('t completed'',-20246);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''VALIDATION_ERROR: Supply a context title up to 200 characters''');
 l_sql:=l_sql||TO_CLOB(');
 END;
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''C''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p');
 l_sql:=l_sql||TO_CLOB('_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''context_id'',p_context);request.put(''title'',p_title);request.put(''body'',p_body);request.put(''expected_version'',p_expected_version);
   IF request_begin(''SAVE_DRAFT'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''STALE_VERSION: New contexts have no saved version'',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_cont');
 l_sql:=l_sql||TO_CLOB('ext_row(p_context);require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Restore before editing'',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''ARCHIVED'';
     require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before editing'',-20242);
   END IF;
   RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_reque');
 l_sql:=l_sql||TO_CLOB('st_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''context_id'',p_context);request.put(''title'',p_title);
   IF request_begin(''DUPLICATE'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''kind'',''owned_context_copy'');provenance.put(''context_id'',r.context_id);provenance.put(''draft_version'',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_r');
 l_sql:=l_sql||TO_CLOB('equest_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''sample_id'',p_sample);request.put(''title'',p_title);
   IF request_begin(''COPY_SAMPLE'',p_request_token,request,result,request_lock) THEN RETURN');
 l_sql:=l_sql||TO_CLOB(' result;END IF;
   g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Choose an available sample'');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''objective_clarity'',''unknown'');
   IF source.has(''question'') THEN draft.put(''question'',source.get_string(''question''));END IF;
   IF source.has(''learning_purpose'') THEN draft.put(''learning_purpose'',source.get_string(''learnin');
 l_sql:=l_sql||TO_CLOB('g_purpose''));END IF;
   IF source.has(''topic_preferences'') THEN draft.put(''topic_preferences'',source.get_object(''topic_preferences''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''kind'',''sample_suggestions'');provenance.put(''sample_id'',p_sample);provenance.put(''snapshot_id'',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_persona');
 l_sql:=l_sql||TO_CLOB('l_contexts%ROWTYPE;new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''RESTORE'' ELSE ''ARCHIVE'' END;
   request.put(''context_id'',p_context);request.put(''expected_version'',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''ARCHIVED'',''VALIDATION_ERROR: Context is not archived'');new_state:=NVL(r.prior_lifecycle,''DRAFT'');
   ELSE require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Context is already archived'',-20243);new_state:=''ARCHIVED'';END IF;
   UPD');
 l_sql:=l_sql||TO_CLOB('ATE kcv_personal_contexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''ARCHIVED'' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before changing its status'',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_tok');
 l_sql:=l_sql||TO_CLOB('en,FALSE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
END;');
  EXECUTE IMMEDIATE l_sql;
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA');
 l_expected:=l_expected||TO_CLOB('XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''AL32UTF8''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''ACTIVE_GRAPH'';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR');
 l_expected:=l_expected||TO_CLOB('CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE');
 l_expected:=l_expected||TO_CLOB(' context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''CONTEXT_UNAVAILABLE: Context is not available to this account'');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''OPERATION_IN_PROGRESS: Another edit is being saved'');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''context_id'',p_row.context_id);j.put(''title'',p_row.title);j.put(''lifecycle'',p_row.lifecycle);
   j.put(''draft_version'',p_row.draft_version);j.put(''latest_revision'',p_row.latest_revision);
   j.put');
 l_expected:=l_expected||TO_CLOB('(''updated_at'',TO_CHAR(p_row.updated_at,''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''topic_preferences'');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''label'',keys(i));topic.put(''weight'',prefs.get_number(keys(i)));topics.append(topic);
    ');
 l_expected:=l_expected||TO_CLOB(' END LOOP;
   END IF;
   j:=summary(r);j.put(''base_graph'',r.base_graph);j.put(''draft'',draft);j.put(''selected_topics'',topics);
   IF r.provenance_json IS NOT NULL THEN j.put(''provenance'',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''edit'',r.lifecycle<>''ARCHIVED'');cap.put(''archive'',r.lifecycle<>''ARCHIVED'');cap.put(''restore'',r.lifecycle=''ARCHIVED'');
   cap.put(''activate'',FALSE);cap.put(''start_conversation'',FALSE);cap.put(''duplicate'',TRUE);
   j.put(''capabilities'',cap);j.put(''feature_stage'',''persistent-drafts'');
   j.put(''notice'',''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sample journeys remain ');
 l_expected:=l_expected||TO_CLOB('available.'');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDA');
 l_expected:=l_expected||TO_CLOB('TION_ERROR: Page size must be 1 to 50'');
   require(status_filter IS NULL OR status_filter IN (''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''VALIDATION_ERROR: Search is limited to 200 characters'');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_');
 l_expected:=l_expected||TO_CLOB('at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''contexts'',a);IF more_rows THEN j.put(''next_cursor'',last_id);ELSE j.put_null(''next_cursor'');END IF;
   j.put(''feature_stage'',''persistent-drafts'');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kc');
 l_expected:=l_expected||TO_CLOB('v_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$'')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
         AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'')
         AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label) LOOP
     a.append(t.label);
   END LOOP;
   j.');
 l_expected:=l_expected||TO_CLOB('put(''base_graph'',g);j.put(''topics'',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Supply a JSON context object'');E');
 l_expected:=l_expected||TO_CLOB('ND;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''|''||ks(i)||''|'')>0,''VALIDATION_ERROR: Unknown context field'');value:=j.get(ks(i));
     IF ks(i) IN (''unknowns'',''constraints'') THEN
       require(value.is_array,''VALIDATION_ERROR: Unknowns and constraints must be arrays'');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''VALIDATION_ERROR: At most 20 unknowns or constraints'');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''VALIDATION_ERROR: Each unknown or constraint must be text'');
         require(LENGTH(a.get_string(k))<=500,''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'');
    ');
 l_expected:=l_expected||TO_CLOB('     require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''VALIDATION_ERROR: Each unknown or constraint must be a single line'');
       END LOOP;
     ELSIF ks(i)=''topic_preferences'' THEN
       require(value.is_object,''VALIDATION_ERROR: Topic preferences must be an object'');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''VALIDATION_ERROR: At most 20 topics'');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''INVALID_TOPIC: Topic label is too long'',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''VALIDATION_ERROR: ');
 l_expected:=l_expected||TO_CLOB('Topic weights must be numbers'');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''VALIDATION_ERROR: Topic weights must be 1 to 10'');
         SELECT COUNT(*) INTO n FROM kcv_graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''$.retrieval_eligible_passage_count'' RETURNING NUMBER) IS NULL
               AND REGEXP_LIKE(gs.version_id,''^S[0-9]+-v'') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
           AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,''$.topics[*]'' COLUMNS(label VARCHAR2(200) PATH ''$''');
 l_expected:=l_expected||TO_CLOB(')) jt WHERE jt.label=topic_label);
         require(n>0,''INVALID_TOPIC: Choose an evidence topic from the pinned collection'',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''VALIDATION_ERROR: Context fields must be text'');
       max_length:=CASE WHEN ks(i) IN (''question'',''objective'') THEN 2000 WHEN ks(i)=''known_situation'' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''VALIDATION_ERROR: Context field is too long'');
     END IF;
   END LOOP;
   IF NOT j.has(''objective_clarity'') OR j.get_string(''objective_clarity'') IS NULL THEN j.put(''objective_clarity'',''unknown'');END IF;
   requir');
 l_expected:=l_expected||TO_CLOB('e(j.get_string(''objective_clarity'') IN (''unknown'',''emerging'',''defined''),''VALIDATION_ERROR: Choose objective clarity'');
   IF NOT j.has(''topic_preferences'') THEN j.put(''topic_preferences'',JSON_OBJECT_T());END IF;
   IF NOT j.has(''unknowns'') THEN j.put(''unknowns'',JSON_ARRAY_T());END IF;
   IF NOT j.has(''constraints'') THEN j.put(''constraints'',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT C');
 l_expected:=l_expected||TO_CLOB('LOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_CONTEXT_REQUEST:''||s||'':''||u||'':''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,re');
 l_expected:=l_expected||TO_CLOB('lease_on_commit=>TRUE);
   require(lock_result=0,''OPERATION_IN_PROGRESS: Retry after the current action finishes'',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''REQUEST_TOKEN_REUSED: Start a new action with a new token'',-20245);
     require(r.result_json IS NOT NULL,''OPERATION_IN_PROGRESS: The prior request has not completed'',-2024');
 l_expected:=l_expected||TO_CLOB('6);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''VALIDATION_ERROR: Supply a context title up to 200 characters'');
 END;
 FUNCTION');
 l_expected:=l_expected||TO_CLOB(' insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''C''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR');
 l_expected:=l_expected||TO_CLOB('2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''context_id'',p_context);request.put(''title'',p_title);request.put(''body'',p_body);request.put(''expected_version'',p_expected_version);
   IF request_begin(''SAVE_DRAFT'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''STALE_VERSION: New contexts have no saved version'',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_context_row(p_context)');
 l_expected:=l_expected||TO_CLOB(';require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Restore before editing'',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''ARCHIVED'';
     require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before editing'',-20242);
   END IF;
   RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2)');
 l_expected:=l_expected||TO_CLOB(' RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''context_id'',p_context);request.put(''title'',p_title);
   IF request_begin(''DUPLICATE'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''kind'',''owned_context_copy'');provenance.put(''context_id'',r.context_id);provenance.put(''draft_version'',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_request_token,cid);');
 l_expected:=l_expected||TO_CLOB('
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''sample_id'',p_sample);request.put(''title'',p_title);
   IF request_begin(''COPY_SAMPLE'',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
  ');
 l_expected:=l_expected||TO_CLOB(' g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''VALIDATION_ERROR: Choose an available sample'');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''objective_clarity'',''unknown'');
   IF source.has(''question'') THEN draft.put(''question'',source.get_string(''question''));END IF;
   IF source.has(''learning_purpose'') THEN draft.put(''learning_purpose'',source.get_string(''learning_purpose''));END I');
 l_expected:=l_expected||TO_CLOB('F;
   IF source.has(''topic_preferences'') THEN draft.put(''topic_preferences'',source.get_object(''topic_preferences''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''kind'',''sample_suggestions'');provenance.put(''sample_id'',p_sample);provenance.put(''snapshot_id'',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE');
 l_expected:=l_expected||TO_CLOB(';new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''RESTORE'' ELSE ''ARCHIVE'' END;
   request.put(''context_id'',p_context);request.put(''expected_version'',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''ARCHIVED'',''VALIDATION_ERROR: Context is not archived'');new_state:=NVL(r.prior_lifecycle,''DRAFT'');
   ELSE require(r.lifecycle<>''ARCHIVED'',''CONTEXT_ARCHIVED: Context is already archived'',-20243);new_state:=''ARCHIVED'';END IF;
   UPDATE kcv_personal_c');
 l_expected:=l_expected||TO_CLOB('ontexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''ARCHIVED'' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''STALE_VERSION: Reload your saved context before changing its status'',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FU');
 l_expected:=l_expected||TO_CLOB('NCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
END;
');
 check_program('KCV_PERSONAL_CONTEXT_API','PACKAGE BODY',l_expected);
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id='2.0.0-c2-007-kcv_personal_context_api-package-body';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id='2.0.0-c2-007-kcv_personal_context_api-package-body';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;
