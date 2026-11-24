"""Authoring/deployment guards; native APEX execution is tested separately."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.build_apex import build
from scripts import build_apex_worksheet as worksheet


class ApexAuthoringTests(unittest.TestCase):
    def fixture(self, root):
        folder=root/'apex/application/pages';folder.mkdir(parents=True)
        for name in ('explorer.js','explorer.css'):
            (root/'apex'/name).write_text('public asset '+name)
        versions={name:hashlib.sha256(('public asset '+name).encode()).hexdigest()[:12]
                  for name in ('explorer.js','explorer.css')}
        page=folder/'p00001-home.apx'
        page.write_text('page 1 (\n native-form-that-must-survive: true\n'+
                        '\n'.join('#APP_FILES#'+n+'?v='+v for n,v in versions.items())+'\n)\n')
        (root/'apex/region.html').write_text('<p>Obsolete HTML must not replace a page.</p>')
        (root/'apex/kcv-explorer.sql').write_text("begin\n null; -- fixture only\nend;\n/\n")
        (root/'VERSION').write_text('2.0.0\n')
        return page

    def receipt(self, root, verified=True):
        (root/'apex/export-validation.json').write_text(json.dumps({
            'product_version':'2.0.0',
            'engine_import_export_verified':verified,
            'application_source_sha256':worksheet.application_source_hash(root),
            'export_sql_sha256':hashlib.sha256((root/'apex/kcv-explorer.sql').read_text().encode()).hexdigest()
        }))

    def test_asset_sync_preserves_directly_authored_pages(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);page=self.fixture(root);before=page.read_bytes()
            build(root=root)
            self.assertEqual(before,page.read_bytes())
            self.assertEqual((root/'apex/explorer.js').read_text(),
                             (root/'apex/application/shared-components/static-files/explorer.js').read_text())
            build(check=True,root=root)

    def test_stale_cache_reference_is_reported_without_rewriting_page(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);page=self.fixture(root);before=page.read_bytes()
            (root/'apex/explorer.js').write_text('changed asset')
            with self.assertRaisesRegex(ValueError,'cache version'):
                build(root=root)
            self.assertEqual(before,page.read_bytes())

    def test_check_mode_does_not_create_generated_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            with self.assertRaisesRegex(ValueError,'asset is stale'):
                build(check=True,root=root)
            self.assertFalse((root/'apex/application/shared-components/static-files').exists())

    def test_application_footer_version_matches_product_version(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            app=root/'apex/application/application.apx'
            app.write_text('app test (\n version: 1.0\n)\n')
            with self.assertRaisesRegex(ValueError,'application version must match VERSION'):
                build(root=root)
            app.write_text('app test (\n version: 2.0.0-dev\n)\n')
            build(root=root)

    def test_upgrade_refuses_missing_or_unverified_engine_export(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            with patch.object(worksheet,'ROOT',root):
                with self.assertRaisesRegex(ValueError,'No validated v2 engine export'):
                    worksheet.build(mode='upgrade')
                self.receipt(root,False)
                with self.assertRaisesRegex(ValueError,'missing acceptance'):
                    worksheet.build(mode='upgrade')

    def test_v2_fresh_installer_also_refuses_unvalidated_export(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            with patch.object(worksheet,'ROOT',root):
                with self.assertRaisesRegex(ValueError,'No validated v2 engine export'):
                    worksheet.build(mode='new')
                self.receipt(root,False)
                with self.assertRaisesRegex(ValueError,'missing acceptance'):
                    worksheet.build(mode='new')

    def test_upgrade_refuses_source_or_export_drift(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);page=self.fixture(root);self.receipt(root)
            page.write_text(page.read_text()+'changed\n')
            with self.assertRaisesRegex(ValueError,'does not match'):
                worksheet.verify_upgrade_export(root)
            self.receipt(root)
            (root/'apex/kcv-explorer.sql').write_text('different export')
            with self.assertRaisesRegex(ValueError,'does not match'):
                worksheet.verify_upgrade_export(root)

    def test_upgrade_preserves_app_id_and_checks_target_before_export(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root);self.receipt(root)
            with patch.object(worksheet,'ROOT',root):
                path=worksheet.build(mode='upgrade')
            sql=path.read_text()
            self.assertIn('l_app_id:=:KCV_APPLICATION_ID;',sql)
            self.assertNotIn('GENERATE_APPLICATION_ID',sql)
            self.assertIn('SET_APPLICATION_ID(l_app_id)',sql)
            self.assertIn("workspace='KCV_KNOWLEDGE'",sql)
            self.assertIn("owner='KCV_LAB' AND UPPER(alias)='KCV-EXPLORER'",sql)
            self.assertLess(sql.index('2.0.0-c3-r4-ready'),sql.index('null; -- fixture only'))
            self.assertNotIn('&',sql)

    def test_fresh_installer_still_allocates_new_id(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'VERSION').write_text('1.0.0\n')
            with patch.object(worksheet,'ROOT',root):
                sql=worksheet.build().read_text()
            self.assertIn('GENERATE_APPLICATION_ID',sql)
            self.assertNotIn(':KCV_APPLICATION_ID',sql)

    def test_validated_v2_fresh_installer_allocates_new_id(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root);self.receipt(root)
            with patch.object(worksheet,'ROOT',root):
                sql=worksheet.build().read_text()
            self.assertIn('GENERATE_APPLICATION_ID',sql)
            self.assertNotIn(':KCV_APPLICATION_ID',sql)
            self.assertLess(sql.index('2.0.0-c3-r4-ready'),sql.index('GENERATE_APPLICATION_ID'))
            self.assertIn("object_name IN ('KCV_ACCESS','KCV_PERSONAL_CONTEXT_API','KCV_PERSONAL_JOURNEY','KCV_SCENARIO','KCV_TRACE','KCV_APEX')",sql)
            self.assertIn('IF l_count<>12',sql)


if __name__=='__main__':unittest.main()
