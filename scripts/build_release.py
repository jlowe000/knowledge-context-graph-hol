"""Build the learner distribution without copying private work files.

Maintainer utility on dev only. This never modifies a Git branch or database.
"""
import argparse
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
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
from scripts import build_apexlang_zip as apexlang_zip
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

# These additions belong only to the prepared v2.1 experience. Developer
# schema/proxy bootstraps and contributor plans remain outside the distribution.
APEX_LED_SQL_FILES = [
    'admin/12_prepare_apexlang_rest.sql', 'admin/13_create_builder_login.sql',
    'admin/14_prepare_owner_credential.sql', 'admin/15_create_apex_owner.sql',
    'install/03_bind_deployment_owner.sql',
]
V1_BRIDGE_SQL_FILES = {'install/00_complete_v1_optional.sql', 'install/00_adopt_schema_baseline.sql'}
RELEASE_DOCUMENTS = ['README.md', 'apex/README.md'] + [
    'labs/'+name+'/'+name+'.md' for name in LABS + ['my-contexts', 'understand-collection']
] + ['docs/'+name+'.md' for name in (
    'architecture', 'authentication', 'cleanup', 'content-ingestion-upgrade', 'context-search',
    'fresh-serverless-deployment', 'github-dataset-load', 'installation-paths', 'learning-paths',
    'livelabs-authoring-alignment', 'migrate-to-v2', 'public-research-catalog', 'release-dataset',
    'scenario-validation', 'screenshots', 'sql-catalogue', 'ui-walkthrough', 'upstream-comparison')]
APEX_LED_DOCUMENTS = ['docs/'+name+'.md' for name in (
    'apex-led-installation', 'apex-led-upgrade', 'apex-led-administrator-preparation',
    'deployment-setup', 'deployment-recovery', 'migrate-to-v2.1', 'oracle-apex-skills')]
APEX_LED_ARCHIVE = 'apex/kcv-explorer.apx.zip'
APEX_LED_RECEIPT = 'apex/apexlang-validation.json'
V21_ACCEPTANCE = 'db/verification/release-v2.1-paths-validation.json'
V21_ROUTES = ('apex_led_clean', 'apex_led_upgrade', 'sql_first_clean', 'sql_first_upgrade')
TEXT_SUFFIXES = {'.md', '.json', '.sql', '.js', '.css', '.svg', '.ttl', '.owl',
                 '.xml', '.rq', '.csv', '.txt', '.yml', '.yaml', '.toml', '.nt', '.trig'}


def apex_led_version(version):
    return version.split('.')[:2] == ['2', '1']


def build_sql_first_app_installers(installer, *, include_script_inputs=False):
    """Keep bind delivery stable; optionally add explicit editable F5 templates.

    This generates transport artifacts only, never deployment acceptance. Each
    form uses the same reviewed native export and complete canonical verifier.
    """
    installer = Path(installer)
    outputs = []
    for name, mode in [('install', 'new'), ('upgrade', 'upgrade')]:
        outputs.append(build_apex_installer(output=installer/f'20_{name}_apex.sql',
                                            mode=mode, runtime_targets=True))
        if include_script_inputs:
            outputs.append(build_apex_installer(output=installer/f'20_{name}_apex_script.sql',
                                                mode=mode, worksheet_script_inputs=True))
    return outputs


def validation_path(version):
    return V21_ACCEPTANCE if apex_led_version(version) else 'db/verification/release-v2-paths-validation.json'


def normalize_release_text(stage):
    """Normalize known text only; accepted archives and other binary files stay exact."""
    for path in stage.rglob('*'):
        if path.is_file() and (path.suffix.lower() in TEXT_SUFFIXES
                               or path.name in {'.gitattributes', '.gitignore', 'VERSION'}):
            write(path, path.read_text(encoding='utf-8'))


def apexlang_declared_version(raw):
    values = re.findall(r'(?m)^[ \t]+version:[ \t]*(?:"([^"\n]+)"|([^\s]+))[ \t]*$',
                        raw.decode('utf-8'))
    if len(values) != 1:
        raise ValueError('Native application must have one unambiguous declared version')
    return values[0][0] or values[0][1]


def verify_publication_versions(stage, version):
    """Candidate labels may differ; published engine bytes must declare the release."""
    with zipfile.ZipFile(stage/APEX_LED_ARCHIVE) as archive:
        zip_version = apexlang_declared_version(archive.read('application.apx'))
    sql = (stage/'apex/kcv-explorer.sql').read_text(encoding='utf-8')
    sql_versions = re.findall(r"\bp_flow_version\s*=>\s*'((?:''|[^'])*)'", sql)
    if zip_version != version or sql_versions != [version]:
        raise ValueError('Publication requires both native ZIP and SQL application versions to equal VERSION; '
                         'change the authored version intentionally and refresh native exports/acceptance')


def reviewed_apexlang_package(root, version, archive_path, receipt_path, canonical_path):
    """Validate explicit native inputs, returning exact bytes and public evidence.

    The canonical input is inspected locally, never copied to the release. A
    native validation receipt does not certify either deployment route.
    """
    if not all((archive_path, receipt_path, canonical_path)):
        raise ValueError('v2.1 packaging requires --apexlang-zip, --apexlang-receipt and '
                         '--apexlang-canonical reviewed inputs; generation is not acceptance')
    archive_path, receipt_path, canonical_path = map(Path, (archive_path, receipt_path, canonical_path))
    if not archive_path.is_file() or archive_path.is_symlink():
        raise ValueError('Reviewed APEXlang ZIP is unavailable')
    receipt_text = checked_validation_record(receipt_path)
    receipt = json.loads(receipt_text)
    raw = archive_path.read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    schema_raw = (root/'db/manifest.json').read_text(encoding='utf-8').encode()
    schema = json.loads(schema_raw)
    canonical_raw = (canonical_path/'manifest.json').read_bytes()
    canonical = json.loads(canonical_raw)
    identities = {'product_version': version, 'archive_sha256': sha,
                  'application_source_sha256': application_source_hash(root),
                  'schema_manifest_sha256': hashlib.sha256(schema_raw).hexdigest(),
                  'canonical_supporting_manifest_sha256': hashlib.sha256(canonical_raw).hexdigest()}
    native = receipt.get('native_export', {})
    validation = receipt.get('native_zip_validation', {})
    security = receipt.get('security_review', {})
    if (receipt.get('format_version') != 1
            or any(receipt.get(key) != value for key, value in identities.items())
            or native.get('status') != 'passed' or native.get('format') != 'APEXLANG'
            or not re.fullmatch(r'26\.1(?:\.\d+)*', native.get('apex_version', ''))
            or validation.get('status') != 'passed' or validation.get('archive_sha256') != sha
            or not re.fullmatch(r'26\.1(?:\.\d+)*', validation.get('apex_version', ''))
            or security.get('status') != 'passed' or security.get('private_deployment_metadata') is not False):
        raise ValueError('APEXlang native/provenance receipt does not match the reviewed ZIP, source and schema')
    if (canonical.get('product_version') != version
            or canonical.get('canonical_manifest_sha256') != identities['schema_manifest_sha256']
            or canonical.get('ready_checkpoint') != schema['migrations'][-1]['id']
            or canonical.get('project_migrations') != len(schema['migrations'])
            or canonical.get('transport') != 'trusted-native-apex-builder'):
        raise ValueError('Canonical Supporting Objects input does not match the current schema contract')
    files = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = archive.infolist()
        if (len(entries) > apexlang_zip.ZIP_COUNT_LIMIT
                or sum(entry.file_size for entry in entries) > apexlang_zip.ZIP_TOTAL_LIMIT
                or sum(entry.compress_size for entry in entries) > apexlang_zip.ZIP_TOTAL_LIMIT):
            raise ValueError('APEXlang ZIP exceeds native default safety limits')
        folded = set()
        allowed = {'.apex', 'deployments', 'pages', 'shared-components', 'supporting-objects'}
        for entry in entries:
            name = entry.filename
            parts = apexlang_zip.safe_relative(name).parts
            mode = entry.external_attr >> 16
            if (entry.is_dir() or (mode & 0o170000) not in (0, 0o100000)
                    or entry.flag_bits & 1 or name.casefold() in folded
                    or (name != 'application.apx' and parts[0] not in allowed)
                    or (name.endswith('.sql') and not name.startswith('supporting-objects/'))):
                raise ValueError('Unexpected or duplicate native APEXlang ZIP entry: '+name)
            # Static assets are checked against the complete maintained inventory
            # below; other component directories cannot carry arbitrary files.
            if (parts[0] == '.apex' and name != '.apex/apexlang.json'
                    or parts[0] == 'pages' and not name.endswith('.apx')
                    or parts[0] == 'shared-components' and not name.startswith('shared-components/static-files/')
                       and not name.endswith('.apx')
                    or parts[0] == 'supporting-objects' and not name.endswith(('.apx', '.sql'))):
                raise ValueError('Unexpected native component file: '+name)
            if (entry.file_size > apexlang_zip.ZIP_ENTRY_LIMIT
                    or entry.compress_size > apexlang_zip.ZIP_ENTRY_LIMIT
                    or entry.file_size / max(1, entry.compress_size) > 200):
                raise ValueError('APEXlang ZIP entry exceeds native default safety limits')
            folded.add(name.casefold())
            files[name] = archive.read(entry)
        if sum(entry.file_size for entry in entries) / max(1, sum(entry.compress_size for entry in entries)) > 300:
            raise ValueError('APEXlang ZIP exceeds native default compression-ratio limit')
    for required in ('application.apx', '.apex/apexlang.json', 'supporting-objects/supporting-objects.apx'):
        if required not in files:
            raise ValueError('Incomplete flat native APEXlang ZIP: '+required)
    untouched = dict(files)
    omitted, deployment = apexlang_zip.portable_deployment(files)
    alias = apexlang_zip.portable_application_alias(files, 'KCV-EXPLORER')
    if omitted or files != untouched or alias['alias_normalized']:
        raise ValueError('ZIP must already have reviewed minimal deployment metadata and KCV-EXPLORER alias')
    mmd = json.loads(files['.apex/apexlang.json']).get('mmdVersion', '')
    if not re.fullmatch(r'26\.1\.\d+\+\d+', mmd):
        raise ValueError('Reviewed APEXlang ZIP must target APEX 26.1')
    ui_version = apexlang_declared_version(files['application.apx'])
    routes = apexlang_zip.supporting_scripts(files)
    apexlang_zip.verify_canonical(files, routes, canonical_path)
    assets = apexlang_zip.static_assets(files, root/'apex/application/shared-components/static-files')
    budget = apexlang_zip.validate_default_zip_budget(files)
    return {'archive_bytes': raw, 'receipt_text': receipt_text,
            'provenance': {**identities, 'receipt_sha256': hashlib.sha256(receipt_text.encode()).hexdigest(),
                           'canonical_script_roundtrip_checked': True, 'maintained_assets_checked': True,
                           'asset_count': len(assets), 'entry_count': len(files), 'mmd_version': mmd,
                           'application_declared_version': ui_version,
                           'native_default_zip_budget': budget, 'source_application_id': deployment['source_application_id'],
                           'source_id_is_target_binding': False, 'archive_bytes_preserved': True,
                           'package_generation_is_deployment_acceptance': False}}


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


def distribution_metadata(root, snapshot, version, prepare_publication=False):
    """Separate a local publication package from candidate and remote state."""
    if not prepare_publication:
        return {'candidate_label': version+'-dev', 'distribution_status': 'unpromoted_candidate'}
    if snapshot.get('dirty') is not False:
        raise ValueError('Publication packaging requires a clean committed source tree')
    if snapshot.get('branch') != 'dev' or not re.fullmatch(r'[a-f0-9]{40}', snapshot.get('commit', '')):
        raise ValueError('Publication packaging requires a committed dev source')
    record_path = root/validation_path(version)
    if not record_path.is_file():
        raise ValueError('Publication packaging requires a version-specific acceptance record: '+validation_path(version))
    record_text = checked_validation_record(record_path)
    record = json.loads(record_text)
    if apex_led_version(version):
        if (record.get('format_version') != 1 or record.get('product_version') != version
                or record.get('status') != 'passed' or record.get('pending_checks') != []
                or record.get('publication_approved') is not True
                or any(record.get('routes', {}).get(route, {}).get('status') != 'passed'
                       or record['routes'][route].get('pending_checks') != []
                       or ('upgrade' in route and record['routes'][route].get('from_product_version') != '2.0.0')
                       for route in V21_ROUTES)
                or not record.get('accepted_runtime_files')):
            raise ValueError('v2.1 publication requires explicit four-route acceptance and publication approval')
        return {'release_label': version, 'distribution_status': 'prepared_for_publication',
                'publication': {'remote_state': 'not_checked', 'push_performed': False, 'tag_created': False,
                                'acceptance_record_sha256': hashlib.sha256(record_text.encode()).hexdigest(),
                                'note': 'Local packaging only; exact accepted runtime comparison is required before publication.'}}
    passed = {'passed', 'passed_with_documented_execution_mode_correction'}
    if (record.get('product_version') != version or record.get('status') not in passed
            or record.get('pending_checks') != []
            or any(record.get(route, {}).get('status') not in passed
                   or record[route].get('pending_checks', []) != []
                   for route in ('clean_installation', 'migration'))):
        raise ValueError('Publication packaging requires recorded clean and migration acceptance for this version')
    return {'release_label': version, 'distribution_status': 'prepared_for_publication',
            'publication': {'remote_state': 'not_checked', 'push_performed': False,
                            'tag_created': False,
                            'acceptance_record_sha256': hashlib.sha256(record_text.encode('utf-8')).hexdigest(),
                            'note': 'Local packaging only. Historical acceptance retains its recorded scope; '
                                    'compare runtime artifacts with the accepted package before publishing.'}}


def runtime_inventory(stage):
    """Stable acceptance boundary without a self-hash of its own receipt."""
    excluded = {'release-provenance.json', 'release-manifest.json',
                'generated/build-report.json', V21_ACCEPTANCE}
    return {path.relative_to(stage).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(stage.rglob('*')) if path.is_file()
            and path.suffix.lower() != '.md' and path.relative_to(stage).as_posix() not in excluded}


def validate_sql_first_transport(route, route_record, actual):
    """Validate reviewed transport attestations against packaged file hashes.

    Target-filled copies remain private. Their execution/derivation evidence is
    identified by hashes, never by target values or private file locations. This
    gate checks those hashes' format and the scope of the reviewed attestation;
    it does not open the external evidence or prove that execution/derivation
    occurred. Source/template and complete package hashes are machine-checked.
    Equivalence is a reviewed attestation, not a positive execution claim.
    """
    def require(ok, detail):
        if not ok:
            raise ValueError('v2.1 SQL-first transport acceptance '+detail+': '+route)

    def digest(value):
        return isinstance(value, str) and re.fullmatch(r'[a-f0-9]{64}', value) is not None

    operation = 'upgrade' if route.endswith('upgrade') else 'install'
    allowed = {f'sql/install/20_{operation}_apex.sql',
               f'sql/install/20_{operation}_apex_script.sql'}
    packaged = allowed & set(actual)
    installation = route_record.get('application_installation', {})
    require(isinstance(installation, dict), 'is missing its installation record')
    transport = installation.get('transport_acceptance', {})
    require(isinstance(transport, dict) and transport.get('status') == 'passed',
            'requires an observed execution record')
    require(transport.get('evidence_basis') == 'reviewed_attestation',
            'must identify its external evidence as a reviewed attestation')
    source = transport.get('source_template_path')
    require(isinstance(source, str) and source in packaged, 'has an invalid source template')
    source_sha = transport.get('source_template_sha256')
    require(source_sha == actual[source]
            and route_record.get('artifacts', {}).get(source) == source_sha,
            'does not identify its exact source template')
    require(digest(transport.get('executed_variant_sha256'))
            and digest(transport.get('execution_evidence_sha256')),
            'requires executed-file and execution-evidence hashes')
    mode = transport.get('execution_mode')
    require(mode in {'Run Statement', 'Run Script'}, 'has an unsupported execution mode')
    derivation = transport.get('derivation', {})
    require(isinstance(derivation, dict), 'has an invalid derivation record')
    kind = derivation.get('kind')
    if kind == 'unchanged':
        require(not source.endswith('_script.sql') and mode == 'Run Statement'
                and transport['executed_variant_sha256'] == source_sha,
                'cannot claim an unchanged NULL template or a changed execution file')
    else:
        names = ['schema', 'workspace', 'alias']
        if operation == 'upgrade':
            names.append('application_id')
        require(kind == 'designated_nonsecret_input_substitutions' and mode == 'Run Script'
                and derivation.get('input_names') == names
                and derivation.get('reverse_substitution_byte_identical') is True
                and derivation.get('canonical_verifier_and_native_export_unchanged') is True
                and digest(derivation.get('proof_sha256'))
                and transport['executed_variant_sha256'] != source_sha,
                'requires the scoped nonsecret substitution attestation')
    equivalents = transport.get('equivalent_templates', [])
    require(isinstance(equivalents, list), 'has invalid equivalent-template evidence')
    remaining = packaged - {source}
    seen = set()
    for equivalent in equivalents:
        require(isinstance(equivalent, dict), 'has invalid equivalent-template evidence')
        path = equivalent.get('path')
        require(isinstance(path, str) and path in remaining and path not in seen,
                'has an unexpected or duplicate equivalent template')
        require(equivalent.get('sha256') == actual[path]
                and route_record.get('artifacts', {}).get(path) == actual[path]
                and equivalent.get('status') == 'reviewed_equivalent_provenance'
                and equivalent.get('positive_installation_executed') is False
                and equivalent.get('canonical_verifier_and_native_export_unchanged') is True
                and equivalent.get('differences') == 'input_declarations_and_fail_closed_guards_only'
                and digest(equivalent.get('proof_sha256')),
                'must distinguish reviewed equivalence from positive execution')
        seen.add(path)
    require(seen == remaining, 'does not cover the other packaged submission form')


def compare_v21_acceptance(root, stage):
    record = json.loads(checked_validation_record(root/V21_ACCEPTANCE))
    actual = runtime_inventory(stage)
    expected = record.get('accepted_runtime_files', {})
    if (not expected or set(expected) != set(actual)
            or any(not isinstance(value, str) or not re.fullmatch(r'[a-f0-9]{64}', value)
                   or value != actual[name] for name, value in expected.items())):
        raise ValueError('v2.1 runtime differs from its accepted package; four-route acceptance must identify these artifacts')
    common = {'db/manifest.json', 'sql/install/02_verify_schema.sql'}
    for route in V21_ROUTES:
        required = common | ({APEX_LED_ARCHIVE, APEX_LED_RECEIPT} if route.startswith('apex_led_') else {
            'apex/kcv-explorer.sql', 'apex/export-validation.json',
            'sql/install/03_bind_deployment_owner.sql'})
        observed = record['routes'][route].get('artifacts', {})
        if not required <= set(observed) or any(name not in actual or sha != actual[name] for name, sha in observed.items()):
            raise ValueError('v2.1 route acceptance does not identify its recorded artifacts: '+route)
        if route.startswith('sql_first_'):
            validate_sql_first_transport(route, record['routes'][route], actual)
    return {'comparison': 'passed', 'accepted_runtime_files': len(actual),
            'routes': list(V21_ROUTES), 'acceptance_record': V21_ACCEPTANCE,
            'sql_first_transport_evidence': 'reviewed_attestation',
            'scope': 'Exact non-document runtime hashes are machine-checked. SQL-first execution and '
                     'derivation evidence are reviewed attestations; external evidence files are not '
                     'revalidated by this builder. Generation does not create deployment acceptance.'}


def compare_accepted_package(root, stage, commit):
    """Bind publication-only changes to the previously accepted Git payload."""
    if not isinstance(commit, str) or not re.fullmatch(r'[a-f0-9]{40}', commit):
        raise ValueError('Supply the full accepted release commit for publication comparison')
    def committed_file(path):
        return subprocess.run(['git', '-C', str(root), 'show', commit+':'+path],
                              check=True, capture_output=True).stdout
    manifest_bytes = committed_file('release-manifest.json')
    accepted = json.loads(manifest_bytes)
    if accepted['product_version'] != (stage/'VERSION').read_text().strip():
        raise ValueError('Accepted release comparison must use the same product version')
    expected = {item['path']: item['sha256'] for item in accepted['files']}
    if len(expected) != len(accepted['files']):
        raise ValueError('Duplicate paths in accepted release manifest')
    actual = {p.relative_to(stage).as_posix(): p for p in stage.rglob('*') if p.is_file()}
    tree_bytes = subprocess.run(['git', '-C', str(root), 'ls-tree', '-r', '-z', commit],
                                check=True, capture_output=True).stdout
    tree = {}
    for entry in tree_bytes.split(b'\0'):
        if not entry:
            continue
        info, name = entry.split(b'\t', 1)
        mode, kind, oid = info.decode().split()
        if kind != 'blob' or mode not in {'100644', '100755'}:
            raise ValueError('Unexpected link or submodule in accepted release')
        tree[name.decode('utf-8')] = oid
    if set(tree) != set(expected) | {'release-manifest.json'}:
        raise ValueError('Accepted manifest inventory differs from its Git tree')
    def blob_id(raw, oid):
        digest = hashlib.sha1() if len(oid) == 40 else hashlib.sha256()
        digest.update(f'blob {len(raw)}\0'.encode())
        digest.update(raw)
        return digest.hexdigest()
    for name, digest in expected.items():
        # Reuse an identical staged blob; read only differing committed files.
        raw = actual[name].read_bytes() if name in actual else None
        if raw is None or blob_id(raw, tree[name]) != tree[name]:
            raw = committed_file(name)
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('Accepted manifest hash differs from its Git payload: '+name)
    metadata = {'release-provenance.json', 'release-manifest.json', 'generated/build-report.json'}
    changed_docs, comment_changes, matched = [], [], []
    for name in sorted((set(expected) | set(actual)) - metadata):
        if name.endswith('.md'):
            if name not in actual or name not in expected or hashlib.sha256(actual[name].read_bytes()).hexdigest() != expected[name]:
                changed_docs.append(name)
            continue
        if name not in actual or name not in expected:
            raise ValueError('Runtime file added or removed since accepted release: '+name)
        raw = actual[name].read_bytes()
        if hashlib.sha256(raw).hexdigest() == expected[name]:
            matched.append(name)
            continue
        if name == 'sql/install/10_load_github.sql':
            old = committed_file(name)
            old_header = b'-- KCV_LAB: install sql/schema/06_dataset_import.sql first. Run Script (F5).\n'
            new_header = (b'-- Project owner: complete the ordered v2 schema installation or migration first.\n'
                          b'-- Run sql/install/02_verify_schema.sql and configure the owner RDF network before loading.\n'
                          b'-- Run this caller with Run Script (F5).\n')
            if old.startswith(old_header) and raw == new_header + old[len(old_header):]:
                comment_changes.append(name)
                continue
        raise ValueError('Runtime differs from accepted release; new acceptance is required: '+name)
    return {'accepted_release_commit': commit,
            'accepted_manifest_sha256': hashlib.sha256(manifest_bytes).hexdigest(),
            'comparison': 'passed', 'unchanged_non_document_files': len(matched),
            'documentation_changes': changed_docs, 'exact_header_only_changes': comment_changes,
            'regenerated_metadata': sorted(metadata),
            'scope': 'All other payload files match accepted SHA-256 values. Historical acceptance records remain unchanged; no new database execution.'}


def build(output, *, prepare_publication=False, accepted_release_commit=None,
          apexlang_archive=None, apexlang_receipt=None, apexlang_canonical=None):
    output = Path(output).resolve()
    if output.exists(): raise ValueError('Use a new output folder; existing output is never deleted')
    # Cover validation and copying with the same source snapshot. A changed
    # public input must never become the baseline after its access check.
    snapshot = source_snapshot(ROOT)
    version = '1.0.0'
    receipt = None
    apexlang = None
    version_file = ROOT / 'VERSION'
    if version_file.exists():
        version = version_file.read_text(encoding='utf-8').strip()
        if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
            raise ValueError('VERSION must use major.minor.patch')
        if apex_led_version(version):
            # Missing ZIP inputs must fail with the new route's actionable gate,
            # rather than reporting only the unrelated historical SQL export.
            apexlang = reviewed_apexlang_package(ROOT, version, apexlang_archive,
                                                apexlang_receipt, apexlang_canonical)
        if int(version.split('.')[0]) >= 2:
            # A new source tree plus an old engine export is not a v2 distribution.
            # This checks import/export provenance, not all release acceptance gates.
            receipt = verify_upgrade_export(ROOT)
    distribution = distribution_metadata(ROOT, snapshot, version, prepare_publication)
    if prepare_publication and not apex_led_version(version) and not accepted_release_commit:
        raise ValueError('Supply the full accepted release commit for publication comparison')
    if apex_led_version(version) and accepted_release_commit:
        raise ValueError('v2.1 uses its four-route artifact record; the v2.0 publication-only commit gate is separate')
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
    if not apex_led_version(version):
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
            if apexlang and relative in V1_BRIDGE_SQL_FILES:
                continue  # v1 must use the published v2.0 bridge before this release.
            copy('sql/' + relative)
        if apexlang:
            for relative in APEX_LED_SQL_FILES:
                copy('sql/' + relative)
            (stage/APEX_LED_ARCHIVE).parent.mkdir(parents=True, exist_ok=True)
            (stage/APEX_LED_ARCHIVE).write_bytes(apexlang['archive_bytes'])
            write(stage/APEX_LED_RECEIPT, apexlang['receipt_text'])
            current_acceptance = json.loads(checked_validation_record(ROOT/V21_ACCEPTANCE))
            if current_acceptance.get('product_version') != version or current_acceptance.get('format_version') != 1:
                raise ValueError('v2.1 candidate acceptance record has the wrong version or format')
            copy(V21_ACCEPTANCE)
        for name in VALIDATION_RECORDS + (['apex-led-candidate-validation.json'] if apexlang else []):
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
        for relative in RELEASE_DOCUMENTS + (APEX_LED_DOCUMENTS if apexlang else []):
            source = ROOT/'release-docs'/relative
            target = stage/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
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
        build_sql_first_app_installers(installer, include_script_inputs=bool(apexlang))
        pipeline.write(stage / 'data/release-summaries.json', {
            'content_kind': 'attributed_editorial_summary',
            'not_verbatim_source_text': True, 'passages': passages})
        report.update({'content_kind': 'attributed_editorial_summary',
            'full_source_text_location': 'Not bundled; summaries in data/release-summaries.json',
            'native_serverless_validation': 'see_recorded_release_path_acceptance',
            'validation_record': validation_path(version),
            'package_generation_is_deployment_acceptance': False,
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
        normalize_release_text(stage)
        if apexlang and (stage/APEX_LED_ARCHIVE).read_bytes() != apexlang['archive_bytes']:
            raise ValueError('Packaging altered the reviewed APEXlang ZIP')
        if prepare_publication:
            if apexlang:
                verify_publication_versions(stage, version)
            distribution['publication']['accepted_runtime_comparison'] = (
                compare_v21_acceptance(ROOT, stage) if apex_led_version(version)
                else compare_accepted_package(ROOT, stage, accepted_release_commit))
        write(stage/'release-provenance.json', json.dumps({
            'format_version': 1, 'product_version': version,
            **distribution,
            'source': snapshot,
            'application_source_sha256': application_source_hash(ROOT),
            'application_export_sha256': hashlib.sha256((stage/'apex/kcv-explorer.sql').read_bytes()).hexdigest(),
            'schema_manifest_sha256': hashlib.sha256((stage/'db/manifest.json').read_bytes()).hexdigest(),
            'schema_ready_checkpoint': schema_manifest['migrations'][-1]['id'],
            'dataset_manifest_sha256': manifest_hash,
            **({'apexlang_package': apexlang['provenance']} if apexlang else {}),
            'acceptance': {'export_receipt': 'apex/export-validation.json',
                           'release_paths_record': validation_path(version),
                           'source_has_uncommitted_changes': snapshot['dirty'],
                           'package_generation_is_deployment_acceptance': False,
                           'worksheet_execution': 'not established by package generation',
                           'note': 'Historical receipts apply only to their recorded source and scope. '
                                   'Compare the generated runtime with the accepted package; changed runtime requires relevant fresh and upgrade acceptance.'}
        }, indent=2)+'\n')
        file_rows = [{'path': p.relative_to(stage).as_posix(),
                      'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                     for p in sorted(stage.rglob('*')) if p.is_file()]
        pipeline.write(stage / 'release-manifest.json', {'format_version': 1,
            'distribution': 'release', 'product_version': version,
            **distribution, 'source_commit': snapshot['commit'],
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
    parser.add_argument('--prepare-publication', action='store_true',
                        help='Require clean committed inputs and recorded installation-path acceptance; does not push or tag')
    parser.add_argument('--accepted-release-commit',
                        help='Full commit of the accepted same-version package; publication changes must preserve its runtime')
    parser.add_argument('--apexlang-zip', type=Path,
                        help='Explicit reviewed native APEXlang ZIP; copied without byte changes (required for v2.1)')
    parser.add_argument('--apexlang-receipt', type=Path,
                        help='Public native export/ZIP validation and provenance receipt for this exact archive')
    parser.add_argument('--apexlang-canonical', type=Path,
                        help='Reviewed canonical Supporting Objects candidate directory; inspected locally, never distributed')
    args = parser.parse_args()
    print(build(args.output, prepare_publication=args.prepare_publication,
                accepted_release_commit=args.accepted_release_commit,
                apexlang_archive=args.apexlang_zip, apexlang_receipt=args.apexlang_receipt,
                apexlang_canonical=args.apexlang_canonical))
