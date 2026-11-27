"""Reviewable preparation boundaries; database execution is a separate gate."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]


class PortablePreparationTests(unittest.TestCase):
    def sql(self,name):return (ROOT/'sql/admin'/name).read_text(encoding='utf-8')

    def test_admin_current_schema_switch_is_not_authorization(self):
        for name in ('12_prepare_apexlang_rest.sql','13_create_builder_login.sql',
                     '14_prepare_owner_credential.sql','15_create_apex_owner.sql'):
            sql=self.sql(name)
            for attribute in ('SESSION_USER','CURRENT_USER','CURRENT_SCHEMA'):
                self.assertIn("SYS_CONTEXT('USERENV','"+attribute+"')<>'ADMIN'",sql,name)
            self.assertIn("NOT IN('ADMIN','ORDS_PUBLIC_USER')",sql,name)
            self.assertNotIn('GRANT CONNECT THROUGH',sql,name)
            self.assertNotIn('ALTER SESSION',sql,name)

    def test_rest_and_credential_use_explicit_mapping_not_name_equality(self):
        for name in ('12_prepare_apexlang_rest.sql','14_prepare_owner_credential.sql'):
            sql=self.sql(name)
            self.assertIn(":KCV_SCHEMA)),'KCV_LAB'",sql)
            self.assertIn(":KCV_WORKSPACE)),'KCV_KNOWLEDGE'",sql)
            self.assertIn('WHERE workspace_name=w AND schema=s',sql)
            self.assertNotIn('w<>s',sql)
            self.assertNotIn('workspace_name=s',sql)
            self.assertNotIn('KCV_V[0-9]',sql)
        rest=self.sql('12_prepare_apexlang_rest.sql')
        self.assertIn('p_auto_rest_auth=>TRUE',rest)
        self.assertNotIn('ENABLE_OBJECT',rest)
        self.assertLess(rest.index('workspace_name=w AND schema=s'),rest.index('ORDS_ADMIN.ENABLE_SCHEMA'))

    def test_schema_only_and_password_routes_do_not_reset_existing_owners(self):
        sql=self.sql('15_create_apex_owner.sql')
        self.assertIn('NO AUTHENTICATION QUOTA 1G ON DATA',sql)
        self.assertNotIn('IDENTIFIED BY',sql)
        self.assertNotIn('GRANT ',sql)
        self.assertNotIn('ALTER USER',sql)
        self.assertNotIn('CREATE_CREDENTIAL',sql)
        self.assertLess(sql.index("WHERE username=s"),sql.index("EXECUTE IMMEDIATE 'CREATE USER"))
        self.assertLess(sql.index("comp_id='JAVAVM' AND status='VALID'"),sql.index("EXECUTE IMMEDIATE 'CREATE USER"))
        password=self.sql('01_create_user_worksheet.sql')
        self.assertIn('IDENTIFIED BY',password)
        self.assertNotIn('GRANT CONNECT THROUGH',password)
        self.assertNotIn('ALTER USER',password)

    def test_builder_login_cannot_gain_owner_or_workspace_privileges(self):
        sql=self.sql('13_create_builder_login.sql')
        self.assertIn(':KCV_INSTALLER_USER',sql)
        self.assertIn('DBMS_ASSERT.ENQUOTE_NAME(u,FALSE)',sql)
        grants=re.findall(r"EXECUTE IMMEDIATE 'GRANT ([^']+)'",sql)
        self.assertEqual(grants,['CREATE SESSION TO '])
        self.assertNotIn('APEX_UTIL.CREATE_USER',sql)
        self.assertNotIn('ALTER USER',sql)

    def test_optional_credential_helper_never_embeds_inputs_or_replaces_credential(self):
        sql=self.sql('14_prepare_owner_credential.sql')
        self.assertIn("authentication_type IN('NONE','PASSWORD')",sql)
        self.assertLess(sql.index("credential_name='OCI_USER_CRED'"),sql.index("EXECUTE IMMEDIATE 'CREATE PROCEDURE"))
        self.assertIn('USING u,t,f,k',sql)
        ddl=sql.split("EXECUTE IMMEDIATE 'CREATE PROCEDURE",1)[1].split("END;~';",1)[0]
        self.assertNotRegex(ddl,r'\|\|\s*(?:u|t|f|k)\b')
        for forbidden in ('DROP_CREDENTIAL','UPDATE_CREDENTIAL','GRANT EXECUTE','SQLERRM'):
            self.assertNotIn(forbidden,sql)
        self.assertIn('IF made THEN',sql)
        self.assertIn("EXECUTE IMMEDIATE 'DROP PROCEDURE '||q",sql)
        self.assertIn('forget_inputs;',sql)


if __name__=='__main__':unittest.main()
