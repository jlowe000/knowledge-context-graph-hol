"""Opt-in functional tests. Requires provisioned, loaded ADB Serverless lab schema."""
import json
import os
import unittest

from kcv.database import connect, preflight, run_team


@unittest.skipUnless(os.environ.get('KCV_RUN_SERVERLESS_TESTS')=='1','ADB Serverless not configured/explicitly enabled')
class ServerlessTests(unittest.TestCase):
    def test_java_rdf_and_agent_packages(self):
        check=preflight()
        self.assertTrue(check['ready_for_rdf_probe'])
        self.assertTrue(check['DBMS_CLOUD_AI_AGENT'])

    def test_native_graph_path_returns_real_passages(self):
        with connect() as conn:
            with conn.cursor() as cur:
                cur.execute('select kcv_evidence_packet(:q) from dual',q='{"context_id":"CTX03"}')
                body=cur.fetchone()[0];body=body.read() if hasattr(body,'read') else body
                result=json.loads(body)
                self.assertNotIn('error',result)
                self.assertTrue(result['evidence'])
                self.assertTrue(all(p['source_id']=='S10' for p in result['evidence']))
                self.assertEqual({p['pdf_page'] for p in result['evidence']},{3,10})

    @unittest.skipUnless(os.environ.get('KCV_RUN_MODEL_TESTS')=='1','No model call requested')
    def test_model_profile_call(self):
        with connect() as conn:
            with conn.cursor() as cur:
                cur.execute("select DBMS_CLOUD_AI.GENERATE(prompt=>'Reply with the single word ready',profile_name=>:n,action=>'chat') from dual",n=os.environ.get('KCV_AI_PROFILE','KCV_GENAI'))
                response=cur.fetchone()[0]
                response=response.read() if hasattr(response,'read') else response
                self.assertTrue(response)

    @unittest.skipUnless(os.environ.get('KCV_RUN_AGENT_TESTS')=='1','No agent/model call requested')
    def test_relevance_agent_cites_only_returned_evidence(self):
        with connect() as conn:
            with conn.cursor() as cur:
                cur.execute('select kcv_evidence_packet(:q) from dual',q='{"context_id":"CTX03"}')
                raw=cur.fetchone()[0];raw=raw.read() if hasattr(raw,'read') else raw
                allowed={p['id'] for p in json.loads(raw)['evidence']}
        result=run_team({'task':'assess_context','context_id':'CTX03','question':'Explain relevance and regional limitations; cite evidence IDs.'})
        def locate(value):
            if isinstance(value,str):
                try:return locate(json.loads(value))
                except (ValueError,TypeError):return None
            if isinstance(value,dict):
                if 'citations' in value:return value['citations']
                for child in value.values():
                    found=locate(child)
                    if found is not None:return found
            if isinstance(value,list):
                for child in value:
                    found=locate(child)
                    if found is not None:return found
            return None
        citations=locate(result)
        self.assertIsInstance(citations,list,'Agent must return inspectable JSON citations')
        self.assertTrue(citations)
        self.assertTrue(all(isinstance(x,str) and x in allowed for x in citations))


if __name__=='__main__':unittest.main()
