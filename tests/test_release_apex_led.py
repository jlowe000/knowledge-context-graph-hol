"""Exercise native-package integrity and distinct v2.1 publication gates offline."""
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest

from scripts import build_release as release
from scripts import build_apexlang_zip as packaging


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def package_fixture():
    """Distribution/data tests only; never a native acceptance receipt."""
    return {'archive_bytes': packaging.archive_bytes({'fixture.txt': b'Not an application export.\n'}),
            'receipt_text': '{"fixture_only":true}\n', 'provenance': {'fixture_only': True}}


class SqlFirstDeliveryPackagingTests(unittest.TestCase):
    def test_v21_delivery_set_includes_both_forms_with_exact_contract_and_export(self):
        with tempfile.TemporaryDirectory() as folder:
            stage = Path(folder)
            installer = stage/'sql/install'
            outputs = release.build_sql_first_app_installers(installer, include_script_inputs=True)
            expected = {f'20_{name}_apex{suffix}.sql'
                        for name in ('install','upgrade') for suffix in ('','_script')}
            self.assertEqual({path.name for path in outputs}, expected)
            self.assertEqual({path.name for path in installer.iterdir()}, expected)
            inventory = release.runtime_inventory(stage)
            self.assertEqual(set(inventory), {'sql/install/'+name for name in expected})
            bound_hashes = {
                'install':'2fe0210090adc426261519ba84c1a40135a54d21262bd2c0fa554bfdfcf6aa13',
                'upgrade':'08980ad557fe336aeeaecc1ea1cdf2a72b724727f73436a65377c07b3dcdc57e'}
            for name in ('install','upgrade'):
                with self.subTest(mode=name):
                    bound = installer/f'20_{name}_apex.sql'
                    script = installer/f'20_{name}_apex_script.sql'
                    self.assertEqual(sha(bound.read_bytes()), bound_hashes[name])
                    bound_sql = bound.read_text(encoding='utf-8')
                    script_sql = script.read_text(encoding='utf-8')
                    start = 'DECLARE l_checkpoint_count NUMBER;'
                    end = ' APEX_APPLICATION_INSTALL.SET_WORKSPACE(l_workspace);'
                    self.assertEqual(bound_sql[bound_sql.index(start):bound_sql.index(end)],
                                     script_sql[script_sql.index(start):script_sql.index(end)])
                    native = ' APEX_APPLICATION_INSTALL.SET_AUTO_INSTALL_SUP_OBJ(FALSE);'
                    self.assertEqual(bound_sql[bound_sql.index(native):], script_sql[script_sql.index(native):])
                    outside_literals = re.sub(r"'(?:''|[^'])*'|--[^\n]*|/\*[\s\S]*?\*/", ' ', script_sql)
                    self.assertEqual(re.findall(r'(?<!:):[A-Za-z][A-Za-z0-9_]*', outside_literals), [])
                    self.assertIn('Run Script (F5)', script_sql)
                    self.assertIn('l_schema IS NULL OR l_workspace IS NULL OR l_alias IS NULL', script_sql)
                    self.assertLess(script_sql.index('Set all three nonsecret Run Script target inputs'),
                                    script_sql.index('KCV schema verification passed'))
                    self.assertIn("SYS_CONTEXT('USERENV','SESSION_USER')<>l_schema", script_sql)
                    self.assertTrue(script_sql.endswith('END;\n/\n'))
                    if name=='install':
                        self.assertLess(script_sql.index('Application alias already exists'),
                                        script_sql.index('GENERATE_APPLICATION_ID'))
                        self.assertNotIn('l_existing_app_id', script_sql)
                    else:
                        self.assertIn('l_existing_app_id NUMBER:=NULL;', script_sql)
                        self.assertIn('l_app_id:=l_existing_app_id;', script_sql)
                        self.assertIn('l_app_id IS NULL OR l_app_id<=0 OR l_app_id<>TRUNC(l_app_id)', script_sql)
                        self.assertIn('WHERE application_id=l_app_id AND workspace=l_workspace', script_sql)
                        self.assertIn('AND owner=l_schema AND UPPER(alias)=l_alias', script_sql)
                        self.assertNotIn('GENERATE_APPLICATION_ID', script_sql)

    def test_existing_delivery_selection_does_not_add_new_script_artifacts(self):
        with tempfile.TemporaryDirectory() as folder:
            installer = Path(folder)/'sql/install'
            outputs = release.build_sql_first_app_installers(installer)
            self.assertEqual({path.name for path in outputs},
                             {'20_install_apex.sql','20_upgrade_apex.sql'})
            self.assertEqual({path.name for path in installer.iterdir()},
                             {'20_install_apex.sql','20_upgrade_apex.sql'})


class ReviewedApexlangTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.canonical = self.root/'canonical'
        self.canonical.mkdir()
        self.archive = self.root/'reviewed.zip'
        self.receipt_path = self.root/'receipt.json'
        schema = {'migrations': [{'id': '2.1.0-fixture-ready'}]}
        (self.root/'db').mkdir()
        (self.root/'db/manifest.json').write_text(json.dumps(schema), encoding='utf-8')
        self.files = {
            'application.apx': b'app KCV-EXPLORER (\n name: Fixture\n version: 2.1.0-dev\n)\n',
            '.apex/apexlang.json': b'{"mmdVersion":"26.1.0+3102"}\n',
            'deployments/default.json': b'{"app":{"id":143}}\n',
            'supporting-objects/supporting-objects.apx': b'supportingObject ()\n',
            'shared-components/static-files.apx': b'file explorer.js (\n mimeType: application/javascript\n)\n',
            'shared-components/static-files/explorer.js': b'"use strict";\n',
        }
        canonical = {'product_version': '2.1.0', 'canonical_manifest_sha256': sha((self.root/'db/manifest.json').read_bytes()),
                     'ready_checkpoint': '2.1.0-fixture-ready', 'project_migrations': 1,
                     'transport': 'trusted-native-apex-builder', 'routes': {}}
        for route, kind in [('install', 'installScript'), ('upgrade', 'upgradeScript')]:
            self.files[f'supporting-objects/{route}-scripts.apx'] = (
                f'{kind} {route}-001-bootstrap (\n execution {{ sequence: 10 }}\n'
                ' script { contentFile: step.sql }\n)\n').encode()
            content = b"BEGIN DBMS_OUTPUT.PUT_LINE('fixture only'); END;\n/\n"
            self.files[f'supporting-objects/{route}-scripts/step.sql'] = content.rstrip(b'\n')
            (self.canonical/f'{route}.sql').write_bytes(content)
            canonical['routes'][route] = [{'ordinal': 1, 'step_id': 'bootstrap', 'sequence': 10,
                                           'path': f'{route}.sql', 'sha256': sha(content)}]
        (self.canonical/'manifest.json').write_text(json.dumps(canonical), encoding='utf-8')
        self.asset = self.root/'apex/application/shared-components/static-files/explorer.js'
        self.asset.parent.mkdir(parents=True)
        self.asset.write_bytes(self.files['shared-components/static-files/explorer.js'])
        self.receipt = {'format_version': 1, 'product_version': '2.1.0',
                        'application_source_sha256': release.application_source_hash(self.root),
                        'schema_manifest_sha256': canonical['canonical_manifest_sha256'],
                        'canonical_supporting_manifest_sha256': sha((self.canonical/'manifest.json').read_bytes()),
                        'native_export': {'status': 'passed', 'format': 'APEXLANG', 'apex_version': '26.1.6'},
                        'native_zip_validation': {'status': 'passed', 'apex_version': '26.1.6'},
                        'security_review': {'status': 'passed', 'private_deployment_metadata': False}}
        self.save()

    def save(self):
        raw = packaging.archive_bytes(self.files)
        self.archive.write_bytes(raw)
        self.receipt['archive_sha256'] = sha(raw)
        self.receipt['native_zip_validation']['archive_sha256'] = sha(raw)
        self.receipt_path.write_text(json.dumps(self.receipt), encoding='utf-8')

    def check(self):
        return release.reviewed_apexlang_package(self.root, '2.1.0', self.archive,
                                                self.receipt_path, self.canonical)

    def test_exact_native_archive_survives_text_normalization(self):
        checked = self.check()
        stage = self.root/'stage'
        target = stage/release.APEX_LED_ARCHIVE
        target.parent.mkdir(parents=True)
        target.write_bytes(checked['archive_bytes'])
        (stage/'README.md').write_bytes(b'one\r\ntwo\r\n')
        (stage/'sample.bin').write_bytes(b'\xff\r\n\x00')
        release.normalize_release_text(stage)
        self.assertEqual(target.read_bytes(), self.archive.read_bytes())
        self.assertEqual((stage/'sample.bin').read_bytes(), b'\xff\r\n\x00')
        self.assertEqual((stage/'README.md').read_bytes(), b'one\ntwo\n')
        self.assertTrue(checked['provenance']['canonical_script_roundtrip_checked'])
        self.assertTrue(checked['provenance']['maintained_assets_checked'])
        self.assertFalse(checked['provenance']['package_generation_is_deployment_acceptance'])
        self.assertFalse(checked['provenance']['source_id_is_target_binding'])
        self.assertEqual(checked['provenance']['application_declared_version'], '2.1.0-dev')

    def test_only_publication_requires_final_versions_in_both_native_artifacts(self):
        checked = self.check()  # A reviewed development label remains valid candidate input.
        stage = self.root/'publication'
        (stage/'apex').mkdir(parents=True)
        (stage/release.APEX_LED_ARCHIVE).write_bytes(checked['archive_bytes'])
        sql = stage/'apex/kcv-explorer.sql'
        sql.write_text("begin api(p_flow_version=>'2.1.0'); end;", encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'both native ZIP and SQL'):
            release.verify_publication_versions(stage, '2.1.0')
        self.files['application.apx'] = self.files['application.apx'].replace(b'2.1.0-dev', b'2.1.0')
        (stage/release.APEX_LED_ARCHIVE).write_bytes(packaging.archive_bytes(self.files))
        release.verify_publication_versions(stage, '2.1.0')
        sql.write_text("begin api(p_flow_version=>'2.0.0-dev'); end;", encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'both native ZIP and SQL'):
            release.verify_publication_versions(stage, '2.1.0')

    def test_missing_input_and_stale_provenance_are_actionable(self):
        with self.assertRaisesRegex(ValueError, '--apexlang-zip'):
            release.reviewed_apexlang_package(self.root, '2.1.0', None, None, None)
        for field in ('archive_sha256', 'application_source_sha256', 'schema_manifest_sha256',
                      'canonical_supporting_manifest_sha256'):
            original = self.receipt[field]
            self.receipt[field] = '0'*64
            self.receipt_path.write_text(json.dumps(self.receipt), encoding='utf-8')
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'receipt does not match'):
                self.check()
            self.receipt[field] = original
        self.receipt['native_zip_validation']['status'] = 'pending'
        self.save()
        with self.assertRaisesRegex(ValueError, 'receipt does not match'):
            self.check()

    def test_current_assets_and_canonical_scripts_are_checked_not_just_receipt_flags(self):
        key = 'shared-components/static-files/explorer.js'
        original = self.files[key]
        self.files[key] = b'changed runtime();\n'
        self.save()  # A matching ZIP hash alone is insufficient.
        with self.assertRaisesRegex(ValueError, 'assets differ'):
            self.check()
        self.files[key] = original
        self.files['supporting-objects/install-scripts/step.sql'] = b'BEGIN NULL; END;\n/'
        self.save()
        with self.assertRaisesRegex(ValueError, 'differs from canonical'):
            self.check()

    def test_private_metadata_staging_alias_and_unexpected_files_are_rejected(self):
        for key, payload, expected in [
            ('deployments/default.json', b'{"app":{"id":143,"schema":"PRIVATE"}}', 'minimal deployment'),
            ('deployments/private.json', b'{}', 'minimal deployment'),
            ('application.apx', b'app KCV-STAGING (\n)\n', 'KCV-EXPLORER alias'),
            ('work/private.json', b'{}', 'Unexpected'),
            ('pages/.env', b'fixture only', 'Unexpected native component'),
            ('.apex/apexlang.json', b'{"mmdVersion":"26.2.0+1"}', 'APEX 26.1')]:
            original = dict(self.files)
            self.files[key] = payload
            self.save()
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, expected):
                self.check()
            self.files = original

    def test_native_default_budgets_apply_before_extracting_content(self):
        from unittest.mock import patch
        with patch.object(packaging, 'ZIP_ENTRY_LIMIT', 20):
            with self.assertRaisesRegex(ValueError, 'safety limits'):
                self.check()

    def test_traversal_and_duplicate_entries_are_rejected(self):
        import io
        import warnings
        import zipfile
        for extra in ('../private.txt', 'application.apx'):
            stream = io.BytesIO()
            with warnings.catch_warnings(), zipfile.ZipFile(stream, 'w') as archive:
                warnings.simplefilter('ignore', UserWarning)
                for name, content in self.files.items():
                    archive.writestr(name, content)
                archive.writestr(extra, b'fixture only')
            raw = stream.getvalue()
            self.archive.write_bytes(raw)
            self.receipt['archive_sha256'] = sha(raw)
            self.receipt['native_zip_validation']['archive_sha256'] = sha(raw)
            self.receipt_path.write_text(json.dumps(self.receipt), encoding='utf-8')
            with self.subTest(extra=extra), self.assertRaisesRegex(ValueError, 'Unsafe|duplicate'):
                self.check()

    def test_matching_receipt_cannot_authorize_a_different_schema_checkpoint(self):
        path = self.canonical/'manifest.json'
        manifest = json.loads(path.read_text(encoding='utf-8'))
        manifest['ready_checkpoint'] = 'old-ready'
        path.write_text(json.dumps(manifest), encoding='utf-8')
        self.receipt['canonical_supporting_manifest_sha256'] = sha(path.read_bytes())
        self.save()
        with self.assertRaisesRegex(ValueError, 'current schema contract'):
            self.check()


class V21PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root/'stage'
        self.stage.mkdir()
        self.snapshot = {'dirty': False, 'branch': 'dev', 'commit': 'a'*40}
        names = [release.APEX_LED_ARCHIVE, release.APEX_LED_RECEIPT, 'db/manifest.json',
                 'apex/kcv-explorer.sql', 'apex/export-validation.json',
                 'sql/install/02_verify_schema.sql', 'sql/install/03_bind_deployment_owner.sql',
                 'sql/install/20_install_apex.sql', 'sql/install/20_upgrade_apex.sql',
                 'sql/install/20_install_apex_script.sql', 'sql/install/20_upgrade_apex_script.sql',
                 'db/verification/release-v2-paths-validation.json']
        for name in names:
            path = self.stage/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(('fixture '+name).encode())
        self.record = {'format_version': 1, 'product_version': '2.1.0', 'status': 'passed',
                       'pending_checks': [], 'publication_approved': True,
                       'accepted_runtime_files': release.runtime_inventory(self.stage), 'routes': {}}
        for route in release.V21_ROUTES:
            self.record['routes'][route] = {'status': 'passed', 'pending_checks': [],
                                          'artifacts': dict(self.record['accepted_runtime_files'])}
            if route.endswith('upgrade'):
                self.record['routes'][route]['from_product_version'] = '2.0.0'
            if route.startswith('sql_first_'):
                self.set_transport(route)
        self.save()

    def set_transport(self, route, *, script=False, substituted=False):
        operation = 'upgrade' if route.endswith('upgrade') else 'install'
        bound = f'sql/install/20_{operation}_apex.sql'
        optional = f'sql/install/20_{operation}_apex_script.sql'
        source, equivalent = (optional, bound) if script else (bound, optional)
        inventory = self.record['accepted_runtime_files']
        transport = {
            # Synthetic external-evidence digests exercise attestation shape,
            # not machine verification of private execution/proof artifacts.
            'status': 'passed', 'evidence_basis': 'reviewed_attestation',
            'execution_mode': 'Run Script' if substituted else 'Run Statement',
            'source_template_path': source, 'source_template_sha256': inventory[source],
            'executed_variant_sha256': 'e'*64 if substituted else inventory[source],
            'execution_evidence_sha256': 'f'*64, 'derivation': {'kind': 'unchanged'},
            'equivalent_templates': [{
                'path': equivalent, 'sha256': inventory[equivalent],
                'status': 'reviewed_equivalent_provenance', 'positive_installation_executed': False,
                'canonical_verifier_and_native_export_unchanged': True,
                'differences': 'input_declarations_and_fail_closed_guards_only',
                'proof_sha256': 'd'*64}]}
        if substituted:
            names = ['schema', 'workspace', 'alias']
            if operation == 'upgrade':names.append('application_id')
            transport['derivation'] = {
                'kind': 'designated_nonsecret_input_substitutions', 'input_names': names,
                'reverse_substitution_byte_identical': True,
                'canonical_verifier_and_native_export_unchanged': True, 'proof_sha256': 'c'*64}
        self.record['routes'][route]['application_installation'] = {'transport_acceptance': transport}
        return transport

    def save(self):
        path = self.root/release.V21_ACCEPTANCE
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.record), encoding='utf-8')

    def test_candidate_build_does_not_require_or_invent_acceptance(self):
        self.record['status'] = 'pending'
        self.record['publication_approved'] = False
        self.save()
        result = release.distribution_metadata(self.root, {'dirty': True}, '2.1.0')
        self.assertEqual(result, {'candidate_label': '2.1.0-dev', 'distribution_status': 'unpromoted_candidate'})
        with self.assertRaisesRegex(ValueError, 'four-route acceptance'):
            release.distribution_metadata(self.root, self.snapshot, '2.1.0', True)

    def test_four_distinct_routes_require_acceptance_and_exact_runtime(self):
        result = release.distribution_metadata(self.root, self.snapshot, '2.1.0', True)
        self.assertEqual(result['distribution_status'], 'prepared_for_publication')
        self.assertEqual(release.compare_v21_acceptance(self.root, self.stage)['comparison'], 'passed')
        for route in release.V21_ROUTES:
            self.record['routes'][route]['status'] = 'pending'
            self.save()
            with self.subTest(route=route), self.assertRaisesRegex(ValueError, 'four-route acceptance'):
                release.distribution_metadata(self.root, self.snapshot, '2.1.0', True)
            self.record['routes'][route]['status'] = 'passed'
        self.save()
        (self.stage/'README.md').write_text('New learner documentation', encoding='utf-8')
        release.compare_v21_acceptance(self.root, self.stage)
        history = self.stage/'db/verification/release-v2-paths-validation.json'
        history.write_bytes(history.read_bytes()+b'changed')
        with self.assertRaisesRegex(ValueError, 'runtime differs'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_route_receipt_cannot_omit_its_actual_install_artifact(self):
        self.record['routes']['sql_first_upgrade']['artifacts'].pop('sql/install/20_upgrade_apex.sql')
        self.save()
        with self.assertRaisesRegex(ValueError, 'exact source template: sql_first_upgrade'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_hash_inventory_alone_does_not_claim_any_transport_executed(self):
        self.record['routes']['sql_first_clean'].pop('application_installation')
        self.save()
        with self.assertRaisesRegex(ValueError, 'observed execution record'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_derived_fresh_and_final_upgrade_have_distinct_execution_and_provenance(self):
        # The observed clean run derived a bind template; the upgrade can use a
        # filled final F5 template. Neither receipt claims the other form ran.
        clean = self.set_transport('sql_first_clean', substituted=True)
        upgrade = self.set_transport('sql_first_upgrade', script=True, substituted=True)
        self.save()
        result = release.compare_v21_acceptance(self.root, self.stage)
        self.assertEqual(result['comparison'], 'passed')
        self.assertEqual(result['sql_first_transport_evidence'], 'reviewed_attestation')
        self.assertIn('external evidence files are not revalidated', result['scope'])
        self.assertTrue(clean['source_template_path'].endswith('/20_install_apex.sql'))
        self.assertTrue(upgrade['source_template_path'].endswith('/20_upgrade_apex_script.sql'))
        for transport in (clean, upgrade):
            self.assertFalse(transport['equivalent_templates'][0]['positive_installation_executed'])

    def test_derived_attestation_requires_exact_source_and_scoped_evidence_fields(self):
        changes = [
            ('source_template_sha256', '0'*64), ('executed_variant_sha256', None),
            ('execution_evidence_sha256', 'missing'), ('execution_mode', 'Run Statement'),
            ('source_template_path', 'sql/install/20_install_apex_script.sql'),
        ]
        for key, value in changes:
            with self.subTest(field=key):
                transport = self.set_transport('sql_first_upgrade', script=True, substituted=True)
                transport[key] = value
                self.save()
                with self.assertRaisesRegex(ValueError, 'transport acceptance'):
                    release.compare_v21_acceptance(self.root, self.stage)
        for key, value in [
            ('input_names', ['schema','workspace','alias']),
            ('input_names', ['schema','workspace','alias','application_id','private_key']),
            ('reverse_substitution_byte_identical', False),
            ('canonical_verifier_and_native_export_unchanged', False),
            ('proof_sha256', None), ('kind', 'arbitrary_edits'),
        ]:
            with self.subTest(proof=key, value=value):
                transport = self.set_transport('sql_first_upgrade', script=True, substituted=True)
                transport['derivation'][key] = value
                self.save()
                with self.assertRaisesRegex(ValueError, 'scoped nonsecret substitution attestation'):
                    release.compare_v21_acceptance(self.root, self.stage)

    def test_external_transport_evidence_cannot_claim_machine_verification(self):
        for basis in (None, 'machine_verified', 'native_execution_proved'):
            with self.subTest(basis=basis):
                transport = self.set_transport('sql_first_clean', substituted=True)
                transport['evidence_basis'] = basis
                self.save()
                with self.assertRaisesRegex(ValueError, 'external evidence as a reviewed attestation'):
                    release.compare_v21_acceptance(self.root, self.stage)

    def test_null_guard_success_cannot_be_recorded_as_positive_unchanged_template_execution(self):
        self.set_transport('sql_first_clean', script=True)
        self.save()
        with self.assertRaisesRegex(ValueError, 'unchanged NULL template'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_alternative_form_requires_scoped_equivalence_without_inventing_execution(self):
        for field, value in [
            ('sha256', '0'*64), ('positive_installation_executed', True),
            ('canonical_verifier_and_native_export_unchanged', False),
            ('differences', 'schema_or_export_changed'), ('proof_sha256', None),
        ]:
            with self.subTest(field=field):
                transport = self.set_transport('sql_first_clean', substituted=True)
                transport['equivalent_templates'][0][field] = value
                self.save()
                with self.assertRaisesRegex(ValueError, 'reviewed equivalence from positive execution'):
                    release.compare_v21_acceptance(self.root, self.stage)
        transport = self.set_transport('sql_first_clean', substituted=True)
        transport['equivalent_templates'] = []
        self.save()
        with self.assertRaisesRegex(ValueError, 'other packaged submission form'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_pending_public_record_remains_blocked_despite_recorded_native_progress(self):
        root = Path(__file__).resolve().parents[1]
        record = json.loads((root/release.V21_ACCEPTANCE).read_text(encoding='utf-8'))
        # Keep real, potentially extensive native progress, but do not bake
        # today's pending state into a test that would forbid later approval.
        record.update(status='pending', publication_approved=False, accepted_runtime_files={})
        self.record = record
        self.save()
        with self.assertRaisesRegex(ValueError, 'four-route acceptance'):
            release.distribution_metadata(self.root, self.snapshot, '2.1.0', True)

    def test_new_runtime_files_cannot_be_added_after_acceptance(self):
        (self.stage/'unreviewed.sql').write_text('BEGIN NULL; END;', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'runtime differs'):
            release.compare_v21_acceptance(self.root, self.stage)

    def test_published_v2_only_upgrade_and_clean_source_remain_required(self):
        self.record['routes']['apex_led_upgrade']['from_product_version'] = '1.0.0'
        self.save()
        with self.assertRaisesRegex(ValueError, 'four-route acceptance'):
            release.distribution_metadata(self.root, self.snapshot, '2.1.0', True)
        with self.assertRaisesRegex(ValueError, 'clean committed'):
            release.distribution_metadata(self.root, {'dirty': True}, '2.1.0', True)


if __name__ == '__main__':
    unittest.main()
