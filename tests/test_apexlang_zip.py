"""Archive contracts, independent of native compiler/browser acceptance."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from scripts import build_apexlang_zip as packaging


class ApexlangZipTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'fixture-app'
        self.output = self.root.parent / 'fixture.zip'
        self.files = {
            'application.apx': b'app KCV-EXPLORER (\n name: Fixture\n)\n',
            '.apex/apexlang.json': b'{"mmdVersion":"26.1.0+3102"}\n',
            'deployments/default.json': b'{"app":{"id":126}}\n',
            'pages/p00001-home.apx': b'page 1 ( name: Home )\n',
            'supporting-objects/supporting-objects.apx': b'supportingObject ( advanced { includeInAppExport: true } )\n',
            'shared-components/static-files.apx': b'file "explorer.js" (\n mimeType: application/javascript\n)\n',
            'shared-components/static-files/explorer.js': b'"use strict";\nconsole.log("fixture only");\n',
        }
        for route, kind in (('install', 'installScript'), ('upgrade', 'upgradeScript')):
            self.files[f'supporting-objects/{route}-scripts.apx'] = (
                f'{kind} {route}-001-bootstrap (\n execution {{ sequence: 10 }}\n'
                ' script { contentFile: step.sql }\n)\n').encode()
            self.files[f'supporting-objects/{route}-scripts/step.sql'] = (
                "BEGIN DBMS_OUTPUT.PUT_LINE('quoted '' & text'); END;\n/").encode()
        self.save()

    def save(self):
        for name, data in self.files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    def candidate(self):
        directory = self.root.parent / 'canonical'
        directory.mkdir()
        manifest = {'routes': {}}
        for route in ('install', 'upgrade'):
            name = f'{route}.sql'
            content = self.files[f'supporting-objects/{route}-scripts/step.sql'] + b'\n'
            (directory / name).write_bytes(content)
            manifest['routes'][route] = [{'ordinal': 1, 'step_id': 'bootstrap', 'sequence': 10,
                                         'path': name, 'sha256': packaging.digest(content)}]
        (directory / 'manifest.json').write_text(json.dumps(manifest))
        return directory

    def test_deterministic_native_layout_and_every_byte_survive_zip(self):
        report = packaging.build(self.root, self.output,
                                 expected_assets=self.root / 'shared-components/static-files',
                                 canonical_candidate=self.candidate())
        self.assertEqual(report['archive_sha256'], hashlib.sha256(self.output.read_bytes()).hexdigest())
        expected_files = self.files
        self.assertEqual(report['entry_count'], len(expected_files))
        self.assertEqual(report['mmd_version'], '26.1.0+3102')
        self.assertEqual(report['archive_root'], '')
        self.assertEqual(report['layout'], 'native-browser-flat-root')
        self.assertTrue(report['canonical_script_roundtrip_checked'])
        self.assertTrue(report['maintained_assets_checked'])
        self.assertEqual(report['native_zip_validation'], 'pending')
        self.assertEqual(report['browser_import'], 'pending')
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertIn('application.apx', archive.namelist())
            self.assertNotIn('fixture-app/application.apx', archive.namelist())
            self.assertEqual(set(archive.namelist()), set(expected_files))
            for name, expected in expected_files.items():
                self.assertEqual(archive.read(name), expected)
        self.assertEqual(packaging.archive_bytes(expected_files), self.output.read_bytes())
        self.assertEqual(report['omitted_deployment_files'], [])
        self.assertTrue(report['includes_deployment_metadata'])
        self.assertFalse(report['includes_private_deployment_metadata'])
        self.assertEqual(report['deployment']['source_application_id'], 126)
        self.assertFalse(report['deployment']['metadata_normalized'])
        self.assertTrue(report['native_file_bytes_preserved'])

    def test_portable_metadata_retains_only_native_app_id_and_private_mode_is_explicit(self):
        data = json.dumps({'app': {'id': 126, 'databaseSession': {'parsingSchema': 'PRIVATE_SCHEMA'},
                                  'sessionStateProtection': {'checksumSalt': 'PRIVATE_SALT'},
                                  'proxy': {'proxyServer': 'https://private.invalid'}},
                           'workspace': {'name': 'PRIVATE_WORKSPACE'}}).encode()
        (self.root / 'deployments/default.json').write_bytes(data)
        (self.root / 'deployments/other.json').write_bytes(b'{"private":"other settings"}')
        report = packaging.build(self.root, self.output)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(json.loads(archive.read('deployments/default.json')), {'app': {'id': 126}})
            self.assertNotIn('deployments/other.json', archive.namelist())
            self.assertNotIn(b'PRIVATE_', b''.join(archive.read(name) for name in archive.namelist()))
            for name, original in self.files.items():
                if not name.startswith('deployments/'):
                    self.assertEqual(archive.read(name), original)
        self.assertTrue(report['deployment']['metadata_normalized'])
        self.assertFalse(report['native_file_bytes_preserved'])
        self.assertTrue(report['native_component_bytes_preserved'])
        private_output = self.root.parent / 'private.zip'
        report = packaging.build(self.root, private_output, include_deployments=True)
        self.assertTrue(report['includes_private_deployment_metadata'])
        with zipfile.ZipFile(private_output) as archive:
            self.assertEqual(archive.read('deployments/default.json'), data)
            self.assertIn('deployments/other.json', archive.namelist())

    def test_staging_alias_is_normalized_without_changing_any_other_export_bytes(self):
        original = (b'app KCV-CREDENTIAL-STAGING (\n name: Fixture\n'
                    b' description: KCV-CREDENTIAL-STAGING is a literal reference\n)\n')
        (self.root / 'application.apx').write_bytes(original)
        report = packaging.build(self.root, self.output, canonical_candidate=self.candidate())
        expected = original.replace(b'app KCV-CREDENTIAL-STAGING (', b'app KCV-EXPLORER (', 1)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.read('application.apx'), expected)
            for name, data in self.files.items():
                if name != 'application.apx':
                    self.assertEqual(archive.read(name), data)
        self.assertEqual((self.root / 'application.apx').read_bytes(), original)
        alias = report['application_alias']
        self.assertEqual(alias['source_alias'], 'KCV-CREDENTIAL-STAGING')
        self.assertEqual(alias['intended_alias'], 'KCV-EXPLORER')
        self.assertEqual(alias['source_sha256'], packaging.digest(original))
        self.assertEqual(alias['packaged_sha256'], packaging.digest(expected))
        self.assertTrue(alias['alias_normalized'])
        self.assertFalse(report['native_file_bytes_preserved'])
        self.assertFalse(report['native_component_bytes_preserved'])
        self.assertTrue(report['native_non_application_component_bytes_preserved'])
        self.assertTrue(report['canonical_script_roundtrip_checked'])
        self.assertEqual(report, packaging.build(self.root, self.output, canonical_candidate=self.root.parent/'canonical', check=True))

    def test_explicit_alias_and_unchanged_alias_have_auditable_identity(self):
        report = packaging.build(self.root, self.output, application_alias='OTHER-LEARNING-APP')
        self.assertEqual(report['application_alias']['intended_alias'], 'OTHER-LEARNING-APP')
        self.assertTrue(report['application_alias']['alias_normalized'])
        report = packaging.build(self.root, self.root.parent/'same.zip', application_alias='KCV-EXPLORER')
        self.assertFalse(report['application_alias']['alias_normalized'])
        self.assertTrue(report['native_component_bytes_preserved'])

    def test_alias_normalization_rejects_injection_and_unreviewed_native_forms(self):
        for alias in ('', 'bad alias', 'X\n)\npage 1 (', '../app', 'X'*256, None):
            with self.subTest(alias=alias), self.assertRaisesRegex(ValueError, 'reviewed application alias'):
                packaging.build(self.root, self.output, application_alias=alias)
        for declaration in (b'app "QUOTED ALIAS" (\n)\n', b'// comment\napp OTHER (\n)\n'):
            (self.root/'application.apx').write_bytes(declaration)
            with self.assertRaisesRegex(ValueError, 'Unsupported native application declaration'):
                packaging.build(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_portable_metadata_rejects_absent_ambiguous_or_invented_source_ids(self):
        path = self.root / 'deployments/default.json'
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'deployment file is missing'):
            packaging.build(self.root, self.output)
        for value in (None, 0, -1, True, 'auto', '126', 126.5):
            path.write_text(json.dumps({'app': {'id': value}}))
            with self.assertRaisesRegex(ValueError, 'positive integer'):
                packaging.build(self.root, self.output)
        for text in ('{}', '{"app":[]}', '[]'):
            path.write_text(text)
            with self.assertRaisesRegex(ValueError, 'positive integer'):
                packaging.build(self.root, self.output)
        path.write_text('{"app":{"id":126,"id":127}}')
        with self.assertRaisesRegex(ValueError, 'Duplicate key'):
            packaging.build(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_refuses_sql_exports_extra_top_level_files_and_missing_metadata(self):
        (self.root / '.apex/apexlang.json').unlink()
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            packaging.build(self.root, self.output)
        self.save()
        (self.root / 'f126.sql').write_text('begin null; end;\n/\n')
        with self.assertRaisesRegex(ValueError, 'Unexpected file'):
            packaging.build(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_static_assets_must_be_declared_present_and_exact(self):
        path = self.root / 'shared-components/static-files/explorer.js'
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'definitions and asset files differ'):
            packaging.build(self.root, self.output)
        self.save()
        expected = self.root.parent / 'maintained-assets'
        expected.mkdir()
        (expected / 'explorer.js').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'differ from the reviewed'):
            packaging.build(self.root, self.output, expected_assets=expected)
        with self.assertRaisesRegex(ValueError, 'directory is unavailable'):
            packaging.build(self.root, self.output, expected_assets=expected / 'missing')

    def test_native_quoted_paths_and_unquoted_asset_identifiers_are_both_preserved(self):
        self.files['shared-components/static-files.apx'] = (
            b'file explorer.js (\n mimeType: application/javascript\n)\n'
            b'file "attribution/LICENSE.txt" (\n mimeType: text/plain\n)\n')
        self.files['shared-components/static-files/attribution/LICENSE.txt'] = b'Fixture license bytes\n'
        self.save()
        report = packaging.build(self.root, self.output,
                                 expected_assets=self.root / 'shared-components/static-files')
        self.assertEqual(len(report['owned_static_assets']), 2)
        with zipfile.ZipFile(self.output) as archive:
            for name in report['owned_static_assets']:
                self.assertEqual(archive.read(name), self.files[name])

    def test_script_content_cannot_escape_or_be_missing_or_unreferenced(self):
        definition = self.root / 'supporting-objects/install-scripts.apx'
        definition.write_text(self.files['supporting-objects/install-scripts.apx'].decode().replace('step.sql', '../step.sql'))
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            packaging.build(self.root, self.output)
        self.save()
        (self.root / 'supporting-objects/install-scripts/extra.sql').write_text('BEGIN NULL; END;\n/')
        with self.assertRaisesRegex(ValueError, 'Unreferenced'):
            packaging.build(self.root, self.output)

    def test_native_roundtrip_must_match_canonical_order_names_and_sql(self):
        candidate = self.candidate()
        script = self.root / 'supporting-objects/install-scripts/step.sql'
        script.write_bytes(script.read_bytes().replace(b'quoted', b'changed'))
        with self.assertRaisesRegex(ValueError, 'differs from canonical'):
            packaging.build(self.root, self.output, canonical_candidate=candidate)
        self.assertFalse(self.output.exists())
        self.save()
        (candidate / 'install.sql').write_text('BEGIN NULL;END;\n/\n')
        with self.assertRaisesRegex(ValueError, 'Canonical candidate script was changed'):
            packaging.build(self.root, self.output, canonical_candidate=candidate)

    def test_existing_artifacts_are_never_overwritten_and_check_is_readonly(self):
        first = packaging.build(self.root, self.output)
        self.assertEqual(first, packaging.build(self.root, self.output, check=True))
        with self.assertRaises(FileExistsError):
            packaging.build(self.root, self.output)
        before = self.output.read_bytes()
        self.output.write_bytes(before + b'changed')
        with self.assertRaisesRegex(ValueError, 'stale'):
            packaging.build(self.root, self.output, check=True)
        self.assertEqual(self.output.read_bytes(), before + b'changed')

    def test_zip_cannot_be_created_inside_input_or_with_unsafe_root(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            packaging.build(self.root, self.root / 'recursive.zip')
        for name in ('..', '/absolute', 'a/b', 'a\\b'):
            with self.assertRaises(ValueError):
                packaging.archive_bytes(self.files, name)

    def test_rejects_default_native_zip_budgets_without_adjusting_runtime_limits(self):
        for files in ({'large.sql': b'x' * (packaging.ZIP_ENTRY_LIMIT + 1)},
                      {str(i): b'x' * (8 * 1024 * 1024) for i in range(4)},
                      {str(i): b'x' for i in range(packaging.ZIP_COUNT_LIMIT + 1)}):
            with self.assertRaisesRegex(ValueError, 'safety limit exceeded'):
                packaging.validate_default_zip_budget(files)


if __name__ == '__main__':
    unittest.main()
