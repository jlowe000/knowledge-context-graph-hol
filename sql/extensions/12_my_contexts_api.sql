-- v2.0.0 C2: durable drafts and library. Activation/conversation integration is gated.
-- Read functions are SQL-safe. Mutations commit their own transactional request receipt.
CREATE OR REPLACE PACKAGE kcv_personal_context_api AUTHID DEFINER AS
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
END;
/
CREATE OR REPLACE PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,'VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMAXSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID('AL32UTF8'),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,'VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_access.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,'CONTEXT_UNAVAILABLE: Context is not available to this account');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_access.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,'CONTEXT_UNAVAILABLE: Context is not available to this account');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,'OPERATION_IN_PROGRESS: Another edit is being saved');END IF;RAISE;
 END;
 FUNCTION lock_owned_context(p_context VARCHAR2) RETURN PLS_INTEGER IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
   kcv_access.assert_context(p_context);kcv_access.assert_writable;
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_PERSONAL:'||p_context,1,1073741823);
   n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,'OPERATION_IN_PROGRESS: Another context operation is running',-20246);
   kcv_access.assert_context(p_context);RETURN lock_id;
 EXCEPTION WHEN OTHERS THEN
   IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();deletion_state VARCHAR2(16);BEGIN
   j.put('context_id',p_row.context_id);j.put('title',p_row.title);j.put('lifecycle',p_row.lifecycle);
   j.put('draft_version',p_row.draft_version);j.put('latest_revision',p_row.latest_revision);
   j.put('updated_at',TO_CHAR(p_row.updated_at,'YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM'));
   SELECT MAX(status) INTO deletion_state FROM kcv_context_deletions
    WHERE context_id=p_row.context_id AND owner_scope=p_row.owner_scope AND owner_subject=p_row.owner_subject;
   IF deletion_state IS NULL THEN j.put_null('deletion_status');ELSE j.put('deletion_status',deletion_state);END IF;
   IF deletion_state IS NULL THEN j.put('objective_preview',kcv_context_search.objective_preview(p_row.draft_json));
   ELSE j.put_null('objective_preview');END IF;
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;ready_body CLOB;dirty NUMBER:=1;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object('topic_preferences');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put('label',keys(i));topic.put('weight',prefs.get_number(keys(i)));topics.append(topic);
     END LOOP;
   END IF;
   j:=summary(r);j.put('base_graph',r.base_graph);j.put('draft',draft);j.put('selected_topics',topics);
   IF r.latest_revision IS NOT NULL THEN
     SELECT context_json INTO ready_body FROM kcv_scenario_revisions WHERE revision_id=r.latest_revision AND context_id=r.context_id;
     SELECT CASE WHEN JSON_EQUAL(r.draft_json,ready_body) THEN 0 ELSE 1 END INTO dirty FROM dual;
     j.put('ready_context',JSON_OBJECT_T.parse(ready_body));
   END IF;
   j.put('has_unapplied_changes',dirty=1);
   IF r.provenance_json IS NOT NULL THEN j.put('provenance',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put('edit',r.lifecycle<>'ARCHIVED');cap.put('archive',r.lifecycle<>'ARCHIVED');cap.put('restore',r.lifecycle='ARCHIVED');
   cap.put('activate',r.lifecycle<>'ARCHIVED');cap.put('start_conversation',r.lifecycle='ACTIVE');cap.put('duplicate',TRUE);
   j.put('capabilities',cap);j.put('feature_stage','personal-contexts');
   j.put('notice','Private context. Topics select evidence; other context fields frame interpretation. Observations do not automatically change your context.');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),'VALIDATION_ERROR: Page size must be 1 to 50');
   require(status_filter IS NULL OR status_filter IN ('DRAFT','ACTIVE','ARCHIVED'),'VALIDATION_ERROR: Unknown context status');
   require(p_search IS NULL OR LENGTH(p_search)<=200,'VALIDATION_ERROR: Search is limited to 200 characters');
   IF search_filter IS NOT NULL THEN
    RETURN kcv_context_search.search_contexts(status_filter,search_filter,p_before_id,p_limit);
   END IF;
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN
    -- Pagination requires only owned list metadata, including pending deletions.
    BEGIN SELECT context_id,updated_at INTO cursor_row.context_id,cursor_row.updated_at
     FROM kcv_personal_contexts WHERE context_id=p_before_id AND owner_scope=s AND owner_subject=u;
    EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,'CONTEXT_UNAVAILABLE: Context is not available to this account');END;
   END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put('contexts',a);IF more_rows THEN j.put('next_cursor',last_id);ELSE j.put_null('next_cursor');END IF;
   j.put('feature_stage','personal-contexts');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   a:=JSON_ARRAY_T.parse(kcv_access.topic_options(g));
   j.put('base_graph',g);j.put('topics',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):='|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,'VALIDATION_ERROR: Supply a JSON context object');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,'|'||ks(i)||'|')>0,'VALIDATION_ERROR: Unknown context field');value:=j.get(ks(i));
     IF ks(i) IN ('unknowns','constraints') THEN
       require(value.is_array,'VALIDATION_ERROR: Unknowns and constraints must be arrays');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,'VALIDATION_ERROR: At most 20 unknowns or constraints');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,'VALIDATION_ERROR: Each unknown or constraint must be text');
         require(LENGTH(a.get_string(k))<=500,'VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters');
         require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           'VALIDATION_ERROR: Each unknown or constraint must be a single line');
       END LOOP;
     ELSIF ks(i)='topic_preferences' THEN
       require(value.is_object,'VALIDATION_ERROR: Topic preferences must be an object');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,'VALIDATION_ERROR: At most 20 topics');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,'INVALID_TOPIC: Topic label is too long',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,'VALIDATION_ERROR: Topic weights must be numbers');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,'VALIDATION_ERROR: Topic weights must be 1 to 10');
         kcv_access.assert_topic(p_graph,topic_label);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,'VALIDATION_ERROR: Context fields must be text');
       max_length:=CASE WHEN ks(i) IN ('question','objective') THEN 2000 WHEN ks(i)='known_situation' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,'VALIDATION_ERROR: Context field is too long');
     END IF;
   END LOOP;
   IF NOT j.has('objective_clarity') OR j.get_string('objective_clarity') IS NULL THEN j.put('objective_clarity','unknown');END IF;
   require(j.get_string('objective_clarity') IN ('unknown','emerging','defined'),'VALIDATION_ERROR: Choose objective clarity');
   -- Drafts may be incomplete, including a Defined objective whose text is not yet supplied.
   IF NOT j.has('topic_preferences') THEN j.put('topic_preferences',JSON_OBJECT_T());END IF;
   IF NOT j.has('unknowns') THEN j.put('unknowns',JSON_ARRAY_T());END IF;
   IF NOT j.has('constraints') THEN j.put('constraints',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;replay_lock PLS_INTEGER;result_context VARCHAR2(32);result_status VARCHAR2(16);
 BEGIN
   p_lock:=NULL;
   kcv_access.assert_writable;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,'^[A-Za-z0-9_-]{16,80}$','c'),'VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   -- Numeric user locks avoid ALLOCATE_UNIQUE's commit. A rare hash collision
   -- yields a conservative busy result; identity and request hashes still gate data.
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_CONTEXT_REQUEST:'||s||':'||u||':'||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>TRUE);
   require(lock_result=0,'OPERATION_IN_PROGRESS: Retry after the current action finishes',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,'REQUEST_TOKEN_REUSED: Start a new action with a new token',-20245);
     require(r.result_json IS NOT NULL,'OPERATION_IN_PROGRESS: The prior request has not completed',-20246);
     SELECT JSON_VALUE(r.result_json,'$.context_id'),JSON_VALUE(r.result_json,'$.status') INTO result_context,result_status FROM dual;
     require(NVL(result_status,'-')<>'DELETED' AND result_context IS NOT NULL,
       'CONTEXT_UNAVAILABLE: The earlier request no longer returns an available context',-20241);
     -- An old receipt can contain an entire draft. Serialize its replay with
     -- deletion, then recheck the stable owner and deletion fence before return.
     replay_lock:=lock_owned_context(result_context);
     p_result:=r.result_json;release_request(replay_lock);release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(replay_lock);release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,'VALIDATION_ERROR: Supply a context title up to 200 characters');
 END;
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):='C'||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   kcv_context_search.refresh_context(cid);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put('context_id',p_context);request.put('title',p_title);request.put('body',p_body);request.put('expected_version',p_expected_version);
   IF request_begin('SAVE_DRAFT',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,'STALE_VERSION: New contexts have no saved version',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);require(r.lifecycle<>'ARCHIVED','CONTEXT_ARCHIVED: Restore before editing',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>'ARCHIVED';
     require(SQL%ROWCOUNT=1,'STALE_VERSION: Reload your saved context before editing',-20242);
     kcv_context_search.refresh_context(cid);
   END IF;
   result:=request_finish(p_request_token,cid);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put('context_id',p_context);request.put('title',p_title);
   IF request_begin('DUPLICATE',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   context_lock:=lock_owned_context(p_context);
   r:=context_row(p_context);provenance.put('kind','owned_context_copy');provenance.put('context_id',r.context_id);provenance.put('draft_version',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());result:=request_finish(p_request_token,cid);
   release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put('sample_id',p_sample);request.put('title',p_title);
   IF request_begin('COPY_SAMPLE',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,'VALIDATION_ERROR: Choose an available sample');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put('objective_clarity','unknown');
   IF source.has('question') THEN draft.put('question',source.get_string('question'));END IF;
   IF source.has('learning_purpose') THEN draft.put('learning_purpose',source.get_string('learning_purpose'));END IF;
   IF source.has('topic_preferences') THEN draft.put('topic_preferences',source.get_object('topic_preferences'));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put('kind','sample_suggestions');provenance.put('sample_id',p_sample);provenance.put('snapshot_id',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;n NUMBER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN 'RESTORE' ELSE 'ARCHIVE' END;
   request.put('context_id',p_context);request.put('expected_version',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle='ARCHIVED','VALIDATION_ERROR: Context is not archived');new_state:=NVL(r.prior_lifecycle,'DRAFT');
   ELSE
     require(r.lifecycle<>'ARCHIVED','CONTEXT_ARCHIVED: Context is already archived',-20243);
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=p_context AND mutation_token IS NOT NULL;
     require(n=0,'OPERATION_IN_PROGRESS: Complete or recover the pending answer before archiving',-20246);new_state:='ARCHIVED';
     SELECT COUNT(*) INTO n FROM kcv_personal_operations WHERE context_id=p_context AND phase IN('BUILDING','READY');
     require(n=0,'OPERATION_IN_PROGRESS: Recover the interrupted context operation before archiving',-20246);
   END IF;
   UPDATE kcv_personal_contexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state='ARCHIVED' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,'STALE_VERSION: Reload your saved context before changing its status',-20242);
   result:=request_finish(p_token,p_context);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS BEGIN
   RETURN clean_body(p_body,p_graph);
 END;
END;
/
