"""Generate locally held SQL Worksheet artifacts; no database connection required."""
import json
from pathlib import Path
import re

from rdflib import Graph
from .pipeline import ROOT, digest, read, content_sources, load_passages


def literal(value):
    # Worksheet scans ampersands even inside quoted strings. Emit CHR(38)
    # instead so source text is preserved without client substitution prompts.
    parts=str(value).split('&')
    quoted=["'"+part.replace("'","''")+"'" for part in parts]
    return quoted[0] if len(quoted)==1 else '('+' || CHR(38) || '.join(quoted)+')'


def clob(value):
    # Keep each SQL literal comfortably below byte-length limits, including UTF-8.
    return ' || '.join('TO_CLOB('+literal(value[i:i+500])+')' for i in range(0,len(value),500)) or "TO_CLOB('')"


def worksheet_units(script):
    """Read our generated, slash-delimited units without client preamble lines.

    This intentionally accepts the generated loader format, not arbitrary SQL.
    Complete units are preserved byte-for-byte after newline normalisation.
    """
    pending=[]; units=[]
    for line in script.replace('\r\n','\n').splitlines(keepends=True):
        stripped=line.strip()
        if not pending and (not stripped or stripped.startswith('--')
                or re.fullmatch(r'SET\s+(?:DEFINE\s+OFF|SERVEROUTPUT\s+ON)',stripped,re.I)):
            continue
        pending.append(line if line.endswith('\n') else line+'\n')
        if stripped=='/':
            if len(pending)==1:
                raise ValueError('Empty slash-delimited SQL unit')
            units.append(''.join(pending)); pending=[]
    if pending:
        raise ValueError('Incomplete SQL unit: expected a final slash delimiter')
    if not units:
        raise ValueError('No SQL units to package')
    return units


def write_dataset_parts(script, folder, max_bytes=2_000_000, notice=None):
    """Package complete loader units into ordered, bounded Worksheet files."""
    folder=Path(folder)
    units=worksheet_units(script)
    source_hash=digest(script)
    notice=notice or '-- Generated dataset loader; preserve its source-content handling rules.'
    def header(index,total):
        return ('SET DEFINE OFF\nSET SERVEROUTPUT ON\n'
            f'-- Dataset part {index:03d} of {total:03d}. Run Script (F5) in numeric order, starting with 001.sql.\n'
            '-- Run one dataset loader at a time. On any error, stop, fix it, then rerun from 001.sql.\n'
            '-- Database-backed batch guards preserve order across separate Worksheet requests.\n'
            f'-- Complete loader SHA-256: {source_hash}\n{notice}\n')
    # Reserve the longest supported numeric header before computing the groups.
    budget=max_bytes-len(header(999999,999999).encode('utf-8'))
    if budget<=0:
        raise ValueError('Dataset part byte limit is too small for the required header')
    groups=[]; current=[]; current_bytes=0
    for unit in units:
        size=len(unit.encode('utf-8'))
        if size>budget:
            raise ValueError('One complete SQL unit exceeds the dataset part byte budget')
        if current and current_bytes+size>budget:
            groups.append(current);current=[];current_bytes=0
        current.append(unit);current_bytes+=size
    if current: groups.append(current)
    if len(groups)>999999:
        raise ValueError('Too many dataset parts')
    # Regeneration may retire old numbered parts, but never unrelated files.
    previous=[]
    manifest_path=folder/'manifest.json'
    if manifest_path.exists():
        for item in read(manifest_path).get('files',[]):
            name=item.get('path','')
            if not re.fullmatch(r'\d{3,6}\.sql',name):
                raise ValueError('Invalid generated dataset part path in previous manifest')
            previous.append(folder/name)
    folder.mkdir(parents=True,exist_ok=True)
    files=[]; first=1
    for index,group in enumerate(groups,1):
        name=f'{index:03d}.sql'; text=header(index,len(groups))+''.join(group)
        body=text.encode('utf-8')
        if len(body)>max_bytes:
            raise ValueError('Dataset part exceeds its byte budget')
        path=folder/name
        path.write_text(text,encoding='utf-8',newline='\n')
        files.append({'order':index,'path':name,'bytes':len(body),'sha256':digest(body),
            'first_unit':first,'last_unit':first+len(group)-1,'unit_count':len(group)})
        first+=len(group)
    retained={f['path'] for f in files}
    for path in previous:
        if path.name not in retained and path.is_file(): path.unlink()
    manifest={'format_version':1,'source_sql':'../10_load_dataset.sql',
        'source_sql_sha256':source_hash,'sql_units_sha256':digest(''.join(units)),
        'max_part_bytes':max_bytes,'part_count':len(files),'unit_count':len(units),
        'execution_order':'Run every SQL file in the listed numeric order, starting at 001.sql.',
        'recovery':'Stop on an error, resolve it, then rerun the complete sequence from 001.sql.',
        'native_database_validation':'not_implied_by_packaging','files':files}
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
    readme=('# Load the dataset in SQL Worksheet\n\n'
        f'This folder contains {len(files)} ordered SQL files. Each file is at most {max_bytes:,} bytes '
        'and ends between complete SQL or PL/SQL units.\n\n'
        '1. Sign in to Database Actions SQL Worksheet as `KCV_LAB` after completing the schema setup.\n'
        '2. Open `001.sql`, paste or load its complete contents, and choose **Run Script (F5)**.\n'
        '3. Check Script Output for errors, then run each remaining numbered file in order. '
        'Keep the same database user; the batch state is stored in the database.\n'
        '4. The final part checks completeness and switches the active graph only after successful loading.\n\n'
        'Run only one dataset load at a time. If any part reports an error, stop. Resolve the error and '
        'rerun all parts starting with `001.sql`; do not resume halfway through the sequence. '
        'Successful batches commit. The previous active graph remains active until the final completeness check passes.\n\n'
        'The complete `../10_load_dataset.sql` remains available for clients such as SQLcl. '
        'Choose either the complete script or the numbered files for a load, not both.\n\n'
        '`manifest.json` records order, byte sizes, hashes and SQL-unit ranges. Packaging verification '
        'does not establish successful execution on an Autonomous Database.\n\n'
        +notice.removeprefix('-- ')+'\n')
    (folder/'README.md').write_text(readme,encoding='utf-8',newline='\n')
    return manifest


def export(root=ROOT, batch_bytes=90000, batch_rows=100):
    passages=load_passages(root)
    notice=('-- Contains attributed editorial summaries, not extracted source text.'
        if passages and all(p.get('content_kind')=='attributed_editorial_summary' for p in passages)
        else '-- Contains public-source passage text: keep this generated script local; do not commit it.')
    graph=Graph().parse(root/'generated/knowledge.ttl',format='turtle')
    graph_hash=digest((root/'generated/knowledge.ttl').read_bytes())
    lines=['-- Generated for KCV_LAB in Database Actions SQL Worksheet.',
      notice,
      '-- Run Script (F5). No client database driver, wallet or database password is used here.',
      '-- Run one dataset loader at a time. A failed batch prevents later batches from activating the graph.',
      '-- Successful batches commit. After resolving an error, rerun this entire script.',
      'SET DEFINE OFF', 'SET SERVEROUTPUT ON',
      'DECLARE','  l_graph VARCHAR2(128);',
      'BEGIN',f"  SELECT MIN(graph_name) INTO l_graph FROM kcv_graph_runs WHERE graph_hash={literal(graph_hash)} AND state='READY';",
      '  IF l_graph IS NULL THEN',"    l_graph:='KCV_G_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);",
      f"    INSERT INTO kcv_graph_runs(graph_name,graph_hash,state) VALUES(l_graph,{literal(graph_hash)},'LOADING');",
      '    DELETE FROM kcv_rdf_stage;', '  END IF;',
      "  MERGE INTO kcv_settings t USING (SELECT 'DATASET_LOAD_GRAPH' setting_key FROM dual) s ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value=l_graph WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('DATASET_LOAD_GRAPH',l_graph);",
      "  MERGE INTO kcv_settings t USING (SELECT 'DATASET_LOAD_BATCH' setting_key FROM dual) s ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value='0' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('DATASET_LOAD_BATCH','0');",
      '  COMMIT;', 'END;', '/']
    batches=[]
    pending=[]
    pending_bytes=0

    def flush():
        nonlocal pending, pending_bytes
        if pending:
            batches.append(pending)
            pending=[]; pending_bytes=0

    def add(statements):
        nonlocal pending_bytes
        size=len('\n'.join(statements).encode('utf-8'))
        if size>batch_bytes:
            raise ValueError('One dataset row exceeds the Worksheet batch byte budget')
        if pending and (len(pending)>=batch_rows or pending_bytes+size>batch_bytes):
            flush()
        pending.append(statements); pending_bytes+=size

    source_rows=content_sources(root,passages)
    for s in source_rows:
        v=literal(s['version']['id']);h=literal(s['version']['sha256']);sid=literal(s['id'])
        body=clob(json.dumps(s,ensure_ascii=False))
        add([f'    SELECT MAX(sha256) INTO l_old_hash FROM kcv_sources WHERE version_id={v};',
          f"    IF l_old_hash IS NOT NULL AND l_old_hash<>{h} THEN RAISE_APPLICATION_ERROR(-20001,'Source version hash changed'); END IF;",
          f'    MERGE INTO kcv_sources t USING (SELECT {v} version_id FROM dual) s ON(t.version_id=s.version_id)',
          f'      WHEN NOT MATCHED THEN INSERT(version_id,source_id,sha256,metadata_json) VALUES({v},{sid},{h},{body});'])
    for p in passages:
        i=literal(p['id']);h=literal(p['text_sha256'])
        page='NULL' if p.get('pdf_page') is None else str(p['pdf_page'])
        add([f'SELECT MAX(text_sha256) INTO l_old_hash FROM kcv_passages WHERE passage_id={i};',
          f"IF l_old_hash IS NOT NULL AND l_old_hash<>{h} THEN RAISE_APPLICATION_ERROR(-20002,'Passage hash changed'); END IF;",
          f'MERGE INTO kcv_passages t USING (SELECT {i} passage_id FROM dual) s ON(t.passage_id=s.passage_id)',
          f" WHEN NOT MATCHED THEN INSERT(passage_id,version_id,pdf_page,chunk_index,text_sha256,passage_text,metadata_json) VALUES({i},{literal(p['version_id'])},{page},{p['chunk_index']},{h},{clob(p['text'])},{clob(json.dumps(p,ensure_ascii=False))});"])
    contexts=read(root/'data/contexts.json')['contexts']
    for c in contexts:
        key=literal(c['id']+'-v'+str(c['snapshot_version']));body=clob(json.dumps(c))
        add(['BEGIN',f'SELECT context_json INTO l_existing FROM kcv_contexts WHERE snapshot_id={key};',
          f"IF DBMS_LOB.COMPARE(l_existing,{body})<>0 THEN RAISE_APPLICATION_ERROR(-20003,'Increment changed context snapshot version'); END IF;",
          'EXCEPTION WHEN NO_DATA_FOUND THEN',f'INSERT INTO kcv_contexts(snapshot_id,context_id,snapshot_version,context_json) VALUES({key},{literal(c["id"])},{c["snapshot_version"]},{body});','END;'])
    flush()
    for s,p,o in sorted(graph,key=lambda t:tuple(x.n3() for x in t)):
        add(['INSERT INTO kcv_rdf_stage(RDF$STC_SUB,RDF$STC_PRED,RDF$STC_OBJ) VALUES('+','.join(literal(x.n3()) for x in (s,p,o))+');'])
    flush()
    add([f"SELECT COUNT(*) INTO l_stage_count FROM kcv_rdf_stage; IF l_stage_count<>{len(graph)} THEN RAISE_APPLICATION_ERROR(-20004,'Incomplete RDF stage'); END IF;",
      "SEM_APIS.CREATE_RDF_GRAPH(l_graph,NULL,NULL,network_owner=>USER,network_name=>'KCV_NET');",
      "SEM_APIS.BULK_LOAD_RDF_GRAPH(l_graph,USER,'KCV_RDF_STAGE',network_owner=>USER,network_name=>'KCV_NET');"])
    flush()
    for s in source_rows:
        add([f"INSERT INTO kcv_graph_sources(graph_name,version_id,metadata_json) VALUES(l_graph,{literal(s['version']['id'])},{clob(json.dumps(s,ensure_ascii=False))});"])
    for c in contexts:
        add([f"INSERT INTO kcv_graph_contexts(graph_name,snapshot_id) VALUES(l_graph,{literal(c['id']+'-v'+str(c['snapshot_version']))});"])
    flush()
    add(["UPDATE kcv_graph_runs SET state='READY' WHERE graph_name=l_graph;"])
    flush()

    guard=['DECLARE', '  l_graph VARCHAR2(128); l_state VARCHAR2(16); l_hash VARCHAR2(64);',
      '  l_old_hash VARCHAR2(64); l_existing CLOB; l_batch NUMBER; l_stage_count NUMBER;', 'BEGIN',
      "  SELECT setting_value INTO l_graph FROM kcv_settings WHERE setting_key='DATASET_LOAD_GRAPH';",
      '  SELECT state,graph_hash INTO l_state,l_hash FROM kcv_graph_runs WHERE graph_name=l_graph;',
      f"  IF l_hash<>{literal(graph_hash)} THEN RAISE_APPLICATION_ERROR(-20005,'Another dataset load replaced this run'); END IF;",
      "  IF l_state<>'READY' THEN",
      "    SELECT TO_NUMBER(setting_value) INTO l_batch FROM kcv_settings WHERE setting_key='DATASET_LOAD_BATCH';"]
    for index, batch in enumerate(batches,1):
        lines.extend(guard)
        lines.append(f"    IF l_batch<>{index-1} THEN RAISE_APPLICATION_ERROR(-20006,'Previous dataset batch failed; rerun the full loader'); END IF;")
        for statements in batch:
            lines.extend(statements)
        lines.extend([f"UPDATE kcv_settings SET setting_value='{index}' WHERE setting_key='DATASET_LOAD_BATCH';",
          f"DBMS_OUTPUT.PUT_LINE('Dataset batch {index}/{len(batches)} complete');",'COMMIT;', 'END IF;', 'END;', '/'])
    lines.extend(['DECLARE', '  l_graph VARCHAR2(128); l_state VARCHAR2(16); l_hash VARCHAR2(64);', 'BEGIN',
      "SELECT setting_value INTO l_graph FROM kcv_settings WHERE setting_key='DATASET_LOAD_GRAPH';",
      'SELECT state,graph_hash INTO l_state,l_hash FROM kcv_graph_runs WHERE graph_name=l_graph;',
      f"IF l_state<>'READY' OR l_hash<>{literal(graph_hash)} THEN RAISE_APPLICATION_ERROR(-20007,'Dataset is incomplete; active graph unchanged'); END IF;",
      "MERGE INTO kcv_settings t USING (SELECT 'ACTIVE_GRAPH' setting_key FROM dual) s ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value=l_graph WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('ACTIVE_GRAPH',l_graph);",
      "COMMIT; DBMS_OUTPUT.PUT_LINE('Active graph: '||l_graph);",'END;','/',
      "SELECT setting_value AS active_graph FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH'",'/'])
    target=root/'work/worksheet/10_load_dataset.sql'
    target.parent.mkdir(parents=True,exist_ok=True)
    script='\n'.join(lines)+'\n'
    target.write_text(script,encoding='utf-8',newline='\n')
    parts=write_dataset_parts(script,target.parent/'dataset-parts',notice=notice)
    return {'script':'work/worksheet/10_load_dataset.sql','triples':len(graph),'graph_sha256':graph_hash,'batches':len(batches),
            'parts_manifest':'work/worksheet/dataset-parts/manifest.json','part_count':parts['part_count'],
            'contains_source_passages':True,'database_connection_required_to_generate':False}
