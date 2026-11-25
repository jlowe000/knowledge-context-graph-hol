"""The release adapter cannot turn a custom or partly migrated schema into v1."""
import contextlib
import io
import re
import unittest

from scripts import build_database_installers as migration
from scripts import build_v1_baseline_completion as completion


class V1BaselineCompletionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = migration.validate_manifest(completion.ROOT)
        cls.baseline = [item for item in cls.manifest['migrations'] if item['group'] == 'baseline']
        cls.sql = completion.render()

    def test_generated_adapter_is_current_and_single_statement(self):
        with contextlib.redirect_stdout(io.StringIO()):
            completion.build(check=True)
        self.assertEqual(len(migration.sql_units(self.sql)), 1)
        self.assertNotIn('&', self.sql)

    def test_every_required_contract_and_existing_optional_contract_precedes_ddl(self):
        first_create = self.sql.index(' IF l_table_present=0 THEN')
        for item in self.baseline:
            expected = migration.read(completion.ROOT / item['verification']).strip()
            with self.subTest(migration=item['id']):
                self.assertLess(self.sql.index(expected), first_create)
        self.assertLess(self.sql.index("object_name='KCV_SCHEMA_MIGRATIONS'"), first_create)
        self.assertIn("require(l_n=0,'A migration registry already exists", self.sql)
        self.assertIn("SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')", self.sql)

    def test_exactly_two_absent_optional_objects_can_be_created_without_replacement(self):
        creates = self.sql[self.sql.index(' IF l_table_present=0 THEN'):]
        self.assertEqual(creates.count('EXECUTE IMMEDIATE l_sql;'), 2)
        self.assertIn(' IF l_function_present=0 THEN', creates)
        self.assertIn('CREATE TABLE kcv_domain_runs', creates)
        self.assertIn('CREATE FUNCTION kcv_extract_domain', creates)
        self.assertNotIn('CREATE OR REPLACE', creates)
        self.assertNotRegex(creates, r'(?im)^\s*(?:INSERT INTO|UPDATE|DELETE FROM)\s+kcv_schema_migrations')
        self.assertNotRegex(creates, r'(?im)^\s*DROP\s')
        self.assertNotIn('DBMS_CLOUD_AI.GENERATE(', creates.split('EXECUTE IMMEDIATE l_sql;')[0])

    def test_function_definition_remains_the_original_frozen_optional_implementation(self):
        item = next(item for item in self.baseline if item['id'] == '1.0.0-033-kcv_extract_domain-function')
        payload = migration.read(completion.ROOT / item['payload']).strip()
        create_only = re.sub(r'^CREATE\s+OR\s+REPLACE\s+', 'CREATE ', payload, count=1, flags=re.I)
        self.assertIn(migration.clob_assignment('l_sql', create_only), self.sql)
        self.assertEqual(set(completion.OPTIONAL), {
            '1.0.0-020-kcv_domain_runs', '1.0.0-033-kcv_extract_domain-function'})


if __name__ == '__main__':
    unittest.main()
