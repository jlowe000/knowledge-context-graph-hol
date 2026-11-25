"""Build the SQL-first learner distribution without copying private work files.

Maintainer utility on dev only. This never modifies a Git branch or database.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from kcv import pipeline
from kcv.worksheet import export
from kcv.github_dataset import generate as generate_github_dataset
from kcv.github_dataset import loader_script
from scripts.build_apex_worksheet import build as build_apex_installer, verify_upgrade_export
from scripts.build_apex_worksheet import application_source_hash
from scripts import build_database_installers as migrations
from scripts import build_release_sql
from scripts.build_v1_baseline_completion import build as verify_optional_baseline

LABS = ['introduction', 'prepare-environment', 'provision-database',
        'configure-database', 'load-knowledge', 'deploy-explorer',
        'explore-evidence', 'need-help']
DOCS = ['fresh-serverless-deployment.md', 'authentication.md', 'cleanup.md',
        'ui-walkthrough.md', 'screenshots.md', 'livelabs-authoring-alignment.md',
        'upstream-comparison.md']

# Public runtime/setup and educational reference SQL only. Initial raw DDL and
# developer schema/proxy bootstraps are deliberately not a release install path.
SQL_FILES = [
    'admin/00_java_status.sql', 'admin/00_readiness.sql', 'admin/01_enable_java.sql',
    'admin/01_create_user_worksheet.sql', 'admin/02_grants.sql',
    'admin/03_resource_principal.sql', 'admin/04_enable_database_actions.sql',
    'admin/06_cloud_apex_preflight.sql', 'admin/07_create_apex_workspace.sql',
    'admin/08_create_apex_app_user.sql', 'admin/11_context_search_grants.sql',
    'schema/00_user_credential_worksheet.sql', 'schema/02_network.sql',
    'schema/05_profile_worksheet.sql', 'schema/06_register_profile.sql',
    'extensions/00_readiness.sql', 'extensions/02_scenario_api.sql',
    'extensions/03_scenario_agents.sql', 'extensions/04_domain_extraction.sql',
    'extensions/06_response_provenance.sql', 'extensions/16_refresh_grounded_answers.sql',
    'extensions/22_setup_context_search.sql',
    'install/00_complete_v1_optional.sql', 'install/00_adopt_schema_baseline.sql', 'install/00_install_schema.sql',
    'install/01_upgrade_schema.sql', 'install/02_verify_schema.sql',
    'queries/00_create_conversation.sql', 'queries/00_inspect_ai_profile.sql',
    'queries/00_java_runtime.sql', 'queries/00_test_genai.sql', 'queries/01_inspect.sql',
    'queries/07_agent_progress.sql', 'queries/08_agent_task_history.sql',
    'queries/09_agent_tool_history.sql',
    'scenarios/01_start.sql', 'scenarios/02_inspect.sql', 'scenarios/03_ask.sql',
    'scenarios/04_preview_change.sql', 'scenarios/05_apply_change.sql',
    'scenarios/06_observe.sql', 'scenarios/07_extract_domain.sql',
    'scenarios/08_audit.sql', 'scenarios/09_propose_change.sql',
    'scenarios/10_owl_inference.sql',
]
VALIDATION_RECORDS = [
    'native-validation.json', 'c3-r4-validation.json', 'fresh-dev-validation.json',
    'sample-navigation-validation.json', 'context-delete-validation.json',
    'context-lifecycle-validation.json', 'context-search-validation.json',
    'release-v2-paths-validation.json',
]


def source_snapshot(root):
    """Identify the actual local inputs without exposing repository credentials."""
    def git(*args):
        return subprocess.run(['git', '-C', str(root), *args], check=True,
                              capture_output=True).stdout
    commit = git('rev-parse', 'HEAD').decode().strip()
    branch = git('branch', '--show-current').decode().strip()
    tracked = git('ls-files', '-z').decode().split('\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    changed = set(git('diff', '--name-only', 'HEAD', '-z').decode().split('\0')) | set(untracked)
    changed.discard('')
    digest = hashlib.sha256()
    for relative in sorted(set(tracked + untracked) - {''}):
        path = root / relative
        if not path.is_file():
            digest.update(relative.encode()+b'\0DELETED\0')
            continue
        raw = path.read_bytes()
        if b'\0' not in raw:
            raw = raw.replace(b'\r\n', b'\n')
        digest.update(relative.encode()+b'\0'+hashlib.sha256(raw).digest())
    return {'commit': commit, 'branch': branch, 'dirty': bool(changed),
            'changed_paths': sorted(changed), 'eligible_source_tree_sha256': digest.hexdigest(),
            'ignored_private_work_included': False}


def checked_validation_record(path):
    """Keep public records exact; reject unsafe records rather than silently redact them."""
    text = path.read_text(encoding='utf-8')
    json.loads(text)
    patterns = [r'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
                r'https?://[^\s"<>]*\.adb\.[^\s"<>]*oraclecloudapps\.com',
                r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
                r'ocid1\.[a-z0-9_]+\.[a-z0-9_.-]{20,}',
                r'https?://[^\s"<>]*(?:sharepoint\.com|onedrive\.live\.com|seismic\.com)',
                r'(?:C:\\\\Users\\\\|/mnt/c/Users/|/home/[^/\s]+/)']
    if any(re.search(pattern, text, re.I) for pattern in patterns):
        raise ValueError('Private data pattern in validation record: '+path.name)
    return text


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')


def summary_passages(root):
    """Own IDs/hashes; never present a paraphrase as a PDF extraction/quotation."""
    sources = {s['id']: s for s in pipeline.sources(root)}
    examples = pipeline.read(root / 'review-examples/examples.json')['examples']
    result = []
    for example in examples:
        source = sources[example['source_id']]
        page = example['pdf_page']
        if page not in source['selected_pdf_pages']:
            raise ValueError('Summary page is outside the reviewed source manifest')
        text = 'Editorial summary, not a quotation: ' + example['expected_statement']
        sha = pipeline.digest(text)
        result.append({'id': f"{source['version']['id']}-summary-p{page:03d}-{sha[:8]}",
            'source_id': source['id'], 'version_id': source['version']['id'],
            'pdf_page': page, 'chunk_index': 1, 'text': text, 'text_sha256': sha,
            'source_sha256': source['version']['sha256'],
            'extractor': 'editorial-summary-v1-not-pdf-extraction',
            'content_kind': 'attributed_editorial_summary',
            'locator_url': source['url'] + f'#page={page}',
            'qualification': 'Author-written summary linked to a public page; not verbatim source text or an accepted extracted claim.'})
    from kcv.editorial import catalogue_summary_passages
    result.extend(catalogue_summary_passages(root))
    if len({p['id'] for p in result}) != len(result):
        raise ValueError('Duplicate summary IDs')
    return result


def validate(folder):
    errors = []
    for p in folder.rglob('*'):
        if not p.is_file(): continue
        if p.suffix.lower() in {'.py', '.sh', '.ps1', '.pem', '.key', '.wallet', '.p12', '.sso', '.jks'}:
            errors.append('Unexpected developer/credential file: ' + str(p.relative_to(folder)))
        if p.suffix != '.md': continue
        text = p.read_text(encoding='utf-8')
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text):
            if '://' in target or target.startswith('#'): continue
            link = target.split('#')[0]
            if link:
                resolved=(p.parent/link).resolve()
                if not resolved.is_relative_to(folder.resolve()):
                    errors.append(str(p.relative_to(folder)) + ': link leaves release tree: ' + target)
                elif not resolved.exists():
                    errors.append(str(p.relative_to(folder)) + ': missing ' + target)
    if errors: raise ValueError('\n'.join(errors))


def build(output):
    output = Path(output).resolve()
    if output.exists(): raise ValueError('Use a new output folder; existing output is never deleted')
    # Cover validation and copying with the same source snapshot. A changed
    # public input must never become the baseline after its access check.
    snapshot = source_snapshot(ROOT)
    version = '1.0.0'
    receipt = None
    version_file = ROOT / 'VERSION'
    if version_file.exists():
        version = version_file.read_text(encoding='utf-8').strip()
        if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
            raise ValueError('VERSION must use major.minor.patch')
        if int(version.split('.')[0]) >= 2:
            # A new source tree plus an old engine export is not a v2 distribution.
            # This checks import/export provenance, not all release acceptance gates.
            receipt = verify_upgrade_export(ROOT)
    if (ROOT / 'data/public-content-summaries.json').exists():
        from kcv.editorial import validate_summary_basis
        validate_summary_basis(ROOT)
    # Every source needs an actual access result or an explicit public classification.
    from kcv.public_access import validate_url, public_rule, retained_publisher
    policy = pipeline.read(ROOT / 'references/public-source-policy.json')
    prefixes = policy['url_prefixes']
    checks = {r['source_id']: r for r in pipeline.read(ROOT / 'references/public-access-checks.json')['checks']}
    for source in pipeline.sources(ROOT) + pipeline.catalog(ROOT):
        checked = checks.get(source['id'], {})
        validate_url(source['url'])
        try:
            verified_at = datetime.fromisoformat(checked.get('checked_at',''))
        except (ValueError, TypeError):
            verified_at = None
        def location(url):
            validate_url(url)
            u = urlsplit(url)
            return (u.scheme, u.hostname.lower(), u.path, u.query)
        matched_rule = public_rule(source['url'],prefixes,source['title'],policy.get('title_rules',[]))
        if not matched_rule and not retained_publisher(source['url'],policy):
            raise ValueError('Industry or third-party reference still requires review: ' + source['id'])
        manual = checked.get('status') == 'manually_marked_public' and matched_rule and checked.get('public_rule') == matched_rule
        verified = checked.get('access_verified') is True and checked.get('http_status') == 200
        if (checked.get('status') not in {'verified_public','manually_marked_public'}
                or (checked.get('status') == 'manually_marked_public' and not manual)
                or (not verified and not manual)
                or checked.get('authentication_used') is not False or checked.get('cookies_used') is not False
                or verified_at is None or verified_at.tzinfo is None
                or location(checked.get('url','')) != location(source['url'])
                or checked.get('sha256') != source['version']['sha256']):
            raise ValueError('Missing or mismatched anonymous verification: ' + source['id'])
        if not verified:
            metadata = {k:source[k] for k in ['title','url','topics','business_domains','session_ids']}
            metadata_hash = hashlib.sha256(json.dumps(metadata,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
            if (not source['id'].startswith('R') or source['version'].get('hash_basis') != 'catalogue_metadata'
                    or checked.get('hash_basis') != 'catalogue_metadata' or not checked.get('reason')
                    or metadata_hash != source['version']['sha256']):
                raise ValueError('Unverified manual source must remain explicit catalogue metadata: ' + source['id'])
    # Reject an altered/unverified public input before requiring unrelated build
    # metadata. The same intake boundary can therefore be tested independently.
    schema_manifest = migrations.validate_manifest(ROOT)
    migrations.build(ROOT, check=True)
    verify_optional_baseline(ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix='kcv-release-') as temporary:
        stage = Path(temporary)
        def copy(relative):
            source = ROOT / relative
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir(): shutil.copytree(source, target)
            else: shutil.copy2(source, target)
        for relative in ['.gitattributes', '.gitignore', 'LICENSE.txt', 'NOTICE.md', 'VERSION',
                         'data', 'ontology', 'references', 'review-examples', 'third-party']:
            copy(relative)
        for relative in SQL_FILES:
            copy('sql/' + relative)
        for name in VALIDATION_RECORDS:
            relative = 'db/verification/' + name
            checked_validation_record(ROOT / relative)
            copy(relative)
        checked_validation_record(ROOT/'apex/export-validation.json')
        copy('apex/export-validation.json')
        copy('db/manifest.json')
        # This is an informational manifest, not a bundled Liquibase authoring tree.
        write(stage/'db/README.md', '# Schema provenance\n\nThe manifest records the immutable migration chain used to generate the supplied SQL. '
              'Payload/source paths describe dev authoring inputs; no Liquibase client is required. '
              'Deploy using the release installation guide and SQL scripts. Public validation records retain their own historical scopes.\n')
        # This is an explicit publication allowlist, never a copy of work/.
        for name in LABS: copy('labs/' + name)
        for name in DOCS: copy('docs/' + name)
        for name in ['verify_worksheet.sql', 'verify_scenario_native.sql', 'verify_github_dataset.sql',
                     'verify_source_packet_scope.sql']:
            copy('integration-test/' + name)
        copy('apex/kcv-explorer.sql')
        copy('apex/explorer.js')
        for name in ['model.svg']:
            copy('generated/' + name)
        # Release documentation is maintained separately from contributor docs.
        for p in (ROOT / 'release-docs').rglob('*'):
            if p.is_file():
                target = stage / p.relative_to(ROOT / 'release-docs')
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, target)
        passages = summary_passages(stage)
        pipeline.write(stage / 'work/passages.json', passages)
        report = pipeline.build(stage)
        export(stage)
        generate_github_dataset(stage, stage / 'data/load')
        installer = stage / 'sql/install'
        installer.mkdir(parents=True, exist_ok=True)
        manifest_hash = hashlib.sha256((stage / 'data/load/manifest.json').read_bytes()).hexdigest()
        write(installer / '10_load_github.sql', loader_script(manifest_hash))
        loader = (stage / 'work/worksheet/10_load_dataset.sql').read_text(encoding='utf-8')
        loader = loader.replace('-- Contains public-source passage text: keep this generated script local; do not commit it.',
            '-- Contains attributed editorial summaries, not extracted PDF text or source quotations.')
        write(installer / '10_load_dataset.sql', loader)
        shutil.copytree(stage / 'work/worksheet/dataset-parts', installer / 'dataset-parts')
        build_release_sql.build(ROOT, installer/'schema-parts')
        build_release_sql.package_recovery(ROOT, stage/'sql/recovery', schema_manifest)
        build_apex_installer(output=installer / '20_install_apex.sql', runtime_targets=True)
        build_apex_installer(output=installer / '20_upgrade_apex.sql', mode='upgrade', runtime_targets=True)
        pipeline.write(stage / 'data/release-summaries.json', {
            'content_kind': 'attributed_editorial_summary',
            'not_verbatim_source_text': True, 'passages': passages})
        report.update({'content_kind': 'attributed_editorial_summary',
            'full_source_text_location': 'Not bundled; summaries in data/release-summaries.json',
            'native_serverless_validation': 'release_summary_dataset_not_yet_run',
            'model_extraction': 'not_applicable', 'distribution': 'release'})
        pipeline.write(stage / 'generated/build-report.json', report)
        preview = (stage / 'generated/dataset-preview.md').read_text(encoding='utf-8')
        preview = preview.replace('Generated from real public editions;', 'Editorial summaries attributed to real public editions;')
        preview = preview.replace('real page-aware passages', 'attributed editorial summaries')
        preview = preview.replace('Actual passages are generated locally and not redistributed.',
            'Summary IDs and hashes identify the editorial text. Follow the PDF links to inspect the original pages.')
        write(stage / 'generated/dataset-preview.md', preview)
        # Change only the generated release copies, leaving dev's original path intact.
        for p in (stage / 'labs').rglob('*.md'):
            text = p.read_text(encoding='utf-8')
            text = text.replace('work/worksheet/10_load_dataset.sql', 'sql/install/10_load_dataset.sql')
            text = text.replace('work/worksheet/dataset-parts/', 'sql/install/dataset-parts/')
            text = text.replace('These are your generated files from the preparation lab.', 'These numbered files are supplied with the release; no local generation is needed.')
            text = text.replace('work/worksheet/20_install_apex.sql', 'sql/install/20_install_apex.sql')
            text = text.replace('your Oracle Linux generated files are accessible', 'the release SQL files are accessible')
            text = text.replace('generated `10_load_dataset.sql`', 'supplied `10_load_dataset.sql`')
            text = text.replace('your generated file from the preparation lab', 'the supplied release file checked in with this branch')
            text = text.replace('verified public passages', 'attributed editorial summaries')
            text = text.replace('Public evidence, native graph', 'Attributed summaries, native graph')
            if p.parent.name == 'load-knowledge':
                text = text.replace('regenerate the loader with the current project code', 'obtain an unchanged copy of the release loader')
                text = text.replace('regenerated loader', 'release loader')
                text = text.replace('Load verified passages', 'Load attributed editorial summaries')
                text = text.replace('Public evidence', 'Editorial summaries')
                text = text.replace('source data', 'summary data')
            if p.parent.name == 'explore-evidence':
                text = text.replace('complete saved passages', 'complete saved editorial summaries')
                text = text.replace('With the supplied baseline,', 'The release uses summaries rather than the extracted text shown in the screenshots. With the supplied baseline,')
            write(p, text)
        # Missing operational documentation is a packaging failure. Contributor
        # references must be deliberately expressed in release-docs, never hidden
        # by automatically rewriting broken links to a vague dev reference.
        for p in stage.rglob('*.md'):
            # LiveLabs uses these wrappers for its renderer. GitHub code blocks
            # must contain only copyable SQL, not the renderer's literal tags.
            text=p.read_text(encoding='utf-8')
            text=re.sub(r'(?m)^[ \t]*</?copy>[ \t]*\r?\n?', '', text)
            if re.search(r'</?copy>',text,re.I):
                raise ValueError('Unexpected inline LiveLabs copy wrapper: '+str(p.relative_to(stage)))
            write(p,text)
        # No private runtime or PDF extraction files are copied into the result.
        shutil.rmtree(stage / 'work')
        # Stable byte hashes across Windows/Linux clones; .gitattributes enforces LF.
        for p in stage.rglob('*'):
            if p.is_file() and p.suffix.lower() not in {'.png', '.jpg'}:
                write(p, p.read_text(encoding='utf-8'))
        write(stage/'release-provenance.json', json.dumps({
            'format_version': 1, 'product_version': version,
            'candidate_label': version+'-dev', 'distribution_status': 'unpromoted_candidate',
            'source': snapshot,
            'application_source_sha256': application_source_hash(ROOT),
            'application_export_sha256': hashlib.sha256((stage/'apex/kcv-explorer.sql').read_bytes()).hexdigest(),
            'schema_manifest_sha256': hashlib.sha256((stage/'db/manifest.json').read_bytes()).hexdigest(),
            'schema_ready_checkpoint': schema_manifest['migrations'][-1]['id'],
            'dataset_manifest_sha256': manifest_hash,
            'acceptance': {'export_receipt': 'apex/export-validation.json',
                           'release_paths_record': 'db/verification/release-v2-paths-validation.json',
                           'source_has_uncommitted_changes': snapshot['dirty'],
                           'package_generation_is_deployment_acceptance': False,
                           'worksheet_execution': 'not established by package generation',
                           'note': 'Historical receipts apply only to their recorded source and scope; the exact candidate requires its own fresh and upgrade acceptance.'}
        }, indent=2)+'\n')
        file_rows = [{'path': p.relative_to(stage).as_posix(),
                      'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                     for p in sorted(stage.rglob('*')) if p.is_file()]
        pipeline.write(stage / 'release-manifest.json', {'format_version': 1,
            'distribution': 'release', 'product_version': version,
            'candidate_label': version+'-dev', 'source_commit': snapshot['commit'],
            'source_dirty': snapshot['dirty'], 'python_required_for_learner': False,
            'dataset_kind': 'attributed_editorial_summary', 'summary_count': len(passages),
            'source_count': report['source_count'], 'catalogue_count': report['catalog_count'],
            'total_content_count': report['total_content_count'], 'files': file_rows})
        validate(stage)
        if source_snapshot(ROOT) != snapshot:
            raise ValueError('Source changed during packaging; rebuild from a stable reviewed tree')
        shutil.copytree(stage, output)
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'work/release-package')
    args = parser.parse_args()
    print(build(args.output))
