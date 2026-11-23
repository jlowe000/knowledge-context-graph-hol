"""Passage provenance and non-PDF locations remain explicit across graph and SQL."""
import copy
from pathlib import Path
import re
import tempfile
import unittest
from rdflib import Graph, Literal
from kcv import pipeline as p
from kcv.worksheet import export


class ContentIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)
        for name in ['data/public-sources.json','review-examples/examples.json','data/contexts.json']:
            p.write(self.root/name,p.read(p.ROOT/name))
        (self.root/'ontology').mkdir()
        (self.root/'ontology/kcv.ttl').write_bytes((p.ROOT/'ontology/kcv.ttl').read_bytes())
        p.write(self.root/'work/passages.json',p.read(p.ROOT/'work/passages.json'))
        self.source={'id':'R9000','title':'Synthetic public documentation',
          'url':'https://docs.oracle.com/example.html','version':{'id':'R9000-v1','sha256':'a'*64,'hash_basis':'source_response'},
          'access_status':'verified_public','access_verified':True,'topics':['Synthetic topic'],
          'business_domains':['General'],'session_ids':[], 'limitations':'Catalogue only.'}
        p.write(self.root/'data/public-catalog.json',{'items':[self.source]})
        text='Synthetic documented content for the integration fixture.'
        self.passage={'id':'R9000-v1-section001-c001-'+p.digest(text)[:8], 'source_id':'R9000','version_id':'R9000-v1',
          'source_sha256':'a'*64,'text':text,'text_sha256':p.digest(text),'pdf_page':None,'chunk_index':1,
          'locator_url':self.source['url']+'#architecture','locator_kind':'html_section','locator_label':'Architecture section',
          'extractor':'test-fixture','content_kind':'extracted_source_text'}

    def test_non_pdf_passage_is_hashed_located_and_loaded_without_fake_page(self):
        p.write(self.root/'work/catalog-passages.json',[self.passage])
        report=p.build(self.root)
        self.assertEqual(report['catalog_passage_count'],1)
        self.assertEqual(report['catalog_sources_with_passages'],1)
        graph=Graph().parse(self.root/'generated/knowledge.ttl',format='turtle')
        node=p.K[self.passage['id']]
        self.assertIn((p.K['R9000-v1'],p.K.hasPassage,node),graph)
        self.assertIsNone(graph.value(node,p.K.pdfPage))
        self.assertEqual(str(graph.value(node,p.K.locatorLabel)),'Architecture section')
        self.assertNotIn(self.passage['text'],(self.root/'generated/knowledge.ttl').read_text())
        runtime=next(s for s in p.content_sources(self.root) if s['id']=='R9000')
        self.assertEqual(runtime['evidence_coverage'],'extracted_source_passages')
        self.assertEqual(runtime['passage_count'],1)
        result=export(self.root)
        sql=(self.root/result['script']).read_text()
        self.assertIn("'R9000-v1',NULL,1,",sql)

    def test_stale_hash_false_locator_and_fake_pdf_page_fail_closed(self):
        for field,value in [('source_sha256','b'*64),('text_sha256','b'*64),
                            ('locator_url','https://docs.oracle.com/unrelated.html'),('pdf_page',0)]:
            with self.subTest(field=field):
                changed={**self.passage,field:value}
                p.write(self.root/'work/catalog-passages.json',[changed])
                with self.assertRaises(ValueError):p.load_passages(self.root)

    def test_summary_stage_does_not_implicitly_read_dev_extraction(self):
        summary=copy.deepcopy(self.passage)
        summary['content_kind']='attributed_editorial_summary'
        p.write(self.root/'work/passages.json',[summary])
        actual=p.load_passages(self.root)
        self.assertEqual(actual,[{**summary,'retrieval_eligible':True}])
        self.assertEqual(p.evidence_coverage(actual),'attributed_editorial_summary')

    def test_retrieval_uses_inspected_basis_including_later_chunks(self):
        first={**self.passage,'text':'A cover page without technical detail.'}
        first['text_sha256']=p.digest(first['text'])
        second={**self.passage,'id':'R9000-v1-section001-c002-reviewed','chunk_index':2}
        p.write(self.root/'work/catalog-passages.json',[first,second])
        p.write(self.root/'data/public-content-summaries.json',{'summaries':[{
          'source_id':'R9000','version_id':'R9000-v1','source_sha256':'a'*64,
          'basis_passage_ids':[second['id']],'basis_text_sha256':[second['text_sha256']]}]})
        loaded={x['id']:x for x in p.load_passages(self.root)}
        self.assertFalse(loaded[first['id']]['retrieval_eligible'])
        self.assertTrue(loaded[second['id']]['retrieval_eligible'])
        p.build(self.root)
        graph=Graph().parse(self.root/'generated/knowledge.ttl',format='turtle')
        self.assertEqual(len(list(graph.objects(p.K['R9000-v1'],p.K.hasPassage))),2)
        self.assertFalse(graph.value(p.K[first['id']],p.K.retrievalEligible).toPython())
        self.assertTrue(graph.value(p.K[second['id']],p.K.retrievalEligible).toPython())

    def test_graph_policy_preserves_only_original_sources_as_legacy_fallback(self):
        graph=Graph()
        for source, flag in [('S02',None),('R9000',None),('R9001',False),('R9002',True)]:
            passage=p.K[source+'-passage']
            graph.add((p.K[source],p.K.hasPassage,passage))
            if flag is not None:graph.add((passage,p.K.retrievalEligible,Literal(flag)))
        selected=graph.query('''SELECT ?item WHERE {
          ?item <https://example.org/kcv/hasPassage> ?passage .
          OPTIONAL { ?passage <https://example.org/kcv/retrievalEligible> ?eligible }
          FILTER (?eligible = true || (!BOUND(?eligible) && REGEX(STR(?item),"/S[0-9]+$"))) }''')
        self.assertEqual({str(row.item) for row in selected},{str(p.K.S02),str(p.K.R9002)})

    def test_immutable_id_reuse_with_different_metadata_is_rejected(self):
        p.write(self.root/'work/passages.json',[self.passage])
        p.write(self.root/'work/catalog-passages.json',[{**self.passage,'locator_label':'Different section'}])
        with self.assertRaisesRegex(ValueError,'Conflicting passage'):
            p.load_passages(self.root)

    def test_source_packet_scopes_shared_version_to_graph_before_row_limit(self):
        sql=(p.ROOT/'sql/schema/03_tools.sql').read_text()
        body=sql.split('CREATE OR REPLACE FUNCTION kcv_source_packet',1)[1].split('\n/\n',1)[0]
        # Execute the actual source tool's SPARQL against snapshots which share
        # an edition but deliberately contain different evidence identities.
        query=re.search(r"l_sparql:='([^']+)'",body).group(1)
        historic,active=Graph(),Graph()
        version=p.K['S02-v1']
        raw=[p.K[f'S02-v1-raw-{i:02d}'] for i in range(12)]
        summary=p.K['S02-v1-summary-current']
        for passage in raw:historic.add((version,p.K.hasPassage,passage))
        active.add((version,p.K.hasPassage,summary))
        # All rows coexist in the database; only the active graph's edges may
        # select them. More than eight older rows must not starve the summary.
        stored={str(x) for x in raw+[summary]}
        selected={str(row.passage) for row in active.query(query)
                  if row.ver==version and str(row.passage) in stored}
        self.assertEqual(selected,{str(summary)})
        self.assertEqual({str(row.passage) for row in historic.query(query)},set(map(str,raw)))
        self.assertIn("a.setting_key='ACTIVE_GRAPH'",body)
        self.assertIn('DBMS_ASSERT.ENQUOTE_LITERAL(l_graph)',body)
        self.assertLess(body.index('m.passage'),body.index('FETCH FIRST 8 ROWS ONLY'))
        self.assertNotIn('SELECT * FROM kcv_passages WHERE version_id=s.version_id',body)
