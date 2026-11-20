"""Create ignored SQL for an isolated component test; no credentials or DB calls."""
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from kcv.worksheet import literal,clob
from kcv.pipeline import read

rows=["INSERT INTO kcv_settings VALUES('ACTIVE_GRAPH','KCV_G_AAAA')",'/',
      "INSERT INTO kcv_settings VALUES('AI_PROFILE','KCV_GENAI')",'/',
      "INSERT INTO kcv_graph_runs(graph_name,graph_hash,state) VALUES('KCV_G_AAAA','local-test-only','READY')",'/']
for s in read(ROOT/'data/public-sources.json')['sources']:
    args=','.join([literal(s['version']['id']),literal(s['id']),literal(s['version']['sha256']),clob(json.dumps(s))])
    rows += ['INSERT INTO kcv_sources VALUES('+args+')','/',
      'INSERT INTO kcv_graph_sources VALUES(\'KCV_G_AAAA\','+literal(s['version']['id'])+','+clob(json.dumps(s))+')','/']
for p in read(ROOT/'work/passages.json'):
    args=','.join([literal(p['id']),literal(p['version_id']),str(p['pdf_page']),str(p['chunk_index']),literal(p['text_sha256']),clob(p['text']),clob(json.dumps(p))])
    rows+=['INSERT INTO kcv_passages VALUES('+args+')','/']
for c in read(ROOT/'data/contexts.json')['contexts']:
    snap=c['id']+'-v'+str(c['snapshot_version'])
    rows+=['INSERT INTO kcv_contexts VALUES('+','.join([literal(snap),literal(c['id']),str(c['snapshot_version']),clob(json.dumps(c))])+')','/',
      "INSERT INTO kcv_graph_contexts VALUES('KCV_G_AAAA',"+literal(snap)+')','/']
rows+=['COMMIT','/']
target=ROOT/'work/local-fixture.sql';target.write_text('\n'.join(rows)+'\n',encoding='utf-8',newline='\n');print(target)
