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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-r6-002-kcv_context_search-package' AND payload_sha256='bd602340ba50fc7a74aa3aee02f08e650a19efb16bebb1c0ebb93a0c664b2d23' AND phase='COMPLETE';
 require(l_n=1,'Required prior migration is incomplete: 2.0.0-c3-r6-002-kcv_context_search-package');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id='2.0.0-c3-r6-003-kcv_context_search-package-body';
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash='3c385a7abaffcd7200be7e5b1bb5729f5ce97b4f352f848e8b71d04dd9c860f1','Migration payload/verification changed: 2.0.0-c3-r6-003-kcv_context_search-package-body');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: 2.0.0-c3-r6-003-kcv_context_search-package-body');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_context_search AS
 c_model CONSTANT VARCHAR2(30):=''KCV_CONTEXT_MINILM'';
 c_model_sha CONSTANT VARCHAR2(64):=''3929907d138051f818619fce3ba054185f748f2739d7a4dbc26e2502dd2499ea'';
 c_chunk_size CONSTANT PLS_INTEGER:=480;
 c_overlap CONSTANT PLS_INTEGER:=64;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION document_text(p_title VARCHAR2,p_body CLOB) RETURN CLOB IS
  j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);a JSON_ARRAY_T;topics JSON_OBJECT_T;keys JSON_KEY_LIST;swap_key VARCHAR2(4000);
  result CLOB;fields SYS.ODCIVARCHAR2LIST:=SYS.ODCIV');
 l_expected:=l_expected||TO_CLOB('ARCHAR2LIST(''question'',''objective'',''known_situation'',''person'',''role'',''organisation'',
    ''learning_purpose'',''time_horizon'',''objective_clarity'');value VARCHAR2(32767);
  PROCEDURE add_line(p_label VARCHAR2,p_value VARCHAR2) IS line VARCHAR2(32767);BEGIN
   IF TRIM(p_value) IS NOT NULL THEN line:=p_label||'': ''||p_value||CHR(10);DBMS_LOB.WRITEAPPEND(result,LENGTH(line),line);END IF;
  END;
 BEGIN
  DBMS_LOB.CREATETEMPORARY(result,TRUE);add_line(''Title'',p_title);
  FOR i IN 1..fields.COUNT LOOP add_line(fields(i),j.get_string(fields(i)));END LOOP;
  fields:=SYS.ODCIVARCHAR2LIST(''unknowns'',''constraints'');
  FOR i IN 1..fields.COUNT LOOP
   IF j.has(fields(i)) THEN a:=j.get_array(fields(i));
    F');
 l_expected:=l_expected||TO_CLOB('OR k IN 0..a.get_size-1 LOOP add_line(fields(i),a.get_string(k));END LOOP;
   END IF;
  END LOOP;
  IF j.has(''topic_preferences'') THEN topics:=j.get_object(''topic_preferences'');keys:=topics.get_keys;
   FOR i IN 1..keys.COUNT LOOP FOR k IN i+1..keys.COUNT LOOP
    IF keys(k)<keys(i) THEN swap_key:=keys(i);keys(i):=keys(k);keys(k):=swap_key;END IF;
   END LOOP;END LOOP;
   FOR i IN 1..keys.COUNT LOOP add_line(''topic'',keys(i)||'' (weight ''||TO_CHAR(topics.get_number(keys(i)),''TM9'',''NLS_NUMERIC_CHARACTERS=''''.,'''''')||'')'');END LOOP;
  END IF;
  RETURN result;
 END;
 FUNCTION objective_preview(p_body CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);BEGIN
  RETURN SUBSTR(REGEXP_R');
 l_expected:=l_expected||TO_CLOB('EPLACE(TRIM(j.get_string(''objective'')),''[[:space:]]+'','' ''),1,240);
 END;
 FUNCTION model_key RETURN VARCHAR2 IS created DATE;BEGIN
  SELECT creation_date INTO created FROM user_mining_models WHERE model_name=c_model;
  RETURN ''v1:''||c_model_sha||'':''||TO_CHAR(created,''YYYYMMDDHH24MISS'');
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION embed(p_text VARCHAR2) RETURN VECTOR IS v VECTOR;dimensions NUMBER;BEGIN
  EXECUTE IMMEDIATE ''SELECT VECTOR_EMBEDDING(KCV_CONTEXT_MINILM USING :text AS data) FROM dual'' INTO v USING p_text;
  SELECT VECTOR_DIMENSION_COUNT(v) INTO dimensions FROM dual;
  require(dimensions=384,''SEARCH_MODEL_INVALID: The local model must produce 384 dimensions'');
 ');
 l_expected:=l_expected||TO_CLOB(' RETURN v;
 END;
 PROCEDURE refresh_row(p_context VARCHAR2) IS
  r kcv_personal_contexts%ROWTYPE;doc CLOB;digest VARCHAR2(64);key VARCHAR2(128):=model_key;
  total NUMBER;current_rows NUMBER;ready_rows NUMBER;offset_chars PLS_INTEGER:=1;chunk_no PLS_INTEGER:=0;piece VARCHAR2(2000);
  v VECTOR;err NUMBER;state VARCHAR2(16);expected_rows NUMBER;
 BEGIN
  SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context FOR UPDATE NOWAIT;
  SELECT COUNT(*) INTO total FROM kcv_context_deletions WHERE context_id=p_context;
  require(total=0,''CONTEXT_DELETING: Search refresh is unavailable during deletion'',-20248);
  doc:=document_text(r.title,r.draft_json);digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.H');
 l_expected:=l_expected||TO_CLOB('ASH(doc,DBMS_CRYPTO.HASH_SH256)));
  expected_rows:=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END;
  SELECT COUNT(*),NVL(SUM(CASE WHEN content_sha256=digest AND model_key=NVL(key,''UNAVAILABLE'') THEN 1 ELSE 0 END),0),
    NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0)
    INTO total,current_rows,ready_rows FROM kcv_context_search_chunks WHERE context_id=p_context;
  IF total=expected_rows AND current_rows=total AND (key IS NULL OR ready_rows=total) THEN
   DBMS_LOB.FREETEMPORARY(doc);RETURN;
  END IF;
  DELETE FROM kcv_context_search_chunks WHERE context_id=p_context;
  LOOP
   chunk_no');
 l_expected:=l_expected||TO_CLOB(':=chunk_no+1;piece:=DBMS_LOB.SUBSTR(doc,c_chunk_size,offset_chars);v:=NULL;err:=NULL;state:=''KEYWORD'';
   IF key IS NOT NULL THEN BEGIN v:=embed(piece);IF v IS NOT NULL THEN state:=''READY'';END IF;
    EXCEPTION WHEN OTHERS THEN err:=SQLCODE;v:=NULL;END;
   END IF;
   INSERT INTO kcv_context_search_chunks(context_id,chunk_no,content_sha256,model_key,chunk_text,embedding,embedding_status,error_code)
    VALUES(p_context,chunk_no,digest,NVL(key,''UNAVAILABLE''),piece,v,state,err);
   EXIT WHEN offset_chars+c_chunk_size-1>=DBMS_LOB.GETLENGTH(doc);
   offset_chars:=offset_chars+c_chunk_size-c_overlap;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(doc);
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc');
 l_expected:=l_expected||TO_CLOB(')=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
 PROCEDURE refresh_context(p_context VARCHAR2) IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  kcv_access.assert_writable;kcv_access.assert_context(p_context);
  lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||p_context,1,1073741823);n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
  require(n IN(0,4),''OPERATION_IN_PROGRESS: Another context operation is running'',-20246);
  kcv_access.assert_context(p_context);refresh_row(p_context);
  IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 PROCEDURE reindex_all');
 l_expected:=l_expected||TO_CLOB(' IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  require(SYS_CONTEXT(''APEX$SESSION'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL
   AND SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,
   ''NOT_AUTHENTICATED: Use the schema owner connection for search maintenance'',-20240);
  kcv_access.assert_writable;
  FOR r IN(SELECT c.context_id FROM kcv_personal_contexts c WHERE NOT EXISTS
    (SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id) ORDER BY c.context_id) LOOP
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||r.context_id,1,1073741823);n:=DBMS_LOCK.REQUES');
 l_expected:=l_expected||TO_CLOB('T(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''OPERATION_IN_PROGRESS: A context is busy; retry search maintenance later'',-20246);
   refresh_row(r.context_id);ignored:=DBMS_LOCK.RELEASE(lock_id);n:=NULL;
  END LOOP;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION keyword_score(p_title VARCHAR2,p_doc CLOB,p_query VARCHAR2) RETURN NUMBER IS
  q VARCHAR2(1000):=LOWER(p_query);t VARCHAR2(1000):=LOWER(p_title);body CLOB:=LOWER(p_doc);token VARCHAR2(1000);score NUMBER:=0;idx PLS_INTEGER:=1;
  seen VARCHAR2(4000):=''|'';
 BEGIN
  IF t=q THEN score:=1000;ELSIF INSTR(t,q)>0 THEN score:=200;END IF;
  IF DBMS_LOB.INSTR(body,q)>0 THEN score:=');
 l_expected:=l_expected||TO_CLOB('score+20;END IF;
  LOOP token:=REGEXP_SUBSTR(q,''[[:alnum:]_]+'',1,idx);EXIT WHEN token IS NULL;idx:=idx+1;
   IF INSTR(seen,''|''||token||''|'')=0 AND INSTR(''|a|an|and|are|as|at|be|by|for|from|how|i|in|is|it|my|of|on|or|that|the|this|to|what|with|'',''|''||token||''|'')=0 THEN
    seen:=seen||token||''|'';
    IF REGEXP_LIKE(t,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+4;END IF;
    IF REGEXP_LIKE(body,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+1;END IF;
   END IF;
  END LOOP;RETURN score;
 END;
 FUNCTION search_contexts(p_status VARCHAR2,p_search VARCHAR2,p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
  s VARCHAR2(128):=kcv_ac');
 l_expected:=l_expected||TO_CLOB('cess.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
  status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));q VARCHAR2(32767):=TRIM(p_search);key VARCHAR2(128):=model_key;
  query_vector VECTOR;doc CLOB;digest VARCHAR2(64);lexical NUMBER;semantic NUMBER;ready_count NUMBER;all_count NUMBER;
  candidates JSON_ARRAY_T:=JSON_ARRAY_T();item JSON_OBJECT_T;payload CLOB;ranked JSON_ARRAY_T:=JSON_ARRAY_T();page JSON_ARRAY_T:=JSON_ARRAY_T();result JSON_OBJECT_T:=JSON_OBJECT_T();
  n NUMBER;total_contexts NUMBER:=0;complete_contexts NUMBER:=0;cursor_rank NUMBER:=0;cursor_seen BOOLEAN:=p_before_id IS NULL;
  page_end NUMBER;more_rows BOOLEAN:=FALSE;last_id VARCHAR2(32);search_mode VARCHAR2(16);no');
 l_expected:=l_expected||TO_CLOB('tice VARCHAR2(1000);query_available BOOLEAN:=FALSE;
 BEGIN
  require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDATION_ERROR: Page size must be 1 to 50'');
  require(status_filter IS NULL OR status_filter IN(''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
  require(q IS NOT NULL AND LENGTH(q)<=200,''VALIDATION_ERROR: Search needs 1 to 200 characters'');
  IF p_before_id IS NOT NULL THEN kcv_access.assert_context(p_before_id);END IF;
  IF key IS NOT NULL THEN BEGIN query_vector:=embed(q);query_available:=query_vector IS NOT NULL;EXCEPTION WHEN OTHERS THEN query_available:=FALSE;END;END IF;
  FOR r IN(SELECT c.* FROM kcv_personal_contexts c WHERE c.owner_sc');
 l_expected:=l_expected||TO_CLOB('ope=s AND c.owner_subject=u
   AND(status_filter IS NULL OR c.lifecycle=status_filter)
   AND NOT EXISTS(SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id)) LOOP
   total_contexts:=total_contexts+1;doc:=document_text(r.title,r.draft_json);
   digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));lexical:=keyword_score(r.title,doc,q);semantic:=NULL;
   IF query_available THEN
    SELECT COUNT(*),NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0),
     MAX(CASE WHEN embedding_status=''READY'' THEN 1-VECTOR_DISTANCE(embedding,query_vector,COSINE) END)
     INTO all_count,ready_count,semantic FROM kcv_context_search_chunks
     WHERE context_id=r.c');
 l_expected:=l_expected||TO_CLOB('ontext_id AND content_sha256=digest AND model_key=key;
    IF all_count=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END
      AND ready_count=all_count THEN complete_contexts:=complete_contexts+1;END IF;
   END IF;
   IF semantic<0.30 THEN semantic:=NULL;END IF;
   IF lexical>0 OR semantic IS NOT NULL THEN
    item:=JSON_OBJECT_T();item.put(''context_id'',r.context_id);item.put(''title'',r.title);item.put(''lifecycle'',r.lifecycle);
    item.put(''draft_version'',r.draft_version);item.put(''latest_revision'',r.latest_revision);item.put_null(''deletion_status'');
    item.put(''updated_at'',TO_CHAR(r.updated_at,''YYYY-MM');
 l_expected:=l_expected||TO_CLOB('-DD"T"HH24:MI:SS.FF6TZH:TZM''));item.put(''objective_preview'',objective_preview(r.draft_json));
    item.put(''lexical'',lexical);IF semantic IS NOT NULL THEN item.put(''semantic'',semantic);ELSE item.put_null(''semantic'');END IF;
    item.put(''title_priority'',CASE WHEN LOWER(r.title)=LOWER(q) THEN 2 WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN 1 ELSE 0 END);
    item.put(''match_reason'',CASE WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN ''Title match''
      WHEN lexical>0 AND semantic IS NOT NULL THEN ''Saved information and similar meaning''
      WHEN lexical>0 THEN ''Saved information match'' ELSE ''Similar meaning'' END);
    candidates.append(item);
   END IF;
   DBMS_LOB.FREETEMPORARY(doc);
  END LOOP;
 ');
 l_expected:=l_expected||TO_CLOB(' payload:=candidates.to_clob();
  FOR r IN(WITH input_rows AS(SELECT x.* FROM JSON_TABLE(payload,''$[*]'' COLUMNS(
    context_id VARCHAR2(32) PATH ''$.context_id'',lexical NUMBER PATH ''$.lexical'',semantic NUMBER PATH ''$.semantic'',
    title_priority NUMBER PATH ''$.title_priority'',updated_at VARCHAR2(40) PATH ''$.updated_at'',item_json CLOB FORMAT JSON PATH ''$'')) x),
   ranks AS(SELECT i.*,ROW_NUMBER() OVER(ORDER BY lexical DESC,updated_at DESC,context_id DESC) lr,
    ROW_NUMBER() OVER(ORDER BY semantic DESC NULLS LAST,updated_at DESC,context_id DESC) vr FROM input_rows i)
   SELECT item_json FROM ranks ORDER BY title_priority DESC,
    (CASE WHEN lexical>0 THEN 1/(60+lr) ELSE 0 END+CASE WHEN sem');
 l_expected:=l_expected||TO_CLOB('antic IS NOT NULL THEN 1/(60+vr) ELSE 0 END) DESC,
    updated_at DESC,context_id DESC) LOOP
   item:=JSON_OBJECT_T.parse(r.item_json);item.remove(''lexical'');item.remove(''semantic'');item.remove(''title_priority'');ranked.append(item);
   IF item.get_string(''context_id'')=p_before_id THEN cursor_rank:=ranked.get_size;cursor_seen:=TRUE;END IF;
  END LOOP;
  IF NOT query_available THEN search_mode:=''KEYWORD'';notice:=''Keyword matches only: the local semantic search model is unavailable.'';
  ELSIF complete_contexts<total_contexts THEN search_mode:=''PARTIAL'';notice:=''Keyword search is complete; semantic search is available only for indexed saved contexts.'';
  ELSE search_mode:=''HYBRID'';notice:=''Searc');
 l_expected:=l_expected||TO_CLOB('h combines words and similar meaning in your titles and latest saved context information.'';END IF;
  IF NOT cursor_seen THEN cursor_rank:=0;notice:=notice||'' Results changed; showing the first page again.'';END IF;
  page_end:=LEAST(cursor_rank+p_limit,ranked.get_size);
  IF cursor_rank<page_end THEN FOR i IN cursor_rank..page_end-1 LOOP item:=TREAT(ranked.get(i) AS JSON_OBJECT_T);page.append(item);last_id:=item.get_string(''context_id'');END LOOP;END IF;
  more_rows:=page_end<ranked.get_size;result.put(''contexts'',page);
  IF more_rows THEN result.put(''next_cursor'',last_id);ELSE result.put_null(''next_cursor'');END IF;
  result.put(''search_mode'',search_mode);result.put(''search_notice'',notice);res');
 l_expected:=l_expected||TO_CLOB('ult.put(''feature_stage'',''personal-contexts'');RETURN result.to_clob();
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
END;
');
 check_program('KCV_CONTEXT_SEARCH','PACKAGE BODY',l_expected);
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES('2.0.0-c3-r6-003-kcv_context_search-package-body','3c385a7abaffcd7200be7e5b1bb5729f5ce97b4f352f848e8b71d04dd9c860f1','2.0.0','RUNNING');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('');
 l_sql:=l_sql||TO_CLOB('CREATE OR REPLACE PACKAGE BODY kcv_context_search AS
 c_model CONSTANT VARCHAR2(30):=''KCV_CONTEXT_MINILM'';
 c_model_sha CONSTANT VARCHAR2(64):=''3929907d138051f818619fce3ba054185f748f2739d7a4dbc26e2502dd2499ea'';
 c_chunk_size CONSTANT PLS_INTEGER:=480;
 c_overlap CONSTANT PLS_INTEGER:=64;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION document_text(p_title VARCHAR2,p_body CLOB) RETURN CLOB IS
  j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);a JSON_ARRAY_T;topics JSON_OBJECT_T;keys JSON_KEY_LIST;swap_key VARCHAR2(4000);
  result CLOB;fields SYS.ODCIVARCH');
 l_sql:=l_sql||TO_CLOB('AR2LIST:=SYS.ODCIVARCHAR2LIST(''question'',''objective'',''known_situation'',''person'',''role'',''organisation'',
    ''learning_purpose'',''time_horizon'',''objective_clarity'');value VARCHAR2(32767);
  PROCEDURE add_line(p_label VARCHAR2,p_value VARCHAR2) IS line VARCHAR2(32767);BEGIN
   IF TRIM(p_value) IS NOT NULL THEN line:=p_label||'': ''||p_value||CHR(10);DBMS_LOB.WRITEAPPEND(result,LENGTH(line),line);END IF;
  END;
 BEGIN
  DBMS_LOB.CREATETEMPORARY(result,TRUE);add_line(''Title'',p_title);
  FOR i IN 1..fields.COUNT LOOP add_line(fields(i),j.get_string(fields(i)));END LOOP;
  fields:=SYS.ODCIVARCHAR2LIST(''unknowns'',''constraints'');
  FOR i IN 1..fields.COUNT LOOP
   IF j.has(fields(i)) THEN a:=j.get_array');
 l_sql:=l_sql||TO_CLOB('(fields(i));
    FOR k IN 0..a.get_size-1 LOOP add_line(fields(i),a.get_string(k));END LOOP;
   END IF;
  END LOOP;
  IF j.has(''topic_preferences'') THEN topics:=j.get_object(''topic_preferences'');keys:=topics.get_keys;
   FOR i IN 1..keys.COUNT LOOP FOR k IN i+1..keys.COUNT LOOP
    IF keys(k)<keys(i) THEN swap_key:=keys(i);keys(i):=keys(k);keys(k):=swap_key;END IF;
   END LOOP;END LOOP;
   FOR i IN 1..keys.COUNT LOOP add_line(''topic'',keys(i)||'' (weight ''||TO_CHAR(topics.get_number(keys(i)),''TM9'',''NLS_NUMERIC_CHARACTERS=''''.,'''''')||'')'');END LOOP;
  END IF;
  RETURN result;
 END;
 FUNCTION objective_preview(p_body CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);BEGIN
  RETU');
 l_sql:=l_sql||TO_CLOB('RN SUBSTR(REGEXP_REPLACE(TRIM(j.get_string(''objective'')),''[[:space:]]+'','' ''),1,240);
 END;
 FUNCTION model_key RETURN VARCHAR2 IS created DATE;BEGIN
  SELECT creation_date INTO created FROM user_mining_models WHERE model_name=c_model;
  RETURN ''v1:''||c_model_sha||'':''||TO_CHAR(created,''YYYYMMDDHH24MISS'');
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION embed(p_text VARCHAR2) RETURN VECTOR IS v VECTOR;dimensions NUMBER;BEGIN
  EXECUTE IMMEDIATE ''SELECT VECTOR_EMBEDDING(KCV_CONTEXT_MINILM USING :text AS data) FROM dual'' INTO v USING p_text;
  SELECT VECTOR_DIMENSION_COUNT(v) INTO dimensions FROM dual;
  require(dimensions=384,''SEARCH_MODEL_INVALID: The local model must produce 3');
 l_sql:=l_sql||TO_CLOB('84 dimensions'');
  RETURN v;
 END;
 PROCEDURE refresh_row(p_context VARCHAR2) IS
  r kcv_personal_contexts%ROWTYPE;doc CLOB;digest VARCHAR2(64);key VARCHAR2(128):=model_key;
  total NUMBER;current_rows NUMBER;ready_rows NUMBER;offset_chars PLS_INTEGER:=1;chunk_no PLS_INTEGER:=0;piece VARCHAR2(2000);
  v VECTOR;err NUMBER;state VARCHAR2(16);expected_rows NUMBER;
 BEGIN
  SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context FOR UPDATE NOWAIT;
  SELECT COUNT(*) INTO total FROM kcv_context_deletions WHERE context_id=p_context;
  require(total=0,''CONTEXT_DELETING: Search refresh is unavailable during deletion'',-20248);
  doc:=document_text(r.title,r.draft_json);digest:=LOWER(RAWT');
 l_sql:=l_sql||TO_CLOB('OHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));
  expected_rows:=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END;
  SELECT COUNT(*),NVL(SUM(CASE WHEN content_sha256=digest AND model_key=NVL(key,''UNAVAILABLE'') THEN 1 ELSE 0 END),0),
    NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0)
    INTO total,current_rows,ready_rows FROM kcv_context_search_chunks WHERE context_id=p_context;
  IF total=expected_rows AND current_rows=total AND (key IS NULL OR ready_rows=total) THEN
   DBMS_LOB.FREETEMPORARY(doc);RETURN;
  END IF;
  DELETE FROM kcv_context_search_chunks WHERE context_id=p_context;
');
 l_sql:=l_sql||TO_CLOB('  LOOP
   chunk_no:=chunk_no+1;piece:=DBMS_LOB.SUBSTR(doc,c_chunk_size,offset_chars);v:=NULL;err:=NULL;state:=''KEYWORD'';
   IF key IS NOT NULL THEN BEGIN v:=embed(piece);IF v IS NOT NULL THEN state:=''READY'';END IF;
    EXCEPTION WHEN OTHERS THEN err:=SQLCODE;v:=NULL;END;
   END IF;
   INSERT INTO kcv_context_search_chunks(context_id,chunk_no,content_sha256,model_key,chunk_text,embedding,embedding_status,error_code)
    VALUES(p_context,chunk_no,digest,NVL(key,''UNAVAILABLE''),piece,v,state,err);
   EXIT WHEN offset_chars+c_chunk_size-1>=DBMS_LOB.GETLENGTH(doc);
   offset_chars:=offset_chars+c_chunk_size-c_overlap;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(doc);
 EXCEPTION WHEN OTHERS THEN IF DBMS_L');
 l_sql:=l_sql||TO_CLOB('OB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
 PROCEDURE refresh_context(p_context VARCHAR2) IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  kcv_access.assert_writable;kcv_access.assert_context(p_context);
  lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||p_context,1,1073741823);n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
  require(n IN(0,4),''OPERATION_IN_PROGRESS: Another context operation is running'',-20246);
  kcv_access.assert_context(p_context);refresh_row(p_context);
  IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 PRO');
 l_sql:=l_sql||TO_CLOB('CEDURE reindex_all IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  require(SYS_CONTEXT(''APEX$SESSION'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL
   AND SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,
   ''NOT_AUTHENTICATED: Use the schema owner connection for search maintenance'',-20240);
  kcv_access.assert_writable;
  FOR r IN(SELECT c.context_id FROM kcv_personal_contexts c WHERE NOT EXISTS
    (SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id) ORDER BY c.context_id) LOOP
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||r.context_id,1,1073741823);n');
 l_sql:=l_sql||TO_CLOB(':=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''OPERATION_IN_PROGRESS: A context is busy; retry search maintenance later'',-20246);
   refresh_row(r.context_id);ignored:=DBMS_LOCK.RELEASE(lock_id);n:=NULL;
  END LOOP;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION keyword_score(p_title VARCHAR2,p_doc CLOB,p_query VARCHAR2) RETURN NUMBER IS
  q VARCHAR2(1000):=LOWER(p_query);t VARCHAR2(1000):=LOWER(p_title);body CLOB:=LOWER(p_doc);token VARCHAR2(1000);score NUMBER:=0;idx PLS_INTEGER:=1;
  seen VARCHAR2(4000):=''|'';
 BEGIN
  IF t=q THEN score:=1000;ELSIF INSTR(t,q)>0 THEN score:=200;END IF;
  IF DBMS_LOB.INSTR(body');
 l_sql:=l_sql||TO_CLOB(',q)>0 THEN score:=score+20;END IF;
  LOOP token:=REGEXP_SUBSTR(q,''[[:alnum:]_]+'',1,idx);EXIT WHEN token IS NULL;idx:=idx+1;
   IF INSTR(seen,''|''||token||''|'')=0 AND INSTR(''|a|an|and|are|as|at|be|by|for|from|how|i|in|is|it|my|of|on|or|that|the|this|to|what|with|'',''|''||token||''|'')=0 THEN
    seen:=seen||token||''|'';
    IF REGEXP_LIKE(t,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+4;END IF;
    IF REGEXP_LIKE(body,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+1;END IF;
   END IF;
  END LOOP;RETURN score;
 END;
 FUNCTION search_contexts(p_status VARCHAR2,p_search VARCHAR2,p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
  s VAR');
 l_sql:=l_sql||TO_CLOB('CHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
  status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));q VARCHAR2(32767):=TRIM(p_search);key VARCHAR2(128):=model_key;
  query_vector VECTOR;doc CLOB;digest VARCHAR2(64);lexical NUMBER;semantic NUMBER;ready_count NUMBER;all_count NUMBER;
  candidates JSON_ARRAY_T:=JSON_ARRAY_T();item JSON_OBJECT_T;payload CLOB;ranked JSON_ARRAY_T:=JSON_ARRAY_T();page JSON_ARRAY_T:=JSON_ARRAY_T();result JSON_OBJECT_T:=JSON_OBJECT_T();
  n NUMBER;total_contexts NUMBER:=0;complete_contexts NUMBER:=0;cursor_rank NUMBER:=0;cursor_seen BOOLEAN:=p_before_id IS NULL;
  page_end NUMBER;more_rows BOOLEAN:=FALSE;last_id VARCHAR2(32);search_mo');
 l_sql:=l_sql||TO_CLOB('de VARCHAR2(16);notice VARCHAR2(1000);query_available BOOLEAN:=FALSE;
 BEGIN
  require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDATION_ERROR: Page size must be 1 to 50'');
  require(status_filter IS NULL OR status_filter IN(''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
  require(q IS NOT NULL AND LENGTH(q)<=200,''VALIDATION_ERROR: Search needs 1 to 200 characters'');
  IF p_before_id IS NOT NULL THEN kcv_access.assert_context(p_before_id);END IF;
  IF key IS NOT NULL THEN BEGIN query_vector:=embed(q);query_available:=query_vector IS NOT NULL;EXCEPTION WHEN OTHERS THEN query_available:=FALSE;END;END IF;
  FOR r IN(SELECT c.* FROM kcv_personal_contexts ');
 l_sql:=l_sql||TO_CLOB('c WHERE c.owner_scope=s AND c.owner_subject=u
   AND(status_filter IS NULL OR c.lifecycle=status_filter)
   AND NOT EXISTS(SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id)) LOOP
   total_contexts:=total_contexts+1;doc:=document_text(r.title,r.draft_json);
   digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));lexical:=keyword_score(r.title,doc,q);semantic:=NULL;
   IF query_available THEN
    SELECT COUNT(*),NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0),
     MAX(CASE WHEN embedding_status=''READY'' THEN 1-VECTOR_DISTANCE(embedding,query_vector,COSINE) END)
     INTO all_count,ready_count,semantic FROM kcv_context_search_chunks
     WH');
 l_sql:=l_sql||TO_CLOB('ERE context_id=r.context_id AND content_sha256=digest AND model_key=key;
    IF all_count=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END
      AND ready_count=all_count THEN complete_contexts:=complete_contexts+1;END IF;
   END IF;
   IF semantic<0.30 THEN semantic:=NULL;END IF;
   IF lexical>0 OR semantic IS NOT NULL THEN
    item:=JSON_OBJECT_T();item.put(''context_id'',r.context_id);item.put(''title'',r.title);item.put(''lifecycle'',r.lifecycle);
    item.put(''draft_version'',r.draft_version);item.put(''latest_revision'',r.latest_revision);item.put_null(''deletion_status'');
    item.put(''updated_at'',TO_CHAR(r.u');
 l_sql:=l_sql||TO_CLOB('pdated_at,''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''));item.put(''objective_preview'',objective_preview(r.draft_json));
    item.put(''lexical'',lexical);IF semantic IS NOT NULL THEN item.put(''semantic'',semantic);ELSE item.put_null(''semantic'');END IF;
    item.put(''title_priority'',CASE WHEN LOWER(r.title)=LOWER(q) THEN 2 WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN 1 ELSE 0 END);
    item.put(''match_reason'',CASE WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN ''Title match''
      WHEN lexical>0 AND semantic IS NOT NULL THEN ''Saved information and similar meaning''
      WHEN lexical>0 THEN ''Saved information match'' ELSE ''Similar meaning'' END);
    candidates.append(item);
   END IF;
   DBMS_LOB.FREETEMPORARY(d');
 l_sql:=l_sql||TO_CLOB('oc);
  END LOOP;
  payload:=candidates.to_clob();
  FOR r IN(WITH input_rows AS(SELECT x.* FROM JSON_TABLE(payload,''$[*]'' COLUMNS(
    context_id VARCHAR2(32) PATH ''$.context_id'',lexical NUMBER PATH ''$.lexical'',semantic NUMBER PATH ''$.semantic'',
    title_priority NUMBER PATH ''$.title_priority'',updated_at VARCHAR2(40) PATH ''$.updated_at'',item_json CLOB FORMAT JSON PATH ''$'')) x),
   ranks AS(SELECT i.*,ROW_NUMBER() OVER(ORDER BY lexical DESC,updated_at DESC,context_id DESC) lr,
    ROW_NUMBER() OVER(ORDER BY semantic DESC NULLS LAST,updated_at DESC,context_id DESC) vr FROM input_rows i)
   SELECT item_json FROM ranks ORDER BY title_priority DESC,
    (CASE WHEN lexical>0 THEN 1/(60+lr) ELSE 0');
 l_sql:=l_sql||TO_CLOB(' END+CASE WHEN semantic IS NOT NULL THEN 1/(60+vr) ELSE 0 END) DESC,
    updated_at DESC,context_id DESC) LOOP
   item:=JSON_OBJECT_T.parse(r.item_json);item.remove(''lexical'');item.remove(''semantic'');item.remove(''title_priority'');ranked.append(item);
   IF item.get_string(''context_id'')=p_before_id THEN cursor_rank:=ranked.get_size;cursor_seen:=TRUE;END IF;
  END LOOP;
  IF NOT query_available THEN search_mode:=''KEYWORD'';notice:=''Keyword matches only: the local semantic search model is unavailable.'';
  ELSIF complete_contexts<total_contexts THEN search_mode:=''PARTIAL'';notice:=''Keyword search is complete; semantic search is available only for indexed saved contexts.'';
  ELSE search_mode:=''HYBR');
 l_sql:=l_sql||TO_CLOB('ID'';notice:=''Search combines words and similar meaning in your titles and latest saved context information.'';END IF;
  IF NOT cursor_seen THEN cursor_rank:=0;notice:=notice||'' Results changed; showing the first page again.'';END IF;
  page_end:=LEAST(cursor_rank+p_limit,ranked.get_size);
  IF cursor_rank<page_end THEN FOR i IN cursor_rank..page_end-1 LOOP item:=TREAT(ranked.get(i) AS JSON_OBJECT_T);page.append(item);last_id:=item.get_string(''context_id'');END LOOP;END IF;
  more_rows:=page_end<ranked.get_size;result.put(''contexts'',page);
  IF more_rows THEN result.put(''next_cursor'',last_id);ELSE result.put_null(''next_cursor'');END IF;
  result.put(''search_mode'',search_mode);result.put(''search_n');
 l_sql:=l_sql||TO_CLOB('otice'',notice);result.put(''feature_stage'',''personal-contexts'');RETURN result.to_clob();
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
END;');
  EXECUTE IMMEDIATE l_sql;
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_context_search AS
 c_model CONSTANT VARCHAR2(30):=''KCV_CONTEXT_MINILM'';
 c_model_sha CONSTANT VARCHAR2(64):=''3929907d138051f818619fce3ba054185f748f2739d7a4dbc26e2502dd2499ea'';
 c_chunk_size CONSTANT PLS_INTEGER:=480;
 c_overlap CONSTANT PLS_INTEGER:=64;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION document_text(p_title VARCHAR2,p_body CLOB) RETURN CLOB IS
  j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);a JSON_ARRAY_T;topics JSON_OBJECT_T;keys JSON_KEY_LIST;swap_key VARCHAR2(4000);
  result CLOB;fields SYS.ODCIVARCHAR2LIST:=SYS.ODCIV');
 l_expected:=l_expected||TO_CLOB('ARCHAR2LIST(''question'',''objective'',''known_situation'',''person'',''role'',''organisation'',
    ''learning_purpose'',''time_horizon'',''objective_clarity'');value VARCHAR2(32767);
  PROCEDURE add_line(p_label VARCHAR2,p_value VARCHAR2) IS line VARCHAR2(32767);BEGIN
   IF TRIM(p_value) IS NOT NULL THEN line:=p_label||'': ''||p_value||CHR(10);DBMS_LOB.WRITEAPPEND(result,LENGTH(line),line);END IF;
  END;
 BEGIN
  DBMS_LOB.CREATETEMPORARY(result,TRUE);add_line(''Title'',p_title);
  FOR i IN 1..fields.COUNT LOOP add_line(fields(i),j.get_string(fields(i)));END LOOP;
  fields:=SYS.ODCIVARCHAR2LIST(''unknowns'',''constraints'');
  FOR i IN 1..fields.COUNT LOOP
   IF j.has(fields(i)) THEN a:=j.get_array(fields(i));
    F');
 l_expected:=l_expected||TO_CLOB('OR k IN 0..a.get_size-1 LOOP add_line(fields(i),a.get_string(k));END LOOP;
   END IF;
  END LOOP;
  IF j.has(''topic_preferences'') THEN topics:=j.get_object(''topic_preferences'');keys:=topics.get_keys;
   FOR i IN 1..keys.COUNT LOOP FOR k IN i+1..keys.COUNT LOOP
    IF keys(k)<keys(i) THEN swap_key:=keys(i);keys(i):=keys(k);keys(k):=swap_key;END IF;
   END LOOP;END LOOP;
   FOR i IN 1..keys.COUNT LOOP add_line(''topic'',keys(i)||'' (weight ''||TO_CHAR(topics.get_number(keys(i)),''TM9'',''NLS_NUMERIC_CHARACTERS=''''.,'''''')||'')'');END LOOP;
  END IF;
  RETURN result;
 END;
 FUNCTION objective_preview(p_body CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);BEGIN
  RETURN SUBSTR(REGEXP_R');
 l_expected:=l_expected||TO_CLOB('EPLACE(TRIM(j.get_string(''objective'')),''[[:space:]]+'','' ''),1,240);
 END;
 FUNCTION model_key RETURN VARCHAR2 IS created DATE;BEGIN
  SELECT creation_date INTO created FROM user_mining_models WHERE model_name=c_model;
  RETURN ''v1:''||c_model_sha||'':''||TO_CHAR(created,''YYYYMMDDHH24MISS'');
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION embed(p_text VARCHAR2) RETURN VECTOR IS v VECTOR;dimensions NUMBER;BEGIN
  EXECUTE IMMEDIATE ''SELECT VECTOR_EMBEDDING(KCV_CONTEXT_MINILM USING :text AS data) FROM dual'' INTO v USING p_text;
  SELECT VECTOR_DIMENSION_COUNT(v) INTO dimensions FROM dual;
  require(dimensions=384,''SEARCH_MODEL_INVALID: The local model must produce 384 dimensions'');
 ');
 l_expected:=l_expected||TO_CLOB(' RETURN v;
 END;
 PROCEDURE refresh_row(p_context VARCHAR2) IS
  r kcv_personal_contexts%ROWTYPE;doc CLOB;digest VARCHAR2(64);key VARCHAR2(128):=model_key;
  total NUMBER;current_rows NUMBER;ready_rows NUMBER;offset_chars PLS_INTEGER:=1;chunk_no PLS_INTEGER:=0;piece VARCHAR2(2000);
  v VECTOR;err NUMBER;state VARCHAR2(16);expected_rows NUMBER;
 BEGIN
  SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context FOR UPDATE NOWAIT;
  SELECT COUNT(*) INTO total FROM kcv_context_deletions WHERE context_id=p_context;
  require(total=0,''CONTEXT_DELETING: Search refresh is unavailable during deletion'',-20248);
  doc:=document_text(r.title,r.draft_json);digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.H');
 l_expected:=l_expected||TO_CLOB('ASH(doc,DBMS_CRYPTO.HASH_SH256)));
  expected_rows:=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END;
  SELECT COUNT(*),NVL(SUM(CASE WHEN content_sha256=digest AND model_key=NVL(key,''UNAVAILABLE'') THEN 1 ELSE 0 END),0),
    NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0)
    INTO total,current_rows,ready_rows FROM kcv_context_search_chunks WHERE context_id=p_context;
  IF total=expected_rows AND current_rows=total AND (key IS NULL OR ready_rows=total) THEN
   DBMS_LOB.FREETEMPORARY(doc);RETURN;
  END IF;
  DELETE FROM kcv_context_search_chunks WHERE context_id=p_context;
  LOOP
   chunk_no');
 l_expected:=l_expected||TO_CLOB(':=chunk_no+1;piece:=DBMS_LOB.SUBSTR(doc,c_chunk_size,offset_chars);v:=NULL;err:=NULL;state:=''KEYWORD'';
   IF key IS NOT NULL THEN BEGIN v:=embed(piece);IF v IS NOT NULL THEN state:=''READY'';END IF;
    EXCEPTION WHEN OTHERS THEN err:=SQLCODE;v:=NULL;END;
   END IF;
   INSERT INTO kcv_context_search_chunks(context_id,chunk_no,content_sha256,model_key,chunk_text,embedding,embedding_status,error_code)
    VALUES(p_context,chunk_no,digest,NVL(key,''UNAVAILABLE''),piece,v,state,err);
   EXIT WHEN offset_chars+c_chunk_size-1>=DBMS_LOB.GETLENGTH(doc);
   offset_chars:=offset_chars+c_chunk_size-c_overlap;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(doc);
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc');
 l_expected:=l_expected||TO_CLOB(')=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
 PROCEDURE refresh_context(p_context VARCHAR2) IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  kcv_access.assert_writable;kcv_access.assert_context(p_context);
  lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||p_context,1,1073741823);n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
  require(n IN(0,4),''OPERATION_IN_PROGRESS: Another context operation is running'',-20246);
  kcv_access.assert_context(p_context);refresh_row(p_context);
  IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 PROCEDURE reindex_all');
 l_expected:=l_expected||TO_CLOB(' IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  require(SYS_CONTEXT(''APEX$SESSION'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL
   AND SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,
   ''NOT_AUTHENTICATED: Use the schema owner connection for search maintenance'',-20240);
  kcv_access.assert_writable;
  FOR r IN(SELECT c.context_id FROM kcv_personal_contexts c WHERE NOT EXISTS
    (SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id) ORDER BY c.context_id) LOOP
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||r.context_id,1,1073741823);n:=DBMS_LOCK.REQUES');
 l_expected:=l_expected||TO_CLOB('T(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''OPERATION_IN_PROGRESS: A context is busy; retry search maintenance later'',-20246);
   refresh_row(r.context_id);ignored:=DBMS_LOCK.RELEASE(lock_id);n:=NULL;
  END LOOP;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION keyword_score(p_title VARCHAR2,p_doc CLOB,p_query VARCHAR2) RETURN NUMBER IS
  q VARCHAR2(1000):=LOWER(p_query);t VARCHAR2(1000):=LOWER(p_title);body CLOB:=LOWER(p_doc);token VARCHAR2(1000);score NUMBER:=0;idx PLS_INTEGER:=1;
  seen VARCHAR2(4000):=''|'';
 BEGIN
  IF t=q THEN score:=1000;ELSIF INSTR(t,q)>0 THEN score:=200;END IF;
  IF DBMS_LOB.INSTR(body,q)>0 THEN score:=');
 l_expected:=l_expected||TO_CLOB('score+20;END IF;
  LOOP token:=REGEXP_SUBSTR(q,''[[:alnum:]_]+'',1,idx);EXIT WHEN token IS NULL;idx:=idx+1;
   IF INSTR(seen,''|''||token||''|'')=0 AND INSTR(''|a|an|and|are|as|at|be|by|for|from|how|i|in|is|it|my|of|on|or|that|the|this|to|what|with|'',''|''||token||''|'')=0 THEN
    seen:=seen||token||''|'';
    IF REGEXP_LIKE(t,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+4;END IF;
    IF REGEXP_LIKE(body,''(^|[^[:alnum:]_])''||token||''([^[:alnum:]_]|$)'') THEN score:=score+1;END IF;
   END IF;
  END LOOP;RETURN score;
 END;
 FUNCTION search_contexts(p_status VARCHAR2,p_search VARCHAR2,p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
  s VARCHAR2(128):=kcv_ac');
 l_expected:=l_expected||TO_CLOB('cess.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
  status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));q VARCHAR2(32767):=TRIM(p_search);key VARCHAR2(128):=model_key;
  query_vector VECTOR;doc CLOB;digest VARCHAR2(64);lexical NUMBER;semantic NUMBER;ready_count NUMBER;all_count NUMBER;
  candidates JSON_ARRAY_T:=JSON_ARRAY_T();item JSON_OBJECT_T;payload CLOB;ranked JSON_ARRAY_T:=JSON_ARRAY_T();page JSON_ARRAY_T:=JSON_ARRAY_T();result JSON_OBJECT_T:=JSON_OBJECT_T();
  n NUMBER;total_contexts NUMBER:=0;complete_contexts NUMBER:=0;cursor_rank NUMBER:=0;cursor_seen BOOLEAN:=p_before_id IS NULL;
  page_end NUMBER;more_rows BOOLEAN:=FALSE;last_id VARCHAR2(32);search_mode VARCHAR2(16);no');
 l_expected:=l_expected||TO_CLOB('tice VARCHAR2(1000);query_available BOOLEAN:=FALSE;
 BEGIN
  require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDATION_ERROR: Page size must be 1 to 50'');
  require(status_filter IS NULL OR status_filter IN(''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
  require(q IS NOT NULL AND LENGTH(q)<=200,''VALIDATION_ERROR: Search needs 1 to 200 characters'');
  IF p_before_id IS NOT NULL THEN kcv_access.assert_context(p_before_id);END IF;
  IF key IS NOT NULL THEN BEGIN query_vector:=embed(q);query_available:=query_vector IS NOT NULL;EXCEPTION WHEN OTHERS THEN query_available:=FALSE;END;END IF;
  FOR r IN(SELECT c.* FROM kcv_personal_contexts c WHERE c.owner_sc');
 l_expected:=l_expected||TO_CLOB('ope=s AND c.owner_subject=u
   AND(status_filter IS NULL OR c.lifecycle=status_filter)
   AND NOT EXISTS(SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id)) LOOP
   total_contexts:=total_contexts+1;doc:=document_text(r.title,r.draft_json);
   digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));lexical:=keyword_score(r.title,doc,q);semantic:=NULL;
   IF query_available THEN
    SELECT COUNT(*),NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0),
     MAX(CASE WHEN embedding_status=''READY'' THEN 1-VECTOR_DISTANCE(embedding,query_vector,COSINE) END)
     INTO all_count,ready_count,semantic FROM kcv_context_search_chunks
     WHERE context_id=r.c');
 l_expected:=l_expected||TO_CLOB('ontext_id AND content_sha256=digest AND model_key=key;
    IF all_count=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END
      AND ready_count=all_count THEN complete_contexts:=complete_contexts+1;END IF;
   END IF;
   IF semantic<0.30 THEN semantic:=NULL;END IF;
   IF lexical>0 OR semantic IS NOT NULL THEN
    item:=JSON_OBJECT_T();item.put(''context_id'',r.context_id);item.put(''title'',r.title);item.put(''lifecycle'',r.lifecycle);
    item.put(''draft_version'',r.draft_version);item.put(''latest_revision'',r.latest_revision);item.put_null(''deletion_status'');
    item.put(''updated_at'',TO_CHAR(r.updated_at,''YYYY-MM');
 l_expected:=l_expected||TO_CLOB('-DD"T"HH24:MI:SS.FF6TZH:TZM''));item.put(''objective_preview'',objective_preview(r.draft_json));
    item.put(''lexical'',lexical);IF semantic IS NOT NULL THEN item.put(''semantic'',semantic);ELSE item.put_null(''semantic'');END IF;
    item.put(''title_priority'',CASE WHEN LOWER(r.title)=LOWER(q) THEN 2 WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN 1 ELSE 0 END);
    item.put(''match_reason'',CASE WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN ''Title match''
      WHEN lexical>0 AND semantic IS NOT NULL THEN ''Saved information and similar meaning''
      WHEN lexical>0 THEN ''Saved information match'' ELSE ''Similar meaning'' END);
    candidates.append(item);
   END IF;
   DBMS_LOB.FREETEMPORARY(doc);
  END LOOP;
 ');
 l_expected:=l_expected||TO_CLOB(' payload:=candidates.to_clob();
  FOR r IN(WITH input_rows AS(SELECT x.* FROM JSON_TABLE(payload,''$[*]'' COLUMNS(
    context_id VARCHAR2(32) PATH ''$.context_id'',lexical NUMBER PATH ''$.lexical'',semantic NUMBER PATH ''$.semantic'',
    title_priority NUMBER PATH ''$.title_priority'',updated_at VARCHAR2(40) PATH ''$.updated_at'',item_json CLOB FORMAT JSON PATH ''$'')) x),
   ranks AS(SELECT i.*,ROW_NUMBER() OVER(ORDER BY lexical DESC,updated_at DESC,context_id DESC) lr,
    ROW_NUMBER() OVER(ORDER BY semantic DESC NULLS LAST,updated_at DESC,context_id DESC) vr FROM input_rows i)
   SELECT item_json FROM ranks ORDER BY title_priority DESC,
    (CASE WHEN lexical>0 THEN 1/(60+lr) ELSE 0 END+CASE WHEN sem');
 l_expected:=l_expected||TO_CLOB('antic IS NOT NULL THEN 1/(60+vr) ELSE 0 END) DESC,
    updated_at DESC,context_id DESC) LOOP
   item:=JSON_OBJECT_T.parse(r.item_json);item.remove(''lexical'');item.remove(''semantic'');item.remove(''title_priority'');ranked.append(item);
   IF item.get_string(''context_id'')=p_before_id THEN cursor_rank:=ranked.get_size;cursor_seen:=TRUE;END IF;
  END LOOP;
  IF NOT query_available THEN search_mode:=''KEYWORD'';notice:=''Keyword matches only: the local semantic search model is unavailable.'';
  ELSIF complete_contexts<total_contexts THEN search_mode:=''PARTIAL'';notice:=''Keyword search is complete; semantic search is available only for indexed saved contexts.'';
  ELSE search_mode:=''HYBRID'';notice:=''Searc');
 l_expected:=l_expected||TO_CLOB('h combines words and similar meaning in your titles and latest saved context information.'';END IF;
  IF NOT cursor_seen THEN cursor_rank:=0;notice:=notice||'' Results changed; showing the first page again.'';END IF;
  page_end:=LEAST(cursor_rank+p_limit,ranked.get_size);
  IF cursor_rank<page_end THEN FOR i IN cursor_rank..page_end-1 LOOP item:=TREAT(ranked.get(i) AS JSON_OBJECT_T);page.append(item);last_id:=item.get_string(''context_id'');END LOOP;END IF;
  more_rows:=page_end<ranked.get_size;result.put(''contexts'',page);
  IF more_rows THEN result.put(''next_cursor'',last_id);ELSE result.put_null(''next_cursor'');END IF;
  result.put(''search_mode'',search_mode);result.put(''search_notice'',notice);res');
 l_expected:=l_expected||TO_CLOB('ult.put(''feature_stage'',''personal-contexts'');RETURN result.to_clob();
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
END;
');
 check_program('KCV_CONTEXT_SEARCH','PACKAGE BODY',l_expected);
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id='2.0.0-c3-r6-003-kcv_context_search-package-body';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id='2.0.0-c3-r6-003-kcv_context_search-package-body';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;
