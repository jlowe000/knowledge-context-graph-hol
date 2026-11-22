"""Check the actual distribution, especially content provenance and file separation."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from rdflib import Graph, URIRef
from kcv import pipeline as p
from scripts.build_release import build


class ReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.folder = build(Path(cls.temporary.name) / 'release')

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_release_is_complete_without_developer_or_private_files(self):
        names = {f.relative_to(self.folder).as_posix() for f in self.folder.rglob('*') if f.is_file()}
        for required in ['sql/install/10_load_dataset.sql', 'sql/install/20_install_apex.sql',
                         'docs/release-dataset.md', 'README.md', 'LICENSE.txt', 'NOTICE.md',
                         'third-party/font-apex/README.md', 'third-party/font-apex/LICENSE.txt',
                         'third-party/oracle-livelabs/README.md', 'third-party/oracle-livelabs/LICENSE.txt']:
            self.assertIn(required, names)
        licence = (self.folder / 'LICENSE.txt').read_text(encoding='utf-8')
        self.assertIn('MIT License', licence)
        self.assertIn('Copyright (c) 2026 Jason Lowe', licence)
        upstream = (self.folder / 'third-party/oracle-livelabs/LICENSE.txt').read_text(encoding='utf-8')
        self.assertIn('Copyright (c) 2022 Oracle and/or its affiliates.', upstream)
        self.assertIn('The Universal Permissive License (UPL), Version 1.0', upstream)
        self.assertFalse(any(n.split('/')[0] in {'work', 'scripts', 'kcv', 'tests',
                         'release-docs', 'config', '.venv'} for n in names))
        self.assertFalse(any(n.endswith(('.py', '.sh', '.env', '.pem', '.key')) for n in names))
        self.assertNotIn('docs/development.md', names)
        self.assertFalse((self.folder / 'integration-test/mocks').exists())

    def test_summaries_have_own_hashes_labels_and_public_page_attribution(self):
        passages = p.read(self.folder / 'data/release-summaries.json')['passages']
        originals = p.read(p.ROOT / 'work/passages.json')
        self.assertEqual(len(passages), 17)
        self.assertFalse({x['id'] for x in passages} & {x['id'] for x in originals})
        for item in passages:
            self.assertIn('-summary-', item['id'])
            self.assertTrue(item['text'].startswith('Editorial summary, not a quotation: '))
            self.assertEqual(item['text_sha256'], p.digest(item['text']))
            self.assertTrue(item['locator_url'].startswith('https://static.rainfocus.com/'))
            self.assertTrue(item['locator_url'].endswith('#page=' + str(item['pdf_page'])))
            self.assertEqual(item['content_kind'], 'attributed_editorial_summary')
        loader = (self.folder / 'sql/install/10_load_dataset.sql').read_text(encoding='utf-8')
        self.assertNotIn('&', loader)
        for item in passages:
            self.assertIn(item['id'], loader)
        # The loader must not silently redistribute any original extracted passage.
        self.assertTrue(all(item['text'] not in loader for item in originals))

    def test_manifest_hashes_and_overwrite_refusal(self):
        manifest = p.read(self.folder / 'release-manifest.json')
        self.assertFalse(manifest['python_required_for_learner'])
        listed = {item['path'] for item in manifest['files']}
        actual = {f.relative_to(self.folder).as_posix() for f in self.folder.rglob('*') if f.is_file()}
        self.assertEqual(actual - {'release-manifest.json'}, listed)
        for item in manifest['files']:
            self.assertEqual(item['sha256'], hashlib.sha256((self.folder / item['path']).read_bytes()).hexdigest())
        with self.assertRaises(ValueError): build(self.folder)

    def evidence(self, labels):
        graph = Graph().parse(self.folder / 'generated/knowledge.ttl', format='turtle')
        rev = p.K['release-check']
        for label in labels: graph.add((rev, p.K.focusesOn, p.K['topic-' + p.slug(label)]))
        return list(graph.query('''SELECT DISTINCT ?item ?ver ?topic ?passage WHERE {
          <https://example.org/kcv/release-check> <https://example.org/kcv/focusesOn> ?topic .
          ?item <https://example.org/kcv/coversTopic> ?topic ; <https://example.org/kcv/hasVersion> ?ver .
          ?ver <https://example.org/kcv/hasPassage> ?passage }
          ORDER BY ?item ?topic ?passage'''))

    def test_summary_graph_preserves_scope_pages_and_context_refinement(self):
        contexts = p.read(self.folder / 'data/contexts.json')['contexts']
        passages = {x['id']: x for x in p.read(self.folder / 'data/release-summaries.json')['passages']}
        healthcare = self.evidence(contexts[2]['topic_preferences'])
        evidence = [passages[str(r.passage).rsplit('/', 1)[-1]] for r in healthcare]
        self.assertEqual({r['source_id'] for r in evidence}, {'S10'})
        self.assertEqual({r['pdf_page'] for r in evidence}, {3, 10})
        labels = contexts[0]['topic_preferences']
        before = {str(r.item) for r in self.evidence(labels)}
        after = {str(r.item) for r in self.evidence([x for x in labels if x != 'Graph capabilities'])}
        self.assertIn(str(p.K.S06), before)
        self.assertNotIn(str(p.K.S06), after)
        self.assertIn(str(p.K.S02), after)

        def bounded_sources(topics):
            selected = []; seen = set(); counts = {}
            for row in self.evidence(topics):
                evidence = passages[str(row.passage).rsplit('/', 1)[-1]]
                key = (evidence['version_id'], evidence['pdf_page'])
                if key not in seen and counts.get(key[0], 0) < 2 and len(selected) < 6:
                    selected.append(evidence['source_id']); seen.add(key)
                    counts[key[0]] = counts.get(key[0], 0) + 1
            return set(selected)

        self.assertEqual(bounded_sources(labels), {'S02', 'S03', 'S06'})
        self.assertEqual(bounded_sources([x for x in labels if x != 'Graph capabilities']),
                         {'S02', 'S03', 'S08'})


if __name__ == '__main__': unittest.main()
