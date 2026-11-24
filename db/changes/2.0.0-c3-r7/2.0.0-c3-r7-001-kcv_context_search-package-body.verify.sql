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
 FUNCTION objective_preview(p_body CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_body);text_value VARCHAR2(10000);BEG');
 l_expected:=l_expected||TO_CLOB('IN
  text_value:=REGEXP_REPLACE(TRIM(j.get_string(''objective'')),''[[:space:]]+'','' '');
  RETURN CASE WHEN LENGTH(text_value)>240 THEN SUBSTR(text_value,1,237)||''...'' ELSE text_value END;
 END;
 FUNCTION model_key RETURN VARCHAR2 IS created DATE;BEGIN
  SELECT creation_date INTO created FROM user_mining_models WHERE model_name=c_model;
  RETURN ''v1:''||c_model_sha||'':''||TO_CHAR(created,''YYYYMMDDHH24MISS'');
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION embed(p_text VARCHAR2) RETURN VECTOR IS v VECTOR;dimensions NUMBER;BEGIN
  EXECUTE IMMEDIATE ''SELECT VECTOR_EMBEDDING(KCV_CONTEXT_MINILM USING :text AS data) FROM dual'' INTO v USING p_text;
  SELECT VECTOR_DIMENSION_COUNT(v) INTO ');
 l_expected:=l_expected||TO_CLOB('dimensions FROM dual;
  require(dimensions=384,''SEARCH_MODEL_INVALID: The local model must produce 384 dimensions'');
  RETURN v;
 END;
 PROCEDURE refresh_row(p_context VARCHAR2) IS
  r kcv_personal_contexts%ROWTYPE;doc CLOB;digest VARCHAR2(64);key VARCHAR2(128):=model_key;
  total NUMBER;current_rows NUMBER;ready_rows NUMBER;offset_chars PLS_INTEGER:=1;chunk_no PLS_INTEGER:=0;piece VARCHAR2(2000);
  v VECTOR;err NUMBER;state VARCHAR2(16);expected_rows NUMBER;
 BEGIN
  SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context FOR UPDATE NOWAIT;
  SELECT COUNT(*) INTO total FROM kcv_context_deletions WHERE context_id=p_context;
  require(total=0,''CONTEXT_DELETING: Search refresh is');
 l_expected:=l_expected||TO_CLOB(' unavailable during deletion'',-20248);
  doc:=document_text(r.title,r.draft_json);digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));
  expected_rows:=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END;
  SELECT COUNT(*),NVL(SUM(CASE WHEN content_sha256=digest AND model_key=NVL(key,''UNAVAILABLE'') THEN 1 ELSE 0 END),0),
    NVL(SUM(CASE WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0)
    INTO total,current_rows,ready_rows FROM kcv_context_search_chunks WHERE context_id=p_context;
  IF total=expected_rows AND current_rows=total AND (key IS NULL OR ready_rows=total) THEN
   DBMS_LOB.FREET');
 l_expected:=l_expected||TO_CLOB('EMPORARY(doc);RETURN;
  END IF;
  DELETE FROM kcv_context_search_chunks WHERE context_id=p_context;
  LOOP
   chunk_no:=chunk_no+1;piece:=DBMS_LOB.SUBSTR(doc,c_chunk_size,offset_chars);v:=NULL;err:=NULL;state:=''KEYWORD'';
   IF key IS NOT NULL THEN BEGIN v:=embed(piece);IF v IS NOT NULL THEN state:=''READY'';END IF;
    EXCEPTION WHEN OTHERS THEN err:=SQLCODE;v:=NULL;END;
   END IF;
   INSERT INTO kcv_context_search_chunks(context_id,chunk_no,content_sha256,model_key,chunk_text,embedding,embedding_status,error_code)
    VALUES(p_context,chunk_no,digest,NVL(key,''UNAVAILABLE''),piece,v,state,err);
   EXIT WHEN offset_chars+c_chunk_size-1>=DBMS_LOB.GETLENGTH(doc);
   offset_chars:=offset_chars+c_ch');
 l_expected:=l_expected||TO_CLOB('unk_size-c_overlap;
  END LOOP;
  DBMS_LOB.FREETEMPORARY(doc);
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
 PROCEDURE refresh_context(p_context VARCHAR2) IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  kcv_access.assert_writable;kcv_access.assert_context(p_context);
  lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||p_context,1,1073741823);n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
  require(n IN(0,4),''OPERATION_IN_PROGRESS: Another context operation is running'',-20246);
  kcv_access.assert_context(p_context);refresh_row(p_context);
  IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;
');
 l_expected:=l_expected||TO_CLOB(' EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 PROCEDURE reindex_all IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
  require(SYS_CONTEXT(''APEX$SESSION'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL
   AND SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,
   ''NOT_AUTHENTICATED: Use the schema owner connection for search maintenance'',-20240);
  kcv_access.assert_writable;
  FOR r IN(SELECT c.context_id FROM kcv_personal_contexts c WHERE NOT EXISTS
    (SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id) ORDER BY c.co');
 l_expected:=l_expected||TO_CLOB('ntext_id) LOOP
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_PERSONAL:''||r.context_id,1,1073741823);n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''OPERATION_IN_PROGRESS: A context is busy; retry search maintenance later'',-20246);
   refresh_row(r.context_id);ignored:=DBMS_LOCK.RELEASE(lock_id);n:=NULL;
  END LOOP;
 EXCEPTION WHEN OTHERS THEN IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION keyword_score(p_title VARCHAR2,p_doc CLOB,p_query VARCHAR2) RETURN NUMBER IS
  q VARCHAR2(1000):=LOWER(p_query);t VARCHAR2(1000):=LOWER(p_title);body CLOB:=LOWER(p_doc);token VARCHAR2(1000);score NUMBER:=0;idx PLS_INTEGER:=1;
  seen VARCHAR2(4000):=''|'';t');
 l_expected:=l_expected||TO_CLOB('itle_words VARCHAR2(2000);body_words CLOB;
 BEGIN
  IF t=q THEN score:=1000;ELSIF INSTR(t,q)>0 THEN score:=200;END IF;
  IF DBMS_LOB.INSTR(body,q)>0 THEN score:=score+20;END IF;
  title_words:='' ''||REGEXP_REPLACE(t,''[^[:alnum:]_]+'','' '')||'' '';
  body_words:=TO_CLOB('' '')||REGEXP_REPLACE(body,''[^[:alnum:]_]+'','' '')||'' '';
  LOOP token:=REGEXP_SUBSTR(q,''[[:alnum:]_]+'',1,idx);EXIT WHEN token IS NULL;idx:=idx+1;
   IF INSTR(seen,''|''||token||''|'')=0 AND INSTR(''|a|an|and|are|as|at|be|by|for|from|how|i|in|is|it|my|of|on|or|that|the|this|to|what|with|'',''|''||token||''|'')=0 THEN
    seen:=seen||token||''|'';
    IF INSTR(title_words,'' ''||token||'' '')>0 THEN score:=score+4;END IF;
    IF DBMS_LOB.INSTR(body_wor');
 l_expected:=l_expected||TO_CLOB('ds,'' ''||token||'' '')>0 THEN score:=score+1;END IF;
   END IF;
  END LOOP;RETURN score;
 END;
 FUNCTION search_contexts(p_status VARCHAR2,p_search VARCHAR2,p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
  s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
  status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));q VARCHAR2(32767):=TRIM(p_search);key VARCHAR2(128):=model_key;
  query_vector VECTOR;doc CLOB;digest VARCHAR2(64);lexical NUMBER;semantic NUMBER;ready_count NUMBER;all_count NUMBER;
  candidates JSON_ARRAY_T:=JSON_ARRAY_T();item JSON_OBJECT_T;payload CLOB;ranked JSON_ARRAY_T:=JSON_ARRAY_T();page JSON_ARRAY_T:=JSON_ARRAY_T();res');
 l_expected:=l_expected||TO_CLOB('ult JSON_OBJECT_T:=JSON_OBJECT_T();
  n NUMBER;total_contexts NUMBER:=0;complete_contexts NUMBER:=0;cursor_rank NUMBER:=0;cursor_seen BOOLEAN:=p_before_id IS NULL;
  page_end NUMBER;more_rows BOOLEAN:=FALSE;last_id VARCHAR2(32);search_mode VARCHAR2(16);notice VARCHAR2(1000);query_available BOOLEAN:=FALSE;
 BEGIN
  require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''VALIDATION_ERROR: Page size must be 1 to 50'');
  require(status_filter IS NULL OR status_filter IN(''DRAFT'',''ACTIVE'',''ARCHIVED''),''VALIDATION_ERROR: Unknown context status'');
  require(q IS NOT NULL AND LENGTH(q)<=200,''VALIDATION_ERROR: Search needs 1 to 200 characters'');
  IF p_before_id IS NOT NULL THEN kcv_access.assert_');
 l_expected:=l_expected||TO_CLOB('context(p_before_id);END IF;
  IF key IS NOT NULL THEN BEGIN query_vector:=embed(q);query_available:=query_vector IS NOT NULL;EXCEPTION WHEN OTHERS THEN query_available:=FALSE;END;END IF;
  FOR r IN(SELECT c.* FROM kcv_personal_contexts c WHERE c.owner_scope=s AND c.owner_subject=u
   AND(status_filter IS NULL OR c.lifecycle=status_filter)
   AND NOT EXISTS(SELECT 1 FROM kcv_context_deletions d WHERE d.context_id=c.context_id)) LOOP
   total_contexts:=total_contexts+1;doc:=document_text(r.title,r.draft_json);
   digest:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(doc,DBMS_CRYPTO.HASH_SH256)));lexical:=keyword_score(r.title,doc,q);semantic:=NULL;
   IF query_available THEN
    SELECT COUNT(*),NVL(SUM(CAS');
 l_expected:=l_expected||TO_CLOB('E WHEN embedding_status=''READY'' THEN 1 ELSE 0 END),0),
     MAX(CASE WHEN embedding_status=''READY'' THEN 1-VECTOR_DISTANCE(embedding,query_vector,COSINE) END)
     INTO all_count,ready_count,semantic FROM kcv_context_search_chunks
     WHERE context_id=r.context_id AND content_sha256=digest AND model_key=key;
    IF all_count=CASE WHEN DBMS_LOB.GETLENGTH(doc)<=c_chunk_size THEN 1 ELSE 1+CEIL((DBMS_LOB.GETLENGTH(doc)-c_chunk_size)/(c_chunk_size-c_overlap)) END
      AND ready_count=all_count THEN complete_contexts:=complete_contexts+1;END IF;
   END IF;
   IF semantic<0.30 THEN semantic:=NULL;END IF;
   IF lexical>0 OR semantic IS NOT NULL THEN
    item:=JSON_OBJECT_T();item.put(''context_id'',r');
 l_expected:=l_expected||TO_CLOB('.context_id);item.put(''title'',r.title);item.put(''lifecycle'',r.lifecycle);
    item.put(''draft_version'',r.draft_version);item.put(''latest_revision'',r.latest_revision);item.put_null(''deletion_status'');
    item.put(''updated_at'',TO_CHAR(r.updated_at,''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''));item.put(''objective_preview'',objective_preview(r.draft_json));
    item.put(''lexical'',lexical);IF semantic IS NOT NULL THEN item.put(''semantic'',semantic);ELSE item.put_null(''semantic'');END IF;
    item.put(''title_priority'',CASE WHEN LOWER(r.title)=LOWER(q) THEN 2 WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN 1 ELSE 0 END);
    item.put(''match_reason'',CASE WHEN INSTR(LOWER(r.title),LOWER(q))>0 THEN ''Title match''
  ');
 l_expected:=l_expected||TO_CLOB('    WHEN lexical>0 AND semantic IS NOT NULL THEN ''Saved information and similar meaning''
      WHEN lexical>0 THEN ''Saved information match'' ELSE ''Similar meaning'' END);
    candidates.append(item);
   END IF;
   DBMS_LOB.FREETEMPORARY(doc);
  END LOOP;
  payload:=candidates.to_clob();
  FOR r IN(WITH input_rows AS(SELECT x.* FROM JSON_TABLE(payload,''$[*]'' COLUMNS(
    context_id VARCHAR2(32) PATH ''$.context_id'',lexical NUMBER PATH ''$.lexical'',semantic NUMBER PATH ''$.semantic'',
    title_priority NUMBER PATH ''$.title_priority'',updated_at VARCHAR2(40) PATH ''$.updated_at'',item_json CLOB FORMAT JSON PATH ''$'')) x),
   ranks AS(SELECT i.*,ROW_NUMBER() OVER(ORDER BY lexical DESC,updated_at DESC,co');
 l_expected:=l_expected||TO_CLOB('ntext_id DESC) lr,
    ROW_NUMBER() OVER(ORDER BY semantic DESC NULLS LAST,updated_at DESC,context_id DESC) vr FROM input_rows i)
   SELECT item_json FROM ranks ORDER BY title_priority DESC,
    (CASE WHEN lexical>0 THEN 1/(60+lr) ELSE 0 END+CASE WHEN semantic IS NOT NULL THEN 1/(60+vr) ELSE 0 END) DESC,
    updated_at DESC,context_id DESC) LOOP
   item:=JSON_OBJECT_T.parse(r.item_json);item.remove(''lexical'');item.remove(''semantic'');item.remove(''title_priority'');ranked.append(item);
   IF item.get_string(''context_id'')=p_before_id THEN cursor_rank:=ranked.get_size;cursor_seen:=TRUE;END IF;
  END LOOP;
  IF NOT query_available THEN search_mode:=''KEYWORD'';notice:=''Keyword matches only: the loca');
 l_expected:=l_expected||TO_CLOB('l semantic search model is unavailable.'';
  ELSIF complete_contexts<total_contexts THEN search_mode:=''PARTIAL'';notice:=''Keyword search is complete; semantic search is available only for indexed saved contexts.'';
  ELSE search_mode:=''HYBRID'';notice:=''Search combines words and similar meaning in your titles and latest saved context information.'';END IF;
  IF NOT cursor_seen THEN cursor_rank:=0;notice:=notice||'' Results changed; showing the first page again.'';END IF;
  page_end:=LEAST(cursor_rank+p_limit,ranked.get_size);
  IF cursor_rank<page_end THEN FOR i IN cursor_rank..page_end-1 LOOP item:=TREAT(ranked.get(i) AS JSON_OBJECT_T);page.append(item);last_id:=item.get_string(''context_id'');END L');
 l_expected:=l_expected||TO_CLOB('OOP;END IF;
  more_rows:=page_end<ranked.get_size;result.put(''contexts'',page);
  IF more_rows THEN result.put(''next_cursor'',last_id);ELSE result.put_null(''next_cursor'');END IF;
  result.put(''search_mode'',search_mode);result.put(''search_notice'',notice);result.put(''feature_stage'',''personal-contexts'');RETURN result.to_clob();
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(doc)=1 THEN DBMS_LOB.FREETEMPORARY(doc);END IF;RAISE;
 END;
END;
');
 check_program('KCV_CONTEXT_SEARCH','PACKAGE BODY',l_expected);
