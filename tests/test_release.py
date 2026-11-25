"""Check the actual distribution, especially content provenance and file separation."""
import hashlib
import json
import re
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from rdflib import Graph, URIRef
from kcv import pipeline as p
from scripts.build_release import build, validate, distribution_metadata, compare_accepted_package
from scripts import build_release_sql
from scripts import build_database_installers as migrations


def decoded_clob(text, variable):
    """Decode actual emitted literal chunks independently of the SQL generator."""
    expressions=re.findall(r'\b'+variable+r'\s*:=\s*'+variable+
        r"\s*\|\|\s*TO_CLOB\(((?:'(?:''|[^'])*'|\s*\|\|\s*CHR\(38\)\s*\|\|\s*)+)\);",text,re.S)
    result=[]
    for expression in expressions:
        result.extend('&' if token=='CHR(38)' else token[1:-1].replace("''", "'")
                      for token in re.findall(r"'(?:''|[^'])*'|CHR\(38\)",expression))
    return ''.join(result)


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
                         'sql/install/20_upgrade_apex.sql','VERSION','release-provenance.json',
                         'sql/install/00_complete_v1_optional.sql',
                         'apex/export-validation.json','db/manifest.json',
                         'sql/install/schema-parts/manifest.json','sql/recovery/manifest.json',
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
        for path in self.folder.rglob('*.md'):
            self.assertNotIn('<copy>',path.read_text(encoding='utf-8'),str(path))
            self.assertNotIn('</copy>',path.read_text(encoding='utf-8'),str(path))
        for excluded in ('sql/admin/09_create_dev_schema.sql','sql/admin/10_create_dev_workspace.sql',
                         'sql/schema/01_objects.sql','sql/extensions/01_scenario_objects.sql'):
            self.assertNotIn(excluded,names)

    def test_release_records_exact_candidate_provenance_without_claiming_deployment(self):
        provenance=json.loads((self.folder/'release-provenance.json').read_text())
        self.assertEqual(provenance['product_version'],(self.folder/'VERSION').read_text().strip())
        self.assertEqual(provenance['distribution_status'],'unpromoted_candidate')
        self.assertRegex(provenance['source']['commit'],r'^[a-f0-9]{40}$')
        self.assertIsInstance(provenance['source']['dirty'],bool)
        self.assertFalse(provenance['acceptance']['package_generation_is_deployment_acceptance'])
        self.assertFalse(provenance['source']['ignored_private_work_included'])
        for key,path in [('application_export_sha256','apex/kcv-explorer.sql'),
                         ('schema_manifest_sha256','db/manifest.json'),
                         ('dataset_manifest_sha256','data/load/manifest.json')]:
            self.assertEqual(provenance[key],hashlib.sha256((self.folder/path).read_bytes()).hexdigest())

    def test_release_has_complete_ordered_parts_and_guarded_runtime_targets(self):
        manifest=json.loads((self.folder/'db/manifest.json').read_text())
        parts=json.loads((self.folder/'sql/install/schema-parts/manifest.json').read_text())
        self.assertEqual(parts['ready_checkpoint'],manifest['migrations'][-1]['id'])
        for route in ('fresh','upgrade'):
            records=parts['routes'][route]
            self.assertEqual([r['ordinal'] for r in records],list(range(1,len(records)+1)))
            steps=[step for row in records for step in row['steps']]
            expected=[m['id'] for m in manifest['migrations'] if route=='fresh' or m['group']=='feature']
            self.assertEqual([step for step in steps if step in expected],expected)
            self.assertEqual(steps[0],'bootstrap')
            self.assertEqual(steps[-1],'final-schema-verification')
            if route=='upgrade':self.assertIn('verified-baseline-gate',steps)
            for row in records:
                sql=(self.folder/'sql/install/schema-parts'/row['path']).read_text()
                self.assertEqual(hashlib.sha256(sql.encode()).hexdigest(),row['sha256'])
                self.assertIn(row['success_marker'],sql)
                self.assertNotIn('&',sql)
                self.assertTrue(sql.rstrip().endswith('END;\n/'))
        recovery=json.loads((self.folder/'sql/recovery/manifest.json').read_text())
        self.assertEqual([r['migration_id'] for r in recovery['steps']],[m['id'] for m in manifest['migrations']])
        for mode in ('install','upgrade'):
            sql=(self.folder/f'sql/install/20_{mode}_apex.sql').read_text()
            header=sql.split('\nDECLARE',1)[0]
            self.assertIn('Run Statement once',header)
            self.assertIn('excluding the final slash',header)
            self.assertNotIn('Run Script',header)
            for bind in (':KCV_SCHEMA',':KCV_WORKSPACE',':KCV_APP_ALIAS'):
                self.assertIn(bind,sql)
            self.assertIn(parts['ready_checkpoint'],sql)
        self.assertIn(':KCV_APPLICATION_ID',(self.folder/'sql/install/20_upgrade_apex.sql').read_text())

    def test_release_learning_routes_include_expanded_casey_without_maintainer_steps(self):
        readme = (self.folder / 'README.md').read_text(encoding='utf-8')
        for route in ['labs/my-contexts/my-contexts.md',
                      'labs/understand-collection/understand-collection.md',
                      'docs/fresh-serverless-deployment.md','docs/migrate-to-v2.md']:
            self.assertIn(route, readme)
            self.assertTrue((self.folder / route).is_file())
        anchor = 'docs/ui-walkthrough.md#explore-the-expanded-research-with-casey'
        self.assertIn(anchor, readme)
        walkthrough = (self.folder / 'docs/ui-walkthrough.md').read_text(encoding='utf-8')
        self.assertIn('## Explore the expanded research with Casey', walkthrough)
        self.assertIn('S10',walkthrough)
        self.assertIn('qualification',walkthrough)
        paths=(self.folder/'docs/learning-paths.md').read_text(encoding='utf-8')
        self.assertIn('../labs/explore-evidence/explore-evidence.md',paths)
        self.assertTrue((self.folder/'labs/explore-evidence/explore-evidence.md').is_file())
        load = (self.folder / 'labs/load-knowledge/load-knowledge.md').read_text(encoding='utf-8')
        self.assertIn('full commit SHA', load)
        self.assertIn('matching manifest hash',load)
        self.assertIn('docs/github-dataset-load.md#choose-a-published-version',load)
        self.assertIn('KCV_GROUNDED_TEAM',load)
        self.assertIn('Do not rerun raw',load)
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
            # Non-Git rejection fixture only: no package/receipt is created.
            with patch('scripts.build_release.ROOT', root), \
                 patch('scripts.build_release.source_snapshot', return_value={'fixture_only':True}):
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
        # The release intentionally omits the raw all-in-one CREATE script.
        # Verify its real executable spec/body survived the ordered SQL path.
        self.assertFalse((self.folder/'sql/schema/06_dataset_import.sql').exists())
        self.assertNotIn('install sql/schema/06_dataset_import.sql first', caller)
        self.assertIn('ordered v2 schema installation or migration', caller)
        self.assertIn('sql/install/02_verify_schema.sql', caller)
        schema=p.read(self.folder/'db/manifest.json')
        parts=p.read(self.folder/'sql/install/schema-parts/manifest.json')['routes']['fresh']
        expected={migrations.program_identity(unit):unit.strip() for unit in
                  migrations.sql_units((p.ROOT/'sql/schema/06_dataset_import.sql').read_text())
                  if migrations.program_identity(unit)}
        found={}
        for step in schema['migrations']:
            if step.get('source_path')!='sql/schema/06_dataset_import.sql':continue
            row=next(row for row in parts if step['id'] in row['steps'])
            sql=(self.folder/'sql/install/schema-parts'/row['path']).read_text()
            decoded=[decoded_clob(block,'l_step') for block in sql.split(' EXECUTE IMMEDIATE l_step;')[:-1]]
            wrapper=decoded[row['steps'].index(step['id'])]
            actual=decoded_clob(wrapper,'l_sql')
            identity=migrations.program_identity(actual)
            if identity:
                self.assertEqual(actual,expected[identity])
                self.assertEqual(hashlib.sha256((actual+'\n').encode()).hexdigest(),step['payload_sha256'])
                found[identity]=actual
        self.assertEqual(set(found),{('KCV_DATASET','PACKAGE'),('KCV_DATASET','PACKAGE BODY')})

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


class ReleasePackagingGuardTests(unittest.TestCase):
    def test_publication_requires_clean_source_and_both_accepted_routes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            path=root/'db/verification/release-v2-paths-validation.json'
            path.parent.mkdir(parents=True)
            accepted={'product_version':'2.0.0','status':'passed','pending_checks':[],
                      'clean_installation':{'status':'passed'},'migration':{'status':'passed'}}
            snapshot={'dirty':False,'branch':'dev','commit':'a'*40}
            path.write_text(json.dumps(accepted),encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'clean committed source'):
                distribution_metadata(root,{'dirty':True},'2.0.0',True)
            for change in ({'branch':'release'},{'commit':'short'}):
                with self.assertRaisesRegex(ValueError,'committed dev source'):
                    distribution_metadata(root,{**snapshot,**change},'2.0.0',True)
            result=distribution_metadata(root,snapshot,'2.0.0',True)
            self.assertEqual(result['distribution_status'],'prepared_for_publication')
            self.assertEqual(result['release_label'],'2.0.0')
            self.assertNotIn('candidate_label',result)
            self.assertFalse(result['publication']['push_performed'])
            self.assertFalse(result['publication']['tag_created'])
            self.assertEqual(result['publication']['acceptance_record_sha256'],
                             hashlib.sha256(path.read_bytes()).hexdigest())
            for change in ({'product_version':'2.1.0'}, {'pending_checks':['browser']},
                           {'migration':{'status':'pending'}},
                           {'clean_installation':{'status':'passed','pending_checks':['reopening']}}):
                path.write_text(json.dumps({**accepted,**change}),encoding='utf-8')
                with self.assertRaisesRegex(ValueError,'clean and migration acceptance'):
                    distribution_metadata(root,snapshot,'2.0.0',True)

    def test_publication_comparison_rejects_runtime_changes_and_preserves_history(self):
        with tempfile.TemporaryDirectory() as temp:
            stage=Path(temp)
            caller='sql/install/10_load_github.sql'
            old_header=b'-- KCV_LAB: install sql/schema/06_dataset_import.sql first. Run Script (F5).\n'
            from kcv.github_dataset import loader_script
            new_caller=loader_script('a'*64).encode()
            marker=b'-- Replace the commit placeholder'
            old_caller=old_header+marker+new_caller.split(marker,1)[1]
            payload={'VERSION':b'2.0.0\n','sql/install/schema-parts/fresh.sql':b'BEGIN NULL; END;\n/',
                     'db/verification/history.json':b'{"status":"historical"}',
                     'README.md':b'Candidate docs', caller:old_caller}
            manifest={'product_version':'2.0.0','files':[{'path':n,'sha256':hashlib.sha256(b).hexdigest()}
                                                       for n,b in payload.items()]}
            manifest_bytes=json.dumps(manifest).encode()
            for name,raw in payload.items():
                file=stage/name; file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(raw)
            (stage/caller).write_bytes(new_caller)
            (stage/'README.md').write_text('Version 2.0.0 distribution')
            def git_result(args,**kwargs):
                if 'ls-tree' in args:
                    blobs={**payload,'release-manifest.json':manifest_bytes}
                    tree=b''.join(b'100644 blob '+hashlib.sha1(f'blob {len(raw)}\0'.encode()+raw).hexdigest().encode()
                                  +b'\t'+name.encode()+b'\0' for name,raw in blobs.items())
                    return SimpleNamespace(stdout=tree)
                path=args[-1].split(':',1)[1]
                return SimpleNamespace(stdout=manifest_bytes if path=='release-manifest.json' else payload[path])
            with patch('scripts.build_release.subprocess.run',side_effect=git_result):
                result=compare_accepted_package(stage,stage,'b'*40)
                self.assertEqual(result['exact_header_only_changes'],[caller])
                self.assertEqual(result['documentation_changes'],['README.md'])
                for name in ('sql/install/schema-parts/fresh.sql','db/verification/history.json',caller):
                    original=(stage/name).read_bytes()
                    (stage/name).write_bytes(original+b'changed')
                    with self.assertRaisesRegex(ValueError,'Runtime differs'):
                        compare_accepted_package(stage,stage,'b'*40)
                    (stage/name).write_bytes(original)
                (stage/'unexpected.json').write_text('{}')
                with self.assertRaisesRegex(ValueError,'added or removed'):
                    compare_accepted_package(stage,stage,'b'*40)
                (stage/'unexpected.json').unlink()
                saved=payload['db/verification/history.json']
                payload['db/verification/history.json']=b'{"status":"changed without manifest"}'
                with self.assertRaisesRegex(ValueError,'manifest hash differs'):
                    compare_accepted_package(stage,stage,'b'*40)
                payload['db/verification/history.json']=saved
                payload['unlisted.json']=b'{}'
                with self.assertRaisesRegex(ValueError,'inventory differs'):
                    compare_accepted_package(stage,stage,'b'*40)
                del payload['unlisted.json']
                manifest['files'].append(manifest['files'][0])
                manifest_bytes=json.dumps(manifest).encode()
                with self.assertRaisesRegex(ValueError,'Duplicate paths'):
                    compare_accepted_package(stage,stage,'b'*40)

    def test_missing_required_document_is_a_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'README.md').write_text('[Required setup](docs/setup.md)')
            with self.assertRaisesRegex(ValueError,'missing docs/setup.md'):
                validate(root)
            self.assertEqual((root/'README.md').read_text(),'[Required setup](docs/setup.md)')

    def test_parts_do_not_split_an_atomic_plsql_step(self):
        steps=[('one',"BEGIN NULL;END;"),('large',"BEGIN NULL; --"+'x'*200+'\nEND;'),
               ('three',"BEGIN DBMS_OUTPUT.PUT_LINE('a/b');END;")]
        groups=build_release_sql.group_steps(steps,target_bytes=170)
        self.assertEqual([item for group in groups for item in group],steps)
        self.assertTrue(any(group==[steps[1]] for group in groups))

    def test_release_links_cannot_escape_package(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'package';root.mkdir()
            (Path(temp)/'outside.md').write_text('not a release document')
            (root/'README.md').write_text('[setup](../outside.md)')
            with self.assertRaisesRegex(ValueError,'leaves release tree'):
                validate(root)


if __name__ == '__main__': unittest.main()
