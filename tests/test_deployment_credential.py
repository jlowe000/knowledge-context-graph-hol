"""Credential input/privacy contracts from maintained SQL; native tests are separate.

Patterns and bounds are read from the actual PL/SQL, rather than keeping a second
copy of the intended validator. These tests do not compile Oracle PL/SQL or prove
APEX debug redaction; the native and browser gates remain required.
"""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'sql/extensions/24_deployment_api.sql'


class DeploymentCredentialTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')
        cls.public = cls.source.split(' PROCEDURE create_oci_credential(', 2)[2].split('\n PROCEDURE test_model(', 1)[0]
        cls.runner = cls.source.split(' PROCEDURE run_action(', 1)[1].split('\n PROCEDURE configure_profile(', 1)[0]
        cls.branch = cls.runner.split("   WHEN 'CREATE_OCI_CREDENTIAL' THEN\n", 1)[1].split("   WHEN 'CONFIGURE_PROFILE' THEN", 1)[0]
        cls.patterns = dict(re.findall(r"REGEXP_LIKE\(([utfk]),'([^']+)','c'\)", cls.public))
        cls.bounds = {name: int(limit) for name, limit in re.findall(r'LENGTHB\((p_\w+)\)<=(\d+)', cls.public)}
        cls.low, cls.high = map(int, re.search(r'LENGTH\(k\) BETWEEN (\d+) AND (\d+)', cls.public).groups())

    def valid(self, **changes):
        values = {'p_user_ocid': 'ocid1.user.oc1..synthetic',
                  'p_tenancy_ocid': 'ocid1.tenancy.oc1..synthetic',
                  'p_fingerprint': 'ab:' * 15 + 'ab', 'p_private_key': 'A' * 128}
        values.update(changes)
        if any(v is None or not v or len(v.encode('utf-8')) > self.bounds[k] for k, v in values.items()):
            return False
        norm = {'u': values['p_user_ocid'].strip(' '), 't': values['p_tenancy_ocid'].strip(' '),
                'f': values['p_fingerprint'].strip(' ').lower(),
                'k': re.sub(r'\s', '', values['p_private_key'])}
        return (all(re.fullmatch(self.patterns[k], value) for k, value in norm.items())
                and self.low <= len(norm['k']) <= self.high and len(norm['k']) % 4 == 0)

    def test_source_validator_accepts_bounded_multiline_body_and_case_insensitive_fingerprint(self):
        self.assertTrue(self.valid())
        self.assertTrue(self.valid(p_private_key='A' * 64 + '\r\n' + 'A' * 64,
                                   p_fingerprint='AB:' * 15 + 'AB'))
        self.assertTrue(self.valid(p_private_key='A' * 126 + '=='))

    def test_source_validator_rejects_wrong_identity_types_padding_headers_and_injection(self):
        cases = [dict(p_user_ocid='ocid1.tenancy.oc1..synthetic'),
                 dict(p_tenancy_ocid='https://example.invalid'), dict(p_fingerprint='ab' * 16),
                 dict(p_private_key='A' * 127), dict(p_private_key='A' * 125 + '==='),
                 dict(p_private_key='A' * 64 + '=AAA' + 'A' * 60),
                 dict(p_private_key='-' * 5 + 'BEGIN PRIVATE KEY' + '-' * 5 + '\n' + 'A' * 128),
                 dict(p_private_key="A' || dangerous_call || '" + 'A' * 128),
                 dict(p_user_ocid='ocid1.user.oc1..synthetic\nignored'),
                 dict(p_private_key='Ａ' * 128), dict(p_private_key='A' * 4004),
                 dict(p_user_ocid=None)]
        for case in cases:
            with self.subTest(case=next(iter(case))):
                self.assertFalse(self.valid(**case))

    def test_authorization_precedes_private_input_inspection_and_every_exit_clears_local_copies(self):
        body = self.public.split('\n BEGIN\n', 1)[1]
        self.assertLess(body.index('authorize(TRUE,ident);'), body.index('LENGTHB(p_user_ocid)'))
        self.assertLess(body.index('authorize(TRUE,ident);'), body.index('u:=TRIM('))
        self.assertIn('u:=NULL;t:=NULL;f:=NULL;k:=NULL;', self.public)
        self.assertRegex(body, r"run_action\('CREATE_OCI_CREDENTIAL',p_request_token,j,u,t,f,k\);\s+forget_inputs;")
        self.assertIn('err:=SQLCODE;forget_inputs;', body)
        self.assertNotIn('SQLERRM', self.public)
        self.assertNotRegex(self.public, r'\b(?:DBMS_OUTPUT|APEX_DEBUG|digest)\s*[.(]')

    def test_journal_identity_is_fixed_metadata_not_secret_or_secret_hash(self):
        puts = re.findall(r'j\.put\(([^;]+)\);', self.public)
        self.assertEqual(puts, ["'credential_name','OCI_USER_CRED'"])
        # The only private runner parameter uses after its declaration must be
        # direct CREATE arguments. This fails if a future edit logs/hashes them.
        body = self.runner.split('\n  ident identity_t;', 1)[1]
        for field in ('user_ocid', 'tenancy_ocid', 'fingerprint', 'private_key'):
            self.assertEqual(len(re.findall(r'\bp_' + field + r'\b', body)), 1)
            self.assertIn(field + '=>p_' + field, self.branch)
        self.assertNotRegex(self.source, r'DBMS_CLOUD\.(?:DROP|UPDATE)_CREDENTIAL')

    def test_duplicate_and_replay_are_non_mutating_under_same_setup_lock(self):
        self.assertLess(self.runner.index('DBMS_LOCK.REQUEST(handle'), self.runner.index("IF p_operation='CREATE_OCI_CREDENTIAL' THEN"))
        early = self.runner.split("IF p_operation='CREATE_OCI_CREDENTIAL' THEN", 1)[1].split('\n  END IF;', 1)[0]
        self.assertIn('require(n=0,c_conflict', early)
        self.assertLess(self.runner.index(early), self.runner.index('INSERT INTO kcv_deploy_runs'))
        replay = self.runner.split("IF old.status='SUCCEEDED' THEN", 1)[1].split('END IF;', 1)[0]
        self.assertIn('verify_action(p_operation,p_inputs)', replay)
        self.assertIn('RETURN;', replay)
        self.assertNotIn('CREATE_CREDENTIAL', replay)

    def test_test_evidence_is_committed_invalid_before_possible_native_mutation(self):
        self.assertIn("model_test_status='NOT_TESTED',model_test_hash=NULL", self.branch)
        self.assertIn('model_test_at=NULL', self.branch)
        self.assertLess(self.branch.index('runtime_started:=TRUE;'), self.branch.index('UPDATE kcv_deploy_state'))
        self.assertLess(self.branch.index('COMMIT;'), self.branch.index('DBMS_CLOUD.CREATE_CREDENTIAL'))
        self.assertIn('IF runtime_started THEN maintenance_on;', self.runner)
        self.assertEqual(self.branch.count('DBMS_CLOUD.CREATE_CREDENTIAL('), 1)


if __name__ == '__main__':
    unittest.main()
