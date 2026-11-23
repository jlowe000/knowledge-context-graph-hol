"""The GitHub package preserves evidence and refuses corruption or raw export."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from rdflib import Graph, Literal, RDF, URIRef

from kcv import pipeline
from kcv.github_dataset import (MAX_FILE_BYTES, canonical_bytes, dataset_identifier,
                                generate, graph_bytes, loader_script, validate,
                                validate_package, write_loader, write_package)


def fixture(count=8):
    source_hash = pipeline.digest('Public fixture source')
    source = {'id': 'S02', 'url': 'https://static.rainfocus.com/oracle/oaiw26/sess/fixture.pdf',
              'title': 'Public fixture', 'version': {'id': 'S02-v1', 'sha256': source_hash},
              'passage_count': count, 'retrieval_eligible_passage_count': count,
              'evidence_coverage': 'attributed_editorial_summary'}
    catalogue = {'id': 'R0001', 'url': 'https://www.oracle.com/example/',
                 'title': 'Discovery reference without answer evidence',
                 'version': {'id': 'R0001-v1', 'sha256': pipeline.digest('Catalogue fixture')},
                 'passage_count': 0, 'retrieval_eligible_passage_count': 0,
                 'evidence_coverage': 'catalogue_only'}
    context = {'id': 'CTX01', 'snapshot_version': 1, 'fictional': True,
               'question': 'How do source versions support an answer?'}
    passages = []
    graph = Graph()
    k = pipeline.K
    for item in (source, catalogue):
        graph.add((k[item['id']], k.hasVersion, k[item['version']['id']]))
    graph.add((k['CTX01-v1'], RDF.type, k.ContextSnapshot))
    graph.add((k['CTX01-v1'], k.question, Literal(context['question'])))
    # Exercises native n3 escaping separately from JSON string escaping.
    graph.add((k.S02, k.description, Literal('Unicode Ω; slash \\; "quotes"\nsecond line', lang='en')))
    graph.add((k.S02, k.ordinal, Literal(1)))
    for index in range(count):
        text = f'Editorial summary, not a quotation: Example {index} connects evidence Ω, "quotes" and \\ paths.\nSecond line.'
        digest = pipeline.digest(text)
        identity = f'S02-v1-summary-{index}-{digest[:8]}'
        passages.append({'id': identity, 'source_id': source['id'], 'version_id': 'S02-v1',
                         'text': text, 'text_sha256': digest, 'source_sha256': source_hash,
                         'content_kind': 'attributed_editorial_summary', 'retrieval_eligible': True,
                         'pdf_page': index + 1, 'chunk_index': 1,
                         'locator_url': source['url'] + '#page=' + str(index + 1)})
        graph.add((k['S02-v1'], k.hasPassage, k[identity]))
        graph.add((k[identity], k.retrievalEligible, Literal(True)))
        graph.add((k[identity], k.textHash, Literal(digest)))
    triples = [{'s': s.n3(), 'p': p.n3(), 'o': o.n3()}
               for s, p, o in sorted(graph, key=lambda t: tuple(x.n3() for x in t))]
    return {'sources': [source, catalogue], 'passages': passages,
            'contexts': [context], 'triples': triples}, graph


def package_files(folder, manifest):
    return {entry['path']: (folder / entry['path']).read_bytes() for entry in manifest['files']}


def replace_payload(manifest, files, role, change):
    """Re-sign a changed fixture part to reach semantic validation checks."""
    entry = next(x for x in manifest['files'] if x['role'] == role)
    payload = json.loads(files[entry['path']])
    change(payload)
    body = canonical_bytes(payload) + b'\n'
    files[entry['path']] = body
    entry.update(bytes=len(body), sha256=pipeline.digest(body), rows=len(payload['rows']))
    manifest['dataset_id'] = dataset_identifier(manifest)


class GithubDatasetTests(unittest.TestCase):
    def test_roundtrip_preserves_native_terms_links_and_byte_bounds(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            manifest = write_package(folder, rows, pipeline.digest(graph_bytes(graph)), max_bytes=1200)
            files = package_files(folder, manifest)
            restored = validate_package(manifest, files)
            self.assertEqual(restored, rows)
            self.assertGreater(len([x for x in manifest['files'] if x['role'] == 'passages']), 1)
            self.assertTrue(all(len(body) <= 1200 and body.endswith(b'\n') for body in files.values()))
            self.assertEqual(validate(folder), manifest)
            self.assertEqual(manifest['dataset_id'], dataset_identifier(manifest))
            self.assertEqual(restored['sources'][1]['passage_count'], 0)
            self.assertTrue(all(p['retrieval_eligible'] for p in restored['passages']))
            self.assertIn('Ω', ''.join(body.decode('utf-8') for body in files.values()))
            self.assertTrue(any('"""' in row['o'] for row in restored['triples']))

    def test_same_input_produces_identical_files_and_manifest(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            left, right = Path(temporary) / 'left', Path(temporary) / 'right'
            a = write_package(left, rows, pipeline.digest(graph_bytes(graph)), max_bytes=1200)
            b = write_package(right, rows, pipeline.digest(graph_bytes(graph)), max_bytes=1200)
            self.assertEqual(a, b)
            self.assertEqual(package_files(left, a), package_files(right, b))
            self.assertEqual((left / 'manifest.json').read_bytes(), (right / 'manifest.json').read_bytes())

    def test_detects_file_corruption_and_manifest_identity_change(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            files = package_files(folder, original)
            files[next(iter(files))] += b' '
            with self.assertRaisesRegex(ValueError, 'size/hash mismatch'):
                validate_package(original, files)
            manifest = copy.deepcopy(original)
            manifest['counts']['sources'] += 1
            with self.assertRaisesRegex(ValueError, 'identifier'):
                validate_package(manifest, package_files(folder, original))

    def test_signed_payload_still_requires_valid_foreign_keys_and_text_hash(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            for changes, expected in [({'version_id': 'S99-v1'}, 'source edition'),
                                      ({'text': rows['passages'][0]['text'] + 'changed'}, 'text/hash'),
                                      ({'retrieval_eligible': False}, 'evidence counts')]:
                manifest, files = copy.deepcopy(original), package_files(folder, original)
                replace_payload(manifest, files, 'passages', lambda p: p['rows'][0].update(changes))
                with self.assertRaisesRegex(ValueError, expected):
                    validate_package(manifest, files)

    def test_graph_hash_and_context_membership_are_checked(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            manifest = copy.deepcopy(original)
            manifest['graph_sha256'] = '0' * 64
            manifest['dataset_id'] = dataset_identifier(manifest)
            with self.assertRaisesRegex(ValueError, 'reconstruct the graph hash'):
                validate_package(manifest, package_files(folder, original))
            manifest, files = copy.deepcopy(original), package_files(folder, original)
            replace_payload(manifest, files, 'contexts', lambda p: p['rows'][0].update(id='CTX99'))
            with self.assertRaisesRegex(ValueError, 'Context snapshot is absent'):
                validate_package(manifest, files)

    def test_rejects_raw_text_and_native_column_overflow_before_writing(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / 'output'
            for change, expected in [({'content_kind': 'extracted_source_text'}, 'editorial summaries'),
                                      ({'id': 'x' * 201}, 'column limit')]:
                modified = copy.deepcopy(rows)
                modified['passages'][0].update(change)
                with self.assertRaisesRegex(ValueError, expected):
                    write_package(folder, modified, pipeline.digest(graph_bytes(graph)))
                self.assertFalse(folder.exists())
            with patch('kcv.github_dataset.pipeline.load_passages', return_value=[{'content_kind': 'extracted_source_text'}]):
                with self.assertRaisesRegex(ValueError, 'summary-stage CLI'):
                    generate(Path(temporary), folder)

    def test_regeneration_retires_only_owned_parts(self):
        rows, graph = fixture(16)
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            first = write_package(folder, rows, pipeline.digest(graph_bytes(graph)), max_bytes=1200)
            (folder / 'keep.txt').write_text('Keep this unrelated file', encoding='utf-8')
            small, small_graph = fixture(1)
            second = write_package(folder, small, pipeline.digest(graph_bytes(small_graph)), max_bytes=1200)
            self.assertLess(len(second['files']), len(first['files']))
            self.assertEqual({x.name for x in folder.glob('*.json')},
                             {'manifest.json'} | {x['path'] for x in second['files']})
            self.assertEqual((folder / 'keep.txt').read_text(), 'Keep this unrelated file')
            validate(folder)

    def test_refuses_traversal_unowned_collision_and_excessive_parts(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            manifest = copy.deepcopy(original)
            manifest['files'][0]['path'] = '../outside.json'
            manifest['dataset_id'] = dataset_identifier(manifest)
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                validate_package(manifest, package_files(folder, original))
            collision = folder / 'collision'
            collision.mkdir()
            protected = collision / 'sources-001.json'
            protected.write_text('Existing user file')
            with self.assertRaisesRegex(ValueError, 'unrelated dataset file'):
                write_package(collision, rows, pipeline.digest(graph_bytes(graph)))
            self.assertEqual(protected.read_text(), 'Existing user file')
            with self.assertRaisesRegex(ValueError, 'row exceeds'):
                write_package(folder / 'small', rows, pipeline.digest(graph_bytes(graph)), max_bytes=100)
            with self.assertRaisesRegex(ValueError, 'part size'):
                write_package(folder / 'huge', rows, pipeline.digest(graph_bytes(graph)), max_bytes=MAX_FILE_BYTES + 1)

    def test_generate_uses_summary_metadata_and_existing_graph_hash(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary)
            pipeline.write(stage / 'data/contexts.json', {'contexts': rows['contexts']})
            (stage / 'generated').mkdir()
            (stage / 'generated/knowledge.ttl').write_bytes(graph_bytes(graph))
            with patch('kcv.github_dataset.pipeline.load_passages', return_value=rows['passages']), \
                    patch('kcv.github_dataset.pipeline.content_sources', return_value=rows['sources']) as source_loader:
                manifest = generate(stage, stage / 'data/load')
                source_loader.assert_called_once_with(stage, rows['passages'])
            self.assertEqual(manifest['graph_sha256'], pipeline.digest((stage / 'generated/knowledge.ttl').read_bytes()))
            self.assertEqual(validate(stage / 'data/load'), manifest)

    def test_manifest_and_snapshot_bounds_match_native_loader(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            files = package_files(folder, original)
            for role in original['counts']:
                manifest = copy.deepcopy(original)
                manifest['counts'][role] = 0
                manifest['dataset_id'] = dataset_identifier(manifest)
                with self.assertRaisesRegex(ValueError, 'manifest counts'):
                    validate_package(manifest, files)
            for count in (3, 257):
                manifest = copy.deepcopy(original)
                manifest['files'] = (manifest['files'] * 65)[:count]
                manifest['dataset_id'] = dataset_identifier(manifest)
                with self.assertRaisesRegex(ValueError, 'between 4 and 256'):
                    validate_package(manifest, files)
            for snapshot_version in (0, 10000000000, True):
                manifest = copy.deepcopy(original)
                modified_files = dict(files)
                replace_payload(manifest, modified_files, 'contexts',
                                lambda p: p['rows'][0].update(snapshot_version=snapshot_version))
                with self.assertRaisesRegex(ValueError, 'context snapshot version'):
                    validate_package(manifest, modified_files)

    def test_caller_pins_validated_package_and_requires_immutable_commit(self):
        rows, graph = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / 'data/load'
            manifest = write_package(folder, rows, pipeline.digest(graph_bytes(graph)))
            target = Path(temporary) / 'sql/install/10_load_github.sql'
            write_loader(folder, target)
            digest = pipeline.digest((folder / 'manifest.json').read_bytes())
            script = target.read_text(encoding='utf-8')
            self.assertEqual(script, loader_script(digest))
            self.assertIn("p_ref => 'PASTE_FULL_40_CHARACTER_COMMIT_SHA'", script)
            self.assertIn("p_expected_manifest_sha256 => '" + digest + "'", script)
            for invalid in ('dev', 'release', 'x' * 64, '0' * 63, None):
                with self.assertRaisesRegex(ValueError, 'SHA-256 manifest digest'):
                    loader_script(invalid)
            part = folder / manifest['files'][0]['path']
            part.write_bytes(part.read_bytes() + b' ')
            with self.assertRaisesRegex(ValueError, 'size/hash mismatch'):
                write_loader(folder, target)
            self.assertEqual(target.read_text(encoding='utf-8'), script)


if __name__ == '__main__':
    unittest.main()
