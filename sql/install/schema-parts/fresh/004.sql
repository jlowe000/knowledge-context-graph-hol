-- FRESH part 004 of 019. Run Script as the project owner.
-- Run in manifest order. Stop after any error; do not skip ahead.
-- An oversized atomic step is retained intact to preserve its checks.
DECLARE l_step CLOB;
BEGIN
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('DECLARE
 l_sql CLOB;l_replaced BOOLEAN:=FALSE;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN ('' '',CHR(9),CHR(10),CHR(13),''"'') THEN r:=r||UPP');
 l_step:=l_step||TO_CLOB('ER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>');
 l_step:=l_step||TO_CLOB('''--'' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,''Installed source differs: ''||p_name||'' ''||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_col');
 l_step:=l_step||TO_CLOB('umn VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string(''name'');cols:=t.get_array(''columns'');cs:=t.get_array(''constraints'');
  wanted_temp:=t.get_string(''temporary'');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,''Missing or incompatible table: ''||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,''Column count differs: ''||name);
  FOR i IN 0..cols.get_size-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string(''name'');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identit');
 l_step:=l_step||TO_CLOB('y_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,''Missing column: ''||name||''.''||c.get_string(''name'')); END;
   require(actual_type=c.get_string(''type''),''Column type differs: ''||name||''.''||c.get_string(''name''));
   require(actual_nullable=c.get_string(''nullable''),''Column nullability differs: ''||name||''.''||c.get_string(''name''));
   IF c.has(''length'') THEN
    require(len=c.get_number(''length''),''Column length differs: ''||name||''.''||c.get_string(''name''));
    require(char_semantics=c.get_string(');
 l_step:=l_step||TO_CLOB('''char_used''),''Column character semantics differ: ''||name||''.''||c.get_string(''name''));
   END IF;
   IF c.get_string(''type'')=''NUMBER'' THEN
    require(NVL(prec,-1)=NVL(c.get_number(''precision''),-1) AND NVL(sc,-99)=NVL(c.get_number(''scale''),-99),''Number precision differs: ''||name||''.''||c.get_string(''name''));
   END IF;
   require(ident=c.get_string(''identity''),''Column identity differs: ''||name||''.''||c.get_string(''name''));
   IF ident=''NO'' THEN d:=def;require(NVL(compact(d),''#NULL#'')=NVL(compact(c.get_string(''default'')),''#NULL#''),''Column default differs: ''||name||''.''||c.get_string(''name''));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;');
 l_step:=l_step||TO_CLOB('wanted_constraint:=c.get_string(''type'');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status=''ENABLED'' AND validated=''VALIDATED''
      AND deferrable=''NOT DEFERRABLE'' AND (constraint_type<>''R'' OR (delete_rule=''NO ACTION'' AND r_owner=USER))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,'','') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_columns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type=''C'' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string(''expression'')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_s');
 l_step:=l_step||TO_CLOB('tring(''columns'') THEN
     IF r.constraint_type=''R'' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,'','') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string(''reference_table'') AND refcols=c.get_string(''reference_columns'') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
   require(found,''Missing or incompatible constraint: ''||name||'' ''||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r');
 l_step:=l_step||TO_CLOB('.constraint_type<>''C'' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),''^[A-Z][A-Z0-9_$]*ISNOTNULL$'') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,''Unexpected constraints: ''||name);
 END;

BEGIN
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c3-r6-004-kcv_personal_context_api-package-body'' AND payload_sha256=''9130c10173d632f015c0e2d38909a24b2070d80c691e3f06b229d2ca866d20a0'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_messag');
 l_step:=l_step||TO_CLOB('e VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA'');
 l_expected:=l_expected||TO_CLOB(''XSIZE,
     dest_offset=>dst_offset,src_offset=>');
 l_step:=l_step||TO_CLOB('src_offset,blob_csid=>NLS_CHARSET_ID(''''AL32UTF8''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR'');
 l_expected:=l_expected||TO_CLOB(''CHAR');
 l_step:=l_step||TO_CLOB('2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_access.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_acc'')');
 l_step:=l_step||TO_CLOB(';
 l_expected:=l_expected||TO_CLOB(''ess.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''''OPERATION_IN_PROGRESS: Another edit is being saved'''');END IF;RAISE;
 END;
 FUNCTION lock_owned_context(p_context VARCHAR2) RETURN PLS_INTEGER IS lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
   kcv_access.assert_context(p_context);kcv_access.assert_writable;
  ');
 l_step:=l_step||TO_CLOB(' lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''K'');
 l_expected:=l_expected||TO_CLOB(''CV_PERSONAL:''''||p_context,1,1073741823);
   n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''''OPERATION_IN_PROGRESS: Another context operation is running'''',-20246);
   kcv_access.assert_context(p_context);RETURN lock_id;
 EXCEPTION WHEN OTHERS THEN
   IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();deletion_state VARCHAR2(16);BEGIN
   j.put(''''context_id'''',p_row.context_id);j.put(''''title'''',p_row.title);j.put(''''lifecycle'''',p_row.lifecycle);
   j.put(''''draft_versio');
 l_step:=l_step||TO_CLOB('n'''',p_row.draft_version);j.put(''''latest_revision'''',p_row.latest_revision);
   j.put(''''updated'');
 l_expected:=l_expected||TO_CLOB(''_at'''',TO_CHAR(p_row.updated_at,''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''));
   SELECT MAX(status) INTO deletion_state FROM kcv_context_deletions
    WHERE context_id=p_row.context_id AND owner_scope=p_row.owner_scope AND owner_subject=p_row.owner_subject;
   IF deletion_state IS NULL THEN j.put_null(''''deletion_status'''');ELSE j.put(''''deletion_status'''',deletion_state);END IF;
   IF deletion_state IS NULL THEN j.put(''''objective_preview'''',kcv_context_search.objective_preview(p_row.draft_json));
   ELSE j.put_null(''''objective_preview'''');END IF;
   RETURN j;
 END;
 FUNCTI');
 l_step:=l_step||TO_CLOB('ON get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T'');
 l_expected:=l_expected||TO_CLOB('':=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;ready_body CLOB;dirty NUMBER:=1;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''topic_preferences'''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''label'''',keys(i));topic.put(''''weight'''',prefs.get_number(keys(i)));topics.append(topic);
     END LOOP;
   END IF;
   j:=s');
 l_step:=l_step||TO_CLOB('ummary(r);j.put(''''base_graph'''',r.base_graph);j.put(''''draft'''',draft);j.put(''''selected_topics'''',topics);
   IF r.latest_revision IS NOT NULL THEN
     SELECT context_json INTO ready_body FROM kc'');
 l_expected:=l_expected||TO_CLOB(''v_scenario_revisions WHERE revision_id=r.latest_revision AND context_id=r.context_id;
     SELECT CASE WHEN JSON_EQUAL(r.draft_json,ready_body) THEN 0 ELSE 1 END INTO dirty FROM dual;
     j.put(''''ready_context'''',JSON_OBJECT_T.parse(ready_body));
   END IF;
   j.put(''''has_unapplied_changes'''',dirty=1);
   IF r.provenance_json IS NOT NULL THEN j.put(''''provenance'''',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''''edit'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''');
 l_step:=l_step||TO_CLOB('archive'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''restore'''',r.lifecycle=''''ARCHIVED'''');
   cap.put(''''activate'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''start_conversation'''',r.lifecycle=''''ACTIVE'''');cap.put(''''duplicate'''',TRUE);
   j.put(''''capabilities'''',cap);j.put(''''fea'');
 l_expected:=l_expected||TO_CLOB(''ture_stage'''',''''personal-contexts'''');
   j.put(''''notice'''',''''Private context. Topics select evidence; other context fields frame interpretation. Observations do not automatically change your context.'''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s');
 l_step:=l_step||TO_CLOB(' VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contex'');
 l_expected:=l_expected||TO_CLOB(''ts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''''VALIDATION_ERROR: Page size must be 1 to 50'''');
   require(status_filter IS NULL OR status_filter IN (''''DRAFT'''',''''ACTIVE'''',''''ARCHIVED''''),''''VALIDATION_ERROR: Unknown context status''');
 l_step:=l_step||TO_CLOB(''');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''''VALIDATION_ERROR: Search is limited to 200 characters'''');
   IF search_filter IS NOT NULL THEN
    RETURN kcv_context_search.search_contexts(status_filter,search_filter,p_before_id,p_limit);
   END IF;
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN
    BEGIN S'');
 l_expected:=l_expected||TO_CLOB(''ELECT context_id,updated_at INTO cursor_row.context_id,cursor_row.updated_at
     FROM kcv_personal_contexts WHERE context_id=p_before_id AND owner_scope=s AND owner_subject=u;
    EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this acco');
 l_step:=l_step||TO_CLOB('unt'''');END;
   END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     O'');
 l_expected:=l_expected||TO_CLOB(''RDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''contexts'''',a);IF more_rows THEN j.put');
 l_step:=l_step||TO_CLOB('(''''next_cursor'''',last_id);ELSE j.put_null(''''next_cursor'''');END IF;
   j.put(''''feature_stage'''',''''personal-contexts'''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context'');
 l_expected:=l_expected||TO_CLOB(''_row(p_context);g:=r.base_graph;END IF;
   a:=JSON_ARRAY_T.parse(kcv_access.topic_options(g));
   j.put(''''base_graph'''',g);j.put(''''topics'''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2)');
 l_step:=l_step||TO_CLOB(' RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'''';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION'');
 l_expected:=l_expected||TO_CLOB('' WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Supply a JSON context object'''');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(a');
 l_step:=l_step||TO_CLOB('llowed,''''|''''||ks(i)||''''|'''')>0,''''VALIDATION_ERROR: Unknown context field'''');value:=j.get(ks(i));
     IF ks(i) IN (''''unknowns'''',''''constraints'''') THEN
       require(value.is_array,''''VALIDATION_ERROR: Unknowns and constraints must be arrays'''');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''''VALIDATION_ERROR: At most 20 unknowns or constraints'''');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''VALIDATION_ERROR: Each unknown or constraint must be text'''');
         require(LENGTH(a.get_'');
 l_expected:=l_expected||TO_CLOB(''string(k))<=500,''''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'''');
         require(INS');
 l_step:=l_step||TO_CLOB('TR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''');
       END LOOP;
     ELSIF ks(i)=''''topic_preferences'''' THEN
       require(value.is_object,''''VALIDATION_ERROR: Topic preferences must be an object'''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''''VALIDATION_ERROR: At most 20 topics'''');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''''INVALID_TOPIC: Topic label is too long'''',-20247);topic_label:'');
 l_expected:=l_expected||TO_CLOB(''=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(val');
 l_step:=l_step||TO_CLOB('ue.is_number,''''VALIDATION_ERROR: Topic weights must be numbers'''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''VALIDATION_ERROR: Topic weights must be 1 to 10'''');
         kcv_access.assert_topic(p_graph,topic_label);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''VALIDATION_ERROR: Context fields must be text'''');
       max_length:=CASE WHEN ks(i) IN (''''question'''',''''objective'''') THEN 2000 WHEN ks(i)=''''known_situation'''' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''VALIDATION_ERROR: Context field is to'');
 l_expected:=l_expected||TO_CLOB(''o long'''');
     E');
 l_step:=l_step||TO_CLOB('ND IF;
   END LOOP;
   IF NOT j.has(''''objective_clarity'''') OR j.get_string(''''objective_clarity'''') IS NULL THEN j.put(''''objective_clarity'''',''''unknown'''');END IF;
   require(j.get_string(''''objective_clarity'''') IN (''''unknown'''',''''emerging'''',''''defined''''),''''VALIDATION_ERROR: Choose objective clarity'''');
   IF NOT j.has(''''topic_preferences'''') THEN j.put(''''topic_preferences'''',JSON_OBJECT_T());END IF;
   IF NOT j.has(''''unknowns'''') THEN j.put(''''unknowns'''',JSON_ARRAY_T());END IF;
   IF NOT j.has(''''constraints'''') THEN j.put(''''constraints'''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGI');
 l_step:=l_step||TO_CLOB('N
   IF p_lock'');
 l_expected:=l_expected||TO_CLOB('' IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;replay_lock PLS_INTEGER;result_context VARCHAR2(32);result_status VARCHAR2(16);
 BEGIN
   p_lock:=NULL;
   kcv_access.assert_writable;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''''^[A-Za-z0-9_-]{16,80}$'''',''''c''''),''''VALIDATION_');
 l_step:=l_step||TO_CLOB('ERROR: Supply a request token of 16 to 80 safe characters'');
 l_expected:=l_expected||TO_CLOB('''''');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''KCV_CONTEXT_REQUEST:''''||s||'''':''''||u||'''':''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>TRUE);
   require(lock_result=0,''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
');
 l_step:=l_step||TO_CLOB('   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope'');
 l_expected:=l_expected||TO_CLOB(''=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''',-20245);
     require(r.result_json IS NOT NULL,''''OPERATION_IN_PROGRESS: The prior request has not completed'''',-20246);
     SELECT JSON_VALUE(r.result_json,''''$.context_id''''),JSON_VALUE(r.result_json,''''$.status'''') INTO result_context,result_status FROM dual;
     require(NVL(result_status,''''-'''')<>''''DELETED'''' AND result_context IS NOT NULL,
       ''''CONTEXT_UNAVAILABLE: The earlier');
 l_step:=l_step||TO_CLOB(' request no longer returns an available context'''',-20241);
     replay_lock:=lock_owned_context(result_context);
     p_result:=r.result_json;release_reques'');
 l_expected:=l_expected||TO_CLOB(''t(replay_lock);release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(replay_lock);release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
');
 l_step:=l_step||TO_CLOB(' END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''VALIDATION_ERROR: Supply a context title up to 200 characters'''');
 END'');
 l_expected:=l_expected||TO_CLOB('';
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''C''''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   kc');
 l_step:=l_step||TO_CLOB('v_context_search.refresh_context(cid);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJEC'');
 l_expected:=l_expected||TO_CLOB(''T_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''''context_id'''',p_context);request.put(''''title'''',p_title);request.put(''''body'''',p_body);request.put(''''expected_version'''',p_expected_version);
   IF request_begin(''''SAVE_');
 l_step:=l_step||TO_CLOB('DRAFT'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''STALE_VERSION: New contexts have no saved version'''',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);c'');
 l_expected:=l_expected||TO_CLOB(''id:=insert_draft(p_title,clean,g);
   ELSE
     context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_ARCHIVED: Restore before editing'''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SY');
 l_step:=l_step||TO_CLOB('STIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''ARCHIVED'''';
     require(SQL%ROWCOUNT=1,''''STALE_VERSION: Reload your saved context before editing'''',-20242);
     kcv_context_search.refresh_context(cid);
   END IF;
   result:=request_finish(p_request_token,cid);release_request(cont'');
 l_expected:=l_expected||TO_CLOB(''ext_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=J');
 l_step:=l_step||TO_CLOB('SON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''context_id'''',p_context);request.put(''''title'''',p_title);
   IF request_begin(''''DUPLICATE'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   context_loc'');
 l_expected:=l_expected||TO_CLOB(''k:=lock_owned_context(p_context);
   r:=context_row(p_context);provenance.put(''''kind'''',''''owned_context_copy'''');provenance.put(''''context_id'''',r.context_id);provenance.put(''''draft_version'''',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());res');
 l_step:=l_step||TO_CLOB('ult:=request_finish(p_request_token,cid);
   release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_'');
 l_expected:=l_expected||TO_CLOB(''T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''s');
 l_step:=l_step||TO_CLOB('ample_id'''',p_sample);request.put(''''title'''',p_title);
   IF request_begin(''''COPY_SAMPLE'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN '');
 l_expected:=l_expected||TO_CLOB(''NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Choose an available sample'''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''objective_clarity'''',''''unknown'''');
  ');
 l_step:=l_step||TO_CLOB(' IF source.has(''''question'''') THEN draft.put(''''question'''',source.get_string(''''question''''));END IF;
   IF source.has(''''learning_purpose'''') THEN draft.put(''''learning_purpose'''',source.get_string(''''learning_purpose''''));END IF;
   IF source.has(''''topic_preferences'''') THEN draft.put(''''topic_preferences'''',source.get_object(''''topic_preferences''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''kind'''',''''sample_suggestions'''');provenance.put(''''sample_id'''',p_sample);provenance.put(''''snapshot_id'''',snapshot_id);
   cid:=insert_'');
 l_expected:=l_expected||TO_CLOB(''draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK T');
 l_step:=l_step||TO_CLOB('O kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;n NUMBER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''RESTORE'''' ELSE ''''ARCHIVE'''' END;
   request.put(''''context_id'''',p_context);request.put(''''expected_version'''',p_expected_version'');
 l_expected:=l_expected||TO_CLOB('');
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RET');
 l_step:=l_step||TO_CLOB('URN result;END IF;
   context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''ARCHIVED'''',''''VALIDATION_ERROR: Context is not archived'''');new_state:=NVL(r.prior_lifecycle,''''DRAFT'''');
   ELSE
     require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_ARCHIVED: Context is already archived'''',-20243);
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=p_context AND mutation_token IS NOT NULL;
     require(n=0,''''OPERATION_IN_PROGRESS: Complete or recover the pending answer before archiving'''',-20246);new_state:=''''ARCHIVED'''';
     SELECT COUNT(*) INTO'');
 l_expected:=l_expected||TO_CLOB('' n FROM kcv_personal_operati');
 l_step:=l_step||TO_CLOB('ons WHERE context_id=p_context AND phase IN(''''BUILDING'''',''''READY'''');
     require(n=0,''''OPERATION_IN_PROGRESS: Recover the interrupted context operation before archiving'''',-20246);
   END IF;
   UPDATE kcv_personal_contexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''''ARCHIVED'''' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''''STALE_VERSION: Reload your saved context before changing its status'''',-20242);
   result:=request_finish(p_token,p_context);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS '');
 l_expected:=l');
 l_step:=l_step||TO_CLOB('_expected||TO_CLOB(''THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS BEGIN
   RETURN clean_body(p_body,p_graph);
 END;
END;
'');
 check_program(''KCV_PERSONAL_CONTEXT_API''');
 l_step:=l_step||TO_CLOB(',''PACKAGE BODY'',l_expected);
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c2-007-kcv_personal_context_api-package-body'' AND payload_sha256=''2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.0.0-c2-007-kcv_personal_context_api-package-body'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c3-r5-005-kcv_personal_context_api-package-body'' AND payload_sha256=''97c4b5ad2195a087edd8a3c54398fcd66671d2d0a2a05676c330199cacc46499'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
l_expected:=TO_C');
 l_step:=l_step||TO_CLOB('LOB('''');
 l_expected:=l_expected||TO_CLOB(''PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>en');
 l_step:=l_step||TO_CLOB('coded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA'');
 l_expected:=l_expected||TO_CLOB(''XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''''AL32UTF8''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''';
   RETURN g;
');
 l_step:=l_step||TO_CLOB(' EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR'');
 l_expected:=l_expected||TO_CLOB(''CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_access.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r k');
 l_step:=l_step||TO_CLOB('cv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   kcv_acc'');
 l_expected:=l_expected||TO_CLOB(''ess.assert_context(p_context);
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''''OPERATION_IN_PROGRESS: Another edit is being saved'''');END IF;RAISE;
 END;
 FUNCTION lock_owned_context(p_context VARCHAR2) RETURN PLS_INTEGER IS');
 l_step:=l_step||TO_CLOB(' lock_id PLS_INTEGER;n PLS_INTEGER;ignored PLS_INTEGER;BEGIN
   kcv_access.assert_context(p_context);kcv_access.assert_writable;
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''K'');
 l_expected:=l_expected||TO_CLOB(''CV_PERSONAL:''''||p_context,1,1073741823);
   n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   require(n=0,''''OPERATION_IN_PROGRESS: Another context operation is running'''',-20246);
   kcv_access.assert_context(p_context);RETURN lock_id;
 EXCEPTION WHEN OTHERS THEN
   IF n=0 THEN ignored:=DBMS_LOCK.RELEASE(lock_id);END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();deletion_state VARCHAR2(16);BEGIN
 ');
 l_step:=l_step||TO_CLOB('  j.put(''''context_id'''',p_row.context_id);j.put(''''title'''',p_row.title);j.put(''''lifecycle'''',p_row.lifecycle);
   j.put(''''draft_version'''',p_row.draft_version);j.put(''''latest_revision'''',p_row.latest_revision);
   j.put(''''updated'');
 l_expected:=l_expected||TO_CLOB(''_at'''',TO_CHAR(p_row.updated_at,''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''));
   SELECT MAX(status) INTO deletion_state FROM kcv_context_deletions
    WHERE context_id=p_row.context_id AND owner_scope=p_row.owner_scope AND owner_subject=p_row.owner_subject;
   IF deletion_state IS NULL THEN j.put_null(''''deletion_status'''');ELSE j.put(''''deletion_status'''',deletion_state);END IF;
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RET');
 l_step:=l_step||TO_CLOB('URN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;ready_body CLOB;dirty NUMBER'');
 l_expected:=l_expected||TO_CLOB('':=1;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''topic_preferences'''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''label'''',keys(i));topic.put(''''weight'''',prefs.get_number(keys(i)));topics.append(topic);
     END LOOP;
   END IF;
   j:=summary(r);j.put(''''base_graph'''',r.base_');
 l_step:=l_step||TO_CLOB('graph);j.put(''''draft'''',draft);j.put(''''selected_topics'''',topics);
   IF r.latest_revision IS NOT NULL THEN
     SELECT context_json INTO ready_body FROM kcv_scenario_revisions WHERE revision_id=r.latest_revision AND context_id=r.context_id;
     SELECT CASE WHEN JSON_EQUAL(r.draft_json,ready_body) THEN 0 ELSE 1 END INT'');
 l_expected:=l_expected||TO_CLOB(''O dirty FROM dual;
     j.put(''''ready_context'''',JSON_OBJECT_T.parse(ready_body));
   END IF;
   j.put(''''has_unapplied_changes'''',dirty=1);
   IF r.provenance_json IS NOT NULL THEN j.put(''''provenance'''',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''''edit'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''archive'''',r.lifecycle<>''''ARCHIVED'''');c');
 l_step:=l_step||TO_CLOB('ap.put(''''restore'''',r.lifecycle=''''ARCHIVED'''');
   cap.put(''''activate'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''start_conversation'''',r.lifecycle=''''ACTIVE'''');cap.put(''''duplicate'''',TRUE);
   j.put(''''capabilities'''',cap);j.put(''''feature_stage'''',''''personal-contexts'''');
   j.put(''''notice'''',''''Private context. Topics select evidence; other context fields frame interpretation. Observations do not automati'');
 l_expected:=l_expected||TO_CLOB(''cally change your context.'''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope');
 l_step:=l_step||TO_CLOB(';u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC('');
 l_expected:=l_expected||TO_CLOB(''p_limit),''''VALIDATION_ERROR: Page size must be 1 to 50'''');
   require(status_filter IS NULL OR status_filter IN (''''DRAFT'''',''''ACTIVE'''',''''ARCHIVED''''),''''VALIDATION_ERROR: Unknown context status'''');
   require(p_search IS NULL OR LEN');
 l_step:=l_step||TO_CLOB('GTH(p_search)<=200,''''VALIDATION_ERROR: Search is limited to 200 characters'''');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN
    BEGIN SELECT context_id,updated_at INTO cursor_row.context_id,cursor_row.updated_at
     FROM kcv_personal_contexts WHERE context_id=p_before_id AND owner_scope=s AND owner_subject=u;
    EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''');
 l_expected:=l_expected||TO_CLOB('');END;
   END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (');
 l_step:=l_step||TO_CLOB('search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''contexts'''',a);IF more_rows THEN j.put(''''next_cursor'''',last_id);ELSE j.put_null(''''next'');
 l_expected:=l_expected||TO_CLOB(''_cursor'''');END IF;
   j.put(''''feature_stage'''',''''personal-contexts'''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCH');
 l_step:=l_step||TO_CLOB('AR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   a:=JSON_ARRAY_T.parse(kcv_access.topic_options(g));
   j.put(''''base_graph'''',g);j.put(''''topics'''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs J'');
 l_expected:=l_expected||TO_CLOB(''SON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''''|question|objective');
 l_step:=l_step||TO_CLOB('_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'''';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Supply a JSON context object'''');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''''|''''||ks(i)||''''|'''')>0,''''VALIDATION_ERROR: Unknown context field'''');value:=j.get(ks(i));
     IF ks(i) IN (''''unknowns'''',''''constraints'''') THE'');
 l_expected:=l_expected||TO_CLOB(''N
       require(value.is_array,''''V');
 l_step:=l_step||TO_CLOB('ALIDATION_ERROR: Unknowns and constraints must be arrays'''');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''''VALIDATION_ERROR: At most 20 unknowns or constraints'''');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''VALIDATION_ERROR: Each unknown or constraint must be text'''');
         require(LENGTH(a.get_string(k))<=500,''''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'''');
         require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''');
       END LOOP;
     ELSIF ks(i)=''''topic_pr'');
 l_expected:=l_expec');
 l_step:=l_step||TO_CLOB('ted||TO_CLOB(''eferences'''' THEN
       require(value.is_object,''''VALIDATION_ERROR: Topic preferences must be an object'''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''''VALIDATION_ERROR: At most 20 topics'''');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''''INVALID_TOPIC: Topic label is too long'''',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''''VALIDATION_ERROR: Topic weights must be numbers'''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''VALIDATION_ERROR: Topic weights must be 1 to 10'''');
         kcv_access.assert_t');
 l_step:=l_step||TO_CLOB('opic(p_graph,topic_label)'');
 l_expected:=l_expected||TO_CLOB('';
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''VALIDATION_ERROR: Context fields must be text'''');
       max_length:=CASE WHEN ks(i) IN (''''question'''',''''objective'''') THEN 2000 WHEN ks(i)=''''known_situation'''' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''VALIDATION_ERROR: Context field is too long'''');
     END IF;
   END LOOP;
   IF NOT j.has(''''objective_clarity'''') OR j.get_string(''''objective_clarity'''') IS NULL THEN j.put(''''objective_clarity'''',''''unknown'''');END IF;
   require(j.get_string(''''objective_clarity'''') IN (''''unknown');
 l_step:=l_step||TO_CLOB(''''',''''emerging'''',''''defined''''),''''VALIDATION_ERROR: Choose objective clarity'''');
   IF NOT j.h'');
 l_expected:=l_expected||TO_CLOB(''as(''''topic_preferences'''') THEN j.put(''''topic_preferences'''',JSON_OBJECT_T());END IF;
   IF NOT j.has(''''unknowns'''') THEN j.put(''''unknowns'''',JSON_ARRAY_T());END IF;
   IF NOT j.has(''''constraints'''') THEN j.put(''''constraints'''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_res');
 l_step:=l_step||TO_CLOB('ult OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;h'');
 l_expected:=l_expected||TO_CLOB(''ash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;replay_lock PLS_INTEGER;result_context VARCHAR2(32);result_status VARCHAR2(16);
 BEGIN
   p_lock:=NULL;
   kcv_access.assert_writable;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''''^[A-Za-z0-9_-]{16,80}$'''',''''c''''),''''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'''');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.G');
 l_step:=l_step||TO_CLOB('ET_HASH_VALUE(''''KCV_CONTEXT_REQUEST:''''||s||'''':''''||u||'''':''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>TRUE)'');
 l_expected:=l_expected||TO_CLOB('';
   require(lock_result=0,''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_acti');
 l_step:=l_step||TO_CLOB('on AND r.payload_sha256=hash_value,''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''',-20245);
     require(r.result_json IS NOT NULL,''''OPERATION_IN_PROGRESS: The prior request has not completed'''',-20246);
     SELECT JSON_V'');
 l_expected:=l_expected||TO_CLOB(''ALUE(r.result_json,''''$.context_id''''),JSON_VALUE(r.result_json,''''$.status'''') INTO result_context,result_status FROM dual;
     require(NVL(result_status,''''-'''')<>''''DELETED'''' AND result_context IS NOT NULL,
       ''''CONTEXT_UNAVAILABLE: The earlier request no longer returns an available context'''',-20241);
     replay_lock:=lock_owned_context(result_context);
     p_result:=r.result_json;release_request(replay_lock);release_req');
 l_step:=l_step||TO_CLOB('uest(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(replay_lock);release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_s'');
 l_expected:=l_expected||TO_CLOB(''ubject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''VALIDATION_ERROR: Supply a context title up to 200 chara');
 l_step:=l_step||TO_CLOB('cters'''');
 END;
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''C''''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_conte'');
 l_expected:=l_expected||TO_CLOB(''xts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=');
 l_step:=l_step||TO_CLOB('JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''''context_id'''',p_context);request.put(''''title'''',p_title);request.put(''''body'''',p_body);request.put(''''e'');
 l_expected:=l_expected||TO_CLOB(''xpected_version'''',p_expected_version);
   IF request_begin(''''SAVE_DRAFT'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''STALE_VERSION: New contexts have no saved version''''');
 l_step:=l_step||TO_CLOB(',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_ARCHIVED: Restore before editing'''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_vers'');
 l_expected:=l_expected||TO_CLOB(''ion+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''ARCHIVED'''';
     require(SQL%ROWCOUNT=1,''''STALE_VERSION: Reload your saved context before editing'''',-20242);
   END IF;
   resu');
 l_step:=l_step||TO_CLOB('lt:=request_finish(p_request_token,cid);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHA'');
 l_expected:=l_expected||TO_CLOB(''R2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''context_id'''',p_context);request.put(''''title'''',p_title);
   IF request_be');
 l_step:=l_step||TO_CLOB('gin(''''DUPLICATE'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   context_lock:=lock_owned_context(p_context);
   r:=context_row(p_context);provenance.put(''''kind'''',''''owned_context_copy'''');provenance.put(''''context_id'''',r.context_id);provenance.put(''''draft_version'''',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());result:=request_finish(p_request_token,cid);
   release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROL'');
 l_expected:=l_expected||TO_CLOB(''LBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VAR');
 l_step:=l_step||TO_CLOB('CHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''sample_id'''',p_sample);request.put(''''title'''',p_title);
   IF request_begin(''''COPY_SAMPLE'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   g'');
 l_expected:=l_expected||TO_CLOB('':=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts ');
 l_step:=l_step||TO_CLOB('c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Choose an available sample'''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''objective_clarity'''',''''unknown'''');
   IF source.has(''''question'''') THEN draft.put(''''question'''',source.get_string(''''question''''));END IF;
   IF source.has(''''learning_purpose'''') THEN draft.put(''''learning_purpose'''',source.get_string(''''learning_purpose''''));END IF;'');
 l_expected:=l_expected||TO_CLOB(''
   IF source.has(''''topic_preferences'''') THEN draft');
 l_step:=l_step||TO_CLOB('.put(''''topic_preferences'''',source.get_object(''''topic_preferences''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''kind'''',''''sample_suggestions'''');provenance.put(''''sample_id'''',p_sample);provenance.put(''''snapshot_id'''',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;n'');
 l_expected:=l_expected||TO_CLOB(');
 l_step:=l_step||TO_CLOB('''ew_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;n NUMBER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''RESTORE'''' ELSE ''''ARCHIVE'''' END;
   request.put(''''context_id'''',p_context);request.put(''''expected_version'''',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''ARCHIVED'''',''''VALIDATION_ERROR: Context is not archived'''');new_state:=NVL(r.prior_lifecycle,''''DRAFT'''');
   ELSE
     require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_AR');
 l_step:=l_step||TO_CLOB('CHIVED: Context is'');
 l_expected:=l_expected||TO_CLOB('' already archived'''',-20243);
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=p_context AND mutation_token IS NOT NULL;
     require(n=0,''''OPERATION_IN_PROGRESS: Complete or recover the pending answer before archiving'''',-20246);new_state:=''''ARCHIVED'''';
     SELECT COUNT(*) INTO n FROM kcv_personal_operations WHERE context_id=p_context AND phase IN(''''BUILDING'''',''''READY'''');
     require(n=0,''''OPERATION_IN_PROGRESS: Recover the interrupted context operation before archiving'''',-20246);
   END IF;
   UPDATE kcv_personal_contexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''''ARCHIVED'''' THEN li');
 l_step:=l_step||TO_CLOB('fecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at='');
 l_expected:=l_expected||TO_CLOB(''SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''''STALE_VERSION: Reload your saved context before changing its status'''',-20242);
   result:=request_finish(p_token,p_context);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_reques');
 l_step:=l_step||TO_CLOB('t_token,FALSE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VA'');
 l_expected:=l_expected||TO_CLOB(''RCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS BEGIN
   RETURN clean_body(p_body,p_graph);
 END;
END;
'');
 check_program(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',l_expected);
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c2-007-kcv_personal_context_api-package-body'' AND payload_sha256=''2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4'' AND phase=''COMPLETE'';
 require(l');
 l_step:=l_step||TO_CLOB('_n=1,''Missing or incompatible completion receipt: 2.0.0-c2-007-kcv_personal_context_api-package-body'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c3-013-kcv_personal_context_api-package-body'' AND payload_sha256=''be487186be2b3c41126eb37377cd83d9166fb7ecdd30ba2e7602f7687120d7c2'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);EN');
 l_step:=l_step||TO_CLOB('D IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA'');
 l_expected:=l_expected||TO_CLOB(''XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''''AL32UTF8''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS');
 l_step:=l_step||TO_CLOB('_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR'');
 l_expected:=l_expected||TO_CLOB(''CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_acces');
 l_step:=l_step||TO_CLOB('s.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE'');
 l_expected:=l_expected||TO_CLOB('' context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WH');
 l_step:=l_step||TO_CLOB('EN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''CONTEXT_UNAVAILABLE: Context is not available to this account'''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''''OPERATION_IN_PROGRESS: Another edit is being saved'''');END IF;RAISE;
 END;
 FUNCTION lock_owned_context(p_context VARCHAR2) RETURN PLS_INTEGER IS lock_id PLS_INTEGER;n PLS_INTEGER;BEGIN
   kcv_access.assert_context(p_context);kcv_access.assert_writable;
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''KCV_PERSONAL:''''||p_context,1,1073741823);
   n:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);
   '');
 l_expected:=l_expected||TO_CLOB(''require(n=0,''''OPERATION_IN_PROGRESS: Another context operation i');
 l_step:=l_step||TO_CLOB('s running'''',-20246);RETURN lock_id;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''''context_id'''',p_row.context_id);j.put(''''title'''',p_row.title);j.put(''''lifecycle'''',p_row.lifecycle);
   j.put(''''draft_version'''',p_row.draft_version);j.put(''''latest_revision'''',p_row.latest_revision);
   j.put(''''updated_at'''',TO_CHAR(p_row.updated_at,''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draf'');
 l_expected:=l_expected||TO_CLOB(''t JSON_OBJ');
 l_step:=l_step||TO_CLOB('ECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;ready_body CLOB;dirty NUMBER:=1;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''topic_preferences'''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''label'''',keys(i));topic.put(''''weight'''',prefs.get_number(keys(i)));topics.append(topic);
     END LOOP;
   END IF;
   j:=summary(r);j.put(''''base_graph'''',r.base_graph);j.put(''''draft'''',draft);j.put(''''selected_topics'''',topics);
   IF r.latest_revision IS NOT NULL THEN
     SELECT context_json INTO ready_body FROM kcv_scenario_revisions WHE');
 l_step:=l_step||TO_CLOB('RE'');
 l_expected:=l_expected||TO_CLOB('' revision_id=r.latest_revision AND context_id=r.context_id;
     SELECT CASE WHEN JSON_EQUAL(r.draft_json,ready_body) THEN 0 ELSE 1 END INTO dirty FROM dual;
     j.put(''''ready_context'''',JSON_OBJECT_T.parse(ready_body));
   END IF;
   j.put(''''has_unapplied_changes'''',dirty=1);
   IF r.provenance_json IS NOT NULL THEN j.put(''''provenance'''',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''''edit'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''archive'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''restore'''',r.lifecycle=''''ARCHIVED'''');
   cap.put(''''activate'''',r.lifecycle<>''''ARCHIVED'''');cap.put(''''start_conversation'''',r.lifecycle=''''ACTIVE'''');cap.put(''''duplicate'''',TRUE');
 l_step:=l_step||TO_CLOB(');
   j.put(''''capabilities'''',cap);j.put(''''feature_stage'''',''''personal-cont'');
 l_expected:=l_expected||TO_CLOB(''exts'''');
   j.put(''''notice'''',''''Private context. Topics select evidence; other context fields frame interpretation. Observations do not automatically change your context.'''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p');
 l_step:=l_step||TO_CLOB('_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_'');
 l_expected:=l_expected||TO_CLOB(''INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''''VALIDATION_ERROR: Page size must be 1 to 50'''');
   require(status_filter IS NULL OR status_filter IN (''''DRAFT'''',''''ACTIVE'''',''''ARCHIVED''''),''''VALIDATION_ERROR: Unknown context status'''');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''''VALIDATION_ERROR: Search is limited to 200 characters'''');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=con');
 l_step:=l_step||TO_CLOB('text_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=st'');
 l_expected:=l_expected||TO_CLOB(''atus_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''contexts'''',a);IF more_rows THE');
 l_step:=l_step||TO_CLOB('N j.put(''''next_cursor'''',last_id);ELSE j.put_null(''''next_cursor'''');END IF;
   j.put(''''feature_stage'''',''''personal-contexts'''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN '');
 l_expected:=l_expected||TO_CLOB(''CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   a:=JSON_ARRAY_T.parse(kcv_access.topic_options(g));
   j.put(''''base_graph'''',g);j.put(''''topics'''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VA');
 l_step:=l_step||TO_CLOB('RCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''''|question|objective_clarity|objective|person|role|organisation|known_situation|learning'');
 l_expected:=l_expected||TO_CLOB(''_purpose|time_horizon|unknowns|constraints|topic_preferences|'''';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Supply a JSON context object'''');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(');
 l_step:=l_step||TO_CLOB('INSTR(allowed,''''|''''||ks(i)||''''|'''')>0,''''VALIDATION_ERROR: Unknown context field'''');value:=j.get(ks(i));
     IF ks(i) IN (''''unknowns'''',''''constraints'''') THEN
       require(value.is_array,''''VALIDATION_ERROR: Unknowns and constraints must be arrays'''');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=2'');
 l_expected:=l_expected||TO_CLOB(''0,''''VALIDATION_ERROR: At most 20 unknowns or constraints'''');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''VALIDATION_ERROR: Each unknown or constraint must be text'''');
         require(LENGTH(a.get_string(k))<=500,''''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'''');
         requ');
 l_step:=l_step||TO_CLOB('ire(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''');
       END LOOP;
     ELSIF ks(i)=''''topic_preferences'''' THEN
       require(value.is_object,''''VALIDATION_ERROR: Topic preferences must be an object'''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=p'');
 l_expected:=l_expected||TO_CLOB(''refs.get_keys;
       require(topic_keys.COUNT<=20,''''VALIDATION_ERROR: At most 20 topics'''');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''''INVALID_TOPIC: Topic label is too long'''',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));requ');
 l_step:=l_step||TO_CLOB('ire(value.is_number,''''VALIDATION_ERROR: Topic weights must be numbers'''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''VALIDATION_ERROR: Topic weights must be 1 to 10'''');
         kcv_access.assert_topic(p_graph,topic_label);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''VALIDATION_ERROR: Context fields must be text'''');
       max_length:=CASE WHE'');
 l_expected:=l_expected||TO_CLOB(''N ks(i) IN (''''question'''',''''objective'''') THEN 2000 WHEN ks(i)=''''known_situation'''' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''VALIDATION_ERROR: Context field is too long'''');');
 l_step:=l_step||TO_CLOB('
     END IF;
   END LOOP;
   IF NOT j.has(''''objective_clarity'''') OR j.get_string(''''objective_clarity'''') IS NULL THEN j.put(''''objective_clarity'''',''''unknown'''');END IF;
   require(j.get_string(''''objective_clarity'''') IN (''''unknown'''',''''emerging'''',''''defined''''),''''VALIDATION_ERROR: Choose objective clarity'''');
   IF NOT j.has(''''topic_preferences'''') THEN j.put(''''topic_preferences'''',JSON_OBJECT_T());END IF;
   IF NOT j.has(''''unknowns'''') THEN j.put(''''unknowns'''',JSON_ARRAY_T());END IF;
'');
 l_expected:=l_expected||TO_CLOB(''   IF NOT j.has(''''constraints'''') THEN j.put(''''constraints'''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN');
 l_step:=l_step||TO_CLOB(' OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   kcv_access.assert_writab'');
 l_expected:=l_expected||TO_CLOB(''le;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''''^[A-Za-z0-9_-]{16,80}$'''',''''c''''),''''VALIDATION_ERROR: Supply a request token of 1');
 l_step:=l_step||TO_CLOB('6 to 80 safe characters'''');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''KCV_CONTEXT_REQUEST:''''||s||'''':''''||u||'''':''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>TRUE);
   require(lock_result=0,''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES'');
 l_expected:=l_expected||TO_CLOB(''(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX');
 l_step:=l_step||TO_CLOB(' THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''',-20245);
     require(r.result_json IS NOT NULL,''''OPERATION_IN_PROGRESS: The prior request has not completed'''',-20246);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owne'');
 l_expected:=l_expected||TO_CLOB(''r_scope;u VARCHAR2(128):=kcv_access.owner_subj');
 l_step:=l_step||TO_CLOB('ect;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''VALIDATION_ERROR: Supply a context title up to 200 characters'''');
 END;
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''C''''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subjec'');
 l_expected:=l_expected||TO_CLOB(''t;
 ');
 l_step:=l_step||TO_CLOB('BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;context_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''''context_id'''',p_context);request.put(''''title'''',p_title');
 l_step:=l_step||TO_CLOB(''');
 l_expected:=l_expected||TO_CLOB('');request.put(''''body'''',p_body);request.put(''''expected_version'''',p_expected_version);
   IF request_begin(''''SAVE_DRAFT'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''STALE_VERSION: New contexts have no saved version'''',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     context_lock:=lock_owned_context(p_context);r:=locked_context_row(p_context);require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_ARCHIVED: Restore before editing'''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     U');
 l_step:=l_step||TO_CLOB('PDATE kcv_personal_contexts SET title=TRIM(p_title'');
 l_expected:=l_expected||TO_CLOB(''),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''ARCHIVED'''';
     require(SQL%ROWCOUNT=1,''''STALE_VERSION: Reload your saved context before editing'''',-20242);
   END IF;
   result:=request_finish(p_request_token,cid);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   ');
 l_step:=l_step||TO_CLOB('request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB'');
 l_expected:=l_expected||TO_CLOB('';r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''context_id'''',p_context);request.put(''''title'''',p_title);
   IF request_begin(''''DUPLICATE'''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''''kind'''',''''owned_context_copy'''');provenance.put(''''context_id'''',r.context_id);provenance.put(''''draft_version'''',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN req');
 l_step:=l_step||TO_CLOB('uest_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION'');
 l_expected:=l_expected||TO_CLOB('' copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''sample_id'''',p_sample);request.put(''''title'''',p_title);
   IF request_begin(''''COPY_SAMPLE');
 l_step:=l_step||TO_CLOB(''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
'');
 l_expected:=l_expected||TO_CLOB(''     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''VALIDATION_ERROR: Choose an available sample'''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''objective_clarity'''',''''unknown'''');
   IF source.has(''''question'''') THEN draft.put(''''question'''',source.get_string(''''question''');
 l_step:=l_step||TO_CLOB('''));END IF;
   IF source.has(''''learning_purpose'''') THEN draft.put(''''learning_purpose'''',source.get_string(''''learning_purpose''''));END IF;
   IF source.has(''''topic_preferences'''') THEN draft.put(''''topic_preferences'''',source.get_object(''''topic_preference'');
 l_expected:=l_expected||TO_CLOB(''s''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''kind'''',''''sample_suggestions'''');provenance.put(''''sample_id'''',p_sample);provenance.put(''''snapshot_id'''',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_cha');
 l_step:=l_step||TO_CLOB('nge(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;context_lock PLS_INTEGER;n NUMBER;
 B'');
 l_expected:=l_expected||TO_CLOB(''EGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''RESTORE'''' ELSE ''''ARCHIVE'''' END;
   request.put(''''context_id'''',p_context);request.put(''''expected_version'''',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   context_lock:=lock_owned_context(p_context);r:=locked_context_ro');
 l_step:=l_step||TO_CLOB('w(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''ARCHIVED'''',''''VALIDATION_ERROR: Context is not archived'''');new_state:=NVL(r.prior_lifecycle,''''DRAFT'''');
   ELSE
     require(r.lifecycle<>''''ARCHIVED'''',''''CONTEXT_ARCHIVED: Context is already archived'''',-20243);
     SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=p_co'');
 l_expected:=l_expected||TO_CLOB(''ntext AND mutation_token IS NOT NULL;
     require(n=0,''''OPERATION_IN_PROGRESS: Complete or recover the pending answer before archiving'''',-20246);new_state:=''''ARCHIVED'''';
     SELECT COUNT(*) INTO n FROM kcv_personal_operations WHERE context_id=p_context AND phase IN(''''BUILDING'''',''''READY'''');
     require(n=0,');
 l_step:=l_step||TO_CLOB('''''OPERATION_IN_PROGRESS: Recover the interrupted context operation before archiving'''',-20246);
   END IF;
   UPDATE kcv_personal_contexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''''ARCHIVED'''' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,'');
 l_expected:=l_expected||TO_CLOB(''''''STALE_VERSION: Reload your saved context before changing its status'''',-20242);
   result:=request_finish(p_token,p_context);release_request(context_lock);RETURN result;
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(context_lock);r');
 l_step:=l_step||TO_CLOB('elease_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);EN'');
 l_expected:=l_expected||TO_CLOB(''D;
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS BEGIN
   RETURN clean_body(p_body,p_graph);
 END;
END;
'');
 check_program(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',l_expected);
 SELECT COUNT(*) IN');
 l_step:=l_step||TO_CLOB('TO l_n FROM kcv_schema_migrations WHERE migration_id=''2.0.0-c2-007-kcv_personal_context_api-package-body'' AND payload_sha256=''2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.0.0-c2-007-kcv_personal_context_api-package-body'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 l_sql:=TO_CLOB('''');
 l_sql:=l_sql||TO_CLOB(''-- Generated from immutable local SQL; do not edit this wrapper.
DECLARE
 l_sql CLOB; l_hash VARCHAR2(64); l_phase VARCHAR2(16); l_started BOOLEAN:=FALSE;
 l_lock VARCHAR2(128); l_lock_result PLS_INTEGER; l_error NUMBER;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_a');
 l_step:=l_step||TO_CLOB('ctual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''''''''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,'');
 l_sql:=l_sql||TO_CLOB(''i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN ('''' '''',CHR(9),CHR(10),CHR(13),''''"'''') THEN r:=r||UPPER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PR');
 l_step:=l_step||TO_CLOB('OCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''''''''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''''VALID'''';
  require(n=1,''''Missing or invalid program: ''''||p_name||'''' ''''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''''ERROR'''';
  require(n=0,''''Compilation errors: ''''||p_name||'''' ''''||p_type);
  FOR r'');
 l_sql:=l_sql||TO_CLOB('' IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''''--'''' THEN
    actu');
 l_step:=l_step||TO_CLOB('al:=actual||RTRIM(r.text,CHR(13)||CHR(10)||'''' '''')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,''''Installed source differs: ''''||p_name||'''' ''''||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); '');
 l_sql:=l_sql||TO_CLOB(''def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR');
 l_step:=l_step||TO_CLOB('2(1); wanted_column VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string(''''name'''');cols:=t.get_array(''''columns'''');cs:=t.get_array(''''constraints'''');
  wanted_temp:=t.get_string(''''temporary'''');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,''''Missing or incompatible table: ''''||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,''''Column count differs: ''''||name);
  FOR i IN 0..cols.get_s'');
 l_sql:=l_sql||TO_CLOB(''ize-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string(''''name'''');
   BEGIN SELECT data_t');
 l_step:=l_step||TO_CLOB('ype,nullable,char_length,data_precision,data_scale,identity_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,''''Missing column: ''''||name||''''.''''||c.get_string(''''name'''')); END;
   require(actual_type=c.get_string(''''type''''),''''Column type differs: ''''||name||''''.''''||c.get_string(''''name''''));
   require(actual_nullable=c.get_string(''''nullable''''),''''Column nullability differs: ''''||name||''''.''''||c.get_string(''''na'');
 l_sql:=l_sql||TO_CLOB(''me''''));
   IF c.has(''''length'''') THEN
    require(len=c.get_number(''');
 l_step:=l_step||TO_CLOB('''length''''),''''Column length differs: ''''||name||''''.''''||c.get_string(''''name''''));
    require(char_semantics=c.get_string(''''char_used''''),''''Column character semantics differ: ''''||name||''''.''''||c.get_string(''''name''''));
   END IF;
   IF c.get_string(''''type'''')=''''NUMBER'''' THEN
    require(NVL(prec,-1)=NVL(c.get_number(''''precision''''),-1) AND NVL(sc,-99)=NVL(c.get_number(''''scale''''),-99),''''Number precision differs: ''''||name||''''.''''||c.get_string(''''name''''));
   END IF;
   require(ident=c.get_string(''''identity''''),''''Column identity differs: ''''||name||''''.''''||c.get_string(''''name''''));
   IF ident=''''NO'''' THEN d:=def;require(NVL(compact(d),''''#NULL#'''')=NVL(compact(c.get_string(''''default'''')),''''#N'');
 l_sql:=l_sql||');
 l_step:=l_step||TO_CLOB('TO_CLOB(''ULL#''''),''''Column default differs: ''''||name||''''.''''||c.get_string(''''name''''));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;wanted_constraint:=c.get_string(''''type'''');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status=''''ENABLED'''' AND validated=''''VALIDATED''''
      AND deferrable=''''NOT DEFERRABLE'''' AND (constraint_type<>''''R'''' OR (delete_rule=''''NO ACTION'''' AND r_owner=USER))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,'''','''') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_colum');
 l_step:=l_step||TO_CLOB('ns WHERE constraint_name=r.con'');
 l_sql:=l_sql||TO_CLOB(''straint_name;
    IF r.constraint_type=''''C'''' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string(''''expression'''')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_string(''''columns'''') THEN
     IF r.constraint_type=''''R'''' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,'''','''') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string(''''reference_table'''') AND refcols=c.get_string(''''reference_columns'''') THEN found:=TRUE;END IF;
     ELSE found:=');
 l_step:=l_step||TO_CLOB('TRUE;END IF;
    END IF;
   END LOOP;
   require(found,''''Missing or incom'');
 l_sql:=l_sql||TO_CLOB(''patible constraint: ''''||name||'''' ''''||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r.constraint_type<>''''C'''' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),''''^[A-Z][A-Z0-9_$]*ISNOTNULL$'''') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,''''Unexpected constraints: ''''||name);
 END;

BEGIN
 require(SYS_CONTEXT(''''USERENV'''',''''CURRENT_SCHEMA'''')=SYS_CONTEXT(''''USERENV'''',''''SESSION_USER'''')
  AND SYS_CONTEXT(''''USERENV'''',''''SESSION_USE');
 l_step:=l_step||TO_CLOB('R'''') NOT IN (''''ADMIN'''',''''SYS'''',''''SYSTEM''''),''''Connect as the intended project schema owner'''');
 DBMS_LOCK.ALLOCATE_UNIQUE(''''KCV_SCHE'');
 l_sql:=l_sql||TO_CLOB(''MA_''''||SYS_CONTEXT(''''USERENV'''',''''CURRENT_SCHEMA''''),l_lock);
 l_lock_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_lock_result=0,''''Another schema migration is active'''');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''''2.0.0-c2-006-kcv_personal_context_api-package'''' AND payload_sha256=''''4623e8027a7c1322905c87cc14037327946c8b96e800f6f7dc5cf539f0081700'''' AND phase=''''COMPLETE'''';
 require(l_n=1,''''Required prior migration is incomplete: 2.0.0-c2-006-kcv_personal_context_api-package'''');

 BEGI');
 l_step:=l_step||TO_CLOB('N SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id=''''2.0.0-c2-007-kcv_personal_context_api-package-body'''';
 EXCEPTION WHEN NO_DATA_'');
 l_sql:=l_sql||TO_CLOB(''FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash=''''2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4'''',''''Migration payload/verification changed: 2.0.0-c2-007-kcv_personal_context_api-package-body'''');
  require(l_phase=''''COMPLETE'''',''''Incomplete migration requires verified recovery: 2.0.0-c2-007-kcv_personal_context_api-package-body'''');
l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE re');
 l_step:=l_step||TO_CLOB('quire(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_chec'');
 l_sql:=l_sql||TO_CLOB(''k(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''''''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA'''');
 l_expected:=l_');
 l_step:=l_step||TO_CLOB('expected||TO_CLOB(''''XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''''''''AL32UTF8''''''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   requi'');
 l_sql:=l_sql||TO_CLOB(''re(warning=0 AND byte_count<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''''''');
 EXCEPTION WHEN OTHERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''''''ACTIVE_GRAPH'''''''';
   RETURN g;
 EXCEPTION WHEN NO_DATA');
 l_step:=l_step||TO_CLOB('_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR'''');
 l_expected:=l_expected||TO_CLOB(''''CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * I'');
 l_sql:=l_sql||TO_CLOB(''NTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s');
 l_step:=l_step||TO_CLOB(' VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE'''');
 l_expected:=l_expected||TO_CLOB('''' context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATI'');
 l_sql:=l_sql||TO_CLOB(''ON_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATION_ERROR(-20246,''''''''OPERATION_IN_PROGRESS: Another edit is being saved'''''''');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OB');
 l_step:=l_step||TO_CLOB('JECT_T();BEGIN
   j.put(''''''''context_id'''''''',p_row.context_id);j.put(''''''''title'''''''',p_row.title);j.put(''''''''lifecycle'''''''',p_row.lifecycle);
   j.put(''''''''draft_version'''''''',p_row.draft_version);j.put(''''''''latest_revision'''''''',p_row.latest_revision);
   j.put'''');
 l_expected:=l_expected||TO_CLOB(''''(''''''''updated_at'''''''',TO_CHAR(p_row.updated_at,''''''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''''''));
   RETURN '');
 l_sql:=l_sql||TO_CLOB(''j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic ');
 l_step:=l_step||TO_CLOB('JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''''''topic_preferences'''''''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''''''label'''''''',keys(i));topic.put(''''''''weight'''''''',prefs.get_number(keys(i)));topics.append(topic);
    '''');
 l_expected:=l_expected||TO_CLOB('''' END LOOP;
   END IF;
   j:=summary(r);j.put('');
 l_sql:=l_sql||TO_CLOB(''''''''''base_graph'''''''',r.base_graph);j.put(''''''''draft'''''''',draft);j.put(''''''''selected_topics'''''''',topics);
   IF r.provenance_json IS NOT NULL THEN j.put(''''''''provenance'''''''',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''''''''edit'''''''',r.');
 l_step:=l_step||TO_CLOB('lifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''archive'''''''',r.lifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''restore'''''''',r.lifecycle=''''''''ARCHIVED'''''''');
   cap.put(''''''''activate'''''''',FALSE);cap.put(''''''''start_conversation'''''''',FALSE);cap.put(''''''''duplicate'''''''',TRUE);
   j.put(''''''''capabilities'''''''',cap);j.put(''''''''feature_stage'''''''',''''''''persistent-drafts'''''''');
   j.put(''''''''notice'''''''',''''''''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sample journeys remain '''');
 l_exp'');
 l_sql:=l_sql||TO_CLOB(''ected:=l_expected||TO_CLOB(''''available.'''''''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search V');
 l_step:=l_step||TO_CLOB('ARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p'');
 l_sql:=l_sql||TO_CLOB(''_limit=TRUNC(p_limit),''''''''VALIDA'''');
 l_expected:=l_expected||TO_CLOB(''''TION_ERROR: Page size must be 1 to 50');
 l_step:=l_step||TO_CLOB(''''''''');
   require(status_filter IS NULL OR status_filter IN (''''''''DRAFT'''''''',''''''''ACTIVE'''''''',''''''''ARCHIVED''''''''),''''''''VALIDATION_ERROR: Unknown context status'''''''');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''''''''VALIDATION_ERROR: Search is limited to 200 characters'''''''');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(sea'');
 l_sql:=l_sql||TO_CLOB(''rch_filter))>0)
     AND (p_before_id IS NULL OR update');
 l_step:=l_step||TO_CLOB('d_at<cursor_row.updated_'''');
 l_expected:=l_expected||TO_CLOB(''''at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''''''contexts'''''''',a);IF more_rows THEN j.put(''''''''next_cursor'''''''',last_id);ELSE j.put_null(''''''''next_cursor'''''''');END IF;
   j.put(''''''''feature_stage'''''''',''''''''persistent-drafts'''''''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_co'');
 l_sql:=l_sql||TO_CLOB(''ntext');
 l_step:=l_step||TO_CLOB('s%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kc'''');
 l_expected:=l_expected||TO_CLOB(''''v_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARCHAR2(200) PATH ''''''''$'''''''')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
         AND REGEXP');
 l_step:=l_step||TO_CLOB('_LIKE(gs.vers'');
 l_sql:=l_sql||TO_CLOB(''ion_id,''''''''^S[0-9]+-v'''''''')
         AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label) LOOP
     a.append(t.label);
   END LOOP;
   j.'''');
 l_expected:=l_expected||TO_CLOB(''''put(''''''''base_graph'''''''',g);j.put(''''''''topics'''''''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''''''''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|''');
 l_step:=l_step||TO_CLOB(''''''';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200'');
 l_sql:=l_sql||TO_CLOB('');max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Supply a JSON context object'''''''');E'''');
 l_expected:=l_expected||TO_CLOB(''''ND;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''''''''|''''''''||ks(i)||''''''''|'''''''')>0,''''''''VALIDATION_ERROR: Unknown context field'''''''');value:=j.get(ks(i));
     IF ks(i) IN (''''''''unknowns'''''''',''''''''constraints'''''''') THEN
       require(value.is_array,''''''''VALIDATION_ERROR: Unknowns and constraints must be arrays'''''''');a:=TREAT(v');
 l_step:=l_step||TO_CLOB('alue AS JSON_ARRAY_T);
       require(a.get_size<=20,''''''''VALIDATION_ERROR: At most 20 unknowns or constraints'''''''');
     '');
 l_sql:=l_sql||TO_CLOB(''  FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''''''VALIDATION_ERROR: Each unknown or constraint must be text'''''''');
         require(LENGTH(a.get_string(k))<=500,''''''''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'''''''');
    '''');
 l_expected:=l_expected||TO_CLOB(''''     require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''''''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''''''');
       END LOOP;
     ELSIF ks(i)=''''''''topic_preference');
 l_step:=l_step||TO_CLOB('s'''''''' THEN
       require(value.is_object,''''''''VALIDATION_ERROR: Topic preferences must be an object'''''''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
 '');
 l_sql:=l_sql||TO_CLOB(''      require(topic_keys.COUNT<=20,''''''''VALIDATION_ERROR: At most 20 topics'''''''');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''''''''INVALID_TOPIC: Topic label is too long'''''''',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''''''''VALIDATION_ERROR: '''');
 l_expected:=l_expected||TO_CLOB(''''Topic weights must be numbers'''''''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''''''VALIDATION_ERR');
 l_step:=l_step||TO_CLOB('OR: Topic weights must be 1 to 10'''''''');
         SELECT COUNT(*) INTO n FROM kcv_graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNIN'');
 l_sql:=l_sql||TO_CLOB(''G NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
               AND REGEXP_LIKE(gs.version_id,''''''''^S[0-9]+-v'''''''') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
           AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARCHAR2(200) PATH ''''''''$'''''''''''');
 l_expected:=l_expected||TO_CLOB('''')) jt WHERE jt.lab');
 l_step:=l_step||TO_CLOB('el=topic_label);
         require(n>0,''''''''INVALID_TOPIC: Choose an evidence topic from the pinned collection'''''''',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''''''VALIDATION_ERROR: Context fields must be text'''''''');
       max_length:=CAS'');
 l_sql:=l_sql||TO_CLOB(''E WHEN ks(i) IN (''''''''question'''''''',''''''''objective'''''''') THEN 2000 WHEN ks(i)=''''''''known_situation'''''''' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''''''VALIDATION_ERROR: Context field is too long'''''''');
     END IF;
   END LOOP;
   IF NOT j.has(''''''''objective_clarity'''''''') OR j.get_string(''''''''objective_clarity'''''''') IS NULL T');
 l_step:=l_step||TO_CLOB('HEN j.put(''''''''objective_clarity'''''''',''''''''unknown'''''''');END IF;
   requir'''');
 l_expected:=l_expected||TO_CLOB(''''e(j.get_string(''''''''objective_clarity'''''''') IN (''''''''unknown'''''''',''''''''emerging'''''''',''''''''defined''''''''),''''''''VALIDATION_ERROR: Choose objective clarity'''''''');
   IF NOT j.has(''''''''topic_preferences'''''''') THEN j.put(''''''''topic_preferences'''''''',JSON_OBJECT_T());END IF;
 '');
 l_sql:=l_sql||TO_CLOB(''  IF NOT j.has(''''''''unknowns'''''''') THEN j.put(''''''''unknowns'''''''',JSON_ARRAY_T());END IF;
   IF NOT j.has(''''''''constraints'''''''') THEN j.put(''''''''constraints'''''''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS');
 l_step:=l_step||TO_CLOB('_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT C'''');
 l_expected:=l_expected||TO_CLOB(''''LOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_contex'');
 l_sql:=l_sql||TO_CLOB(''t_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''''''''^[A-Za-z0-9_-]{16,80}$'''''''',''''''''c''''''''),''''''''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters');
 l_step:=l_step||TO_CLOB(''''''''');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''''''KCV_CONTEXT_REQUEST:''''''''||s||'''''''':''''''''||u||'''''''':''''''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,re'''');
 l_expected:=l_expected||TO_CLOB(''''lease_on_commit=>TRUE);
   require(lock_result=0,''''''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''''''',-'');
 l_sql:=l_sql||TO_CLOB(''20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPT');
 l_step:=l_step||TO_CLOB('ION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''''''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''''''',-20245);
     require(r.result_json IS NOT NULL,''''''''OPERATION_IN_PROGRESS: The prior request has not completed'''''''',-2024'''');
 l_expected:=l_expected||TO_CLOB(''''6);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   '');
 l_sql:=l_sql||TO_CLOB(''END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128)');
 l_step:=l_step||TO_CLOB(':=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''''''VALIDATION_ERROR: Supply a context title up to 200 characters'''''''');
 END;
 FUNCTION'''');
 l_expected:=l_expected||TO_CLOB('''' insert_draft(p_title VARCHAR2,p_'');
 l_sql:=l_sql||TO_CLOB(''body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''''''C''''''''||SUBSTR(RAWTOHEX(SYS_G');
 l_step:=l_step||TO_CLOB('UID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARCHAR'''');
 l_expected:=l_expected||TO'');
 l_sql:=l_sql||TO_CLOB(''_CLOB(''''2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVE');
 l_step:=l_step||TO_CLOB('POINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);request.put(''''''''body'''''''',p_body);request.put(''''''''expected_version'''''''',p_expected_version);
   IF request_begin(''''''''SAVE_DRAFT'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''''''STALE_VERSION: New contexts have no saved version'''''''',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_con'');
 l_sql:=l_sql||TO_CLOB(''text_row(p_context)'''');
 l_expected:=l_expect');
 l_step:=l_step||TO_CLOB('ed||TO_CLOB('''';require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Restore before editing'''''''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''''''ARCHIVED'''''''';
     require(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before editing'''''''',-20242);
   END IF;
   RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_cont'');
 l_sql:=l_sql||TO_CLOB(');
 l_step:=l_step||TO_CLOB('''ext(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2)'''');
 l_expected:=l_expected||TO_CLOB('''' RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''DUPLICATE'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''''''''kind'''''''',''''''''owned_context_copy'''''''');provenance.put(''''''''context_id'''''''',r.context_id);provenance.put(''''''''draft_ve');
 l_step:=l_step||TO_CLOB('rsion'''''''',r.draft_version);
   '');
 l_sql:=l_sql||TO_CLOB(''cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_request_token,cid);'''');
 l_expected:=l_expected||TO_CLOB(''''
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEP');
 l_step:=l_step||TO_CLOB('OINT kcv_context_write;title_check(p_title);request.put(''''''''sam'');
 l_sql:=l_sql||TO_CLOB(''ple_id'''''''',p_sample);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''COPY_SAMPLE'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
  '''');
 l_expected:=l_expected||TO_CLOB('''' g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Choose an available sam');
 l_step:=l_step||TO_CLOB('ple'''''''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''''''objective_clarity'''''''',''''''''unknown'''''''');
   I'');
 l_sql:=l_sql||TO_CLOB(''F source.has(''''''''question'''''''') THEN draft.put(''''''''question'''''''',source.get_string(''''''''question''''''''));END IF;
   IF source.has(''''''''learning_purpose'''''''') THEN draft.put(''''''''learning_purpose'''''''',source.get_string(''''''''learning_purpose''''''''));END I'''');
 l_expected:=l_expected||TO_CLOB(''''F;
   IF source.has(''''''''topic_preferences'''''''') THEN draft.put(''''''''topic_preferences'''''''',source.get_object(''''''''topic_preferences''''''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''''''kind'''''''',''''''''sample_suggestions'''''''');provenance.put(''''''''sample_id'''''''',p_sam');
 l_step:=l_step||TO_CLOB('ple);provenance.put(''''''''snapshot_id'''''''',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO '');
 l_sql:=l_sql||TO_CLOB(''kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE'''');
 l_expected:=l_expected||TO_CLOB('''';new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''''''RESTORE''''''''');
 l_step:=l_step||TO_CLOB(' ELSE ''''''''ARCHIVE'''''''' END;
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''expected_version'''''''',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=locked_cont'');
 l_sql:=l_sql||TO_CLOB(''ext_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''''''ARCHIVED'''''''',''''''''VALIDATION_ERROR: Context is not archived'''''''');new_state:=NVL(r.prior_lifecycle,''''''''DRAFT'''''''');
   ELSE require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Context is already archived'''''''',-20243);new_state:=''''''''ARCHIVED'''''''';END IF;
   UPDATE kcv_personal_c'''');
 l_expected:=l_expected||TO_CLOB(''''ontexts SET lifecycle=new_state,
     ');
 l_step:=l_step||TO_CLOB('prior_lifecycle=CASE WHEN new_state=''''''''ARCHIVED'''''''' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before changing its '');
 l_sql:=l_sql||TO_CLOB(''status'''''''',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 ');
 l_step:=l_step||TO_CLOB('FU'''');
 l_expected:=l_expected||TO_CLOB(''''NCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
END;
'''');
 check_program(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE BODY'''',l_expected);
 ELSE
  INSERT I'');
 l_sql:=l_sql||TO_CLOB(''NTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES(''''2.0.0-c2-007-kcv_personal_context_api-package-body'''',''''2b940ca81dc485e759a951f84ada608c939f4eb782a7465ee3554cb48078bfd4'''',''''2.0.0'''',''''RUNNING'''');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('''''''');
 l_sql:=l_sql||TO_CLOB(''''CREATE OR REPLACE PACKA');
 l_step:=l_step||TO_CLOB('GE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAUL'');
 l_sql:=l_sql||TO_CLOB(''T_LANG_CTX;warning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''''''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>');
 l_step:=l_step||TO_CLOB('p_body,amou'''');
 l_sql:=l_sql||TO_CLOB(''''nt=>DBMS_LOB.LOBMAXSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''''''''AL32UTF8''''''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''''''');
 EXCEPTION WHEN OTH'');
 l_sql:=l_sql||TO_CLOB(''ERS THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETURN VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''''''ACTIVE_GRAPH''''''');
 l_step:=l_step||TO_CLOB(''';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context'''');
 l_sql:=l_sql||TO_CLOB(''''_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN NO_DATA'');
 l_sql:=l_sql||TO_CLOB(''_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kc');
 l_step:=l_step||TO_CLOB('v_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_perso'''');
 l_sql:=l_sql||TO_CLOB(''''nal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THEN RAISE_APPLICATIO'');
 l_sql:=l_sql||TO_CLOB(''N_ERROR(-20246,''''''''OPERATION_IN_PROGRESS: Another edit is being saved'''''''');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSO');
 l_step:=l_step||TO_CLOB('N_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''''''''context_id'''''''',p_row.context_id);j.put(''''''''title'''''''',p_row.title);j.put(''''''''lifecycle'''''''',p_row.lifecycle);
   j.put(''''''''draft_version'''''''',p_row.draft_version);j.put(''''''''latest_revision'''''''',p_row.latest_r'''');
 l_sql:=l_sql||TO_CLOB(''''evision);
   j.put(''''''''updated_at'''''''',TO_CHAR(p_row.updated_at,''''''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''''''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j JSON_OBJECT_T;cap JSON_OBJEC'');
 l_sql:=l_sql||TO_CLOB(''T_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T');
 l_step:=l_step||TO_CLOB('();topic JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''''''topic_preferences'''''''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''''''label'''''''',keys(i));topic.put(''''''''weight'''''''',prefs.get_number(keys(i)));topics.a'''');
 l_sql:=l_sql||TO_CLOB(''''ppend(topic);
     END LOOP;
   END IF;
   j:=summary(r);j.put(''''''''base_graph'''''''',r.base_graph);j.put(''''''''draft'''''''',draft);j.put(''''''''selected_topics'''''''',topics);
   IF r.provenance_json IS NOT NULL THEN j.put(''''''''provenance'''''''',JSON_OBJECT_T.pa'');
 l_sql:=l_sql||TO_CLOB(''rse(r.provenance_json));END IF;
   cap.put(''''''''edit'''''''',r.l');
 l_step:=l_step||TO_CLOB('ifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''archive'''''''',r.lifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''restore'''''''',r.lifecycle=''''''''ARCHIVED'''''''');
   cap.put(''''''''activate'''''''',FALSE);cap.put(''''''''start_conversation'''''''',FALSE);cap.put(''''''''duplicate'''''''',TRUE);
   j.put(''''''''capabilities'''''''',cap);j.put(''''''''feature_stage'''''''',''''''''persistent-drafts'''''''');
   j.put(''''''''notice'''''''',''''''''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sampl'''');
 l_sql:=l_sql||TO_CLOB(''''e journeys remain available.'''''''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id V''');
 l_step:=l_step||TO_CLOB(');
 l_sql:=l_sql||TO_CLOB(''ARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limit BETWEEN 1 AND 50 AND p_limit=TRUN'''');
 l_sql:=l_sql||TO_CLOB(''''C(p_limit),''''''''VALIDATION_ERROR: Page size must be 1 to 50'''''''');
   require(status_filter IS NULL OR status');
 l_step:=l_step||TO_CLOB('_filter IN (''''''''DRAFT'''''''',''''''''ACTIVE'''''''','');
 l_sql:=l_sql||TO_CLOB(''''''''''ARCHIVED''''''''),''''''''VALIDATION_ERROR: Unknown context status'''''''');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''''''''VALIDATION_ERROR: Search is limited to 200 characters'''''''');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<c'''');
 l_sql:=l_sql||TO_CLOB(''''ursor_row.upd');
 l_step:=l_step||TO_CLOB('ated_at OR
       (updated_at=cursor_row.updated_at AND context_id<p_before_id))
  '');
 l_sql:=l_sql||TO_CLOB(''   ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''''''contexts'''''''',a);IF more_rows THEN j.put(''''''''next_cursor'''''''',last_id);ELSE j.put_null(''''''''next_cursor'''''''');END IF;
   j.put(''''''''feature_stage'''''''',''''''''persistent-drafts'''''''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j ');
 l_step:=l_step||TO_CLOB('JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128'''');
 l_sql:=l_sql||TO_CLOB('''');
 BEGIN
   s:=kcv_access.owner_scope;
   IF p_context IS'');
 l_sql:=l_sql||TO_CLOB('' NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARCHAR2(200) PATH ''''''''$'''''''')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
         AND REGEXP_LIKE(gs.version_id,''''''''^S[0-9]+-v'''''''')
 ');
 l_step:=l_step||TO_CLOB('        AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label) LOOP
     a.append(t.label);
'''');
 l_sql:=l_sql||TO_CLOB(''''   END LOOP;
   j.pu'');
 l_sql:=l_sql||TO_CLOB(''t(''''''''base_graph'''''''',g);j.put(''''''''topics'''''''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2(1000):=''''''''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'''''''';
   text_value VARCHAR2(32767);topic_label VARC');
 l_step:=l_step||TO_CLOB('HAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Supply a JSON '''');
 l_sql:=l'');
 l_sql:=l_sql||TO_CLOB(''_sql||TO_CLOB(''''context object'''''''');END;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''''''''|''''''''||ks(i)||''''''''|'''''''')>0,''''''''VALIDATION_ERROR: Unknown context field'''''''');value:=j.get(ks(i));
     IF ks(i) IN (''''''''unknowns'''''''',''''''''constraints'''''''') THEN
       require(value.is_array,''''''''VALIDATION_ERROR: Unknowns and constraints must be arrays'''''''');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''''''''VALI');
 l_step:=l_step||TO_CLOB('DATION_ERROR: At most 20 unknowns or constraints'''''''');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''''''VALIDATION_ERROR: Each unknown or constraint must be text'''''''');
         require(LENGTH(a.get_string(k))<=500,''''''''VALIDATION_ERROR: Each unknown o'');
 l_sql:=l_sql||TO_CLOB(''r constraint must be at most 500 '''');
 l_sql:=l_sql||TO_CLOB(''''characters'''''''');
         require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_string(k),CHR(13))=0,
           ''''''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''''''');
       END LOOP;
     ELSIF ks(i)=''''''''topic_preferences'''''''' THEN
       require(value.is_object,''''''''VALIDATION_ERROR: Topic p');
 l_step:=l_step||TO_CLOB('references must be an object'''''''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''''''''VALIDATION_ERROR: At most 20 topics'''''''');
       FOR k IN 1..topic_keys.COUNT LOOP
         require(LENGTH(topic_keys(k))<=200,''''''''INVALID_TOPIC: Topic label is too long'''''''',-20247);topic_label:=topic_key'');
 l_sql:=l_sql||TO_CLOB(''s(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,'''''''''''');
 l_sql:=l_sql||TO_CLOB(''''VALIDATION_ERROR: Topic weights must be numbers'''''''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''''''VALIDATION_ERROR: Topic weights must be 1 to 10'''''''');
         SELECT COUNT(*) INTO n FROM kcv_');
 l_step:=l_step||TO_CLOB('graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
               AND REGEXP_LIKE(gs.version_id,''''''''^S[0-9]+-v'''''''') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.'');
 l_sql:=l_sql||TO_CLOB(''version_id)))
           AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARC'''');
 l_sql:=l_sql||TO_CLOB(''''HAR2(200) PATH ''''''''$'''''''')) jt WHERE jt.label=topic_label);
         require(n>0,''''''''INVALID_TOPIC: Choose an evidence topic from the ');
 l_step:=l_step||TO_CLOB('pinned collection'''''''',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''''''VALIDATION_ERROR: Context fields must be text'''''''');
       max_length:=CASE WHEN ks(i) IN (''''''''question'''''''',''''''''objective'''''''') THEN 2000 WHEN ks(i)=''''''''known_situation'''''''' THEN 4000 ELSE 200 END;
       text_value:=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''''''VALIDATION_ERROR: Context field is too long'');
 l_sql:=l_sql||TO_CLOB('''''''''');
     END IF;
   END LOOP;
   IF NOT j.has(''''''''objective_clarity'''''''') OR j.get_string(''''''''objective_clarity'''''''') IS NULL THEN j.put(''''''''objective_clarity'''''''',''''''''unknown'''''''')'''');
 l_sql:=l_sql||TO_CLOB('''';END IF;
');
 l_step:=l_step||TO_CLOB('   require(j.get_string(''''''''objective_clarity'''''''') IN (''''''''unknown'''''''',''''''''emerging'''''''',''''''''defined''''''''),''''''''VALIDATION_ERROR: Choose objective clarity'''''''');
   IF NOT j.has(''''''''topic_preferences'''''''') THEN j.put(''''''''topic_preferences'''''''',JSON_OBJECT_T());END IF;
   IF NOT j.has(''''''''unknowns'''''''') THEN j.put(''''''''unknowns'''''''',JSON_ARRAY_T());END IF;
   IF NOT j.has(''''''''constraints'''''''') THEN j.put(''''''''constraints'''''''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT P'');
 l_sql:=l_sql||TO_CLOB(''LS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
');
 l_step:=l_step||TO_CLOB(' END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJEC'''');
 l_sql:=l_sql||TO_CLOB(''''T_T,p_result OUT CLOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''''''''^[A-Za-z0-9_-]{16,80}$'''''''',''''''''c''''''''),''''''''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'''''''');
   hash_value:=LOWE'');
 l_sql:=l_sql||TO_CLOB(''R(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id');
 l_step:=l_step||TO_CLOB(':=DBMS_UTILITY.GET_HASH_VALUE(''''''''KCV_CONTEXT_REQUEST:''''''''||s||'''''''':''''''''||u||'''''''':''''''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_'''');
 l_sql:=l_sql||TO_CLOB(''''MODE,timeout=>0,release_on_commit=>TRUE);
   require(lock_result=0,''''''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''''''',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests(owner_scope,owner_subject,request_token,action,payload_sha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHER'');
 l_sql:=l_sql||TO_CLOB(''E owner_scope=s AND owner_subject=u AND');
 l_step:=l_step||TO_CLOB(' request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''''''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''''''',-20245);
     require(r.result_json IS NOT NULL,''''''''OPERATION_IN_PROGRESS: The prior request has no'''');
 l_sql:=l_sql||TO_CLOB(''''t completed'''''''',-20246);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCHAR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_conte'');
 l_sql:=l_sql||TO_CLOB(''x');
 l_step:=l_step||TO_CLOB('t_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''''''VALIDATION_ERROR: Supply a context title up to 200 characters'''''''''''');
 l_sql:=l_sql||TO_CLOB('''');
 END;
 FUNCTION insert_draft(p_title VARCHAR2,p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''''''C''''''''||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,ow');
 l_step:=l_step||TO_CLOB('ner_subje'');
 l_sql:=l_sql||TO_CLOB(''ct,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p'''');
 l_sql:=l_sql||TO_CLOB(''''_context;g VARCHAR2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   title_check(p_title);body_size_check(p_body);
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);request.put(''''''''body'''''''',');
 l_step:=l_step||TO_CLOB('p_body);request.put(''''''''expected_version'''''''',p_expected'');
 l_sql:=l_sql||TO_CLOB(''_version);
   IF request_begin(''''''''SAVE_DRAFT'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''''''STALE_VERSION: New contexts have no saved version'''''''',-20242);
     g:=active_graph;clean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_cont'''');
 l_sql:=l_sql||TO_CLOB(''''ext_row(p_context);require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Restore before editing'''''''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts');
 l_step:=l_step||TO_CLOB(' SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     '');
 l_sql:=l_sql||TO_CLOB(''  WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''''''ARCHIVED'''''''';
     require(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before editing'''''''',-20242);
   END IF;
   RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_reque'''');
 l_sql:=l_sql||TO_CLOB(''''st_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJE');
 l_step:=l_step||TO_CLOB('CT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_c'');
 l_sql:=l_sql||TO_CLOB(''heck(p_title);request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''DUPLICATE'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=context_row(p_context);provenance.put(''''''''kind'''''''',''''''''owned_context_copy'''''''');provenance.put(''''''''context_id'''''''',r.context_id);provenance.put(''''''''draft_version'''''''',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_r'''');
 l_sql:=l_sql||TO_CLOB(''''equest_toke');
 l_step:=l_step||TO_CLOB('n,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETUR'');
 l_sql:=l_sql||TO_CLOB(''N CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''''''sample_id'''''''',p_sample);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''COPY_SAMPLE'''''''',p_request_token,reque');
 l_step:=l_step||TO_CLOB('st,result,request_lock) THEN RETURN'''');
 l_sql:=l_sql||TO_CLOB('''' result;END IF;
   g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapsho'');
 l_sql:=l_sql||TO_CLOB(''t_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Choose an available sample'''''''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''''''objective_clarity'''''''',''''''''unknown'''''''');
   IF source.has(''''''''question'''''''') THEN draft.put(''''''''question'''''''',source.get_st');
 l_step:=l_step||TO_CLOB('ring(''''''''question''''''''));END IF;
   IF source.has(''''''''learning_purpose'''''''') THEN draft.put(''''''''learning_purpose'''''''',source.get_string(''''''''learnin'''');
 l_sql:=l_sql||TO_CLOB(''''g_purpose''''''''));END IF;
   IF source.has(''''''''topic_preferences'''''''') THEN draft.put(''''''''topic_preferences'''''''',source.get_object(''''''''topic_pref'');
 l_sql:=l_sql||TO_CLOB(''erences''''''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''''''kind'''''''',''''''''sample_suggestions'''''''');provenance.put(''''''''sample_id'''''''',p_sample);provenance.put(''''''''snapshot_id'''''''',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_');
 l_step:=l_step||TO_CLOB('context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version NUMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_persona'''');
 l_sql:=l_sql||TO_CLOB(''''l_contexts%ROWTYPE;new_state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_IN'');
 l_sql:=l_sql||TO_CLOB(''TEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''''''RESTORE'''''''' ELSE ''''''''ARCHIVE'''''''' END;
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''expected_version'''''''',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN ');
 l_step:=l_step||TO_CLOB('result;END IF;
   r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''''''ARCHIVED'''''''',''''''''VALIDATION_ERROR: Context is not archived'''''''');new_state:=NVL(r.prior_lifecycle,''''''''DRAFT'''''''');
   ELSE require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Context is already archived'''''''',-20243);new_state:=''''''''ARCHIVED'''''''';END IF;
   UPD'''');
 l_sql:=l_sql||TO_CLOB(''''ATE kcv_personal_contexts SET lifecycl'');
 l_sql:=l_sql||TO_CLOB(''e=new_state,
     prior_lifecycle=CASE WHEN new_state=''''''''ARCHIVED'''''''' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   requir');
 l_step:=l_step||TO_CLOB('e(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before changing its status'''''''',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_tok'''');
 l_sql:=l_sql||TO_CLOB(''''en,FAL'');
 l_sql:=l_sql||TO_CLOB(''SE);END;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TR');
 l_step:=l_step||TO_CLOB('UE);END;
END;'''');
  EXECUTE IMMEDIATE l_sql;
l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''PACKAGE BODY kcv_personal_context_api AS
 PROCEDURE require(p_condition BOOLEAN,p_message VARCHAR2,p_code NUMBER DEFAULT -20244) IS BEGIN
   IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 PROCEDURE body_size_check(p_body CLOB) IS
   encoded BLOB;dst_offset INTEGER:=1;src_offset INTEGER:=1;lang_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;w'');
 l_sql:=l_sql||TO_CLOB(''arning INTEGER;byte_count NUMBER;
 BEGIN
   require(p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body)<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF');
 l_step:=l_step||TO_CLOB('-8 bytes'''''''');
   DBMS_LOB.CREATETEMPORARY(encoded,TRUE);
   DBMS_LOB.CONVERTTOBLOB(dest_lob=>encoded,src_clob=>p_body,amount=>DBMS_LOB.LOBMA'''');
 l_expected:=l_expected||TO_CLOB(''''XSIZE,
     dest_offset=>dst_offset,src_offset=>src_offset,blob_csid=>NLS_CHARSET_ID(''''''''AL32UTF8''''''''),lang_context=>lang_context,warning=>warning);
   byte_count:=DBMS_LOB.GETLENGTH(encoded);DBMS_LOB.FREETEMPORARY(encoded);
   require(warning=0 AND byte_count<=16000,''''''''VALIDATION_ERROR: Context JSON must be at most 16000 UTF-8 bytes'''''''');
 EXCEPTION WHEN OTHER'');
 l_sql:=l_sql||TO_CLOB(''S THEN IF DBMS_LOB.ISTEMPORARY(encoded)=1 THEN DBMS_LOB.FREETEMPORARY(encoded);END IF;RAISE;
 END;
 FUNCTION active_graph RETUR');
 l_step:=l_step||TO_CLOB('N VARCHAR2 IS g VARCHAR2(128);BEGIN
   SELECT setting_value INTO g FROM kcv_settings WHERE setting_key=''''''''ACTIVE_GRAPH'''''''';
   RETURN g;
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;
 END;
 FUNCTION context_row(p_context VAR'''');
 l_expected:=l_expected||TO_CLOB(''''CHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE context_id=p_context AND owner_scope=s AND owner_subject=u;
   RETURN r;
 EXCEPTION WHEN'');
 l_sql:=l_sql||TO_CLOB('' NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not av');
 l_step:=l_step||TO_CLOB('ailable to this account'''''''');
 END;
 FUNCTION locked_context_row(p_context VARCHAR2) RETURN kcv_personal_contexts%ROWTYPE IS
   r kcv_personal_contexts%ROWTYPE;s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   SELECT * INTO r FROM kcv_personal_contexts WHERE'''');
 l_expected:=l_expected||TO_CLOB('''' context_id=p_context AND owner_scope=s AND owner_subject=u FOR UPDATE NOWAIT;
   RETURN r;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20241,''''''''CONTEXT_UNAVAILABLE: Context is not available to this account'''''''');
   WHEN OTHERS THEN
     IF SQLCODE=-54 THE'');
 l_sql:=l_sql||TO_CLOB(''N RAISE_APPLICATION_ERROR(-20246,''''''''OPERATION_IN_PROGR');
 l_step:=l_step||TO_CLOB('ESS: Another edit is being saved'''''''');END IF;RAISE;
 END;
 FUNCTION summary(p_row kcv_personal_contexts%ROWTYPE) RETURN JSON_OBJECT_T IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''''''''context_id'''''''',p_row.context_id);j.put(''''''''title'''''''',p_row.title);j.put(''''''''lifecycle'''''''',p_row.lifecycle);
   j.put(''''''''draft_version'''''''',p_row.draft_version);j.put(''''''''latest_revision'''''''',p_row.latest_revision);
   j.put'''');
 l_expected:=l_expected||TO_CLOB(''''(''''''''updated_at'''''''',TO_CHAR(p_row.updated_at,''''''''YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM''''''''));
   RETURN j;
 END;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE:=context_row(p_context);j '');
 l_sql:=l_sql||TO');
 l_step:=l_step||TO_CLOB('_CLOB(''JSON_OBJECT_T;cap JSON_OBJECT_T:=JSON_OBJECT_T();
   draft JSON_OBJECT_T;prefs JSON_OBJECT_T;keys JSON_KEY_LIST;topics JSON_ARRAY_T:=JSON_ARRAY_T();topic JSON_OBJECT_T;
 BEGIN
   draft:=JSON_OBJECT_T.parse(r.draft_json);prefs:=draft.get_object(''''''''topic_preferences'''''''');
   IF prefs IS NOT NULL THEN
     keys:=prefs.get_keys;
     FOR i IN 1..keys.COUNT LOOP
       topic:=JSON_OBJECT_T();topic.put(''''''''label'''''''',keys(i));topic.put(''''''''weight'''''''',prefs.get_number(keys(i)));topics.append(topic);
    '''');
 l_expected:=l_expected||TO_CLOB('''' END LOOP;
   END IF;
   j:=summary(r);j.put(''''''''base_graph'''''''',r.base_graph);j.put(''''''''draft'''''''',draft);j.put(''''''''selected_topics'''''''',topics);
   IF r');
 l_step:=l_step||TO_CLOB('.provenance_json IS NOT NULL THEN'');
 l_sql:=l_sql||TO_CLOB('' j.put(''''''''provenance'''''''',JSON_OBJECT_T.parse(r.provenance_json));END IF;
   cap.put(''''''''edit'''''''',r.lifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''archive'''''''',r.lifecycle<>''''''''ARCHIVED'''''''');cap.put(''''''''restore'''''''',r.lifecycle=''''''''ARCHIVED'''''''');
   cap.put(''''''''activate'''''''',FALSE);cap.put(''''''''start_conversation'''''''',FALSE);cap.put(''''''''duplicate'''''''',TRUE);
   j.put(''''''''capabilities'''''''',cap);j.put(''''''''feature_stage'''''''',''''''''persistent-drafts'''''''');
   j.put(''''''''notice'''''''',''''''''Your draft is saved privately in this application. Personal-context exploration is not enabled in this development increment. The sample journeys remain '''');
 l_expected:=');
 l_step:=l_step||TO_CLOB('l_expected||TO_CLOB(''''available.'''''''');
   RETURN j.to_clob();
 END;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,'');
 l_sql:=l_sql||TO_CLOB(''p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
   a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();row_j JSON_OBJECT_T;
   status_filter VARCHAR2(32767):=UPPER(TRIM(p_status));search_filter VARCHAR2(32767):=TRIM(p_search);
   cursor_row kcv_personal_contexts%ROWTYPE;limit_rows PLS_INTEGER;fetch_rows PLS_INTEGER;last_id VARCHAR2(32);more_rows BOOLEAN:=FALSE;
 BEGIN
   require(p_limi');
 l_step:=l_step||TO_CLOB('t BETWEEN 1 AND 50 AND p_limit=TRUNC(p_limit),''''''''VALIDA'''');
 l_expected:=l_expected||TO_CLOB(''''TION_ERROR: Page size must be 1 to 50'''''''');
   require(status'');
 l_sql:=l_sql||TO_CLOB(''_filter IS NULL OR status_filter IN (''''''''DRAFT'''''''',''''''''ACTIVE'''''''',''''''''ARCHIVED''''''''),''''''''VALIDATION_ERROR: Unknown context status'''''''');
   require(p_search IS NULL OR LENGTH(p_search)<=200,''''''''VALIDATION_ERROR: Search is limited to 200 characters'''''''');
   limit_rows:=p_limit;fetch_rows:=limit_rows+1;
   IF p_before_id IS NOT NULL THEN cursor_row:=context_row(p_before_id);END IF;
   FOR r IN (SELECT * FROM kcv_personal_contexts WHERE owner_scope=s AND owner_subject=u
     AND (status_filter IS NULL OR lifecycle=');
 l_step:=l_step||TO_CLOB('status_filter)
     AND (search_filter IS NULL OR INSTR(LOWER(title),LOWER(search_filter))>0)
     AND (p_before_id IS NULL OR updated_at<cursor_row.updated_'''');
 l_expected:=l_expected||TO_CLOB(''''at OR
    '');
 l_sql:=l_sql||TO_CLOB(''   (updated_at=cursor_row.updated_at AND context_id<p_before_id))
     ORDER BY updated_at DESC,context_id DESC FETCH FIRST fetch_rows ROWS ONLY) LOOP
     IF a.get_size=limit_rows THEN more_rows:=TRUE;EXIT;END IF;
     row_j:=summary(r);a.append(row_j);last_id:=r.context_id;
   END LOOP;
   j.put(''''''''contexts'''''''',a);IF more_rows THEN j.put(''''''''next_cursor'''''''',last_id);ELSE j.put_null(''''''''next_cursor'''''''');END IF;
   j.put(''''''''feature_stage'''''''',''''''''persistent-dr');
 l_step:=l_step||TO_CLOB('afts'''''''');RETURN j.to_clob();
 END;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB IS
   r kcv_personal_contexts%ROWTYPE;g VARCHAR2(128);a JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T:=JSON_OBJECT_T();s VARCHAR2(128);
 BEGIN
   s:=kc'');
 l_sql:=l_sql||TO_CLOB('''''');
 l_expected:=l_expected||TO_CLOB(''''v_access.owner_scope;
   IF p_context IS NULL THEN g:=active_graph;ELSE r:=context_row(p_context);g:=r.base_graph;END IF;
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARCHAR2(200) PATH ''''''''$'''''''')) jt
     WHERE gs.graph_name=g AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_pass');
 l_step:=l_step||TO_CLOB('age_count'''''''' RETURNING NUMBER)>0
       OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
         AND REGEXP_LIKE(gs.version_id,''''''''^S[0-9]+-v'''''''')
         AND EXISTS (SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id))) ORDER BY jt.label)'');
 l_sql:=l_sql||TO_CLOB('' LOOP
     a.append(t.label);
   END LOOP;
   j.'''');
 l_expected:=l_expected||TO_CLOB(''''put(''''''''base_graph'''''''',g);j.put(''''''''topics'''''''',a);RETURN j.to_clob();
 END;
 FUNCTION clean_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB IS
   j JSON_OBJECT_T;ks JSON_KEY_LIST;value JSON_ELEMENT_T;a JSON_ARRAY_T;prefs JSON_OBJECT_T;topic_keys JSON_KEY_LIST;
   allowed VARCHAR2');
 l_step:=l_step||TO_CLOB('(1000):=''''''''|question|objective_clarity|objective|person|role|organisation|known_situation|learning_purpose|time_horizon|unknowns|constraints|topic_preferences|'''''''';
   text_value VARCHAR2(32767);topic_label VARCHAR2(200);max_length PLS_INTEGER;n NUMBER;
 BEGIN
   body_size_check(p_body);
   BEGIN j:=JSON_OBJECT_T.parse(p_body);EXCEPTION WHEN OT'');
 l_sql:=l_sql||TO_CLOB(''HERS THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Supply a JSON context object'''''''');E'''');
 l_expected:=l_expected||TO_CLOB(''''ND;
   ks:=j.get_keys;
   FOR i IN 1..ks.COUNT LOOP
     require(INSTR(allowed,''''''''|''''''''||ks(i)||''''''''|'''''''')>0,''''''''VALIDATION_ERROR: Unknown context field'''''''');value:=j.get(ks(i));
     IF');
 l_step:=l_step||TO_CLOB(' ks(i) IN (''''''''unknowns'''''''',''''''''constraints'''''''') THEN
       require(value.is_array,''''''''VALIDATION_ERROR: Unknowns and constraints must be arrays'''''''');a:=TREAT(value AS JSON_ARRAY_T);
       require(a.get_size<=20,''''''''VALIDATION_ERROR: At most 20 unknowns or constraints'''''''');
       FOR k IN 0..a.get_size-1 LOOP
         value:=a.get(k);require(value.is_string,''''''''VALIDATION_ERROR: Each unknown or constraint'');
 l_sql:=l_sql||TO_CLOB('' must be text'''''''');
         require(LENGTH(a.get_string(k))<=500,''''''''VALIDATION_ERROR: Each unknown or constraint must be at most 500 characters'''''''');
    '''');
 l_expected:=l_expected||TO_CLOB(''''     require(INSTR(a.get_string(k),CHR(10))=0 AND INSTR(a.get_str');
 l_step:=l_step||TO_CLOB('ing(k),CHR(13))=0,
           ''''''''VALIDATION_ERROR: Each unknown or constraint must be a single line'''''''');
       END LOOP;
     ELSIF ks(i)=''''''''topic_preferences'''''''' THEN
       require(value.is_object,''''''''VALIDATION_ERROR: Topic preferences must be an object'''''''');prefs:=TREAT(value AS JSON_OBJECT_T);topic_keys:=prefs.get_keys;
       require(topic_keys.COUNT<=20,''''''''VALIDATION_ERROR: At most 20 topics'''''''');
       FOR k IN 1..topic_keys.COUNT LOOP
         '');
 l_sql:=l_sql||TO_CLOB(''require(LENGTH(topic_keys(k))<=200,''''''''INVALID_TOPIC: Topic label is too long'''''''',-20247);topic_label:=topic_keys(k);
         value:=prefs.get(topic_keys(k));require(value.is_number,''''''''VALIDATION_ERROR: '''');');
 l_step:=l_step||TO_CLOB('
 l_expected:=l_expected||TO_CLOB(''''Topic weights must be numbers'''''''');
         n:=prefs.get_number(topic_keys(k));require(n BETWEEN 1 AND 10,''''''''VALIDATION_ERROR: Topic weights must be 1 to 10'''''''');
         SELECT COUNT(*) INTO n FROM kcv_graph_sources gs WHERE gs.graph_name=p_graph
           AND (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER)>0
             OR (JSON_VALUE(gs.metadata_json,''''''''$.retrieval_eligible_passage_count'''''''' RETURNING NUMBER) IS NULL
     '');
 l_sql:=l_sql||TO_CLOB(''          AND REGEXP_LIKE(gs.version_id,''''''''^S[0-9]+-v'''''''') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
           AND EXISTS(S');
 l_step:=l_step||TO_CLOB('ELECT 1 FROM JSON_TABLE(gs.metadata_json,''''''''$.topics[*]'''''''' COLUMNS(label VARCHAR2(200) PATH ''''''''$'''''''''''');
 l_expected:=l_expected||TO_CLOB('''')) jt WHERE jt.label=topic_label);
         require(n>0,''''''''INVALID_TOPIC: Choose an evidence topic from the pinned collection'''''''',-20247);
       END LOOP;
     ELSE
       require(value.is_string OR value.is_null,''''''''VALIDATION_ERROR: Context fields must be text'''''''');
       max_length:=CASE WHEN ks(i) IN (''''''''question'''''''',''''''''objective'''''''') THEN 2000 WHEN ks(i)=''''''''known_situation'''''''' THEN 4000 ELSE 200 END;
       text_value'');
 l_sql:=l_sql||TO_CLOB('':=j.get_string(ks(i));require(text_value IS NULL OR LENGTH(text_value)<=max_length,''''''''VALIDATION');
 l_step:=l_step||TO_CLOB('_ERROR: Context field is too long'''''''');
     END IF;
   END LOOP;
   IF NOT j.has(''''''''objective_clarity'''''''') OR j.get_string(''''''''objective_clarity'''''''') IS NULL THEN j.put(''''''''objective_clarity'''''''',''''''''unknown'''''''');END IF;
   requir'''');
 l_expected:=l_expected||TO_CLOB(''''e(j.get_string(''''''''objective_clarity'''''''') IN (''''''''unknown'''''''',''''''''emerging'''''''',''''''''defined''''''''),''''''''VALIDATION_ERROR: Choose objective clarity'''''''');
   IF NOT j.has(''''''''topic_preferences'''''''') THEN j.put(''''''''topic_preferences'''''''',JSON_OBJECT_T());END IF;
   IF NOT j.has(''''''''unknowns'''''''') THEN j.put(''''''''unknowns'''''''',JSON_ARRAY_T());END IF;
   IF NOT j.has(''''''''constraints'''''''') THEN j.put(''''''''cons'');
 l_sql:=l_sql||TO_CLOB(''train');
 l_step:=l_step||TO_CLOB('ts'''''''',JSON_ARRAY_T());END IF;
   body_size_check(j.to_clob());
   RETURN j.to_clob();
 END;
 PROCEDURE release_request(p_lock IN OUT PLS_INTEGER) IS ignored PLS_INTEGER;BEGIN
   IF p_lock IS NOT NULL THEN ignored:=DBMS_LOCK.RELEASE(p_lock);p_lock:=NULL;END IF;
 END;
 FUNCTION request_begin(p_action VARCHAR2,p_token VARCHAR2,p_payload JSON_OBJECT_T,p_result OUT C'''');
 l_expected:=l_expected||TO_CLOB(''''LOB,p_lock OUT PLS_INTEGER) RETURN BOOLEAN IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;hash_value VARCHAR2(64);r kcv_context_requests%ROWTYPE;
   lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 BEGIN
   p_lock:=NULL;
   require(p_token IS NOT NULL AND ''');
 l_step:=l_step||TO_CLOB(');
 l_sql:=l_sql||TO_CLOB(''REGEXP_LIKE(p_token,''''''''^[A-Za-z0-9_-]{16,80}$'''''''',''''''''c''''''''),''''''''VALIDATION_ERROR: Supply a request token of 16 to 80 safe characters'''''''');
   hash_value:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_payload.to_clob(),DBMS_CRYPTO.HASH_SH256)));
   lock_id:=DBMS_UTILITY.GET_HASH_VALUE(''''''''KCV_CONTEXT_REQUEST:''''''''||s||'''''''':''''''''||u||'''''''':''''''''||p_token,1,1073741823);
   lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,re'''');
 l_expected:=l_expected||TO_CLOB(''''lease_on_commit=>TRUE);
   require(lock_result=0,''''''''OPERATION_IN_PROGRESS: Retry after the current action finishes'''''''',-20246);p_lock:=lock_id;
   BEGIN
     INSERT INTO kcv_context_requests');
 l_step:=l_step||TO_CLOB('(owner_scope,owner_subject,request_token,action,payload_s'');
 l_sql:=l_sql||TO_CLOB(''ha256) VALUES(s,u,p_token,p_action,hash_value);
     RETURN FALSE;
   EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
     SELECT * INTO r FROM kcv_context_requests WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
     require(r.action=p_action AND r.payload_sha256=hash_value,''''''''REQUEST_TOKEN_REUSED: Start a new action with a new token'''''''',-20245);
     require(r.result_json IS NOT NULL,''''''''OPERATION_IN_PROGRESS: The prior request has not completed'''''''',-2024'''');
 l_expected:=l_expected||TO_CLOB(''''6);
     p_result:=r.result_json;release_request(p_lock);RETURN TRUE;
   END;
 EXCEPTION WHEN OTHERS THEN');
 l_step:=l_step||TO_CLOB(' release_request(p_lock);RAISE;
 END;
 FUNCTION request_finish(p_token VARCHAR2,p_context VARCH'');
 l_sql:=l_sql||TO_CLOB(''AR2) RETURN CLOB IS
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;result CLOB:=get_context(p_context);
 BEGIN
   UPDATE kcv_context_requests SET result_json=result WHERE owner_scope=s AND owner_subject=u AND request_token=p_token;
   COMMIT;RETURN result;
 END;
 PROCEDURE title_check(p_title VARCHAR2) IS BEGIN
   require(TRIM(p_title) IS NOT NULL AND LENGTH(TRIM(p_title))<=200,''''''''VALIDATION_ERROR: Supply a context title up to 200 characters'''''''');
 END;
 FUNCTION'''');
 l_expected:=l_expected||TO_CLOB('''' insert_draft(p_title VARCHAR2,');
 l_step:=l_step||TO_CLOB('p_body CLOB,p_graph VARCHAR2,p_provenance CLOB DEFAULT NULL) RETURN VARCHAR2 IS
   cid VARCHAR2(32):=''''''''C''''''''||SUBSTR(RAWTOHEX(SYS_G'');
 l_sql:=l_sql||TO_CLOB(''UID()),1,31);
   s VARCHAR2(128):=kcv_access.owner_scope;u VARCHAR2(128):=kcv_access.owner_subject;
 BEGIN
   INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph,provenance_json)
     VALUES(cid,s,u,TRIM(p_title),p_body,p_graph,p_provenance);
   RETURN cid;
 END;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;cid VARCHAR2(32):=p_context;g VARC');
 l_step:=l_step||TO_CLOB('HAR'''');
 l_expected:=l_expected||TO_CLOB(''''2(128);clean CLOB;r kcv_personal_contexts%ROWTYPE;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;
   ti'');
 l_sql:=l_sql||TO_CLOB(''tle_check(p_title);body_size_check(p_body);
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);request.put(''''''''body'''''''',p_body);request.put(''''''''expected_version'''''''',p_expected_version);
   IF request_begin(''''''''SAVE_DRAFT'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;
   IF p_context IS NULL THEN
     require(p_expected_version IS NULL OR p_expected_version=0,''''''''STALE_VERSION: New contexts have no saved version'''''''',-20242);
     g:=active_graph;cl');
 l_step:=l_step||TO_CLOB('ean:=clean_body(p_body,g);cid:=insert_draft(p_title,clean,g);
   ELSE
     r:=locked_context_row(p_context)'''');
 l_expected:=l_expected||TO_CLOB('''';require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Restore before '');
 l_sql:=l_sql||TO_CLOB(''editing'''''''',-20243);
     clean:=clean_body(p_body,r.base_graph);
     UPDATE kcv_personal_contexts SET title=TRIM(p_title),draft_json=clean,draft_version=draft_version+1,updated_at=SYSTIMESTAMP
       WHERE context_id=p_context AND draft_version=p_expected_version AND lifecycle<>''''''''ARCHIVED'''''''';
     require(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before editing'''''''',-20242);
   END IF;
   RETURN request_finish(p_request_tok');
 l_step:=l_step||TO_CLOB('en,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2)'''');
 l_expected:=l_expected||TO_CLOB('''' RETURN CLOB IS
   reque'');
 l_sql:=l_sql||TO_CLOB(''st JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE;cid VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''''''context_id'''''''',p_context);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''DUPLICATE'''''''',p_request_token,request,result,request_lock) THEN RETURN result;END IF;');
 l_step:=l_step||TO_CLOB('
   r:=context_row(p_context);provenance.put(''''''''kind'''''''',''''''''owned_context_copy'''''''');provenance.put(''''''''context_id'''''''',r.context_id);provenance.put(''''''''draft_version'''''''',r.draft_version);
   cid:=insert_draft(p_title,r.draft_json,r.base_graph,provenance.to_clob());RETURN request_finish(p_request_token,cid);'''');
 l_exp'');
 l_sql:=l_sql||TO_CLOB(''ected:=l_expected||TO_CLOB(''''
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();provenance JSON_OBJECT_T:=JSON_OBJECT_T();source JSON_OBJECT_T;draft JSON_OBJECT_');
 l_step:=l_step||TO_CLOB('T:=JSON_OBJECT_T();
   result CLOB;raw_source CLOB;g VARCHAR2(128);snapshot_id VARCHAR2(64);cid VARCHAR2(32);clean CLOB;request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;title_check(p_title);request.put(''''''''sample_id'''''''',p_sample);request.put(''''''''title'''''''',p_title);
   IF request_begin(''''''''COPY_SAMPLE'''''''',p_request_token,request,result,request_l'');
 l_sql:=l_sql||TO_CLOB(''ock) THEN RETURN result;END IF;
  '''');
 l_expected:=l_expected||TO_CLOB('''' g:=active_graph;
   BEGIN SELECT c.context_json,c.snapshot_id INTO raw_source,snapshot_id FROM kcv_contexts c
     JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g AND c.context_id=p_sample
     ORDER BY ');
 l_step:=l_step||TO_CLOB('c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20244,''''''''VALIDATION_ERROR: Choose an available sample'''''''');END;
   source:=JSON_OBJECT_T.parse(raw_source);draft.put(''''''''objective_clarity'''''''',''''''''unknown'''''''');
   IF source.has(''''''''question'''''''') THEN draft.put(''''''''question'''''''',source.get_string(''''''''question''''''''));END IF;
   IF source.has(''''''''learning_pur'');
 l_sql:=l_sql||TO_CLOB(''pose'''''''') THEN draft.put(''''''''learning_purpose'''''''',source.get_string(''''''''learning_purpose''''''''));END I'''');
 l_expected:=l_expected||TO_CLOB(''''F;
   IF source.has(''''''''topic_preferences'''''''') THEN draft.put(''''''''topic_preferences'''''''',source.get_object(''''''''topic');
 l_step:=l_step||TO_CLOB('_preferences''''''''));END IF;
   clean:=clean_body(draft.to_clob(),g);provenance.put(''''''''kind'''''''',''''''''sample_suggestions'''''''');provenance.put(''''''''sample_id'''''''',p_sample);provenance.put(''''''''snapshot_id'''''''',snapshot_id);
   cid:=insert_draft(p_title,clean,g,provenance.to_clob());RETURN request_finish(p_request_token,cid);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;release_request(request_lock);RAISE;
 END;
 FUNCTION lifecycle_change(p_context VARCHAR2,p_expected_version N'');
 l_sql:=l_sql||TO_CLOB(''UMBER,p_token VARCHAR2,p_restore BOOLEAN) RETURN CLOB IS
   request JSON_OBJECT_T:=JSON_OBJECT_T();result CLOB;r kcv_personal_contexts%ROWTYPE'''');
 l_expected:=l_expected||TO_CLOB('''';new_');
 l_step:=l_step||TO_CLOB('state VARCHAR2(16);action_name VARCHAR2(32);request_lock PLS_INTEGER;
 BEGIN
   SAVEPOINT kcv_context_write;action_name:=CASE WHEN p_restore THEN ''''''''RESTORE'''''''' ELSE ''''''''ARCHIVE'''''''' END;
   request.put(''''''''context_id'''''''',p_context);request.put(''''''''expected_version'''''''',p_expected_version);
   IF request_begin(action_name,p_token,request,result,request_lock) THEN RETURN result;END IF;
   r:=locked_context_row(p_context);
   IF p_restore THEN
     require(r.lifecycle=''''''''ARCHIVED'''''''',''''''''VALIDATION_ERROR: Context is not archived'''''''');n'');
 l_sql:=l_sql||TO_CLOB(''ew_state:=NVL(r.prior_lifecycle,''''''''DRAFT'''''''');
   ELSE require(r.lifecycle<>''''''''ARCHIVED'''''''',''''''''CONTEXT_ARCHIVED: Context is alread');
 l_step:=l_step||TO_CLOB('y archived'''''''',-20243);new_state:=''''''''ARCHIVED'''''''';END IF;
   UPDATE kcv_personal_c'''');
 l_expected:=l_expected||TO_CLOB(''''ontexts SET lifecycle=new_state,
     prior_lifecycle=CASE WHEN new_state=''''''''ARCHIVED'''''''' THEN lifecycle ELSE NULL END,
     draft_version=draft_version+1,updated_at=SYSTIMESTAMP
     WHERE context_id=p_context AND draft_version=p_expected_version;
   require(SQL%ROWCOUNT=1,''''''''STALE_VERSION: Reload your saved context before changing its status'''''''',-20242);
   RETURN request_finish(p_token,p_context);
 EXCEPTION WHEN OTHERS THEN ROLLBACK TO kcv_context_write;releas'');
 l_sql:=l_sql||TO_CLOB(''e_request(request_lock);RAISE;
 END;
 FUNCTION archive_context(p_context VARCHA');
 l_step:=l_step||TO_CLOB('R2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,FALSE);END;
 FU'''');
 l_expected:=l_expected||TO_CLOB(''''NCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB IS BEGIN
   RETURN lifecycle_change(p_context,p_expected_version,p_request_token,TRUE);END;
END;
'''');
 check_program(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE BODY'''',l_expected);
  UPDATE kcv_schema_migrations SET phase=''''COMPLETE'''',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id=''''2.0.0-c2-007-kcv_personal_con'');
 l_sql:=l_sql||TO_CLOB(''text_api-package-body'''';
  COMMIT;
 END I');
 l_step:=l_step||TO_CLOB('F;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase=''''FAILED'''',error_code=l_error WHERE migration_id=''''2.0.0-c2-007-kcv_personal_context_api-package-body'''';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;'');
 EXECUTE IMMEDIATE l_sql;END IF;
END;');
 EXECUTE IMMEDIATE l_step;
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('BEGIN DBMS_OUTPUT.PUT_LINE(''KCV_SCHEMA_PART_COMPLETE=fresh:004/019'');END;');
 EXECUTE IMMEDIATE l_step;
END;
/
