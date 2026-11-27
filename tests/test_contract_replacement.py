"""Contract replacement boundaries; no database execution or migration edits."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import build_apex_supporting as supporting
from scripts import build_database_installers as db


class ContractReplacementTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'db/payloads').mkdir(parents=True)
        self.manifest = {'format_version': 1, 'target_product_version': '2.1.0', 'migrations': []}
        self.add('old-deploy', 'CREATE OR REPLACE PACKAGE BODY kcv_deploy AS\nEND;\n')
        self.add('contract-spec', 'CREATE OR REPLACE PACKAGE kcv_deploy_contract AS\n PROCEDURE verify_schema;\nEND;\n')
        self.old = self.add('old-contract-body', 'CREATE OR REPLACE PACKAGE BODY kcv_deploy_contract AS\n PROCEDURE verify_schema IS BEGIN NULL; END;\nEND;\n')
        self.old_ready = self.add('old-ready', 'BEGIN NULL; END;')
        self.new_deploy = self.add('new-deploy', 'CREATE OR REPLACE PACKAGE BODY kcv_deploy AS\n -- revised implementation\n PROCEDURE cleanup IS BEGIN NULL; END;\nEND;\n', supersedes=['old-deploy'])
        self.anchor = self.add('new-backend-ready', 'BEGIN NULL; END;', supersedes=['old-ready'])
        calls = []
        for item in (self.new_deploy, self.manifest['migrations'][1]):
            sql = db.read(self.root / item['payload'])
            name, kind = db.program_identity(sql)
            calls.append(" check_digest('%s','%s','%s');" % (name, kind, db.sha(db.canonical_program(sql))))
        self.set_verifier(self.anchor, '\n'.join(calls) + '\n')
        self.future = self.add('new-contract-body', 'CREATE OR REPLACE PACKAGE BODY kcv_deploy_contract AS\n PROCEDURE verify_schema IS BEGIN NULL; END;\nEND;\n', supersedes=['old-contract-body'])
        self.final = self.add('new-ready', 'BEGIN NULL; END;', supersedes=['new-backend-ready'])
        self.save()

    def add(self, suffix, sql, supersedes=None):
        mid = '2.1.0-' + suffix
        item = {'id': mid, 'group': 'baseline', 'version': '2.1.0',
                'payload': f'db/payloads/{mid}.sql', 'verification': f'db/payloads/{mid}.verify.sql',
                'depends_on': [self.manifest['migrations'][-1]['id']] if self.manifest['migrations'] else []}
        if supersedes:
            item['supersedes'] = ['2.1.0-' + name for name in supersedes]
        (self.root / item['payload']).write_text(sql, encoding='utf-8')
        item['payload_sha256'] = db.sha(sql)
        self.set_verifier(item, " require(TRUE,'physical-%s');\n" % suffix)
        self.manifest['migrations'].append(item)
        return item

    def set_verifier(self, item, sql):
        (self.root / item['verification']).write_text(sql, encoding='utf-8')
        item['verification_sha256'] = db.sha(sql)

    def save(self):
        (self.root / 'db/manifest.json').write_text(json.dumps(self.manifest), encoding='utf-8')

    def generate(self, **overrides):
        options = {'through_migration': self.anchor['id'], 'target_checkpoint': self.final['id'],
                   'replaces_body_migration': self.old['id']}
        options.update(overrides)
        return supporting.contract_artifacts(self.root, **options)

    def test_every_historical_receipt_remains_but_each_physical_target_runs_once(self):
        with patch.object(db, 'retirement_guard', return_value=" require(TRUE,'reviewed-retirement-guard');\n") as guard:
            files = self.generate()
        guard.assert_called_once_with(self.root)
        body = files['kcv_deploy_contract.body.sql'].decode()
        self.assertIn('reviewed-retirement-guard', body)
        for item in self.manifest['migrations'][:6]:
            self.assertEqual(body.count(db.receipt_check(item)), 1)
        self.assertNotIn(db.read(self.root / self.old['verification']).strip(), body)
        self.assertNotIn(db.read(self.root / self.old_ready['verification']).strip(), body)
        self.assertEqual(body.count(db.read(self.root / self.new_deploy['verification']).strip()), 1)
        self.assertEqual(body.count(db.read(self.root / self.anchor['verification']).strip()), 1)
        metadata = json.loads(files['manifest.json'])['replacement_contract']
        self.assertEqual(metadata['historical_body_receipts_retained'], [self.old['id']])
        self.assertEqual(metadata['physical_body_check_omitted'], self.old['id'])
        self.assertEqual(len(metadata['physical_targets_checked_once']), 3)

    def test_default_rejection_is_unchanged_and_future_body_cannot_change_generated_prefix(self):
        with self.assertRaisesRegex(ValueError, 'own body'):
            supporting.contract_artifacts(self.root, through_migration=self.anchor['id'])
        before = self.generate()
        payload = db.read(self.root / self.future['payload']) + '-- future body change\n'
        (self.root / self.future['payload']).write_text(payload, encoding='utf-8')
        self.future['payload_sha256'] = db.sha(payload)
        self.set_verifier(self.future, " require(TRUE,'different future postcondition');\n")
        self.save()
        self.assertEqual(before, self.generate())

    def test_missing_wrong_or_self_included_body_and_checkpoint_are_rejected(self):
        for selected in ('missing', self.new_deploy['id'], self.future['id']):
            with self.subTest(selected=selected), self.assertRaisesRegex(ValueError, 'explicit historical'):
                self.generate(replaces_body_migration=selected)
        with self.assertRaisesRegex(ValueError, 'outside'):
            self.generate(target_checkpoint=self.anchor['id'])
        with self.assertRaisesRegex(ValueError, 'backend-ready'):
            self.generate(through_migration=self.future['id'])

    def test_ambiguous_body_and_unsuperseded_aggregate_checkpoint_are_rejected(self):
        self.new_deploy['payload'] = self.old['payload']
        self.new_deploy['payload_sha256'] = self.old['payload_sha256']
        self.save()
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            self.generate()
        self.setUp_for_other_boundary()

    def setUp_for_other_boundary(self):
        # This separate assertion needs no new fixture or shared-file mutation.
        prefix = self.manifest['migrations'][:6]
        prefix[4]['payload'] = 'db/payloads/2.1.0-new-deploy.sql'
        prefix[4]['payload_sha256'] = db.sha(db.read(self.root / prefix[4]['payload']))
        del self.anchor['supersedes']
        self.save()
        with self.assertRaisesRegex(ValueError, 'Every aggregate checkpoint'):
            self.generate()

    def test_stale_missing_or_self_body_program_digest_is_rejected(self):
        original = db.read(self.root / self.anchor['verification'])
        bad_cases = [original.replace(self.new_deploy['payload_sha256'], '0' * 64),
                     original + " check_digest('KCV_DEPLOY_CONTRACT','PACKAGE BODY','" + '0' * 64 + "');\n",
                     original + " require(EXISTS_BODY('KCV_DEPLOY_CONTRACT'),'unsafe direct comparison');\n"]
        # The source digest is canonical, rather than the raw payload hash.
        canonical = db.sha(db.canonical_program(db.read(self.root / self.new_deploy['payload'])))
        bad_cases[0] = original.replace(canonical, '0' * 64)
        for text in bad_cases:
            self.set_verifier(self.anchor, text)
            self.save()
            with self.assertRaisesRegex(ValueError, 'Backend-ready'):
                self.generate()


if __name__ == '__main__':
    unittest.main()
