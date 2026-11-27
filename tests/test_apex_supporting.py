"""Supporting Objects packaging contracts; not native APEX installation tests."""
import json
import base64
import gzip
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from scripts import build_apex_supporting as supporting
from scripts import build_database_installers as migrations
from scripts.build_release_sql import installation_steps


def decoded_driver_steps(driver):
    pattern = (r" l_encoded:=TO_CLOB\(''\);\n"
               r"((?: l_encoded:=l_encoded\|\|TO_CLOB\('[A-Za-z0-9+/=]+'\);\n)+)"
               r" l_step:=decode_sql\(l_encoded,'([0-9a-f]{64})','([0-9a-f]{64})',(\d+),(\d+)\);")
    result = []
    for match in re.finditer(pattern, driver):
        encoded = ''.join(re.findall(r"TO_CLOB\('([A-Za-z0-9+/=]+)'\)", match[1]))
        zipped = base64.b64decode(encoded, validate=True)
        plain = gzip.decompress(zipped)
        if (supporting.digest(zipped) != match[2] or supporting.digest(plain) != match[3]
                or len(zipped) != int(match[4]) or len(plain) != int(match[5])):
            raise AssertionError('Driver transport bytes or pinned checksums differ')
        result.append(plain)
    return result


class SupportingPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'source'
        (self.root / 'db/payloads').mkdir(parents=True)
        self.manifest = {'format_version': 1, 'target_product_version': '2.0.0', 'migrations': []}
        for ordinal, group in enumerate(('baseline', 'feature', 'feature'), 1):
            mid = f'2.0.0-{ordinal:03d}-fixture'
            payload = f"BEGIN DBMS_OUTPUT.PUT_LINE('fixture {ordinal}: apostrophe '' and & and ```sql'); END;\n"
            verification = f" require(TRUE,'fixture {ordinal} physical postcondition');\n"
            item = {'id': mid, 'group': group, 'version': '2.0.0',
                    'payload': f'db/payloads/{mid}.sql',
                    'verification': f'db/payloads/{mid}.verify.sql',
                    'payload_sha256': migrations.sha(payload),
                    'verification_sha256': migrations.sha(verification),
                    'depends_on': [self.manifest['migrations'][-1]['id']] if ordinal > 1 else []}
            (self.root / item['payload']).write_text(payload, encoding='utf-8', newline='\n')
            (self.root / item['verification']).write_text(verification, encoding='utf-8', newline='\n')
            self.manifest['migrations'].append(item)
        self.save_manifest()

    def save_manifest(self):
        (self.root / 'db/manifest.json').write_text(json.dumps(self.manifest), encoding='utf-8', newline='\n')

    def test_native_definitions_preserve_exact_canonical_scripts_and_order(self):
        files = supporting.artifacts(self.root)
        metadata = json.loads(files['manifest.json'])
        apx = files['supporting-objects/supporting-objects.apx'].decode()
        self.assertEqual(metadata['apexlang_path'], 'supporting-objects/supporting-objects.apx')
        self.assertNotIn('supporting-object.apx', files)
        for route, canonical_route, kind in (('install', 'fresh', 'installScript'), ('upgrade', 'upgrade', 'upgradeScript')):
            expected = installation_steps(self.root, self.manifest, canonical_route)
            rows = metadata['routes'][route]
            self.assertEqual([row['step_id'] for row in rows], [name for name, _ in expected])
            # Resolve the actual native contentFile reference; canonical SQL can
            # contain triple backticks inside literals, so inline fences lose data.
            definitions = files[f'supporting-objects/{route}-scripts.apx'].decode()
            external = re.findall(r'contentFile: ([^\s]+)', definitions)
            self.assertEqual(len(external), len(rows))
            self.assertNotIn('content:', definitions)
            for ordinal, (row, (step_id, sql), filename) in enumerate(zip(rows, expected, external), 1):
                decoded = files[f'supporting-objects/{route}-scripts/{filename}'].decode()
                actual = files[row['path']].decode()
                self.assertEqual(actual, sql.strip() + '\n/\n')
                self.assertEqual(decoded, actual)
                self.assertEqual(row['ordinal'], ordinal)
                self.assertEqual(row['sequence'], ordinal * 10)
                self.assertEqual(row['sha256'], supporting.digest(files[row['path']]))
                self.assertEqual(row['bytes'], len(files[row['path']]))
                self.assertEqual(len(migrations.sql_units(actual)), 1)
                self.assertTrue(row['atomic'])
        self.assertIn('includeInAppExport: true', apx)
        self.assertNotIn('autoInstall', apx)
        self.assertNotIn('deinstall {', apx)
        # These are engine metadata semantics, not merely valid EBNF tokens:
        # support-component identifiers ARE their names; CLOB has no language tag.
        self.assertNotRegex(apx, r'(?m)^\s*name:(?!=)')
        self.assertTrue(apx.startswith('supportingObject (\n'))
        self.assertNotIn('installScript', apx)
        self.assertIn('installScript install-001-bootstrap (', files['supporting-objects/install-scripts.apx'].decode())
        self.assertIn('   createTable\n', apx)
        self.assertNotIn('   CREATE TABLE\n', apx)
        self.assertIn('validation kcv-owner-transport (', files['supporting-objects/validations.apx'].decode())
        native_files = metadata['native_supporting_files']
        self.assertEqual({row['path'] for row in native_files},
                         {path for path in files if path.startswith('supporting-objects/')})
        for row in native_files:
            self.assertEqual(row['sha256'], supporting.digest(files[row['path']]))

    def test_metadata_records_original_checksums_and_does_not_claim_native_pass(self):
        result = json.loads(supporting.artifacts(self.root)['manifest.json'])
        self.assertEqual(result['native_apex_execution'], 'not_validated')
        self.assertFalse(result['engine_export_generated'])
        self.assertFalse(result['route_detection_is_authorization'])
        rows = {row['step_id']: row for row in result['routes']['install']}
        for item in self.manifest['migrations']:
            row = rows[item['id']]
            self.assertEqual(row['migration']['depends_on'], item['depends_on'])
            self.assertEqual(row['migration']['payload_sha256'], item['payload_sha256'])
            self.assertEqual(row['receipt_sha256'], migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256']))

    def test_existing_owner_guards_and_readonly_detection_are_preserved(self):
        files = supporting.artifacts(self.root)
        bootstrap = files['scripts/install/001-bootstrap.sql'].decode()
        self.assertEqual(bootstrap, migrations.BOOTSTRAP.strip() + '\n/\n')
        self.assertIn("SYS_CONTEXT('USERENV','SESSION_USER')", supporting.OWNER_PRECHECK)
        self.assertIn("NOT IN ('ADMIN','SYS','SYSTEM')", supporting.OWNER_PRECHECK)
        self.assertRegex(supporting.UPGRADE_DETECTION, '^SELECT ')
        self.assertNotRegex(supporting.UPGRADE_DETECTION, r'(?i)\b(?:insert|update|delete|create|alter)\b')

    def test_rejects_changed_payload_or_bad_dependency_before_writing(self):
        output = Path(self.temp.name) / 'candidate'
        item = self.manifest['migrations'][0]
        (self.root / item['payload']).write_text('BEGIN NULL; END;\n', encoding='utf-8', newline='\n')
        with self.assertRaisesRegex(ValueError, 'Immutable migration hash mismatch'):
            supporting.build(output, self.root)
        self.assertFalse(output.exists())
        self.manifest['migrations'][0]['depends_on'] = [self.manifest['migrations'][-1]['id']]
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'must appear earlier'):
            supporting.artifacts(self.root)

    def test_deterministic_build_refuses_overwrite_and_check_detects_tampering(self):
        output = Path(self.temp.name) / 'candidate'
        first = supporting.build(output, self.root)
        self.assertEqual(first, supporting.build(output, self.root, check=True))
        with self.assertRaises(FileExistsError):
            supporting.build(output, self.root)
        path = output / first['routes']['install'][0]['path']
        original = path.read_bytes(); path.write_bytes(original + b'-- tampered\n')
        with self.assertRaisesRegex(ValueError, 'stale'):
            supporting.build(output, self.root, check=True)
        self.assertEqual(path.read_bytes(), original + b'-- tampered\n')

    def test_rejects_app_importers_split_steps_and_fence_escapes(self):
        for sql in ("BEGIN apex_application_install.set_application_id(100); END;",
                    "BEGIN wwv_flow_imp.import_begin; END;",
                    'BEGIN NULL; END;\n/\nBEGIN NULL; END;'):
            with self.assertRaises(ValueError):
                supporting.executable_script(sql)
        for text in ('BEGIN\n```\nEND;', "BEGIN x:='embedded ```sql';END;"):
            with self.assertRaisesRegex(ValueError, 'terminate'):
                supporting.fenced(text, 4)
        with self.assertRaisesRegex(ValueError, 'LF'):
            supporting.fenced('BEGIN\r\nNULL;\r\nEND;', 4)
        # Only the read-only native target getter is allowed, not setters/import.
        self.assertIn('GET_APPLICATION_ID', supporting.executable_script(
            'DECLARE n NUMBER;BEGIN n:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;END;'))

    def test_builder_transport_preserves_payloads_receipts_and_default_owner_route(self):
        owner_before = supporting.artifacts(self.root)
        original_wrapper = migrations.wrapper
        files = supporting.artifacts(self.root, transport='apex-builder')
        self.assertIs(migrations.wrapper, original_wrapper)
        self.assertEqual(owner_before, supporting.artifacts(self.root))
        metadata = json.loads(files['manifest.json'])
        self.assertEqual(metadata['transport'], 'trusted-native-apex-builder')
        self.assertTrue(metadata['one_failure_stop_driver_per_route'])
        self.assertFalse(metadata['ddl_is_transactional'])
        self.assertTrue(metadata['initial_v2_upgrade_requires_quiescent_maintenance_window'])
        self.assertEqual([row['migration']['id'] for row in metadata['canonical_steps']['install'] if 'migration' in row],
                         [item['id'] for item in self.manifest['migrations']])
        for route in ('install', 'upgrade'):
            self.assertEqual(len(metadata['routes'][route]), 1)
            driver = files[metadata['routes'][route][0]['path']].decode()
            previous = -1
            for row in metadata['canonical_steps'][route]:
                marker = f"KCV schema step {row['ordinal']}/{len(metadata['canonical_steps'][route])}: {row['step_id']}"
                location = driver.index(marker)
                self.assertGreater(location, previous);previous = location
                if 'migration' in row:
                    item = next(item for item in self.manifest['migrations'] if item['id'] == row['step_id'])
                    step = files[row['path']].decode()
                    original_payload = migrations.read(self.root / item['payload']).strip()
                    self.assertIn(migrations.clob_assignment('l_sql', original_payload), step)
                    self.assertEqual(row['receipt_sha256'], migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256']))
                    self.assertNotIn(supporting.OWNER_WRAPPER_GUARD, step)
                    self.assertIn(supporting.builder_guard(), step)
            self.assertIn('unlock_all(FALSE);RAISE;', driver)
            self.assertIn('ELSIF l_maintenance_changed THEN\n  BEGIN restore_maintenance;', driver)
            self.assertLess(driver.index('snapshot_maintenance;l_maintenance_changed:=TRUE;maintenance_on;idle;'),
                            driver.index('l_mutation_started:=TRUE;EXECUTE IMMEDIATE l_step;'))
            self.assertIn('release_on_commit=>FALSE', driver)
            self.assertIn('KCV_WRITE_ADMISSION:', driver)
            self.assertIn('Another installer/setup operation is active', driver)

    def test_builder_auth_and_maintenance_precede_any_canonical_execution(self):
        files = supporting.artifacts(self.root, transport='apex-builder')
        driver = files['drivers/install.sql'].decode()
        first_step = driver.index('KCV schema step 1/')
        prefix = driver[:first_step]
        self.assertIn("SYS_CONTEXT('APEX$SESSION','APP_ID')='4000'", prefix)
        self.assertIn('apex_authentication.is_authenticated', prefix)
        self.assertIn("':ADMIN:'", prefix)
        self.assertIn('APEX_APPLICATION_INSTALL.GET_APPLICATION_ID', prefix)
        self.assertIn('apex_workspace_schemas', prefix)
        self.assertLess(prefix.index('idle;\n SELECT COUNT(*)'), prefix.index('maintenance_on;idle;'))
        self.assertIn('Existing project objects need the reviewed upgrade', prefix)
        # Fresh driver compilation must not resolve nonexistent project tables.
        self.assertNotRegex(prefix, r'(?mi)^\s*(?:SELECT[^\n]*FROM|INSERT INTO|UPDATE)\s+kcv_')
        self.assertIn("EXECUTE IMMEDIATE 'INSERT INTO kcv_deploy_state", driver)
        self.assertIn('Bind and both maintenance flags commit together', driver)
        self.assertLess(prefix.index(' l_step:=decode_sql('), prefix.index(' allocate_setup;l_result:='))
        self.assertIn('free_transport_clob(l_encoded);', prefix)

    def test_compressed_native_driver_roundtrips_every_reviewed_step_in_order(self):
        files = supporting.artifacts(self.root, transport='apex-builder')
        for route, canonical_route in (('install', 'fresh'), ('upgrade', 'upgrade')):
            driver = files[f'drivers/{route}.sql'].decode()
            expected = []
            if route == 'upgrade':
                expected.append(migrations.installed_contract_gate(
                    self.root, self.manifest['migrations'], self.manifest['migrations'], effective_owner=True).strip())
            expected.append(supporting.TRANSPORT_READINESS_SQL)
            expected.extend(sql.strip() for _, sql in supporting.builder_steps(self.root, self.manifest, canonical_route))
            decoded = decoded_driver_steps(driver)
            self.assertEqual(decoded, [sql.encode('utf-8') for sql in expected])
            self.assertEqual(len(decoded), driver.count(' l_step:=decode_sql('))
            self.assertIn(supporting.TRANSPORT_DECODER, driver)
            self.assertLess(driver.index('Compressed SHA256 differs'), driver.index('l_plain:=UTL_COMPRESS.LZ_UNCOMPRESS'))
            self.assertIn("NLS_CHARSET_ID('AL32UTF8')", driver)
            self.assertIn('SQL UTF8 roundtrip differs', driver)

    def test_gzip_transport_is_deterministic_bounded_and_unicode_lossless(self):
        sql = "BEGIN NULL; END; -- α café 東京 😀 & ```sql\n" * 1200
        metadata, encoded = supporting.transport_payload(sql)
        self.assertEqual((metadata, encoded), supporting.transport_payload(sql))
        data = base64.b64decode(encoded, validate=True)
        self.assertEqual(data[4:8], b'\0' * 4)
        self.assertEqual(data[9], 255)
        self.assertEqual(gzip.decompress(data), sql.encode('utf-8'))
        with self.assertRaisesRegex(ValueError, 'bounded'):
            supporting.transport_payload('x' * (supporting.TRANSPORT_MAX_SQL_BYTES + 1))

    def test_builder_guard_shape_failure_restores_canonical_renderer(self):
        original = migrations.wrapper
        def unexpected(root, item, effective_owner=False):
            return 'BEGIN NULL; END;'
        migrations.wrapper = unexpected
        try:
            with self.assertRaisesRegex(ValueError, 'guard shape changed'):
                supporting.builder_steps(self.root, self.manifest, 'fresh')
            self.assertIs(migrations.wrapper, unexpected)
        finally:
            migrations.wrapper = original

    def test_fresh_builder_executes_every_historical_payload_without_upgrade_branches(self):
        # The later migration supersedes an earlier one. A clean install must
        # still execute both exact payloads and record both immutable receipts.
        earlier, later = self.manifest['migrations'][1:]
        later['supersedes'] = [earlier['id']]
        self.save_manifest()
        with patch.object(migrations, 'retired_candidate_preflight',
                          side_effect=AssertionError('Fresh schema cannot have retired receipts')):
            with patch.object(migrations, 'worksheet_step',
                              side_effect=AssertionError('Fresh route cannot select a successor')):
                steps = supporting.builder_steps(self.root, self.manifest, 'fresh')
        self.assertEqual([name for name, _ in steps],
                         ['bootstrap'] + [item['id'] for item in self.manifest['migrations']]
                         + ['final-schema-verification'])
        driver = supporting.builder_driver(self.root, self.manifest, 'install', steps)
        decoded = decoded_driver_steps(driver)
        self.assertEqual(decoded[1:], [sql.strip().encode() for _, sql in steps])
        for item, (_, step) in zip(self.manifest['migrations'], steps[1:-1]):
            payload = migrations.read(self.root / item['payload']).strip()
            verification = migrations.effective_owner_verification(self.root, item).strip()
            receipt = migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256'])
            self.assertIn(migrations.clob_assignment('l_sql', payload), step)
            self.assertIn(verification, step)
            self.assertIn(receipt, step)
            self.assertIn("'RUNNING'", step)
            self.assertIn("SET phase='COMPLETE'", step)
            self.assertNotIn('l_replaced', step)
        self.assertEqual(steps[-1][1], migrations.verification_block(
            self.root, self.manifest['migrations'], effective_owner=True))
        first_execution = driver.index('l_mutation_started:=TRUE;EXECUTE IMMEDIATE l_step;')
        self.assertLess(driver.index("require(l_registry=0,'APEX_INSTALL_CONFLICT"), first_execution)
        self.assertLess(driver.index("require(l_n=0,'APEX_INSTALL_CONFLICT: Existing project objects"),
                        first_execution)

    def test_builder_upgrade_keeps_canonical_successor_and_retirement_selection(self):
        earlier, later = self.manifest['migrations'][1:]
        later['supersedes'] = [earlier['id']]
        self.save_manifest()
        preflight = 'DECLARE n NUMBER;BEGIN n:=1;END;'
        with patch.object(migrations, 'retired_candidate_preflight', return_value=preflight):
            with supporting.builder_rendering():
                expected = installation_steps(self.root, self.manifest, 'upgrade', effective_owner=True)
            expected[0] = ('bootstrap', expected[0][1].replace(
                supporting.OWNER_BOOTSTRAP_GUARD, supporting.builder_guard()))
            actual = supporting.builder_steps(self.root, self.manifest, 'upgrade')
        self.assertEqual(actual, expected)
        self.assertIn(('retired-candidate-preflight', preflight), actual)
        old_step = dict(actual)[earlier['id']]
        self.assertIn('l_replaced', old_step)
        self.assertIn(later['id'], old_step)
        with self.assertRaisesRegex(ValueError, 'Unknown Builder canonical route'):
            supporting.builder_steps(self.root, self.manifest, 'unrecognised')

    def test_contract_uses_exact_verified_prefix_and_static_dataset_getters(self):
        end = self.manifest['migrations'][1]['id']
        files = supporting.contract_artifacts(self.root, through_migration=end)
        metadata = json.loads(files['manifest.json'])
        self.assertEqual([item['id'] for item in metadata['verified_migrations']],
                         [item['id'] for item in self.manifest['migrations'][:2]])
        body = files['kcv_deploy_contract.body.sql'].decode()
        expected = migrations.verification_block(self.root, self.manifest['migrations'][:2], effective_owner=True)
        self.assertIn('PROCEDURE verify_schema IS\n' + expected.removeprefix('DECLARE\n'), body)
        spec = files['kcv_deploy_contract.spec.sql'].decode()
        self.assertIn('AUTHID DEFINER', spec)
        for name in ('target_version', 'target_checkpoint', 'dataset_ref', 'dataset_manifest_sha256'):
            self.assertIn('FUNCTION ' + name + ' RETURN VARCHAR2', spec)
        self.assertIn(supporting.APPROVED_DATASET_REF, body)
        self.assertIn(supporting.APPROVED_DATASET_MANIFEST_SHA256, body)
        self.assertTrue(metadata['full_standalone_verifier_still_required'])
        self.assertEqual(metadata['status'], 'candidate_not_frozen_or_executed')

    def test_contract_does_not_hash_future_payloads_or_its_own_body(self):
        end = self.manifest['migrations'][1]['id']
        before = supporting.contract_artifacts(self.root, through_migration=end)
        future = self.manifest['migrations'][2]
        future_payload = 'CREATE OR REPLACE PACKAGE BODY kcv_deploy_contract AS\nEND;\n'
        (self.root / future['payload']).write_text(future_payload, encoding='utf-8', newline='\n')
        future['payload_sha256'] = migrations.sha(future_payload)
        self.save_manifest()
        after = supporting.contract_artifacts(self.root, through_migration=end)
        self.assertEqual(before, after)
        with self.assertRaisesRegex(ValueError, 'own body'):
            supporting.contract_artifacts(self.root, through_migration=future['id'])

    def test_contract_rejects_unknown_prefix_and_unsafe_target_values(self):
        with self.assertRaisesRegex(ValueError, 'existing reviewed migration'):
            supporting.contract_artifacts(self.root, through_migration='missing')
        end = self.manifest['migrations'][-1]['id']
        with self.assertRaisesRegex(ValueError, 'version'):
            supporting.contract_artifacts(self.root, through_migration=end, target_version="2.0.0'; NULL;")
        with self.assertRaisesRegex(ValueError, 'checkpoint'):
            supporting.contract_artifacts(self.root, through_migration=end, target_checkpoint='../unreviewed')


class CurrentManifestSupportingTests(unittest.TestCase):
    def test_retired_index_guard_checks_all_receipts_and_current_objects_without_mutation(self):
        manifest = migrations.validate_manifest()
        sql = supporting.builder_retired_index_guard(supporting.ROOT, manifest)
        self.assertIsNotNone(sql)
        self.assertLess(sql.index('l_repair PLS_INTEGER:=0;'), sql.index('PROCEDURE require('))
        prefix = manifest['migrations'][:100]
        self.assertEqual(sql.count('Retirement prefix receipt differs:'), 100)
        self.assertEqual(sql.count("AND phase='COMPLETE' AND completed_at IS NOT NULL AND error_code IS NULL;"), 100)
        for item in prefix:
            receipt = migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256'])
            self.assertIn("AND payload_sha256='" + receipt + "' AND product_version='" + item['version'] + "'", sql)
        physical = {}
        for item in prefix:
            successors = migrations.successor_chain(item, prefix)
            target = successors[-1] if successors else item
            physical[target['id']] = target
        for mid, item in physical.items():
            text = migrations.effective_owner_verification(supporting.ROOT, item).strip()
            if mid.endswith('-ready'):
                self.assertNotIn(text, sql)
            else:
                self.assertIn(text, sql)
        self.assertIn(migrations.deployment_request_index_verification().strip(), sql)
        self.assertIn("AND phase='FAILED' AND error_code=-20301 AND completed_at IS NULL", sql)
        self.assertIn('Unexecuted retired migration has a receipt:', sql)
        self.assertIn('Retired migration appears in Liquibase history:', sql)
        self.assertIn('Retirement preflight cannot reconcile another incomplete active migration', sql)
        self.assertIn("AND phase<>'COMPLETE'", sql)
        self.assertIn('l_repair:=1;', sql)
        self.assertTrue(sql.endswith(':repair_required:=l_repair;\nEND;'))
        # Expected program text contains DML as data inside SQL string literals.
        # Only the verifier's executable text must remain read-only.
        executable = re.sub(r"'(?:[^']|'')*'", "''", sql)
        self.assertIsNone(re.search(r'(?mi)^\s*(?:INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|COMMIT)\b', executable),
                          'Retirement admission must not mutate the registry or schema')

    def test_retired_builder_preflight_runs_once_between_fence_and_full_gate(self):
        manifest = migrations.validate_manifest()
        steps = supporting.builder_steps(supporting.ROOT, manifest, 'upgrade')
        driver = supporting.builder_driver(supporting.ROOT, manifest, 'upgrade', steps)
        decoded = decoded_driver_steps(driver)
        preflight = next(sql.strip().encode() for mid, sql in steps if mid == 'retired-candidate-preflight')
        gate = migrations.installed_contract_gate(
            supporting.ROOT, [m for m in manifest['migrations'] if m['version'] == '2.0.0' or m['version'] == '1.0.0'],
            manifest['migrations'], effective_owner=True).strip().encode()
        guard = supporting.builder_retired_index_guard(supporting.ROOT, manifest).encode()
        self.assertEqual(decoded.count(preflight), 1)
        self.assertEqual(decoded.count(gate), 1)
        self.assertEqual(decoded.count(guard), 1)
        self.assertEqual(decoded[:3], [gate, supporting.TRANSPORT_READINESS_SQL.encode(), guard])
        self.assertEqual(decoded[3:], [sql.strip().encode() for _, sql in steps])
        self.assertEqual(driver.count('snapshot_maintenance;l_maintenance_changed:=TRUE;maintenance_on;idle;'), 1)
        normal_gate = driver.index('IF l_retired_repair=0 THEN verify_published_v2;END IF;')
        fence = driver.index('snapshot_maintenance;l_maintenance_changed:=TRUE;maintenance_on;idle;')
        preflight_start = driver.index(': retired-candidate-preflight')
        recovered_gate = driver.index('IF l_retired_repair=1 THEN verify_published_v2;END IF;')
        baseline = driver.index(': verified-baseline-gate')
        self.assertLess(normal_gate, fence)
        self.assertLess(fence, preflight_start)
        self.assertLess(preflight_start, recovered_gate)
        self.assertLess(recovered_gate, baseline)
        self.assertLess(driver.index('l_admission_locked:=TRUE;'), driver.index('USING OUT l_retired_repair;'))
        self.assertIn("Unknown or newer migration history must not be downgraded", driver[:normal_gate])
        fresh = supporting.builder_driver(supporting.ROOT, manifest, 'install',
                                          supporting.builder_steps(supporting.ROOT, manifest, 'fresh'))
        self.assertNotIn('USING OUT l_retired_repair;', fresh)
        self.assertIn("require(l_registry=0,'APEX_INSTALL_CONFLICT", fresh)

    def test_builder_retirement_refuses_an_unreviewed_failure_or_prefix(self):
        manifest = migrations.validate_manifest()
        original = migrations.retirement_records(supporting.ROOT)
        for field, value in (('applied_prefix_count', 99), ('error_code', -99999),
                             ('verification_sha256', '0' * 64)):
            records = json.loads(json.dumps(original))
            record = next(r for r in records if r['id'] == supporting.BUILDER_RETIRED_INDEX_AUDIT)
            if field == 'applied_prefix_count':
                record[field] = value
            elif field == 'error_code':
                record['entries'][0][field] = value
            else:
                record['entries'][0]['migration'][field] = value
            with patch.object(migrations, 'retirement_records', return_value=records):
                with self.assertRaisesRegex(ValueError, 'Builder retirement'):
                    supporting.builder_retired_index_guard(supporting.ROOT, manifest)

    def test_current_builder_drivers_fit_native_zip_entry_budget_and_decode_all_steps(self):
        files = supporting.artifacts(transport='apex-builder')
        metadata = json.loads(files['manifest.json'])
        for route, canonical_route in (('install', 'fresh'), ('upgrade', 'upgrade')):
            driver = files[f'drivers/{route}.sql']
            self.assertLess(len(driver), 10 * 1024 * 1024)
            decoded = decoded_driver_steps(driver.decode())
            expected = [sql.strip().encode() for _, sql in supporting.builder_steps(
                supporting.ROOT, migrations.validate_manifest(), canonical_route)]
            self.assertEqual(decoded[-len(expected):], expected)
            rows = metadata['canonical_steps'][route]
            self.assertEqual([row['transport']['sql_sha256'] for row in rows],
                             [supporting.digest(data) for data in expected])

    def test_real_manifest_completeness_and_large_atomic_steps(self):
        files = supporting.artifacts()
        packaged = json.loads(files['manifest.json'])
        current = migrations.validate_manifest()
        for route in ('install', 'upgrade'):
            actual = [row['migration']['id'] for row in packaged['routes'][route] if 'migration' in row]
            expected = [item['id'] for item in current['migrations'] if route == 'install' or item['group'] == 'feature']
            self.assertEqual(actual, expected)
        self.assertEqual(packaged['project_migrations'], len(current['migrations']))
        self.assertGreater(packaged['largest_atomic_script_bytes'], 1024 * 1024)
        self.assertFalse(any('20_install_apex' in path for path in files))


if __name__ == '__main__':
    unittest.main()
