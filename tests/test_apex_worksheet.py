"""SQL-first packaging boundaries; these are not native execution acceptance."""
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from scripts import build_apex_worksheet as worksheet
from scripts import build_database_installers as migrations


class WorksheetContractTests(unittest.TestCase):
    @staticmethod
    def external_binds(sql):
        # Native export component source can contain hundreds of quoted binds;
        # only colon names outside ordinary SQL literals/comments are external.
        code=re.sub(r"'(?:''|[^'])*'|--[^\n]*|/\*[\s\S]*?\*/",' ',sql)
        return set(re.findall(r'(?<!:):([A-Za-z][A-Za-z0-9_]*)',code))

    def fixture(self, root):
        (root/'apex/application').mkdir(parents=True)
        (root/'apex/application/application.apx').write_text('app fixture ()\n')
        (root/'apex/kcv-explorer.sql').write_text("begin\n null; -- native export fixture\nend;\n/\n")
        (root/'VERSION').write_text('2.1.0\n')
        (root/'db').mkdir()
        items=[]
        for version, name in [('2.0.0','old'),('2.1.0','current')]:
            payload='BEGIN NULL;END;\n'
            verification=f" require(1=1,'{name} physical contract');\n"
            (root/f'db/{name}.sql').write_text(payload)
            (root/f'db/{name}-verify.sql').write_text(verification)
            item={'id':version+'-'+name+'-ready','version':version,'group':'feature',
                  'depends_on':[items[-1]['id']] if items else [],
                  'payload':f'db/{name}.sql','payload_sha256':migrations.sha(payload),
                  'verification':f'db/{name}-verify.sql','verification_sha256':migrations.sha(verification)}
            if items:item['supersedes']=[items[-1]['id']]
            items.append(item)
        (root/'db/manifest.json').write_text(json.dumps({
            'format_version':1,'target_product_version':'2.1.0','migrations':items}))
        (root/'apex/export-validation.json').write_text(json.dumps({
            'product_version':'2.1.0','engine_import_export_verified':True,
            'engine':{'supporting_objects_exported':False},
            'application_source_sha256':worksheet.application_source_hash(root),
            'export_sql_sha256':hashlib.sha256((root/'apex/kcv-explorer.sql').read_text().encode()).hexdigest()}))
        return items

    def test_current_contract_precedes_import_and_preserves_historical_receipts(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);items=self.fixture(root)
            with patch.object(worksheet,'ROOT',root):
                sql=worksheet.build(mode='upgrade',runtime_targets=True).read_text()
            for item in items:
                digest=migrations.sha(item['payload_sha256']+':'+item['verification_sha256'])
                self.assertIn(digest,sql)
                self.assertIn("migration_id='"+item['id']+"'",sql)
            self.assertIn("product_version='2.1.0'",sql)
            self.assertIn("phase='COMPLETE' AND completed_at IS NOT NULL AND error_code IS NULL",sql)
            self.assertIn('current physical contract',sql)
            self.assertNotIn('old physical contract',sql)
            self.assertLess(sql.index('KCV schema verification passed'),sql.index('APEX_APPLICATION_INSTALL.SET_WORKSPACE'))
            self.assertLess(sql.index('SESSION_USER'),sql.index('SELECT COUNT(*) INTO l_checkpoint_count'))
            self.assertNotIn('2.0.0-c3-r7-ready',sql)
            self.assertNotIn('IF l_count<>16',sql)
            self.assertNotIn('GENERATE_APPLICATION_ID',sql)

    def test_changed_payload_or_postcondition_is_rejected_before_output(self):
        for part in ('current.sql','current-verify.sql'):
            with self.subTest(part=part),tempfile.TemporaryDirectory() as folder:
                root=Path(folder);self.fixture(root)
                (root/'db'/part).write_text('changed\n')
                output=root/'out.sql'
                with patch.object(worksheet,'ROOT',root):
                    with self.assertRaisesRegex(ValueError,'Immutable migration hash mismatch'):
                        worksheet.build(output=output)
                self.assertFalse(output.exists())

    def test_sql_first_refuses_missing_or_included_supporting_object_acceptance(self):
        for value in (None,True,'false'):
            with self.subTest(value=value),tempfile.TemporaryDirectory() as folder:
                root=Path(folder);self.fixture(root)
                path=root/'apex/export-validation.json';receipt=json.loads(path.read_text())
                receipt['engine']={} if value is None else {'supporting_objects_exported':value}
                path.write_text(json.dumps(receipt))
                with self.assertRaisesRegex(ValueError,'explicitly exclude Supporting Objects'):
                    worksheet.verify_upgrade_export(root)

    def test_mismatched_final_checkpoint_version_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);self.fixture(root)
            path=root/'db/manifest.json';manifest=json.loads(path.read_text())
            manifest['migrations'][-1]['version']='2.0.0'
            path.write_text(json.dumps(manifest))
            with patch.object(worksheet,'ROOT',root):
                with self.assertRaisesRegex(ValueError,'checkpoint must match'):
                    worksheet.build()

    def test_missing_canonical_history_cannot_fall_back_to_package_count(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);self.fixture(root)
            (root/'db/manifest.json').unlink()
            with patch.object(worksheet,'ROOT',root):
                with self.assertRaises(FileNotFoundError):worksheet.build()

    def test_old_release_and_build_targets_preserve_owner_and_binding_boundaries(self):
        for schema,workspace in [('KCV_LAB','KCV_KNOWLEDGE'),('KCV_V2_999','KCV_V2_999')]:
            with self.subTest(schema=schema),tempfile.TemporaryDirectory() as folder:
                root=Path(folder);self.fixture(root)
                with patch.object(worksheet,'ROOT',root):
                    sql=worksheet.build(schema=schema,workspace=workspace,mode='upgrade').read_text()
                self.assertIn("SYS_CONTEXT('USERENV','SESSION_USER')<>'"+schema+"'",sql)
                self.assertIn("USER IN ('ADMIN','SYS','SYSTEM')",sql)
                self.assertIn("workspace='"+workspace+"'",sql)
                self.assertIn("owner='"+schema+"'",sql)
                self.assertIn('03_bind_deployment_owner.sql separately',sql)
                self.assertNotIn('INSERT INTO kcv_deploy_state',sql)
                self.assertNotIn('ALTER SESSION',sql)
                self.assertLess(sql.index('SET_AUTO_INSTALL_SUP_OBJ(FALSE)'),sql.index('null; -- native export fixture'))

    def test_current_real_manifest_supplies_all_receipts_and_final_version(self):
        root=Path(__file__).resolve().parents[1]
        manifest=migrations.validate_manifest(root)
        sql=worksheet.schema_verification(root,(root/'VERSION').read_text().strip())
        self.assertIn(manifest['migrations'][-1]['id'],sql)
        for item in manifest['migrations']:
            self.assertIn('Missing or incompatible completion receipt: '+item['id'],sql)
        self.assertIn('Retired',sql)

    def test_script_delivery_has_no_external_binds_and_keeps_real_contract_and_export(self):
        root=Path(__file__).resolve().parents[1]
        # Exercise the real verifier/export as well as synthetic fixtures: quoted
        # page-item references must survive without becoming installer inputs.
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)
            for mode in ('new','upgrade'):
                with self.subTest(mode=mode):
                    bound=worksheet.build(mode=mode,runtime_targets=True,
                        output=output/(mode+'-bound.sql')).read_text()
                    scripted=worksheet.build(mode=mode,worksheet_script_inputs=True,
                        output=output/(mode+'-script.sql')).read_text()
                    expected={'KCV_SCHEMA','KCV_WORKSPACE','KCV_APP_ALIAS'}
                    if mode=='upgrade':expected.add('KCV_APPLICATION_ID')
                    self.assertEqual(self.external_binds(bound),expected)
                    self.assertEqual(self.external_binds(scripted),set())
                    gate_start='DECLARE l_checkpoint_count NUMBER;'
                    gate_end=' APEX_APPLICATION_INSTALL.SET_WORKSPACE(l_workspace);'
                    self.assertEqual(bound[bound.index(gate_start):bound.index(gate_end)],
                                     scripted[scripted.index(gate_start):scripted.index(gate_end)])
                    native_start=' APEX_APPLICATION_INSTALL.SET_AUTO_INSTALL_SUP_OBJ(FALSE);'
                    self.assertEqual(bound[bound.index(native_start):],scripted[scripted.index(native_start):])
                    self.assertIn('Run Script (F5)',scripted)
                    self.assertNotIn('bind prompts.',scripted)
                    self.assertTrue(scripted.endswith('END;\n/\n'))

    def test_script_placeholders_fail_closed_before_installation_and_keep_target_guards(self):
        for mode in ('new','upgrade'):
            with self.subTest(mode=mode),tempfile.TemporaryDirectory() as folder:
                root=Path(folder);self.fixture(root)
                with patch.object(worksheet,'ROOT',root):
                    sql=worksheet.build(mode=mode,worksheet_script_inputs=True).read_text()
                for name in ('schema','workspace','alias'):
                    self.assertIn(f'l_{name} VARCHAR2(128):=NULL;',sql)
                    self.assertNotIn(f'TRIM(:KCV_{name.upper()})',sql)
                null_gate=sql.index('IF l_schema IS NULL OR l_workspace IS NULL OR l_alias IS NULL THEN')
                format_gate=sql.index("IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')")
                owner_gate=sql.index("SYS_CONTEXT('USERENV','SESSION_USER')<>l_schema")
                verification=sql.index('DECLARE l_checkpoint_count NUMBER;')
                install=sql.index('APEX_APPLICATION_INSTALL.SET_WORKSPACE(l_workspace)')
                self.assertLess(null_gate,format_gate)
                self.assertLess(format_gate,owner_gate)
                self.assertLess(owner_gate,verification)
                self.assertLess(verification,install)
                self.assertIn("USER IN ('ADMIN','SYS','SYSTEM')",sql)
                self.assertNotIn('ALTER SESSION',sql)
                self.assertNotIn('INSERT INTO kcv_deploy_state',sql)
                self.assertNotIn('MERGE INTO kcv_settings',sql)
                if mode=='new':
                    self.assertIn('WHERE workspace=l_workspace AND UPPER(alias)=l_alias',sql)
                    self.assertLess(sql.index('Application alias already exists'),sql.index('GENERATE_APPLICATION_ID'))
                    self.assertNotIn('l_existing_app_id',sql)
                else:
                    self.assertIn('l_existing_app_id NUMBER:=NULL;',sql)
                    self.assertIn('l_app_id:=l_existing_app_id;',sql)
                    self.assertIn('l_app_id IS NULL OR l_app_id<=0 OR l_app_id<>TRUNC(l_app_id)',sql)
                    self.assertIn('WHERE application_id=l_app_id AND workspace=l_workspace',sql)
                    self.assertIn('AND owner=l_schema AND UPPER(alias)=l_alias',sql)
                    self.assertLess(sql.index('Application, workspace, alias and parsing schema must match'),
                                    sql.index('SET_APPLICATION_ID(l_app_id)'))
                    self.assertNotIn('GENERATE_APPLICATION_ID',sql)

    def test_script_mode_rejects_ambiguous_or_silently_ignored_target_inputs(self):
        for args in ({'runtime_targets':True},{'schema':'KCV_V2_999'},
                     {'workspace':'KCV_V2_999'},{'alias':'KCV-CUSTOM'}):
            with self.subTest(args=args),tempfile.TemporaryDirectory() as folder:
                output=Path(folder)/'must-not-exist.sql'
                with self.assertRaisesRegex(ValueError,'Choose either|NULL placeholders'):
                    worksheet.build(worksheet_script_inputs=True,output=output,**args)
                self.assertFalse(output.exists())

    def test_existing_bind_mode_output_remains_identical_to_reviewed_package(self):
        # Stable public wrappers are already accepted inputs; adding an optional
        # delivery mode must not silently replace either artifact.
        expected={
            'new':'2fe0210090adc426261519ba84c1a40135a54d21262bd2c0fa554bfdfcf6aa13',
            'upgrade':'08980ad557fe336aeeaecc1ea1cdf2a72b724727f73436a65377c07b3dcdc57e'}
        with tempfile.TemporaryDirectory() as folder:
            for mode,digest in expected.items():
                with self.subTest(mode=mode):
                    output=worksheet.build(mode=mode,runtime_targets=True,
                        output=Path(folder)/(mode+'.sql'))
                    self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(),digest)


if __name__=='__main__':unittest.main()
