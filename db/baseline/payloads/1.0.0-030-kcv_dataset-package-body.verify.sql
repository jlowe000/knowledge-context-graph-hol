 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_dataset AS
  PROCEDURE require(p_ok BOOLEAN, p_message VARCHAR2) IS
  BEGIN
    IF p_ok IS NULL OR NOT p_ok THEN
      RAISE_APPLICATION_ERROR(-20070, p_message);
    END IF;
  END;
  PROCEDURE lock_handle(p_handle OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    DBMS_LOCK.ALLOCATE_UNIQUE(''KCV_DATASET_'' || $$PLSQL_UNIT_OWNER, p_handle);
    COMMIT;
  END;
  FUNCTION download(p_url VARCHAR2, p_hash VARCHAR2, p_bytes NUMBER DEFAULT NULL)
    RETURN CLOB IS
    b BLOB; c CLOB; d INTEGER := 1; s INTEGER := 1;
    ctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX; warning INTEGER; valid NUMBER;
  BEGIN
    b := DBMS_CLOUD.GET_OBJECT(credential_name => NULL, object_uri => p_');
 l_expected:=l_expected||TO_CLOB('url);
    require(DBMS_LOB.GETLENGTH(b) BETWEEN 1 AND 1500000, ''Download exceeds package file limit'');
    IF p_bytes IS NOT NULL THEN
      require(DBMS_LOB.GETLENGTH(b) = p_bytes, ''Downloaded file byte count differs'');
    END IF;
    require(LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(b, DBMS_CRYPTO.HASH_SH256))) = LOWER(p_hash),
            ''Downloaded file SHA-256 differs; check the commit and release loader'');
    DBMS_LOB.CREATETEMPORARY(c, TRUE);
    DBMS_LOB.CONVERTTOCLOB(c,b,DBMS_LOB.LOBMAXSIZE,d,s,NLS_CHARSET_ID(''AL32UTF8''),ctx,warning);
    require(warning = 0, ''Dataset is not valid UTF-8'');
    SELECT CASE WHEN c IS JSON STRICT WITH UNIQUE KEYS THEN 1 ELSE 0 END INTO valid FROM dual;
    re');
 l_expected:=l_expected||TO_CLOB('quire(valid = 1, ''Dataset is not strict JSON with unique keys'');
    IF DBMS_LOB.ISTEMPORARY(b) = 1 THEN DBMS_LOB.FREETEMPORARY(b); END IF;
    RETURN c;
  EXCEPTION WHEN OTHERS THEN
    IF DBMS_LOB.ISTEMPORARY(b) = 1 THEN DBMS_LOB.FREETEMPORARY(b); END IF;
    IF DBMS_LOB.ISTEMPORARY(c) = 1 THEN DBMS_LOB.FREETEMPORARY(c); END IF;
    RAISE;
  END;
  PROCEDURE load_github(
    p_ref VARCHAR2, p_expected_manifest_sha256 VARCHAR2,
    p_owner VARCHAR2 DEFAULT ''jlowe000'',
    p_repo VARCHAR2 DEFAULT ''knowledge-context-graph-hol'') IS
    l_run VARCHAR2(32) := RAWTOHEX(SYS_GUID());
    l_ref VARCHAR2(40); l_expected VARCHAR2(64); l_base VARCHAR2(1000);
    l_handle VARCHAR2(128); l_locked BOOLEAN');
 l_expected:=l_expected||TO_CLOB(' := FALSE; l_result INTEGER;
    l_started BOOLEAN := FALSE; l_finished BOOLEAN := FALSE;
    l_error NUMBER; l_phase VARCHAR2(128) := ''VALIDATING_INPUT'';
    l_cleanup_errors VARCHAR2(1000);
    l_manifest CLOB; l_payload CLOB;
    m JSON_OBJECT_T; f JSON_OBJECT_T; obj JSON_OBJECT_T; ver JSON_OBJECT_T;
    cnt JSON_OBJECT_T; files JSON_ARRAY_T;
    l_dataset VARCHAR2(64); l_hash VARCHAR2(64); l_graph VARCHAR2(128);
    l_name VARCHAR2(80); l_role VARCHAR2(16); l_file_hash VARCHAR2(64);
    l_bytes NUMBER; l_rows NUMBER; l_actual NUMBER; l_previous NUMBER := 0; l_order NUMBER;
    l_sources NUMBER; l_passages NUMBER; l_contexts NUMBER; l_triples NUMBER;
    l_id VARCHAR2(200); l_version VARC');
 l_expected:=l_expected||TO_CLOB('HAR2(128); l_source VARCHAR2(32); l_sha VARCHAR2(64);
    l_source_sha VARCHAR2(64);
    l_text VARCHAR2(32767); l_page NUMBER; l_chunk NUMBER; l_snapshot NUMBER;
    l_stmt VARCHAR2(4000);
    PROCEDURE progress(p_status VARCHAR2 DEFAULT ''RUNNING'') IS
      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
      MERGE INTO kcv_dataset_runs t USING (SELECT l_run run_id FROM dual) s
      ON (t.run_id = s.run_id)
      WHEN MATCHED THEN UPDATE SET status=p_status, phase=l_phase,
        dataset_id=l_dataset, graph_name=l_graph, updated_at=SYSTIMESTAMP,
        completed_at=CASE WHEN p_status != ''RUNNING'' THEN SYSTIMESTAMP END,
        error_code=l_error
      WHEN NOT MATCHED THEN INSERT(run_id,status');
 l_expected:=l_expected||TO_CLOB(',phase,source_ref,manifest_sha256,
        dataset_id,graph_name,error_code)
        VALUES(l_run,p_status,l_phase,l_ref,l_expected,l_dataset,l_graph,l_error);
      COMMIT;
    END;
    PROCEDURE activate IS
    BEGIN
      MERGE INTO kcv_settings t USING (SELECT ''ACTIVE_GRAPH'' setting_key FROM dual) s
      ON (t.setting_key=s.setting_key)
      WHEN MATCHED THEN UPDATE SET setting_value=l_graph
      WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(''ACTIVE_GRAPH'',l_graph);
      UPDATE kcv_dataset_runs SET status=''SUCCEEDED'', phase=l_phase,
        dataset_id=l_dataset, graph_name=l_graph, updated_at=SYSTIMESTAMP,
        completed_at=SYSTIMESTAMP, error_code=NULL WHERE run_');
 l_expected:=l_expected||TO_CLOB('id=l_run;
      DELETE FROM kcv_dataset_stage;
      COMMIT;
      l_finished := TRUE;
    END;
    PROCEDURE verify_native_graph IS
    BEGIN
      l_stmt := ''SELECT COUNT(*) FROM TABLE(SEM_MATCH(''||
        ''''''SELECT ?s ?p ?o WHERE { ?s ?p ?o }'''',SEM_MODELS(''||DBMS_ASSERT.ENQUOTE_LITERAL(l_graph)||
        ''),NULL,NULL,NULL,NULL,NULL,NULL,NULL,''||DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||'',''''KCV_NET''''))'';
      EXECUTE IMMEDIATE l_stmt INTO l_actual;
      require(l_actual=l_triples, ''Native RDF triple count differs; previous graph remains active'');
      SELECT COUNT(*) INTO l_actual FROM kcv_graph_sources WHERE graph_name=l_graph;
      require(l_actual=l_sources, ''Graph source co');
 l_expected:=l_expected||TO_CLOB('unt differs'');
      SELECT COUNT(*) INTO l_actual FROM kcv_graph_contexts WHERE graph_name=l_graph;
      require(l_actual=l_contexts, ''Graph context count differs'');
    END;
  BEGIN
    require(REGEXP_LIKE(p_owner,''^[A-Za-z0-9][A-Za-z0-9-]{0,38}$'',''c''), ''Invalid GitHub owner'');
    require(REGEXP_LIKE(p_repo,''^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$'',''c''), ''Invalid GitHub repository'');
    require(LENGTH(p_ref)=40 AND REGEXP_LIKE(p_ref,''^[0-9a-fA-F]{40}$'',''c''),
            ''Use the full 40-character published Git commit SHA, not a branch or tag'');
    require(LENGTH(p_expected_manifest_sha256)=64 AND
            REGEXP_LIKE(p_expected_manifest_sha256,''^[0-9a-fA-F]{64}$'',''c''),
            ''Use th');
 l_expected:=l_expected||TO_CLOB('e manifest SHA-256 from the matching release loader'');
    l_ref := LOWER(p_ref); l_expected := LOWER(p_expected_manifest_sha256);
    l_base := ''https://raw.githubusercontent.com/''||p_owner||''/''||p_repo||''/''||l_ref||''/data/load/'';
    lock_handle(l_handle);
    l_result := DBMS_LOCK.REQUEST(l_handle,DBMS_LOCK.X_MODE,0,FALSE);
    require(l_result = 0, ''A GitHub dataset load is already running in this schema'');
    l_locked := TRUE;
    l_phase := ''FETCHING_MANIFEST''; progress; l_started := TRUE;
    DELETE FROM kcv_dataset_stage;
    l_manifest := download(l_base||''manifest.json'',l_expected);
    m := JSON_OBJECT_T.parse(l_manifest);
    require(m.get_number(''format_version'')=1, ''Unsupporte');
 l_expected:=l_expected||TO_CLOB('d dataset manifest version'');
    l_dataset := m.get_string(''dataset_id''); l_hash := m.get_string(''graph_sha256'');
    require(REGEXP_LIKE(l_dataset,''^[0-9a-f]{64}$'',''c'') AND
            REGEXP_LIKE(l_hash,''^[0-9a-f]{64}$'',''c''), ''Invalid dataset or graph identity'');
    cnt := m.get_object(''counts'');
    l_sources := cnt.get_number(''sources''); l_passages := cnt.get_number(''passages'');
    l_contexts := cnt.get_number(''contexts''); l_triples := cnt.get_number(''triples'');
    require(l_sources>0 AND l_passages>0 AND l_contexts>0 AND l_triples>0,
            ''Manifest counts must be positive'');
    SELECT MIN(r.graph_name) INTO l_graph FROM kcv_dataset_runs r
      JOIN kcv_graph_runs g ON g.gra');
 l_expected:=l_expected||TO_CLOB('ph_name=r.graph_name AND g.state=''READY''
      WHERE r.manifest_sha256=l_expected AND r.dataset_id=l_dataset AND r.status=''SUCCEEDED'';
    IF l_graph IS NOT NULL THEN
      l_phase := ''VERIFYING_READY_GRAPH''; progress;
      verify_native_graph;
      l_phase := ''REUSED_READY_GRAPH''; activate;
    ELSE
      files := m.get_array(''files'');
      require(files.get_size BETWEEN 4 AND 256, ''Invalid number of dataset files'');
      FOR i IN 0..files.get_size-1 LOOP
        f := TREAT(files.get(i) AS JSON_OBJECT_T);
        l_name := f.get_string(''path''); l_role := f.get_string(''role'');
        require(l_role IN (''sources'',''passages'',''contexts'',''triples''), ''Unknown dataset file role'');
        req');
 l_expected:=l_expected||TO_CLOB('uire(REGEXP_LIKE(l_name,''^''||l_role||''-[0-9]{3,6}\.json$'',''c''),
                ''Manifest file path must be a package basename'');
        l_order := CASE l_role WHEN ''sources'' THEN 1 WHEN ''passages'' THEN 2 WHEN ''contexts'' THEN 3 ELSE 4 END;
        require(l_order>=l_previous, ''Manifest files are out of dependency order''); l_previous := l_order;
        l_file_hash := f.get_string(''sha256''); l_bytes := f.get_number(''bytes''); l_rows := f.get_number(''rows'');
        require(REGEXP_LIKE(l_file_hash,''^[0-9a-f]{64}$'',''c'') AND
                l_bytes BETWEEN 1 AND 1500000 AND l_bytes=TRUNC(l_bytes) AND
                l_rows>0 AND l_rows=TRUNC(l_rows), ''Invalid dataset file metadata'');
        l_p');
 l_expected:=l_expected||TO_CLOB('hase := ''FETCHING ''||l_name; progress;
        l_payload := download(l_base||l_name,l_file_hash,l_bytes);
        obj := JSON_OBJECT_T.parse(l_payload);
        require(obj.get_number(''format_version'')=1, ''Unsupported payload version'');
        SELECT COUNT(*) INTO l_actual FROM JSON_TABLE(l_payload,''$.rows[*]'' COLUMNS(n FOR ORDINALITY));
        require(l_actual=l_rows, ''Payload row count differs from manifest'');
        INSERT INTO kcv_dataset_stage VALUES(l_name,l_role,l_rows,l_payload);
        DBMS_LOB.FREETEMPORARY(l_payload);
      END LOOP;
      SELECT NVL(SUM(CASE WHEN file_role=''sources'' THEN row_count END),0),
             NVL(SUM(CASE WHEN file_role=''passages'' THEN row_count END');
 l_expected:=l_expected||TO_CLOB('),0),
             NVL(SUM(CASE WHEN file_role=''contexts'' THEN row_count END),0),
             NVL(SUM(CASE WHEN file_role=''triples'' THEN row_count END),0)
        INTO l_actual,l_rows,l_bytes,l_order FROM kcv_dataset_stage;
      require(l_actual=l_sources AND l_rows=l_passages AND l_bytes=l_contexts AND l_order=l_triples,
              ''Manifest totals do not match the verified files'');
      l_graph := ''KCV_G_''||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);
      INSERT INTO kcv_graph_runs(graph_name,graph_hash,state) VALUES(l_graph,l_hash,''LOADING'');
      l_phase := ''LOADING_SOURCES''; progress;
      FOR r IN (SELECT j.doc FROM kcv_dataset_stage s,
        JSON_TABLE(s.payload,''$.rows[*]'' COLUMNS(');
 l_expected:=l_expected||TO_CLOB('doc CLOB FORMAT JSON PATH ''$'')) j
        WHERE s.file_role=''sources'') LOOP
        obj := JSON_OBJECT_T.parse(r.doc); ver := obj.get_object(''version'');
        l_source := obj.get_string(''id''); l_version := ver.get_string(''id''); l_sha := ver.get_string(''sha256'');
        SELECT COUNT(*) INTO l_actual FROM kcv_sources WHERE version_id=l_version
          AND (source_id<>l_source OR sha256<>l_sha);
        require(l_actual=0, ''Source version identity changed; create a new source version'');
        MERGE INTO kcv_sources t USING (SELECT l_version version_id FROM dual) s ON(t.version_id=s.version_id)
        WHEN NOT MATCHED THEN INSERT(version_id,source_id,sha256,metadata_json)
          VALUE');
 l_expected:=l_expected||TO_CLOB('S(l_version,l_source,l_sha,r.doc);
        INSERT INTO kcv_graph_sources VALUES(l_graph,l_version,r.doc);
      END LOOP;
      l_phase := ''LOADING_PASSAGES''; progress;
      FOR r IN (SELECT j.doc FROM kcv_dataset_stage s,
        JSON_TABLE(s.payload,''$.rows[*]'' COLUMNS(doc CLOB FORMAT JSON PATH ''$'')) j
        WHERE s.file_role=''passages'') LOOP
        obj := JSON_OBJECT_T.parse(r.doc);
        require(obj.get_string(''content_kind'')=''attributed_editorial_summary'',
                ''The public GitHub package must contain editorial summaries only'');
        l_id := obj.get_string(''id''); l_version := obj.get_string(''version_id'');
        l_source := obj.get_string(''source_id''); l_sha := obj.g');
 l_expected:=l_expected||TO_CLOB('et_string(''text_sha256'');
        l_source_sha := obj.get_string(''source_sha256'');
        l_text := obj.get_string(''text''); l_page := obj.get_number(''pdf_page'');
        l_chunk := obj.get_number(''chunk_index'');
        require(LENGTHB(l_text) BETWEEN 1 AND 32767 AND l_chunk>0 AND l_chunk=TRUNC(l_chunk),
                ''Invalid summary text or chunk index'');
        require(LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(l_text,''AL32UTF8''),
                  DBMS_CRYPTO.HASH_SH256)))=l_sha, ''Summary text SHA-256 differs'');
        SELECT COUNT(*) INTO l_actual FROM kcv_sources s JOIN kcv_graph_sources g ON g.version_id=s.version_id
          WHERE g.graph_name=l_graph AND s.version_');
 l_expected:=l_expected||TO_CLOB('id=l_version AND s.source_id=l_source
            AND s.sha256=l_source_sha;
        require(l_actual=1, ''Passage source is absent from this dataset or its source hash differs'');
        SELECT COUNT(*) INTO l_actual FROM kcv_passages WHERE passage_id=l_id
          AND (text_sha256<>l_sha OR version_id<>l_version OR chunk_index<>l_chunk
               OR DECODE(pdf_page,l_page,0,1)=1);
        require(l_actual=0, ''Passage identity changed; create a new passage ID'');
        MERGE INTO kcv_passages t USING (SELECT l_id passage_id FROM dual) s ON(t.passage_id=s.passage_id)
        WHEN NOT MATCHED THEN INSERT(passage_id,version_id,pdf_page,chunk_index,text_sha256,passage_text,metadata_json)
 ');
 l_expected:=l_expected||TO_CLOB('         VALUES(l_id,l_version,l_page,l_chunk,l_sha,l_text,r.doc);
      END LOOP;
      l_phase := ''LOADING_CONTEXTS''; progress;
      FOR r IN (SELECT j.doc FROM kcv_dataset_stage s,
        JSON_TABLE(s.payload,''$.rows[*]'' COLUMNS(doc CLOB FORMAT JSON PATH ''$'')) j
        WHERE s.file_role=''contexts'') LOOP
        obj := JSON_OBJECT_T.parse(r.doc); l_source := obj.get_string(''id'');
        l_snapshot := obj.get_number(''snapshot_version'');
        require(l_snapshot BETWEEN 1 AND 9999999999 AND l_snapshot=TRUNC(l_snapshot), ''Invalid context version'');
        l_id := l_source||''-v''||TO_CHAR(l_snapshot,''FM9999999990'');
        SELECT COUNT(*) INTO l_actual FROM kcv_contexts WHERE snapshot_i');
 l_expected:=l_expected||TO_CLOB('d=l_id
          AND (context_id<>l_source OR snapshot_version<>l_snapshot OR NOT JSON_EQUAL(context_json,r.doc));
        require(l_actual=0, ''Context changed; increment its snapshot_version'');
        MERGE INTO kcv_contexts t USING (SELECT l_id snapshot_id FROM dual) s ON(t.snapshot_id=s.snapshot_id)
        WHEN NOT MATCHED THEN INSERT(snapshot_id,context_id,snapshot_version,context_json)
          VALUES(l_id,l_source,l_snapshot,r.doc);
        INSERT INTO kcv_graph_contexts VALUES(l_graph,l_id);
      END LOOP;
      l_phase := ''STAGING_RDF''; progress;
      DELETE FROM kcv_rdf_stage;
      INSERT INTO kcv_rdf_stage(RDF$STC_SUB,RDF$STC_PRED,RDF$STC_OBJ)
        SELECT j.s,j.p,j.o FROM ');
 l_expected:=l_expected||TO_CLOB('kcv_dataset_stage f,
          JSON_TABLE(f.payload,''$.rows[*]'' COLUMNS(
            s VARCHAR2(4000) PATH ''$.s'' ERROR ON ERROR,
            p VARCHAR2(4000) PATH ''$.p'' ERROR ON ERROR,
            o VARCHAR2(4000) PATH ''$.o'' ERROR ON ERROR)) j WHERE f.file_role=''triples'';
      SELECT COUNT(*) INTO l_actual FROM kcv_rdf_stage;
      require(l_actual=l_triples, ''RDF staging count differs'');
      SELECT COUNT(*) INTO l_actual FROM kcv_rdf_stage
        WHERE RDF$STC_SUB IS NULL OR RDF$STC_PRED IS NULL OR RDF$STC_OBJ IS NULL;
      require(l_actual=0, ''RDF staging contains an empty term'');
      COMMIT;
      l_phase := ''BUILDING_NATIVE_GRAPH''; progress;
      SEM_APIS.CREATE_RDF_GRAPH(l_graph');
 l_expected:=l_expected||TO_CLOB(',NULL,NULL,network_owner=>$$PLSQL_UNIT_OWNER,network_name=>''KCV_NET'');
      SEM_APIS.BULK_LOAD_RDF_GRAPH(l_graph,$$PLSQL_UNIT_OWNER,''KCV_RDF_STAGE'',
                                 network_owner=>$$PLSQL_UNIT_OWNER,network_name=>''KCV_NET'');
      l_phase := ''VERIFYING_NATIVE_GRAPH''; progress;
      verify_native_graph;
      UPDATE kcv_graph_runs SET state=''READY'' WHERE graph_name=l_graph;
      l_phase := ''COMPLETE''; activate;
    END IF;
    DBMS_LOB.FREETEMPORARY(l_manifest);
    l_result := DBMS_LOCK.RELEASE(l_handle);
    require(l_result=0,''Dataset is ready but its session lock could not be released'');
    l_locked := FALSE;
    DBMS_OUTPUT.PUT_LINE(''Dataset ready. Run ''||l_run||''; a');
 l_expected:=l_expected||TO_CLOB('ctive graph ''||l_graph);
  EXCEPTION WHEN OTHERS THEN
    l_error := SQLCODE; ROLLBACK;
    BEGIN
      IF l_started AND NOT l_finished THEN progress(''FAILED''); END IF;
    EXCEPTION WHEN OTHERS THEN
      l_cleanup_errors := l_cleanup_errors||'' run-log=''||SQLCODE;
    END;
    BEGIN
      IF DBMS_LOB.ISTEMPORARY(l_manifest)=1 THEN DBMS_LOB.FREETEMPORARY(l_manifest); END IF;
      IF DBMS_LOB.ISTEMPORARY(l_payload)=1 THEN DBMS_LOB.FREETEMPORARY(l_payload); END IF;
    EXCEPTION WHEN OTHERS THEN
      l_cleanup_errors := l_cleanup_errors||'' temporary-LOB=''||SQLCODE;
    END;
    BEGIN
      IF l_locked THEN
        l_result := DBMS_LOCK.RELEASE(l_handle);
        IF l_result<>0 THEN l_cleanup');
 l_expected:=l_expected||TO_CLOB('_errors := l_cleanup_errors||'' lock-status=''||l_result; END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      l_cleanup_errors := l_cleanup_errors||'' lock-release=''||SQLCODE;
    END;
    IF l_cleanup_errors IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20071,''Dataset error ''||l_error||''; cleanup issues:''||l_cleanup_errors,TRUE);
    END IF;
    RAISE;
  END load_github;
END kcv_dataset;
');
 check_program('KCV_DATASET','PACKAGE BODY',l_expected);
