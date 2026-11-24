"""Check the actual distribution, especially content provenance and file separation."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from rdflib import Graph, URIRef
from kcv import pipeline as p
from scripts.build_release import build


class ReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        # Fixture for dataset/distribution regression only. Real engine-export
        # gating is exercised separately; this mock is never an acceptance receipt.
        with patch('scripts.build_release.verify_upgrade_export', return_value={'fixture_only': True}), \
             patch('scripts.build_apex_worksheet.verify_upgrade_export', return_value={'fixture_only': True}):
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

    def test_release_learning_routes_include_expanded_casey_without_maintainer_steps(self):
        readme = (self.folder / 'README.md').read_text(encoding='utf-8')
        for route in ['labs/explore-evidence/explore-evidence.md',
                      'labs/understand-collection/understand-collection.md',
                      'docs/fresh-serverless-deployment.md']:
            self.assertIn(route, readme)
            self.assertTrue((self.folder / route).is_file())
        anchor = 'docs/ui-walkthrough.md#explore-the-expanded-research-with-casey'
        self.assertIn(anchor, readme)
        walkthrough = (self.folder / 'docs/ui-walkthrough.md').read_text(encoding='utf-8')
        self.assertIn('## Explore the expanded research with Casey', walkthrough)
        self.assertIn('R0691', walkthrough)
        load = (self.folder / 'labs/load-knowledge/load-knowledge.md').read_text(encoding='utf-8')
        self.assertIn('select **release**', load)
        self.assertNotIn('select **dev** for native acceptance', load)
        self.assertNotIn('Keep release unchanged', load)
        self.assertNotIn('local authoring loader', load)
        self.assertIn('sql/install/10_load_github.sql', load)

    def test_summaries_have_own_hashes_labels_and_public_page_attribution(self):
        passages = p.read(self.folder / 'data/release-summaries.json')['passages']
        originals = p.read(p.ROOT / 'work/passages.json')
        expected = 17 + len(p.read(p.ROOT / 'data/public-content-summaries.json')['summaries'])
        self.assertEqual(len(passages), expected)
        self.assertFalse({x['id'] for x in passages} & {x['id'] for x in originals})
        for item in passages:
            self.assertIn('-summary-', item['id'])
            self.assertTrue(item['text'].startswith('Editorial summary, not a quotation: '))
            self.assertEqual(item['text_sha256'], p.digest(item['text']))
            from kcv.public_access import validate_url
            validate_url(item['locator_url'])
            if item['pdf_page'] is not None:
                self.assertTrue(item['locator_url'].endswith('#page=' + str(item['pdf_page'])))
            else:
                self.assertTrue(item['locator_kind'])
                self.assertTrue(item['locator_label'])
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

    def test_v2_distribution_refuses_missing_engine_export_before_packaging(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'VERSION').write_text('2.0.0\n', encoding='utf-8')
            with patch('scripts.build_release.ROOT', root):
                with self.assertRaisesRegex(ValueError, 'No validated v2 engine export'):
                    build(root / 'candidate')
            self.assertFalse((root / 'candidate').exists())

    def test_github_dataset_is_valid_public_and_pinned_by_the_sql_caller(self):
        from kcv.github_dataset import validate, validate_package
        folder = self.folder / 'data/load'
        manifest = validate(folder)
        files = {item['path']: (folder / item['path']).read_bytes() for item in manifest['files']}
        rows = validate_package(manifest, files)
        self.assertEqual(manifest['graph_sha256'], p.digest((self.folder / 'generated/knowledge.ttl').read_bytes()))
        self.assertEqual(manifest['counts']['sources'], len(p.content_sources(p.ROOT)))
        summaries = p.read(self.folder / 'data/release-summaries.json')['passages']
        self.assertEqual({item['id']: item['text'] for item in rows['passages']},
                         {item['id']: item['text'] for item in summaries})
        raw_passages = []
        for filename in ('passages.json', 'catalog-passages.json'):
            path = p.ROOT / 'work' / filename
            if path.exists():
                raw_passages.extend(p.read(path))
        self.assertFalse({item['id'] for item in rows['passages']} & {item['id'] for item in raw_passages})
        self.assertFalse({item['text'] for item in rows['passages']} & {item['text'] for item in raw_passages})
        self.assertTrue(all(item['content_kind'] == 'attributed_editorial_summary' for item in rows['passages']))
        caller = (self.folder / 'sql/install/10_load_github.sql').read_text(encoding='utf-8')
        self.assertIn('KCV_DATASET.LOAD_GITHUB(', caller)
        self.assertIn("p_ref => 'PASTE_FULL_40_CHARACTER_COMMIT_SHA'", caller)
        manifest_hash = p.digest((folder / 'manifest.json').read_bytes())
        self.assertRegex(caller, r"p_expected_manifest_sha256\s*=>\s*'" + manifest_hash + "'")
        importer = self.folder / 'sql/schema/06_dataset_import.sql'
        self.assertEqual(importer.read_bytes(), (p.ROOT / 'sql/schema/06_dataset_import.sql').read_bytes())

    def evidence(self, labels):
        graph = Graph().parse(self.folder / 'generated/knowledge.ttl', format='turtle')
        rev = p.K['release-check']
        for label in labels: graph.add((rev, p.K.focusesOn, p.K['topic-' + p.slug(label)]))
        rows = list(graph.query('''SELECT DISTINCT ?item ?ver ?topic ?passage WHERE {
          <https://example.org/kcv/release-check> <https://example.org/kcv/focusesOn> ?topic .
          ?item <https://example.org/kcv/coversTopic> ?topic ; <https://example.org/kcv/hasVersion> ?ver .
          ?ver <https://example.org/kcv/hasPassage> ?passage }
          ORDER BY ?item ?topic ?passage'''))
        return sorted(rows, key=lambda r: (0 if str(r.item).rsplit('/', 1)[-1].startswith('S') else 1,
                                          str(r.item), str(r.topic), str(r.passage)))

    def test_summary_graph_preserves_scope_pages_and_context_refinement(self):
        contexts = p.read(self.folder / 'data/contexts.json')['contexts']
        passages = {x['id']: x for x in p.read(self.folder / 'data/release-summaries.json')['passages']}
        healthcare = self.evidence(contexts[2]['topic_preferences'])
        evidence = [passages[str(r.passage).rsplit('/', 1)[-1]] for r in healthcare]
        self.assertTrue(any(r['source_id'] == 'S10' for r in evidence))
        self.assertEqual({r['pdf_page'] for r in evidence if r['source_id'] == 'S10'}, {3, 10})
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
