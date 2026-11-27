"""Authoring/deployment guards; native APEX execution is tested separately."""
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from scripts.build_apex import build
from scripts import build_apex_worksheet as worksheet


class ApexAuthoringTests(unittest.TestCase):
    def test_deployment_guards_cover_all_learner_pages_and_do_not_cache(self):
        root=Path(__file__).resolve().parents[1]/'apex/application'
        names=('p00001-home.apx','p00010-my-contexts.apx','p00011-context-editor.apx',
               'p00012-review-context.apx','p00013-context-overview.apx',
               'p00014-sample-contexts.apx','p00015-delete-context.apx')
        for name in names:
            page=(root/'pages'/name).read_text(encoding='utf-8')
            page_security=page.split('security {',1)[1].split('}',1)[0]
            self.assertIn('authorizationScheme: @learning-ready',page_security,name)
        schemes=(root/'shared-components/authorizations.apx').read_text(encoding='utf-8')
        for scheme,method in (('deployment-installer','is_installer'),('learning-ready','learner_ready')):
            body=schemes.split('authorization '+scheme+' (',1)[1].split('\n)',1)[0]
            self.assertIn('evaluationType: always',body)
            self.assertIn('kcv_deploy.'+method,body)
            self.assertIn('EXCEPTION WHEN OTHERS THEN RETURN FALSE',body)
        setup=(root/'pages/p00900-deployment-setup.apx').read_text(encoding='utf-8')
        self.assertNotIn('@administration-rights',setup)
        self.assertIn('authorizationScheme: @deployment-installer',setup.split('region ',1)[0])

    def test_setup_render_is_read_only_and_sensitive_configuration_is_request_only(self):
        root=Path(__file__).resolve().parents[1]/'apex/application'
        setup=(root/'pages/p00900-deployment-setup.apx').read_text(encoding='utf-8')
        read=setup.split('process read-setup-readiness (',1)[1]
        self.assertIn('point: beforeHeader',read)
        calls=re.findall(r'kcv_deploy\.([a-z_]+)',read,re.I)
        self.assertEqual(calls,['status_json','credential_options'])
        for name in ('CREDENTIAL','REGION','COMPARTMENT','MODEL','STATUS','CREDENTIALS'):
            item=setup.split('pageItem P900_'+name+' (',1)[1].split('\n  )',1)[0]
            self.assertIn('storage: request',item,name)
            self.assertNotIn('default {',item,name)
        token=setup.split('pageItem P900_TOKEN (',1)[1].split('\n  )',1)[0]
        self.assertIn('valueProtected: true',token)
        self.assertIn('sessionStateProtection: checksumRequiredSessionLevel',token)
        self.assertIn(':P900_TOKEN:=RAWTOHEX(SYS_GUID())',read)
        actions=setup.split('process run-requested-setup-action (',1)[1].split('process read-setup-readiness',1)[0]
        self.assertIn('point: processing',actions)
        self.assertIn('authorizationScheme: @deployment-installer',actions)
        self.assertNotIn('SQLERRM',setup)
        self.assertNotRegex(setup,r'pageItem\s+P900_(?:PRIVATE_KEY|PASSWORD|ENDPOINT)\b')
        self.assertIn("JSON_TABLE(apex_session_state.get_clob('P900_STATUS')",setup)
        for name in ('DATASET_STATUS','DATASET_PHASE','COLLECTION_COUNTS'):
            self.assertIn('&P900_'+name+'!HTML.',setup)
            item=setup.split('pageItem P900_'+name+' (',1)[1].split('\n  )',1)[0]
            self.assertIn('storage: request',item)
        self.assertIn("'$.dataset_progress.phase' RETURNING VARCHAR2(128)",read)
        self.assertIn("'$.collection_counts.sources' RETURNING NUMBER",read)
        for column in ('NEXT_ACTION','ERROR_CODE'):
            blocks=setup.split('column '+column+' (')[1:]
            self.assertTrue(blocks)
            for block in blocks:self.assertIn('escapeSpecialChars: true',block.split('\n    )',1)[0])

    def test_missing_backend_routes_to_neutral_handoff_without_granting_identity(self):
        root=Path(__file__).resolve().parents[1]/'apex/application'
        auth=(root/'shared-components/authentications.apx').read_text(encoding='utf-8')
        self.assertIn('postAuthenticationProcedureName: kcv_post_login',auth)
        self.assertIn('IF package_objects<>2 THEN RETURN',auth)
        self.assertIn('kcv_deploy.capture_identity',auth)
        self.assertNotIn('kcv_access.capture_identity',auth.lower())
        self.assertNotIn('set_session_state',auth.lower())
        app=(root/'application.apx').read_text(encoding='utf-8')
        self.assertIn('page: 901',app.split('homeUrl:',1)[1].split('}',1)[0])
        handoff=(root/'pages/p00901-installation-status.apx').read_text(encoding='utf-8')
        self.assertIn('Supporting Objects',handoff)
        self.assertIn('EXCEPTION WHEN OTHERS THEN ready:=FALSE; installer:=FALSE',handoff)
        self.assertNotRegex(handoff,r'kcv_deploy\.(?:test_model|configure_profile|enable_learning|load_dataset)')

    def test_context_search_runs_once_and_report_uses_request_only_payload(self):
        # Repeated report evaluation must not repeat an embedding request or
        # reuse another request's private results from persistent session state.
        page=(Path(__file__).resolve().parents[1]/'apex/application/pages/p00010-my-contexts.apx').read_text()
        calls=re.findall(r'kcv_personal_context_api\.list_contexts\s*\(',page,re.I)
        self.assertEqual(len(calls),1)
        prepare=page.split('process prepare-library (',1)[1].split('\n  )',1)[0]
        self.assertIn('point: beforeHeader',prepare)
        self.assertIn("p_item=>'P10_RESULTS',p_value=>l_result",prepare)
        self.assertIn("JSON_VALUE(l_result,'$.next_cursor')",prepare)
        self.assertIn("JSON_VALUE(l_result,'$.search_notice'",prepare)
        cache=page.split('pageItem P10_RESULTS (',1)[1].split('\n  )',1)[0]
        self.assertIn('dataType: clob',cache)
        self.assertIn('storage: request',cache)
        self.assertIn('valueProtected: true',cache)
        report=page.split('region contexts (',1)[1]
        self.assertNotIn('list_contexts(',report)
        self.assertIn("JSON_TABLE(apex_session_state.get_clob('P10_RESULTS')",report)

    def test_context_search_explanations_are_bounded_and_html_escaped(self):
        # Saved context/model-derived match text is untrusted display content.
        page=(Path(__file__).resolve().parents[1]/'apex/application/pages/p00010-my-contexts.apx').read_text()
        self.assertIn('SUBSTR(j.objective_preview,1,240)',page)
        self.assertIn('&P10_SEARCH_NOTICE!HTML.',page)
        for name in ('OBJECTIVE_PREVIEW','MATCH_REASON'):
            column=page.split(f'column {name} (',1)[1].split('\n    )',1)[0]
            self.assertIn('type: plainText',column)
            self.assertIn('escapeSpecialChars: true',column)

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
        (root/'db').mkdir()
        payload='BEGIN NULL;END;\n'
        verification=" require(1=1,'Fixture schema contract');\n"
        (root/'db/payload.sql').write_text(payload)
        (root/'db/verify.sql').write_text(verification)
        (root/'db/manifest.json').write_text(json.dumps({
            'format_version':1,'target_product_version':'2.0.0','migrations':[{
                'id':'2.0.0-test-ready','version':'2.0.0','group':'feature','depends_on':[],
                'payload':'db/payload.sql','payload_sha256':hashlib.sha256(payload.encode()).hexdigest(),
                'verification':'db/verify.sql','verification_sha256':hashlib.sha256(verification.encode()).hexdigest()
            }]}))
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
            self.assertLess(sql.index('2.0.0-test-ready'),sql.index('null; -- fixture only'))
            self.assertNotIn('&',sql)

    def test_release_targets_are_bound_and_checked_before_import(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root);self.receipt(root)
            with patch.object(worksheet,'ROOT',root):
                fresh=worksheet.build(runtime_targets=True).read_text()
                upgrade=worksheet.build(mode='upgrade',runtime_targets=True).read_text()
            for sql in (fresh,upgrade):
                header=sql.split('\nDECLARE',1)[0]
                self.assertIn('Run Statement once',header)
                self.assertIn('excluding the final slash',header)
                self.assertNotIn('Run Script',header)
                for bind in (':KCV_SCHEMA',':KCV_WORKSPACE',':KCV_APP_ALIAS'):
                    self.assertIn(bind,sql)
                self.assertIn("SYS_CONTEXT('USERENV','SESSION_USER')<>l_schema",sql)
                self.assertIn("USER<>SYS_CONTEXT('USERENV','SESSION_USER')",sql)
                self.assertIn("USER IN ('ADMIN','SYS','SYSTEM')",sql)
                self.assertIn('SET_WORKSPACE(l_workspace)',sql)
                self.assertIn('SET_SCHEMA(l_schema)',sql)
                self.assertIn('SET_APPLICATION_ALIAS(l_alias)',sql)
                self.assertLess(sql.index('Use valid project schema'),sql.index('null; -- fixture only'))
                self.assertNotIn('&',sql)
            self.assertIn('Application alias already exists',fresh)
            self.assertLess(fresh.index('Application alias already exists'),fresh.index('GENERATE_APPLICATION_ID'))
            self.assertIn('l_app_id:=:KCV_APPLICATION_ID;',upgrade)
            self.assertIn('workspace=l_workspace',upgrade)
            self.assertIn('owner=l_schema AND UPPER(alias)=l_alias',upgrade)
            self.assertNotIn('GENERATE_APPLICATION_ID',upgrade)

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
            self.assertLess(sql.index('2.0.0-test-ready'),sql.index('GENERATE_APPLICATION_ID'))
            self.assertIn("require(1=1,'Fixture schema contract')",sql)
            self.assertIn("product_version='2.0.0'",sql)
            self.assertNotIn('IF l_count<>16',sql)


if __name__=='__main__':unittest.main()
