"""Local artifact checks, not Oracle/Liquibase execution or native acceptance."""
import contextlib
import io
import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

from scripts import build_database_installers as migration

ROOT = Path(__file__).resolve().parents[1]


def decode_assignments(text):
    """Independent decoder for the limited generated CLOB literal expressions."""
    expressions = re.findall(r"TO_CLOB\(((?:'(?:''|[^'])*'|\s*\|\|\s*CHR\(38\)\s*\|\|\s*)+)\);", text, re.S)
    chunks = []
    for expr in expressions:
        tokens = re.findall(r"'(?:''|[^'])*'|CHR\(38\)", expr)
        chunks.append(''.join('&' if token == 'CHR(38)' else token[1:-1].replace("''", "'") for token in tokens))
    return ''.join(chunks)


class MigrationArtifactsTests(unittest.TestCase):
    def test_manifest_and_generated_outputs_are_current(self):
        with contextlib.redirect_stdout(io.StringIO()):
            migration.build(ROOT, check=True)

    def test_liquibase_keeps_plsql_units_intact(self):
        manifest = migration.validate_manifest(ROOT)
        seen = []
        for group in ('baseline', 'feature'):
            document = ET.parse(ROOT / 'db' / group / 'changelog.xml')
            for change in document.findall(f'{{{migration.NS}}}changeSet'):
                self.assertEqual(change.attrib['runInTransaction'], 'false')
                file = change.find(f'{{{migration.NS}}}sqlFile')
                self.assertEqual(file.attrib['splitStatements'], 'false')
                self.assertEqual(file.attrib['stripComments'], 'false')
                self.assertEqual(file.attrib['relativeToChangelogFile'], 'true')
                target = ROOT / 'db' / group / file.attrib['path']
                body = migration.read(target)
                self.assertTrue(body.rstrip().endswith('END;'))
                self.assertNotIn('\n/\n', body)
                if change.attrib['id'] != 'kcv-migration-registry-v1':
                    seen.append(change.attrib['id'])
        self.assertEqual(seen, [m['id'] for m in manifest['migrations']])

    def test_worksheet_runs_same_wrappers_and_stops_in_one_outer_block(self):
        manifest = migration.validate_manifest(ROOT)
        for name, group in [('00_install_schema.sql', None), ('01_upgrade_schema.sql', 'feature')]:
            text = migration.read(ROOT / 'sql/install' / name)
            self.assertEqual([line for line in text.splitlines() if line.strip() == '/'], ['/'])
            self.assertNotIn('&', text)
            steps = [decode_assignments(part) for part in text.split(' EXECUTE IMMEDIATE l_step;')[:-1]]
            self.assertEqual(steps[0], migration.BOOTSTRAP)
            expected = [migration.worksheet_step(ROOT, m, manifest['migrations']).strip() for m in manifest['migrations'] if not group or m['group'] == group]
            offset = (2 if group else 1) + bool(migration.retirement_records(ROOT))
            self.assertEqual(steps[offset:offset+len(expected)], expected)
            self.assertIn('KCV schema verification passed', steps[-1])

    def test_superseded_worksheet_step_requires_completed_matching_successor(self):
        items = migration.validate_manifest(ROOT)['migrations']
        old = next(m for m in items if m['id'] == '2.0.0-c2-005-kcv_access-package-body')
        latest = migration.successor_chain(old, items)[-1]
        text = migration.worksheet_step(ROOT, old, items)
        self.assertIn("AND phase='COMPLETE'", text)
        self.assertIn(migration.sha(latest['payload_sha256'] + ':' + latest['verification_sha256']), text)
        self.assertLess(text.index(migration.read(ROOT / latest['verification']).strip()), text.index('l_replaced:=TRUE'))
        self.assertLess(text.index(migration.receipt_check(old)), text.index('l_replaced:=TRUE'))
        self.assertIn('IF NOT l_replaced THEN', text)
        # No successor receipt (including FAILED/RUNNING) falls back to the
        # historical wrapper, whose exact physical check rejects partial work.
        old_encoded = text[text.rindex(' IF NOT l_replaced THEN'):]
        self.assertEqual(decode_assignments(old_encoded), migration.wrapper(ROOT, old).strip())

    def test_final_verifier_requires_latest_receipt_and_physical_source(self):
        items = migration.validate_manifest(ROOT)['migrations']
        old = next(m for m in items if m['id'] == '2.0.0-c2-005-kcv_access-package-body')
        latest = migration.successor_chain(old, items)[-1]
        text = migration.verification_block(ROOT, items)
        self.assertIn(migration.receipt_check(latest), text)
        self.assertIn(migration.receipt_check(old), text)
        self.assertIn(migration.read(ROOT / latest['verification']).strip(), text)
        self.assertNotIn(migration.read(ROOT / old['verification']).strip(), text)

    def test_upgrade_gate_checks_completed_successor_or_original_without_writes(self):
        items = migration.validate_manifest(ROOT)['migrations']
        old = next(m for m in items if m['id'] == '2.0.0-c2-005-kcv_access-package-body')
        latest = migration.successor_chain(old, items)[-1]
        text = migration.installed_contract_gate(ROOT, [old], items)
        latest_check = migration.read(ROOT / latest['verification']).strip()
        original_check = migration.read(ROOT / old['verification']).strip()
        self.assertIn("AND phase='COMPLETE'", text)
        self.assertIn(migration.sha(latest['payload_sha256'] + ':' + latest['verification_sha256']), text)
        self.assertLess(text.index(latest_check), text.index('l_replaced:=TRUE'))
        self.assertIn('IF NOT l_replaced THEN\n' + original_check, text)
        self.assertIn(migration.receipt_check(old), text)
        executable = re.sub(r"'(?:''|[^'])*'", "''", text)
        self.assertNotIn('EXECUTE IMMEDIATE', executable)
        self.assertNotIn('INSERT INTO', executable)
        self.assertNotIn('UPDATE kcv_schema_migrations', executable)

    def test_upgrade_bundle_uses_live_baseline_gate_not_future_only_verifier(self):
        items = migration.validate_manifest(ROOT)['migrations']
        baseline = [item for item in items if item['group'] == 'baseline']
        text = migration.read(ROOT / 'sql/install/01_upgrade_schema.sql')
        steps = [decode_assignments(part) for part in text.split(' EXECUTE IMMEDIATE l_step;')[:-1]]
        offset = 1 + bool(migration.retirement_records(ROOT))
        self.assertEqual(steps[offset], migration.installed_contract_gate(ROOT, baseline, items).strip())

    def test_supersession_does_not_change_historical_liquibase_sql(self):
        manifest = migration.validate_manifest(ROOT)
        for old in manifest['migrations']:
            if migration.successor_chain(old, manifest['migrations']):
                generated = migration.read(ROOT / f"db/generated/{old['id']}.sql")
                self.assertEqual(generated, migration.wrapper(ROOT, old))
                self.assertNotIn('l_replaced', generated)
                self.assertIn(migration.read(ROOT / old['verification']).strip(), generated)

    def test_liquibase_marks_only_verified_superseded_history(self):
        items = migration.validate_manifest(ROOT)['migrations']
        changes = {}
        for group in ('baseline', 'feature'):
            document = ET.parse(ROOT / 'db' / group / 'changelog.xml')
            changes.update({c.attrib['id']: c for c in document.findall(f'{{{migration.NS}}}changeSet')})
        for item in items:
            successors = migration.successor_chain(item, items)
            if not successors:
                continue
            change = changes[item['id']]
            pre = change.find(f'{{{migration.NS}}}preConditions')
            self.assertEqual(pre.attrib, {'onFail': 'MARK_RAN', 'onError': 'HALT'})
            check = pre.find(f'{{{migration.NS}}}sqlCheck')
            self.assertEqual(check.attrib['expectedResult'], '1')
            self.assertEqual(check.text, migration.liquibase_needs_historical_step(ROOT, item, items))
            self.assertLess(check.text.index(migration.receipt_check(item)), check.text.index('RETURN 0;'))
            self.assertIn(migration.read(ROOT / successors[-1]['verification']).strip(), check.text)
            executable = re.sub(r"'(?:''|[^'])*'", "''", check.text)
            self.assertNotIn('WHEN OTHERS', executable)

    def test_literal_roundtrip_preserves_untrusted_characters(self):
        body = "BEGIN\n text := 'O''Brien & \"quoted\" / Unicode — λ';\n END;" * 100
        encoded = migration.clob_assignment('l_step', body)
        self.assertNotIn('&', encoded)
        self.assertEqual(decode_assignments(encoded), body)

    def test_adoption_verifies_before_recording_any_receipt(self):
        manifest = migration.validate_manifest(ROOT)
        items = [m for m in manifest['migrations'] if m['group'] == 'baseline']
        text = migration.adoption(ROOT, items)
        steps = [decode_assignments(part) for part in text.split(' EXECUTE IMMEDIATE l_step;')[:-1]]
        self.assertEqual(len(steps), 3)
        self.assertIn('check_program(', steps[0])
        self.assertIn('check_table(', steps[0])
        self.assertNotIn('INSERT INTO kcv_schema_migrations', steps[0])
        self.assertEqual(steps[1], migration.BOOTSTRAP)
        self.assertNotIn('DATABASECHANGELOG', text)
        self.assertNotIn('2.0.0-c2-', steps[2])

    def test_failed_migration_requires_verification_not_blind_retry(self):
        item = migration.validate_manifest(ROOT)['migrations'][-1]
        run = migration.wrapper(ROOT, item)
        self.assertIn("require(l_phase='COMPLETE'", run)
        self.assertLess(run.index('USER_ERRORS'.lower()), run.index("SET phase='COMPLETE'"))
        recover = migration.recovery(ROOT, item)
        self.assertIn("phase IN ('FAILED','RUNNING')", recover)
        self.assertIn('DBMS_LOCK.REQUEST', recover)
        self.assertLess(recover.index('Connect as the intended project schema owner'), recover.index('DBMS_LOCK.ALLOCATE_UNIQUE'))
        self.assertRegex(recover, r"require\(l_n=0,'C[23] (?:API|project) compilation errors remain'\)")
        # Stored program source is compared as string data; it may itself use
        # dynamic SQL. The recovery block must not execute dynamic SQL.
        executable = re.sub(r"'(?:''|[^'])*'", "''", recover)
        self.assertNotIn('EXECUTE IMMEDIATE', executable)

    def test_all_previously_native_verified_wrappers_remain_byte_equivalent(self):
        for record_path in ('native-validation.json', 'c3-r1-validation.json', 'c3-r2-validation.json', 'c3-r3-validation.json'):
            path = ROOT / 'db/verification' / record_path
            if not path.exists():
                continue
            record = json.loads(migration.read(path))
            for name, expected in record.get('generated_wrapper_hashes', {}).items():
                self.assertEqual(migration.sha(migration.read(ROOT / 'db/generated' / name)), expected, name)

    def test_retired_candidate_preserves_applied_and_failed_artifacts(self):
        manifest = migration.validate_manifest(ROOT)
        active = {item['id'] for item in manifest['migrations']}
        for record in migration.retirement_records(ROOT):
            original = json.loads(migration.read(ROOT / record['original_manifest']))
            count = record['applied_prefix_count']
            self.assertEqual(manifest['migrations'][:count], original['migrations'][:count])
            self.assertEqual(len(record['applied_wrapper_hashes']), count + 1)
            for path, digest in record['applied_wrapper_hashes'].items():
                self.assertEqual(migration.sha(migration.read(ROOT / path)), digest)
            for entry in record['entries']:
                self.assertNotIn(entry['migration']['id'], active)
                for path, digest in entry['artifact_hashes'].items():
                    self.assertEqual(migration.sha(migration.read(ROOT / path)), digest)

    def test_retirement_guard_only_accepts_exact_failed_audit_or_absence(self):
        text = migration.retirement_guard(ROOT)
        if not migration.retirement_records(ROOT):
            self.skipTest('Historical fixture has no retired candidates')
        self.assertIn("phase='FAILED' AND error_code=-24344 AND completed_at IS NULL", text)
        self.assertIn('Retired migration appears in Liquibase history:', text)
        self.assertIn('Unexecuted retired migration has a receipt:', text)
        self.assertNotIn("phase='COMPLETE'", text)
        executable = re.sub(r"'(?:''|[^'])*'", "''", text)
        self.assertNotRegex(executable, r'(?i)\b(?:INSERT|UPDATE|DELETE|MERGE|COMMIT)\b')
        for query in re.findall(r"EXECUTE IMMEDIATE '([^']*)'", text):
            self.assertEqual(query, 'SELECT COUNT(*) FROM databasechangelog WHERE id=:retired_id')

    def test_failed_candidate_preflight_uses_new_wrappers_before_normal_gate(self):
        items = migration.validate_manifest(ROOT)['migrations']
        preflight = migration.retired_candidate_preflight(ROOT, items)
        if preflight is None:
            self.skipTest('Historical fixture has no retired candidates')
        self.assertIn("AND phase='FAILED';", preflight)
        self.assertLess(preflight.index('Retired migration audit differs'), preflight.index('IF l_n>0 THEN'))
        decoded = decode_assignments(preflight)
        for record in migration.retirement_records(ROOT):
            for mid in record['replacement_migrations']:
                step = next(item for item in items if item['id'] == mid)
                self.assertIn(migration.worksheet_step(ROOT, step, items).strip(), decoded)
            for entry in record['entries']:
                if entry['allowed_registry_state'] == 'ABSENT_OR_FAILED':
                    self.assertNotIn(migration.read(ROOT / entry['migration']['payload']).strip(), decoded)

    def test_replacement_and_final_verification_keep_retirement_guard(self):
        items = migration.validate_manifest(ROOT)['migrations']
        for record in migration.retirement_records(ROOT):
            for mid in (record['replacement_migrations'][0], record['replacement_migrations'][-1]):
                item = next(item for item in items if item['id'] == mid)
                self.assertIn(migration.retirement_guard(ROOT, [record['id']]), migration.wrapper(ROOT, item))
        self.assertIn(migration.retirement_guard(ROOT), migration.verification_block(ROOT, items))

    def test_baseline_is_source_anchored_and_runtime_rows_are_absent(self):
        manifest = migration.validate_manifest(ROOT)
        self.assertEqual(manifest['baseline_source_commit'], 'cb4608c8b594d73e3908a63561cc963d386e52f8')
        for item in manifest['migrations']:
            payload = migration.read(ROOT / item['payload'])
            if item['group'] == 'baseline':
                self.assertEqual(item['source_commit'], manifest['baseline_source_commit'])
            if not migration.program_identity(payload):
                self.assertNotRegex(payload, r'(?i)INSERT\s+INTO\s+kcv_(?:chat_turns|personal_contexts|scenario_observations)')


class MigrationIntegrityFailures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'db', self.root / 'db')
        shutil.copy2(ROOT / 'VERSION', self.root / 'VERSION')
        self.manifest = json.loads(migration.read(self.root / 'db/manifest.json'))
        for path in {m['source_path'] for m in self.manifest['migrations'] if m['group'] == 'feature' and 'source_path' in m}:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)

    def save(self):
        (self.root / 'db/manifest.json').write_text(json.dumps(self.manifest), encoding='utf-8')

    def test_changed_frozen_payload_fails(self):
        p = self.root / self.manifest['migrations'][0]['payload']
        p.write_text(migration.read(p) + '\n-- changed\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Immutable migration hash mismatch'):
            migration.validate_manifest(self.root)

    def test_changed_postcondition_fails(self):
        p = self.root / self.manifest['migrations'][0]['verification']
        p.write_text('NULL;\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Immutable migration hash mismatch'):
            migration.validate_manifest(self.root)

    def test_dependency_cannot_reference_pending_work(self):
        self.manifest['migrations'][0]['depends_on'] = [self.manifest['migrations'][-1]['id']]
        self.save()
        with self.assertRaisesRegex(ValueError, 'must appear earlier'):
            migration.validate_manifest(self.root)

    def test_migration_cannot_read_outside_db(self):
        self.manifest['migrations'][0]['payload'] = '../private.sql'
        self.save()
        with self.assertRaisesRegex(ValueError, 'local db/'):
            migration.validate_manifest(self.root)

    def test_changed_current_api_requires_new_reviewed_snapshot(self):
        item = next(m for m in self.manifest['migrations'] if m.get('source_path') == 'sql/extensions/12_my_contexts_api.sql')
        p = self.root / item['source_path']
        p.write_text(migration.read(p).replace('FUNCTION', 'function', 1), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'differs from latest frozen payload'):
            migration.validate_manifest(self.root)

    def test_product_version_must_match(self):
        (self.root / 'VERSION').write_text('9.0.0\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'maintained product VERSION'):
            migration.validate_manifest(self.root)

    def test_supersession_cannot_replace_future_step(self):
        self.manifest['migrations'][0]['supersedes'] = [self.manifest['migrations'][-1]['id']]
        self.save()
        with self.assertRaisesRegex(ValueError, 'uniquely replace an earlier'):
            migration.validate_manifest(self.root)

    def test_postcondition_cannot_have_ambiguous_successors(self):
        last = self.manifest['migrations'][-1]
        last['supersedes'] = ['2.0.0-c2-004-kcv_access-package']
        self.save()
        with self.assertRaisesRegex(ValueError, 'uniquely replace an earlier'):
            migration.validate_manifest(self.root)

    def test_retired_failed_payload_cannot_change(self):
        records = migration.retirement_records(self.root)
        if not records:
            self.skipTest('Historical fixture has no retired candidates')
        path = self.root / records[0]['entries'][0]['migration']['payload']
        path.write_text(migration.read(path) + '\n-- changed\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Immutable retirement audit hash mismatch'):
            migration.validate_manifest(self.root)

    def test_retirement_record_cannot_change_without_explicit_hash_review(self):
        if not self.manifest.get('retirements'):
            self.skipTest('Historical fixture has no retired candidates')
        path = self.root / self.manifest['retirements'][0]['path']
        path.write_text(migration.read(path) + '\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Immutable retirement audit hash mismatch'):
            migration.validate_manifest(self.root)

    def test_applied_prefix_cannot_be_rewritten_during_retirement(self):
        if not self.manifest.get('retirements'):
            self.skipTest('Historical fixture has no retired candidates')
        self.manifest['migrations'][0]['version'] = '9.0.0'
        self.save()
        with self.assertRaisesRegex(ValueError, 'Applied migration prefix differs'):
            migration.validate_manifest(self.root)


if __name__ == '__main__':
    unittest.main()
