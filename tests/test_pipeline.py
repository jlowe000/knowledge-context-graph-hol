import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from rdflib import Graph, RDF

from kcv import pipeline as p
from kcv.database import sql_statements
from kcv.worksheet import clob, export


class DatasetTests(unittest.TestCase):
    def test_sql_literal_export_preserves_untrusted_text_without_executing_it(self):
        import sqlite3
        conn=sqlite3.connect(':memory:')
        conn.create_function('TO_CLOB',1,lambda value:value)
        conn.create_function('CHR',1,chr)
        conn.execute('create table protected_data(id integer)')
        text="x'); DROP TABLE protected_data; --\nUnicode: \u03a9 ' &topic &&again & "*80
        self.assertNotIn('&',clob(text))
        self.assertEqual(conn.execute('select '+clob(text)).fetchone()[0],text)
        self.assertEqual(conn.execute('select count(*) from protected_data').fetchone()[0],0)
        conn.close()
    def test_public_corpus_and_upstream_are_separate(self):
        rows=p.sources()
        self.assertEqual(len(rows),9)
        self.assertNotIn('S01',{r['id'] for r in rows})
        self.assertFalse(any('F1' in r['title'] or 'Formula' in r['title'] for r in rows))
        examples=p.read(p.ROOT/'review-examples/examples.json')['examples']
        self.assertEqual(len(examples),17)
        self.assertTrue({e['source_id'] for e in examples}<={s['id'] for s in rows})

    def test_same_session_is_not_same_document(self):
        rows={s['id']:s for s in p.sources()}
        self.assertEqual(rows['S04']['session_ids'],rows['S05']['session_ids'])
        self.assertNotEqual(rows['S04']['version']['sha256'],rows['S05']['version']['sha256'])

    def test_context_changes_selection_and_unknown_goal_stays_optional(self):
        contexts=p.read(p.ROOT/'data/contexts.json')['contexts']
        self.assertNotIn('objective',contexts[0])
        a=p.assess(contexts[0],p.sources());b=p.assess(contexts[2],p.sources())
        self.assertNotEqual(a['recommendations'],b['recommendations'])
        self.assertEqual([x['source_id'] for x in b['recommendations']],['S10'])
        self.assertIsNone(b['observed_value'])

    def test_evidence_validation_rejects_invented_and_misattributed_quotes(self):
        passages=[{'id':'p1','source_id':'S03','version_id':'S03-v1','text':'AI Discovery is described as Coming Soon in this presentation.'}]
        claim={'statement':'The slide qualifies availability.','topic_labels':['Ontology'],'evidence_id':'p1','quote':'Coming Soon in this presentation'}
        self.assertEqual(len(p.validate_candidates({'claims':[claim]},passages,{'Ontology'})),1)
        for field,value in [('quote','Currently generally available everywhere'),('evidence_id','invented'),('topic_labels',['Invented topic'])]:
            modified={**claim,field:value}
            with self.assertRaises(ValueError):p.validate_candidates({'claims':[modified]},passages,{'Ontology'})

    def test_candidate_cannot_become_accepted_without_explicit_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);candidate={'id':'C-demo','statement':'Demo'}
            p.write(root/'work/candidates.json',[candidate])
            with self.assertRaises(ValueError):p.review('C-demo','accept','','',root)
            self.assertFalse((root/'work/accepted-claims.json').exists())
            p.review('C-demo','accept','Test reviewer','Explicit fixture decision',root)
            self.assertEqual(p.read(root/'work/accepted-claims.json')[0]['review_status'],'accepted')
            p.review('C-demo','reject','Test reviewer','Reconsidered',root)
            self.assertEqual(p.read(root/'work/accepted-claims.json'),[])
            self.assertEqual(len((root/'work/reviews.jsonl').read_text().splitlines()),2)

    def test_sql_scripts_are_delimited_and_no_blanket_error_suppression(self):
        import re
        # These generated bundles retain superseded immutable migration payloads.
        # Migration integrity/postcondition checks validate that history; lint the
        # current maintained code while retaining delimiter checks for every file.
        historical_bundles={
            'sql/install/00_adopt_schema_baseline.sql',
            'sql/install/00_install_schema.sql',
            'sql/install/01_upgrade_schema.sql',
            'sql/install/02_verify_schema.sql',
        }
        for file in (p.ROOT/'sql').rglob('*.sql'):
            units=list(sql_statements(file))
            self.assertTrue(units,str(file))
            for unit in units:
                if not re.match(r'\s*(BEGIN\b|DECLARE\b|CREATE\s+OR\s+REPLACE\b)',unit,re.I):
                    self.assertFalse(unit.rstrip().endswith(';'),'SQL plus slash would execute twice in SQLcl-style script mode: '+str(file))
            if file.relative_to(p.ROOT).as_posix() not in historical_bundles:
                self.assertNotIn('WHEN OTHERS THEN NULL',file.read_text().upper(),str(file))

    def test_public_files_have_no_private_source_urls(self):
        import re
        for folder in ['data','review-examples','references','generated']:
            for file in (p.ROOT/folder).rglob('*'):
                if file.is_file() and file.suffix in {'.json','.md','.ttl'}:
                    urls=re.findall(r'https?://[^\s<>"\']+',file.read_text(encoding='utf-8'))
                    self.assertFalse(any('sharepoint' in u.lower() or 'onedrive' in u.lower() for u in urls),str(file))


@unittest.skipUnless((p.ROOT/'work/passages.json').exists(),'Run prepare first for artifact checks')
class ArtifactTests(unittest.TestCase):
    def test_worksheet_export_carries_same_graph_and_stays_out_of_git(self):
        result=export()
        report=p.read(p.ROOT/'generated/build-report.json')
        self.assertEqual(result['graph_sha256'],report['graph_sha256'])
        text=(p.ROOT/result['script']).read_text(encoding='utf-8')
        self.assertIn('SEM_APIS.BULK_LOAD_RDF_GRAPH',text)
        self.assertIn('Increment changed context snapshot version',text)
        self.assertIn(report['graph_sha256'],text)
        units=list(sql_statements(p.ROOT/result['script']))
        self.assertEqual(len(units),result['batches']+3)
        self.assertLess(max(len(unit.encode('utf-8')) for unit in units),95000)
        self.assertIn('Previous dataset batch failed',text)
        self.assertIn('Dataset is incomplete; active graph unchanged',text)
        self.assertNotIn('ADMIN_PASSWORD',text)
        self.assertNotIn('&',text,'Worksheet loader must not prompt for substitutions')
    def test_real_page_coverage_and_content_hashes(self):
        rows=p.sources();passages=p.read(p.ROOT/'work/passages.json')
        for source in rows:
            actual=[x for x in passages if x['source_id']==source['id']]
            self.assertEqual(set(source['selected_pdf_pages']),{x['pdf_page'] for x in actual})
            for passage in actual:
                self.assertEqual(p.digest(passage['text']),passage['text_sha256'])
                self.assertEqual(passage['source_sha256'],source['version']['sha256'])

    def test_graph_contains_review_examples_not_unreviewed_claims(self):
        g=Graph().parse(p.ROOT/'generated/knowledge.ttl',format='turtle')
        self.assertEqual(len(set(g.subjects(RDF.type,p.K.ReviewExample))),17)
        expected=p.read(p.ROOT/'generated/build-report.json')['accepted_claim_count']
        self.assertEqual(len(set(g.subjects(RDF.type,p.K.Claim))),expected)
        paths=list(g.query('''SELECT ?v WHERE {
          ?a <https://example.org/kcv/forContext> <https://example.org/kcv/CTX03-v1> ;
             <https://example.org/kcv/recommendsVersion> ?v . }'''))
        self.assertEqual([str(row[0]) for row in paths],[str(p.K['S10-v1'])])

    def test_packet_preserves_two_distinct_pages_for_scope_and_overview(self):
        packet=p.packet('CTX03','What is available?')
        self.assertEqual({x['pdf_page'] for x in packet['evidence']},{3,10})
        self.assertTrue(all(x['source_id']=='S10' for x in packet['evidence']))
        self.assertLessEqual(len(packet['evidence']),6)

    def test_build_is_repeatable(self):
        first=p.build()['graph_sha256'];second=p.build()['graph_sha256']
        self.assertEqual(first,second)


if __name__=='__main__':unittest.main()
