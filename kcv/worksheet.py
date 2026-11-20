"""Generate locally held SQL Worksheet artifacts; no database connection required."""
from rdflib import Graph
from .pipeline import ROOT, digest, read, sources


def literal(value):
    # Worksheet scans ampersands even inside quoted strings. Emit CHR(38)
    # instead so source text is preserved without client substitution prompts.
    parts=str(value).split('&')
    quoted=["'"+part.replace("'","''")+"'" for part in parts]
    return quoted[0] if len(quoted)==1 else '('+' || CHR(38) || '.join(quoted)+')'


def clob(value):
    # Keep each SQL literal comfortably below byte-length limits, including UTF-8.
    return ' || '.join('TO_CLOB('+literal(value[i:i+500])+')' for i in range(0,len(value),500)) or "TO_CLOB('')"


def export(root=ROOT):
    import json
    graph=Graph().parse(root/'generated/knowledge.ttl',format='turtle')
    graph_hash=digest((root/'generated/knowledge.ttl').read_bytes())
    lines=['-- Generated for KCV_LAB in Database Actions SQL Worksheet.',
      '-- Contains public-source passage text: keep this generated script local; do not commit it.',
      '-- Run Script (F5). No client database driver, wallet or database password is used here.',
      'DECLARE','  l_graph VARCHAR2(128);','  l_old_hash VARCHAR2(64);','  l_existing CLOB;',
      'BEGIN',f"  SELECT MIN(graph_name) INTO l_graph FROM kcv_graph_runs WHERE graph_hash={literal(graph_hash)} AND state='READY';",
      '  IF l_graph IS NULL THEN',"    l_graph:='KCV_G_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);",
      f"    INSERT INTO kcv_graph_runs(graph_name,graph_hash,state) VALUES(l_graph,{literal(graph_hash)},'LOADING');"]
    source_rows=sources(root)
    for s in source_rows:
        v=literal(s['version']['id']);h=literal(s['version']['sha256']);sid=literal(s['id'])
        body=clob(json.dumps(s,ensure_ascii=False))
        lines.extend([f'    SELECT MAX(sha256) INTO l_old_hash FROM kcv_sources WHERE version_id={v};',
          f"    IF l_old_hash IS NOT NULL AND l_old_hash<>{h} THEN RAISE_APPLICATION_ERROR(-20001,'Source version hash changed'); END IF;",
          f'    MERGE INTO kcv_sources t USING (SELECT {v} version_id FROM dual) s ON(t.version_id=s.version_id)',
          f'      WHEN NOT MATCHED THEN INSERT(version_id,source_id,sha256,metadata_json) VALUES({v},{sid},{h},{body});'])
    for p in read(root/'work/passages.json'):
        i=literal(p['id']);h=literal(p['text_sha256'])
        lines.extend([f'SELECT MAX(text_sha256) INTO l_old_hash FROM kcv_passages WHERE passage_id={i};',
          f"IF l_old_hash IS NOT NULL AND l_old_hash<>{h} THEN RAISE_APPLICATION_ERROR(-20002,'Passage hash changed'); END IF;",
          f'MERGE INTO kcv_passages t USING (SELECT {i} passage_id FROM dual) s ON(t.passage_id=s.passage_id)',
          f" WHEN NOT MATCHED THEN INSERT(passage_id,version_id,pdf_page,chunk_index,text_sha256,passage_text,metadata_json) VALUES({i},{literal(p['version_id'])},{p['pdf_page']},{p['chunk_index']},{h},{clob(p['text'])},{clob(json.dumps(p,ensure_ascii=False))});"])
    contexts=read(root/'data/contexts.json')['contexts']
    for c in contexts:
        key=literal(c['id']+'-v'+str(c['snapshot_version']));body=clob(json.dumps(c))
        lines.extend(['BEGIN',f'SELECT context_json INTO l_existing FROM kcv_contexts WHERE snapshot_id={key};',
          f"IF DBMS_LOB.COMPARE(l_existing,{body})<>0 THEN RAISE_APPLICATION_ERROR(-20003,'Increment changed context snapshot version'); END IF;",
          'EXCEPTION WHEN NO_DATA_FOUND THEN',f'INSERT INTO kcv_contexts(snapshot_id,context_id,snapshot_version,context_json) VALUES({key},{literal(c["id"])},{c["snapshot_version"]},{body});','END;'])
    lines.append('DELETE FROM kcv_rdf_stage;')
    for s,p,o in sorted(graph,key=lambda t:tuple(x.n3() for x in t)):
        lines.append('INSERT INTO kcv_rdf_stage(RDF$STC_SUB,RDF$STC_PRED,RDF$STC_OBJ) VALUES('+','.join(literal(x.n3()) for x in (s,p,o))+');')
    lines.extend(['COMMIT; -- Stage data before invoking native RDF bulk loading.',"SEM_APIS.CREATE_RDF_GRAPH(l_graph,NULL,NULL,network_owner=>USER,network_name=>'KCV_NET');",
      "SEM_APIS.BULK_LOAD_RDF_GRAPH(l_graph,USER,'KCV_RDF_STAGE',network_owner=>USER,network_name=>'KCV_NET');"])
    for s in source_rows:
        lines.append(f"INSERT INTO kcv_graph_sources(graph_name,version_id,metadata_json) VALUES(l_graph,{literal(s['version']['id'])},{clob(json.dumps(s,ensure_ascii=False))});")
    for c in contexts:
        lines.append(f"INSERT INTO kcv_graph_contexts(graph_name,snapshot_id) VALUES(l_graph,{literal(c['id']+'-v'+str(c['snapshot_version']))});")
    lines.extend(["UPDATE kcv_graph_runs SET state='READY' WHERE graph_name=l_graph;",'END IF;',
      "MERGE INTO kcv_settings t USING (SELECT 'ACTIVE_GRAPH' setting_key FROM dual) s ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value=l_graph WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('ACTIVE_GRAPH',l_graph);",
      "COMMIT; DBMS_OUTPUT.PUT_LINE('Active graph: '||l_graph);",'END;','/',
      "SELECT setting_value AS active_graph FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH'",'/'])
    target=root/'work/worksheet/10_load_dataset.sql'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    return {'script':'work/worksheet/10_load_dataset.sql','triples':len(graph),'graph_sha256':graph_hash,
            'contains_source_passages':True,'database_connection_required_to_generate':False}
