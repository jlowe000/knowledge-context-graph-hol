-- Deterministic read-only evidence tools. Model reasoning is outside these functions.
CREATE OR REPLACE FUNCTION kcv_context_packet(p_request CLOB) RETURN CLOB AUTHID DEFINER AS
  l_context VARCHAR2(32);
  l_body CLOB;
BEGIN
  l_context:=JSON_VALUE(p_request,'$.context_id' RETURNING VARCHAR2(32) ERROR ON ERROR);
  SELECT c.context_json INTO l_body FROM kcv_contexts c
   JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id
   JOIN kcv_settings a ON a.setting_key='ACTIVE_GRAPH' AND a.setting_value=gc.graph_name
   WHERE c.context_id=l_context
   ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
  RETURN l_body;
EXCEPTION WHEN NO_DATA_FOUND THEN
  RETURN '{"error":"Unknown context; do not infer personal intent"}';
END;
/
CREATE OR REPLACE FUNCTION kcv_source_packet(p_request CLOB) RETURN CLOB AUTHID DEFINER AS
  l_source VARCHAR2(32);
  l_version VARCHAR2(128);
  l_graph VARCHAR2(128);
  l_metadata CLOB;
  l_passages CLOB;
  l_sparql VARCHAR2(4000);
  l_sql VARCHAR2(8000);
  l_result CLOB;
BEGIN
  l_source:=JSON_VALUE(p_request,'$.source_id' RETURNING VARCHAR2(32) ERROR ON ERROR);
  SELECT s.version_id,gs.graph_name,gs.metadata_json
    INTO l_version,l_graph,l_metadata FROM kcv_sources s
      JOIN kcv_graph_sources gs ON gs.version_id=s.version_id
      JOIN kcv_settings a ON a.setting_key='ACTIVE_GRAPH' AND a.setting_value=gs.graph_name
      JOIN kcv_graph_runs g ON g.graph_name=gs.graph_name AND g.state='READY'
    WHERE s.source_id=l_source
    ORDER BY s.version_id DESC FETCH FIRST 1 ROW ONLY;
  -- Source editions can be shared by raw and editorial snapshots. Select the
  -- active graph's passage edges before limiting rows; retain historic evidence.
  l_sparql:='SELECT DISTINCT ?ver ?passage WHERE { ?ver <https://example.org/kcv/hasPassage> ?passage }';
  l_sql:='SELECT JSON_ARRAYAGG(JSON_OBJECT(''evidence_id'' VALUE p.passage_id,'||
    '''pdf_page'' VALUE p.pdf_page,''text'' VALUE p.passage_text RETURNING CLOB) '||
    'ORDER BY p.pdf_page,p.chunk_index,p.passage_id RETURNING CLOB) FROM ('||
    'SELECT p.* FROM TABLE(SEM_MATCH('||DBMS_ASSERT.ENQUOTE_LITERAL(l_sparql)||
    ',SEM_MODELS('||DBMS_ASSERT.ENQUOTE_LITERAL(l_graph)||'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,'||
    DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||',''KCV_NET'')) m JOIN kcv_passages p ON p.passage_id='||
    'REPLACE(REPLACE(REPLACE(m.passage,''<'',''''),''>'',''''),''https://example.org/kcv/'','''') '||
    'WHERE p.version_id=:version_id AND p.version_id='||
    'REPLACE(REPLACE(REPLACE(m.ver,''<'',''''),''>'',''''),''https://example.org/kcv/'','''') '||
    'ORDER BY p.pdf_page,p.chunk_index,p.passage_id FETCH FIRST 8 ROWS ONLY) p';
  EXECUTE IMMEDIATE l_sql INTO l_passages USING l_version;
  SELECT JSON_OBJECT('source' VALUE l_metadata FORMAT JSON,
    'passages' VALUE l_passages FORMAT JSON RETURNING CLOB) INTO l_result FROM dual;
  RETURN l_result;
EXCEPTION WHEN NO_DATA_FOUND THEN
  RETURN '{"error":"Unknown source or no active graph"}';
END;
/
CREATE OR REPLACE FUNCTION kcv_evidence_packet(p_request CLOB) RETURN CLOB AUTHID DEFINER AS
  l_context VARCHAR2(32);
  l_snapshot VARCHAR2(128);
  l_graph VARCHAR2(128);
  l_sparql VARCHAR2(4000);
  l_sql VARCHAR2(8000);
  l_cursor SYS_REFCURSOR;
  l_uri VARCHAR2(4000);
  l_id VARCHAR2(200);
  l_page NUMBER;
  l_version VARCHAR2(128);
  l_key VARCHAR2(200);
  l_context_json CLOB;
  l_payload CLOB;
  l_array JSON_ARRAY_T:=JSON_ARRAY_T();
  l_output JSON_OBJECT_T:=JSON_OBJECT_T();
  TYPE seen_t IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(200);
  l_seen seen_t;
  l_counts seen_t;
BEGIN
  l_context:=JSON_VALUE(p_request,'$.context_id' RETURNING VARCHAR2(32) ERROR ON ERROR);
  SELECT c.snapshot_id,c.context_json INTO l_snapshot,l_context_json FROM kcv_contexts c
    JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id
    JOIN kcv_settings a ON a.setting_key='ACTIVE_GRAPH' AND a.setting_value=gc.graph_name
    WHERE c.context_id=l_context ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
  SELECT setting_value INTO l_graph FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
  IF NOT REGEXP_LIKE(l_snapshot,'^CTX[0-9]+-v[0-9]+$') OR NOT REGEXP_LIKE(l_graph,'^KCV_G_[A-F0-9]+$') THEN
    RAISE_APPLICATION_ERROR(-20001,'Invalid lab identity');
  END IF;
  l_sparql:='SELECT DISTINCT ?passage WHERE { ?a <https://example.org/kcv/forContext> <https://example.org/kcv/'||
    l_snapshot||'> . ?a <https://example.org/kcv/recommendsVersion> ?v . ?v <https://example.org/kcv/hasPassage> ?passage } ORDER BY ?passage LIMIT 100';
  l_sql:='SELECT passage FROM TABLE(SEM_MATCH('||DBMS_ASSERT.ENQUOTE_LITERAL(l_sparql)||
    ',SEM_MODELS('||DBMS_ASSERT.ENQUOTE_LITERAL(l_graph)||'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,'||
    DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||',''KCV_NET''))';
  OPEN l_cursor FOR l_sql;
  LOOP
    FETCH l_cursor INTO l_uri;
    EXIT WHEN l_cursor%NOTFOUND OR l_array.get_size>=6;
    l_id:=REPLACE(TRIM(BOTH '>' FROM TRIM(BOTH '<' FROM l_uri)),'https://example.org/kcv/','');
    SELECT pdf_page,version_id INTO l_page,l_version FROM kcv_passages WHERE passage_id=l_id;
    l_key:=l_version||':'||TO_CHAR(l_page);
    IF NOT l_counts.EXISTS(l_version) THEN l_counts(l_version):=0; END IF;
    IF NOT l_seen.EXISTS(l_key) AND l_counts(l_version)<2 THEN
      SELECT metadata_json INTO l_payload FROM kcv_passages WHERE passage_id=l_id;
      l_array.append(JSON_OBJECT_T.parse(l_payload));
      l_seen(l_key):=1;l_counts(l_version):=l_counts(l_version)+1;
    END IF;
  END LOOP;
  CLOSE l_cursor;
  l_output.put('context',JSON_OBJECT_T.parse(l_context_json));
  l_output.put('evidence',l_array);
  l_output.put('graph_snapshot',l_graph);
  l_output.put('status','retrieved evidence and proposed baseline links; not observed value');
  RETURN l_output.to_clob;
EXCEPTION WHEN NO_DATA_FOUND THEN
  IF l_cursor%ISOPEN THEN CLOSE l_cursor; END IF;
  RETURN '{"error":"Unknown context, missing graph or inconsistent evidence identity"}';
END;
/
