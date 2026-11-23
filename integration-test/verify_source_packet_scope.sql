-- KCV_LAB, after a dataset load and the current sql/schema/03_tools.sql.
-- Native regression: add a temporary passage outside the active graph under an
-- existing source edition. The source tool must not return it. Roll back only
-- this fixture, preserving loaded snapshots and pre-existing user work.
-- Run alone in SQL Worksheet (F5); no model calls or credentials are needed.
DECLARE
  l_graph VARCHAR2(128); l_version VARCHAR2(128);
  l_sentinel VARCHAR2(200):='KCV_SCOPE_TEST_'||RAWTOHEX(SYS_GUID());
  l_packet CLOB; l_count NUMBER; l_sql VARCHAR2(8000);
  l_sparql VARCHAR2(4000):='SELECT DISTINCT ?ver ?passage WHERE { ?ver <https://example.org/kcv/hasPassage> ?passage }';
BEGIN
  SAVEPOINT kcv_source_scope;
  SELECT gs.graph_name,s.version_id INTO l_graph,l_version
    FROM kcv_sources s JOIN kcv_graph_sources gs ON gs.version_id=s.version_id
    JOIN kcv_settings a ON a.setting_key='ACTIVE_GRAPH' AND a.setting_value=gs.graph_name
    JOIN kcv_graph_runs g ON g.graph_name=gs.graph_name AND g.state='READY'
    WHERE s.source_id='S02' ORDER BY s.version_id DESC FETCH FIRST 1 ROW ONLY;
  INSERT INTO kcv_passages(passage_id,version_id,pdf_page,chunk_index,
    text_sha256,passage_text,metadata_json)
    VALUES(l_sentinel,l_version,1,1,RPAD('0',64,'0'),
      'Synthetic out-of-graph passage for native scope validation.',
      '{"test_fixture":true}');

  l_packet:=kcv_source_packet('{"source_id":"S02"}');
  SELECT COUNT(*) INTO l_count FROM JSON_TABLE(l_packet,'$.passages[*]'
    COLUMNS(passage_id VARCHAR2(200) PATH '$.evidence_id'));
  IF l_count=0 THEN RAISE_APPLICATION_ERROR(-20084,'Source packet returned no active evidence'); END IF;
  SELECT COUNT(*) INTO l_count FROM JSON_TABLE(l_packet,'$.passages[*]'
    COLUMNS(passage_id VARCHAR2(200) PATH '$.evidence_id')) j WHERE j.passage_id=l_sentinel;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20085,'Source packet exposed out-of-graph evidence'); END IF;

  -- Every returned identity must have the edition/passage edge in this graph,
  -- including when historical raw and current editorial rows coexist.
  l_sql:='WITH graph_ids AS (SELECT '||
    'REPLACE(REPLACE(REPLACE(m.passage,''<'',''''),''>'',''''),''https://example.org/kcv/'','''') passage_id,'||
    'REPLACE(REPLACE(REPLACE(m.ver,''<'',''''),''>'',''''),''https://example.org/kcv/'','''') version_id '||
    'FROM TABLE(SEM_MATCH('||DBMS_ASSERT.ENQUOTE_LITERAL(l_sparql)||',SEM_MODELS('||
    DBMS_ASSERT.ENQUOTE_LITERAL(l_graph)||'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,'||
    DBMS_ASSERT.ENQUOTE_LITERAL(USER)||',''KCV_NET'')) m) '||
    'SELECT COUNT(*) FROM JSON_TABLE(:packet,''$.passages[*]'' '||
    'COLUMNS(passage_id VARCHAR2(200) PATH ''$.evidence_id'')) j '||
    'WHERE NOT EXISTS (SELECT 1 FROM graph_ids g WHERE g.passage_id=j.passage_id AND g.version_id=:version_id)';
  EXECUTE IMMEDIATE l_sql INTO l_count USING l_packet,l_version;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20086,'Source packet passage is absent from active graph'); END IF;
  ROLLBACK TO kcv_source_scope;
  DBMS_OUTPUT.PUT_LINE('PASS: source packet returns only active graph evidence; fixture rolled back');
EXCEPTION WHEN OTHERS THEN
  ROLLBACK TO kcv_source_scope;
  RAISE;
END;
/
