"""Public-source intake and graph discovery cannot silently become answer evidence."""
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from rdflib import Graph
from kcv import pipeline as p
from kcv.public_access import validate_url, inspect_body, PublicRedirect, public_rule, retained_publisher
from scripts.build_release import build


class PublicAccessTests(unittest.TestCase):
    def test_youtube_public_rule_requires_exact_event_phrase_and_host(self):
        policy=p.read(p.ROOT/'references/public-source-policy.json')
        def match(url,title): return public_rule(url,policy['url_prefixes'],title,policy['title_rules'])
        self.assertIsNotNone(match('https://www.youtube.com/watch?v=example','Keynote | ORACLE AI WORLD 2026'))
        self.assertIsNotNone(match('https://www.youtube.com/watch?v=example','Oracle  AI World\n2026 - session'))
        for url,title in [('https://www.youtube.com/watch?v=example','Oracle AI World 2025'),
                          ('https://www.youtube.com/watch?v=example','Oracle AI World 20260'),
                          ('https://www.youtube.com/watch?v=example','Oracle AI World'),
                          ('https://www.youtube-nocookie.com/embed/example','Oracle AI World 2026')]:
            self.assertIsNone(match(url,title))
        self.assertTrue(retained_publisher('https://blogs.oracle.com/example',policy))
        self.assertFalse(retained_publisher('https://partner.example/article',policy))
        self.assertFalse(retained_publisher('https://github.com/another-owner/example',policy))

    def test_public_rules_match_exact_hosts_and_path_boundaries(self):
        policy=p.read(p.ROOT/'references/public-source-policy.json')
        prefixes=policy['url_prefixes']
        for url in ['https://api.github.com/repos/oracle/example/zipball/main',
                    'https://raw.githubusercontent.com/helidon-io/example/main/README.md',
                    'https://github.com/helidon-io/example',
                    'https://static.rainfocus.com/oracle/oaiw26/sess/123/file.pdf']:
            self.assertIsNotNone(public_rule(url,prefixes))
        for url in ['https://api.github.com.evil.example/repos/oracle/example',
                    'https://github.com/helidon-io-other/example',
                    'https://static.rainfocus.com/oracle/oaiw26/session-other/file.pdf',
                    'https://example.org/?next=https://github.com/helidon-io/example',
                    'https://github.com/helidon-io/../another-owner/example']:
            self.assertIsNone(public_rule(url,prefixes))

    def test_private_hosts_encoded_references_credentials_and_redirects_rejected(self):
        blocked=['http://example.org/a','https://user:pass@example.org/a',
          'https://tenant.sharepoint.com/a','https://tenant.seismic.com/a',
          'https://1drv.ms/a','https://onedrive.live.com/a',
          'https://example.org/?target=https%3A%2F%2Ftenant.sharepoint.com',
          'https://example.org/?access_token=demo','https://127.0.0.1/a']
        for url in blocked:
            with self.subTest(url=url), self.assertRaises(ValueError): validate_url(url)
        with self.assertRaises(ValueError):
            PublicRedirect().redirect_request(None,None,302,'',{},blocked[2])
        self.assertEqual(validate_url('https://docs.oracle.com/en/example.html'),
                         'https://docs.oracle.com/en/example.html')

    def test_http_200_login_shell_is_not_public_content(self):
        for body in [b'<html><title>Sign in</title><p>'+b'Login '*100+b'</p></html>',
                     b'<html><title>Just a moment</title>'+b'Wait '*100+b'</html>',
                     b'<html><title>Public content</title><p>'+b'Example '*100+b' Confidential - Oracle Restricted</p></html>']:
            with self.assertRaises(ValueError): inspect_body(body,'text/html')
        good=b'<html><title>Public technical article</title><p>'+b'Public article body. '*30+b'</p></html>'
        self.assertEqual(inspect_body(good,'text/html')['access_scope'],'public_page_only')
        sample=b'<html><title>Sign in</title><p>'+b'Example source code '*30+b'</p></html>'
        self.assertEqual(inspect_body(sample,'text/plain',raw_repository_source=True)['access_scope'],
                         'public_repository_source')

    def test_pdf_marking_ligatures_are_detected_and_exact_edition_review_is_explicit(self):
        reader=SimpleNamespace(is_encrypted=False,pages=[SimpleNamespace(
            extract_text=lambda: 'Public slide content. '*20+"Con\ufb01dential - Do not duplicate or distribute")])
        with patch('kcv.public_access.PdfReader',return_value=reader):
            with self.assertRaises(ValueError): inspect_body(b'%PDF-test','application/pdf')
            result=inspect_body(b'%PDF-test','application/pdf',reviewed_marking=True)
            self.assertEqual(result['marking_check'],'user_reviewed_template_footer_exact_edition')


class PublicCatalogTests(unittest.TestCase):
    def test_catalog_graph_has_discovery_paths_and_only_actual_passages(self):
        graph=Graph().parse(p.ROOT/'generated/knowledge.ttl',format='turtle')
        rows=p.catalog(); self.assertGreater(len(rows),0)
        available={}
        for passage in p.load_passages():
            available.setdefault(passage['source_id'],[]).append(passage)
        for row in rows:
            item=p.K[row['id']]; version=p.K[row['version']['id']]
            self.assertIn((item,p.K.hasVersion,version),graph)
            self.assertTrue(list(graph.objects(item,p.K.coversTopic)))
            actual=available.get(row['id'],[])
            self.assertEqual(str(graph.value(version,p.K.evidenceCoverage)),p.evidence_coverage(actual))
            self.assertEqual(set(graph.objects(version,p.K.hasPassage)),{p.K[x['id']] for x in actual})
            self.assertFalse(list(graph.subjects(p.K.recommendsVersion,version)))
        packet=p.packet('CTX01','Find relevant evidence')
        self.assertTrue(all(x['source_id'].startswith('S') for x in packet['evidence']))

    def test_every_reference_has_matching_access_result_and_explicit_classification(self):
        audit=p.read(p.ROOT/'references/public-access-checks.json')
        policy=p.read(p.ROOT/'references/public-source-policy.json')
        prefixes=policy['url_prefixes']
        checks={r['source_id']:r for r in audit['checks']}
        for row in p.sources()+p.catalog():
            checked=checks[row['id']]
            self.assertIn(checked['status'],{'verified_public','manually_marked_public'})
            if checked['status']=='manually_marked_public':
                self.assertEqual(checked['public_rule'],public_rule(row['url'],prefixes,row['title'],policy.get('title_rules',[])))
                self.assertEqual(checked['classification_status'],'manually marked as public')
            if checked['access_verified']:
                self.assertEqual(checked['http_status'],200)
                self.assertEqual(checked['hash_basis'],'source_response')
            else:
                self.assertEqual(checked['status'],'manually_marked_public')
                self.assertEqual(checked['hash_basis'],'catalogue_metadata')
                self.assertTrue(checked['reason'])
                self.assertNotIn('verified_on',row['version'])
            self.assertFalse(checked['authentication_used'])
            self.assertFalse(checked['cookies_used'])
            self.assertEqual(checked['sha256'],row['version']['sha256'])
            self.assertEqual(checked['url'],row['url'])
            validate_url(row['url'])
            validate_url(checked['url'])
        self.assertEqual(set(checks),{r['id'] for r in p.sources()+p.catalog()})

    def test_unapproved_third_party_items_and_nonmatching_youtube_titles_are_not_distributed(self):
        policy=p.read(p.ROOT/'references/public-source-policy.json')
        youtube=[]
        for item in p.catalog():
            rule=public_rule(item['url'],policy['url_prefixes'],item['title'],policy.get('title_rules',[]))
            self.assertTrue(rule or retained_publisher(item['url'],policy),item['id'])
            if item['url'].startswith('https://www.youtube.com/'):
                youtube.append(item)
                self.assertIn('Oracle AI World 2026',item['title'])
                self.assertEqual(item['access_status'],'manually_marked_public')
        self.assertEqual(len(youtube),11)

    def test_release_rejects_a_changed_url_reusing_an_unrelated_access_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in ['data/public-sources.json','data/public-catalog.json','references/public-access-checks.json','references/public-source-policy.json']:
                p.write(root/name,p.read(p.ROOT/name))
            changed=p.read(root/'data/public-catalog.json')
            changed['items'][0]['url']='https://docs.oracle.com/not-the-verified-resource.html'
            p.write(root/'data/public-catalog.json',changed)
            with patch('scripts.build_release.ROOT',root), self.assertRaisesRegex(ValueError,'Missing or mismatched anonymous verification'):
                build(root/'release')

    def test_release_includes_catalogue_graph_metadata_and_prepared_sql(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=build(Path(tmp)/'release')
            self.assertTrue((folder/'data/public-catalog.json').exists())
            self.assertTrue((folder/'references/public-access-checks.json').exists())
            loader=(folder/'sql/install/10_load_dataset.sql').read_text(encoding='utf-8')
            graph=Graph().parse(folder/'generated/knowledge.ttl',format='turtle')
            for row in p.catalog():
                self.assertIn(row['version']['id'],loader)
                self.assertIn((p.K[row['id']],p.K.hasVersion,p.K[row['version']['id']]),graph)
            self.assertNotIn('&',loader)
            # Check every distributable text file, including generated SQL and HTML.
            for file in folder.rglob('*'):
                if file.is_file() and file.suffix.lower() not in {'.png','.jpg'}:
                    text=file.read_text(encoding='utf-8')
                    import re
                    for url in re.findall(r'https?://[^\s<>"\']+',text):
                        self.assertFalse(any(x in url.lower() for x in ('sharepoint','onedrive','seismic','1drv.ms')),str(file))
