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
