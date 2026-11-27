"""Package canonical migration SQL as APEXlang Supporting Objects.

This is a deterministic authoring step, not an application export or database
runner. The default schema-owner transport is unchanged. The explicit Builder
transport uses the proven native identity boundary; its complete installation
still needs native acceptance. Neither route rewrites frozen payloads or includes
the application's own importer.
"""
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import build_database_installers as migrations
from scripts.build_release_sql import installation_steps


SYSTEM_PRIVILEGES = ('createTable', 'createView', 'createProcedure',
                     'createSequence', 'createType', 'createTrigger')
# Oracle's bundled APEXlang 26.1.0+3102 component metadata gives
# supportingObject.filePath = supporting-objects/supporting-objects#ext#.
# An arbitrary root filename can be silently ignored during engine import.
APEXLANG_PATH = 'supporting-objects/supporting-objects.apx'
OWNER_PRECHECK = """BEGIN
 RETURN SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM');
END;"""
UPGRADE_DETECTION = "SELECT 1 FROM user_tables WHERE table_name='KCV_SCHEMA_MIGRATIONS'"
APPROVED_DATASET_REF = '84d93fdad0b42d8e21affa9aa2b96312f15a0dfc'
APPROVED_DATASET_MANIFEST_SHA256 = 'dae8efdcd9e99874c8dfc3d9a3ccaf4a861f76b3b5442f71f075a6d9b64ef8ad'
OWNER_WRAPPER_GUARD = """ require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM'),'Connect as the intended project schema owner');"""
OWNER_BOOTSTRAP_GUARD = """ IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR SYS_CONTEXT('USERENV','SESSION_USER') IN ('ADMIN','SYS','SYSTEM') THEN
  RAISE_APPLICATION_ERROR(-20300,'Connect as the intended project schema owner'); END IF;"""


def builder_guard(check_target: bool = True) -> str:
    """Authorize the proven native Builder context, never a browser-supplied ID."""
    target = """
 a_app:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;
 ok(a_app>0 AND a_app=TRUNC(a_app),'APEX_INSTALL_FORBIDDEN: Native installation target is unavailable');
 SELECT COUNT(*),MAX(workspace) INTO a_n,a_workspace FROM apex_applications
  WHERE application_id=a_app AND owner=a_owner;
 ok(a_n=1 AND apex_util.find_security_group_id(p_workspace=>a_workspace)=a_workspace_id,
  'APEX_INSTALL_FORBIDDEN: Target application owner/workspace differs');
 SELECT COUNT(*) INTO a_n FROM apex_workspace_schemas WHERE workspace_name=a_workspace AND schema=a_owner;
 ok(a_n=1,'APEX_INSTALL_FORBIDDEN: Target workspace schema mapping differs');
 SELECT COUNT(*) INTO a_n FROM user_tables WHERE table_name='KCV_DEPLOY_STATE';
 IF a_n=1 THEN
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_deploy_state' INTO a_rows;
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_deploy_state WHERE singleton_id=1 '
   ||'AND schema_owner=:o AND workspace_id=:w AND application_id=:a' INTO a_n
   USING a_owner,a_workspace_id,a_app;
  ok(a_rows IN(0,1) AND a_n=a_rows,'APEX_INSTALL_FORBIDDEN: Existing installation is bound to a different target');
 END IF;
""" if check_target else ''
    return """DECLARE
 a_owner VARCHAR2(128):=SYS_CONTEXT('USERENV','CURRENT_USER');
 a_user VARCHAR2(255):=SYS_CONTEXT('APEX$SESSION','APP_USER');
 a_app NUMBER;a_workspace_id NUMBER;a_account NUMBER;a_n NUMBER;a_rows NUMBER;
 a_workspace VARCHAR2(255);a_roles VARCHAR2(4000);a_authenticated BOOLEAN;
 PROCEDURE ok(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20300,p_message);END IF;
 END;
BEGIN
 ok(a_owner=SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AND a_owner NOT IN('ADMIN','SYS','SYSTEM'),
  'APEX_INSTALL_FORBIDDEN: Effective parsing owner is required');
 ok(SYS_CONTEXT('APEX$SESSION','APP_ID')='4000' AND a_user IS NOT NULL
  AND UPPER(a_user) NOT IN('NOBODY','APEX_PUBLIC_USER'),
  'APEX_INSTALL_FORBIDDEN: Use authenticated App Builder Supporting Objects');
 a_authenticated:=apex_authentication.is_authenticated;
 ok(a_authenticated,'APEX_INSTALL_FORBIDDEN: Native Builder authentication is required');
 a_workspace_id:=apex_custom_auth.get_security_group_id;
 a_account:=apex_util.get_user_id(p_username=>a_user);
 a_roles:=apex_util.get_user_roles(p_username=>a_user);
 ok(a_workspace_id>0 AND a_account>0 AND INSTR(':'||UPPER(a_roles)||':',':ADMIN:')>0,
  'APEX_INSTALL_FORBIDDEN: A native workspace administrator is required');
""" + target + 'END;'


@contextmanager
def builder_rendering():
    """Replace only known transport guards before canonical CLOB serialization.

    No source file or frozen payload/verification is rewritten. The canonical
    effective-owner option supplies its separately audited read-only semantics.
    Restore the module hook even if generation rejects an unexpected wrapper.
    """
    original = migrations.wrapper

    def adapted(root, item, effective_owner=False):
        if not effective_owner:
            raise ValueError('APEX rendering requires explicit effective-owner verification')
        sql = original(root, item, effective_owner=True)
        if sql.count(OWNER_WRAPPER_GUARD) != 1:
            raise ValueError('Canonical migration owner guard shape changed')
        return sql.replace(OWNER_WRAPPER_GUARD, builder_guard())

    migrations.wrapper = adapted
    try:
        yield
    finally:
        migrations.wrapper = original


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


TRANSPORT_MAX_GZIP_BYTES = 4 * 1024 * 1024
TRANSPORT_MAX_SQL_BYTES = 16 * 1024 * 1024
TRANSPORT_READINESS_SQL = 'BEGIN NULL; END;'

# Exact decoder proven by the isolated native positive/negative owner probe.
TRANSPORT_DECODER = """ PROCEDURE free_transport_clob(p_value IN OUT NOCOPY CLOB) IS BEGIN
  IF DBMS_LOB.ISTEMPORARY(p_value)=1 THEN DBMS_LOB.FREETEMPORARY(p_value);END IF;p_value:=NULL;
 END;
 FUNCTION decode_sql(p_encoded CLOB,p_zip_sha VARCHAR2,p_sql_sha VARCHAR2,
  p_zip_bytes PLS_INTEGER,p_sql_bytes PLS_INTEGER) RETURN CLOB IS
  l_zip BLOB;l_plain BLOB;l_roundtrip BLOB;l_text CLOB;
  l_offset PLS_INTEGER:=1;l_piece VARCHAR2(8000);l_raw RAW(6000);
  l_dest INTEGER:=1;l_src INTEGER:=1;l_context INTEGER:=DBMS_LOB.DEFAULT_LANG_CTX;l_warning INTEGER;
  PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20310,p_message);END IF;
  END;
  PROCEDURE free_blob(p_value IN OUT NOCOPY BLOB) IS BEGIN
   IF DBMS_LOB.ISTEMPORARY(p_value)=1 THEN DBMS_LOB.FREETEMPORARY(p_value);END IF;p_value:=NULL;
  END;
  PROCEDURE cleanup IS BEGIN
   BEGIN free_blob(l_zip);EXCEPTION WHEN OTHERS THEN NULL;END;
   BEGIN free_blob(l_plain);EXCEPTION WHEN OTHERS THEN NULL;END;
   BEGIN free_blob(l_roundtrip);EXCEPTION WHEN OTHERS THEN NULL;END;
  END;
 BEGIN
  require(p_zip_bytes BETWEEN 1 AND 4194304 AND p_sql_bytes BETWEEN 1 AND 16777216,
   'KCV_TRANSPORT_SIZE: Declared script size is outside the bounded transport');
  require(LENGTH(p_zip_sha)=64 AND LENGTH(p_sql_sha)=64
   AND REGEXP_LIKE(p_zip_sha,'^[0-9a-f]{64}$') AND REGEXP_LIKE(p_sql_sha,'^[0-9a-f]{64}$'),
   'KCV_TRANSPORT_HASH: SHA256 metadata is invalid');
  require(DBMS_LOB.GETLENGTH(p_encoded)=4*CEIL(p_zip_bytes/3),
   'KCV_TRANSPORT_SIZE: Encoded length differs');
  DBMS_LOB.CREATETEMPORARY(l_zip,TRUE,DBMS_LOB.CALL);
  WHILE l_offset<=DBMS_LOB.GETLENGTH(p_encoded) LOOP
   l_piece:=DBMS_LOB.SUBSTR(p_encoded,8000,l_offset);
   require(LENGTH(l_piece)>0 AND MOD(LENGTH(l_piece),4)=0,
    'KCV_TRANSPORT_ENCODING: Invalid Base64 chunk boundary');
   l_raw:=UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(l_piece));
   DBMS_LOB.WRITEAPPEND(l_zip,UTL_RAW.LENGTH(l_raw),l_raw);l_offset:=l_offset+LENGTH(l_piece);
  END LOOP;
  require(DBMS_LOB.GETLENGTH(l_zip)=p_zip_bytes,'KCV_TRANSPORT_SIZE: Compressed length differs');
  require(LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(l_zip,DBMS_CRYPTO.HASH_SH256)))=p_zip_sha,
   'KCV_TRANSPORT_HASH: Compressed SHA256 differs');
  -- Only the fixed, hash-verified generated gzip stream is inflated.
  l_plain:=UTL_COMPRESS.LZ_UNCOMPRESS(l_zip);
  require(DBMS_LOB.GETLENGTH(l_plain)=p_sql_bytes,'KCV_TRANSPORT_SIZE: Expanded length differs');
  require(LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(l_plain,DBMS_CRYPTO.HASH_SH256)))=p_sql_sha,
   'KCV_TRANSPORT_HASH: SQL UTF8 SHA256 differs');
  DBMS_LOB.CREATETEMPORARY(l_text,TRUE,DBMS_LOB.CALL);
  DBMS_LOB.CONVERTTOCLOB(l_text,l_plain,DBMS_LOB.LOBMAXSIZE,l_dest,l_src,
   NLS_CHARSET_ID('AL32UTF8'),l_context,l_warning);
  require(l_warning=DBMS_LOB.NO_WARNING AND l_src=p_sql_bytes+1,
   'KCV_TRANSPORT_ENCODING: SQL UTF8 conversion was incomplete');
  -- Verify the exact UTF8 bytes again after conversion, before execution.
  DBMS_LOB.CREATETEMPORARY(l_roundtrip,TRUE,DBMS_LOB.CALL);
  l_dest:=1;l_src:=1;l_context:=DBMS_LOB.DEFAULT_LANG_CTX;
  DBMS_LOB.CONVERTTOBLOB(l_roundtrip,l_text,DBMS_LOB.LOBMAXSIZE,l_dest,l_src,
   NLS_CHARSET_ID('AL32UTF8'),l_context,l_warning);
  require(l_warning=DBMS_LOB.NO_WARNING AND l_src=DBMS_LOB.GETLENGTH(l_text)+1
   AND DBMS_LOB.GETLENGTH(l_roundtrip)=p_sql_bytes
   AND LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(l_roundtrip,DBMS_CRYPTO.HASH_SH256)))=p_sql_sha,
   'KCV_TRANSPORT_ENCODING: SQL UTF8 roundtrip differs');
  free_blob(l_zip);free_blob(l_plain);free_blob(l_roundtrip);RETURN l_text;
 EXCEPTION WHEN OTHERS THEN
  cleanup;BEGIN free_transport_clob(l_text);EXCEPTION WHEN OTHERS THEN NULL;END;RAISE;
 END;
"""


def transport_payload(sql: str) -> tuple[dict, str]:
    """Lossless deterministic transport of reviewed SQL, never remote code."""
    plain = sql.encode('utf-8')
    if not 0 < len(plain) <= TRANSPORT_MAX_SQL_BYTES:
        raise ValueError('Canonical SQL exceeds the bounded transport size')
    output = io.BytesIO()
    # Explicit filename/mtime and GzipFile make header bytes independent of
    # gzip.compress's Python-version-dependent OS byte behavior.
    with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as stream:
        stream.write(plain)
    compressed = output.getvalue()
    if not 0 < len(compressed) <= TRANSPORT_MAX_GZIP_BYTES:
        raise ValueError('Compressed canonical SQL exceeds the bounded transport size')
    if gzip.decompress(compressed) != plain:
        raise ValueError('Canonical SQL did not roundtrip through gzip')
    encoded = base64.b64encode(compressed).decode('ascii')
    return {'encoding': 'gzip-base64-utf8-v1', 'sql_sha256': digest(plain),
            'sql_bytes': len(plain), 'gzip_sha256': digest(compressed),
            'gzip_bytes': len(compressed), 'base64_characters': len(encoded)}, encoded


def transport_assignment(sql: str) -> str:
    metadata, encoded = transport_payload(sql)
    return (migrations.clob_assignment('l_encoded', encoded) + '\n'
            + f" l_step:=decode_sql(l_encoded,'{metadata['gzip_sha256']}','{metadata['sql_sha256']}',"
            + f"{metadata['gzip_bytes']},{metadata['sql_bytes']});\n"
            + ' free_transport_clob(l_encoded);')


def fenced(text: str, indent: int, language: str = 'sql') -> str:
    """Use real APEXlang multiline strings without altering embedded SQL."""
    if '\r' in text:
        raise ValueError('APEXlang source must use LF line endings')
    if '```' in text:
        raise ValueError('Text contains triple backticks that would terminate its APEXlang fence')
    pad = ' ' * indent
    return '\n'.join([pad + '```' + language,
                      *(pad + line for line in text.rstrip('\n').split('\n')),
                      pad + '```'])


def executable_script(step: str) -> str:
    """One indivisible canonical step; the APEX script runner owns the slash."""
    text = step.strip() + '\n/\n'
    if len(migrations.sql_units(text)) != 1:
        raise ValueError('Supporting Objects requires an intact single canonical step')
    inspected = re.sub(r'\bapex_application_install\s*\.\s*get_application_id\b', '', text, flags=re.I)
    if re.search(r'\b(?:wwv_flow_imp|apex_application_install)\b|20_install_apex', inspected, re.I):
        raise ValueError('Supporting Objects cannot recursively import the application')
    return text


def script_alias(kind: str, ordinal: int, step_id: str) -> str:
    if kind not in ('installScript', 'upgradeScript'):
        raise ValueError('Unsupported supporting script kind')
    if not re.fullmatch(r'[a-zA-Z0-9_.-]+', step_id):
        raise ValueError('Invalid canonical step identity')
    # These component types use property 1 (name) as identifierPropertyId.
    # Repeating a separate name property is rejected by the native compiler.
    return ('install' if kind == 'installScript' else 'upgrade') + '-' + f'{ordinal:03d}-{step_id}'


def render_script(kind: str, ordinal: int, step_id: str) -> str:
    """Use the actual engine export's external SQL layout, never inline SQL."""
    alias = script_alias(kind, ordinal, step_id)
    return (f'{kind} {alias} (\n'
            ' execution {\n'
            f'  sequence: {ordinal * 10}\n'
            ' }\n script {\n'
            f'  contentFile: {alias}.sql\n'
            ' }\n)\n')


def render_supporting(routes: dict[str, list[tuple[str, str]]], transport: str = 'schema-owner') -> dict[str, bytes]:
    """Render the native split definitions and byte-preserved external SQL.

    APEXlang terminates multiline fences at *any* triple backticks, including
    those inside SQL string literals. External SQL is therefore mandatory for
    the canonical payloads, not merely an optimization for their size.
    """
    precheck = OWNER_PRECHECK
    message = 'This candidate retains the schema-owner transport. Complete native APEX execution-identity acceptance before deployment.'
    if transport == 'apex-builder':
        precheck = 'BEGIN\n' + builder_guard(False) + '\nRETURN TRUE;\nEXCEPTION WHEN OTHERS THEN RETURN FALSE;END;'
        message = 'Use the authorised workspace administrator in App Builder and the prepared parsing schema. The target application is verified again before installation.'
    result = [
        'supportingObject (',
        ' advanced {', '  includeInAppExport: true', ' }',
        ' prerequisites {', '  systemPrivileges: [',
        *('   ' + privilege for privilege in SYSTEM_PRIVILEGES), '  ]', ' }',
        ' installation {', '  objectNames: KCV_SCHEMA_MIGRATIONS', ' }',
        ' upgrade {', '  upgradeWhenSqlQuery:', fenced(UPGRADE_DETECTION, 3), ' }',
        ' installationMessages {',
        '  welcome: Install the canonical project schema in the prepared environment.',
        '  confirmation: Database DDL commits independently. Review the target and prerequisites before continuing.',
        '  installSuccess: Schema scripts completed. Runtime configuration and collection readiness are separate checks.',
        '  installFailure: Stop and inspect the failed migration receipt. Do not skip a step or delete existing work.',
        ' }',
        ' upgradeMessages {',
        '  welcome: The migration registry was detected; its physical contract and receipts will be verified before mutation.',
        '  confirmation: Retain a verified backup and use the approved upgrade path. Collection updates are separate.',
        '  success: Schema verification completed. Existing runtime configuration and data were not refreshed by this package.',
        '  failure: Inspect the reported migration and use its reviewed recovery procedure before retrying.',
        ' }',
    ]
    result.extend([')', ''])
    validation = [
        'validation kcv-owner-transport (',
        ' execution {', '  sequence: 10', ' }',
        ' validation {', '  type: functionBody', '  language: plsql',
        '  plsqlFunctionBody:', fenced(precheck, 3, 'plsql'), ' }',
        ' error {', '  errorMessage: ' + message, ' }', ')', '',
    ]
    files = {APEXLANG_PATH: '\n'.join(result).encode('utf-8'),
             'supporting-objects/validations.apx': '\n'.join(validation).encode('utf-8')}
    for route, kind in (('install', 'installScript'), ('upgrade', 'upgradeScript')):
        definitions = []
        for ordinal, (step_id, sql) in enumerate(routes[route], 1):
            alias = script_alias(kind, ordinal, step_id)
            definitions.append(render_script(kind, ordinal, step_id))
            files[f'supporting-objects/{route}-scripts/{alias}.sql'] = sql.encode('utf-8')
        files[f'supporting-objects/{route}-scripts.apx'] = '\n'.join(definitions).encode('utf-8')
    return files


def builder_steps(root: Path, manifest: dict, route: str) -> list[tuple[str, str]]:
    """Render canonical steps, with a smaller plan only for a proven empty schema.

    The Builder install driver rejects every existing project object/registry
    before executing these steps. No successor or retired candidate can exist
    on that route, so retain each direct migration wrapper and final verifier
    without compiling unreachable upgrade/recovery branches. Do not apply this
    reduction to the upgrade route or the SQL-first installation helpers.
    """
    if route not in ('fresh', 'upgrade'):
        raise ValueError('Unknown Builder canonical route')
    with builder_rendering():
        if route == 'fresh':
            steps = [('bootstrap', migrations.BOOTSTRAP)]
            steps.extend((item['id'], migrations.wrapper(root, item, effective_owner=True))
                         for item in manifest['migrations'])
            steps.append(('final-schema-verification', migrations.verification_block(
                root, manifest['migrations'], effective_owner=True)))
        else:
            steps = installation_steps(root, manifest, route, effective_owner=True)
    if steps[0][0] != 'bootstrap' or steps[0][1].count(OWNER_BOOTSTRAP_GUARD) != 1:
        raise ValueError('Canonical bootstrap owner guard shape changed')
    steps[0] = ('bootstrap', steps[0][1].replace(OWNER_BOOTSTRAP_GUARD, builder_guard()))
    return steps


BUILDER_RETIRED_INDEX_AUDIT = '2.1.0-apl-unaccepted-index-verifier'
BUILDER_RETIRED_INDEX_ID = '2.1.0-apl-005-kcv_deploy_runs_recent'


def builder_retired_index_guard(root: Path, manifest: dict) -> str | None:
    """Read-only admission for the one observed, unaccepted Builder failure.

    The old readiness checkpoints contain superseded package bodies. Require
    every historical receipt, but inspect each latest object contract once and
    defer only aggregate *-ready physical checks until the replacement checkpoint
    completes. This is not a general partial-upgrade or failed-receipt bypass.
    """
    records = [record for record in migrations.retirement_records(root)
               if record['id'] == BUILDER_RETIRED_INDEX_AUDIT]
    if not records:
        return None
    if len(records) != 1:
        raise ValueError('Builder retirement audit must be unique')
    record = records[0]
    original = json.loads(migrations.read(root / record['original_manifest']))['migrations']
    prefix = original[:100]
    expected_suffix = [BUILDER_RETIRED_INDEX_ID,
                       '2.1.0-apl-006-kcv_deploy_contract-package',
                       '2.1.0-apl-007-kcv_deploy-package',
                       '2.1.0-apl-008-kcv_deploy-package-body',
                       '2.1.0-apl-009-backend-ready',
                       '2.1.0-apl-010-kcv_deploy_contract-package-body',
                       '2.1.0-apl-ready']
    if (record['applied_prefix_count'] != 100 or len(original) != 107
            or manifest['migrations'][:100] != prefix
            or prefix[-1]['id'] != '2.1.0-apl-004-kcv_deploy_runs'
            or [entry['migration']['id'] for entry in record['entries']] != expected_suffix):
        raise ValueError('Builder retirement must preserve the reviewed 100-step prefix')
    failed = record['entries'][0]
    if (failed['allowed_registry_state'] != 'ABSENT_OR_FAILED'
            or failed.get('error_code') != -20301
            or failed['migration']['payload_sha256'] != '3d92dd3e6cd87af17e33f5c50c152d13fd114196fbf04795977c48b923997645'
            or failed['migration']['verification_sha256'] != '4cea314f31f86be2e35d536c26d7968a06d404d54ca35bc390dab71914e94735'
            or any(entry['allowed_registry_state'] != 'ABSENT' for entry in record['entries'][1:])):
        raise ValueError('Builder retirement differs from the observed index-verifier failure')
    lines = ['DECLARE', ' l_repair PLS_INTEGER:=0;', migrations.VERIFY_DECLARATIONS, 'BEGIN',
             f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={migrations.literal(BUILDER_RETIRED_INDEX_ID)};",
             ' IF l_n<>0 THEN', migrations.retirement_guard(root)]
    for item in prefix:
        receipt_hash = migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256'])
        lines.extend([
            f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={migrations.literal(item['id'])}",
            f"  AND payload_sha256={migrations.literal(receipt_hash)} AND product_version={migrations.literal(item['version'])}",
            "  AND phase='COMPLETE' AND completed_at IS NOT NULL AND error_code IS NULL;",
            f" require(l_n=1,'Retirement prefix receipt differs: {item['id']}');"])
    active_ids = ','.join(migrations.literal(item['id']) for item in manifest['migrations'])
    lines.extend([
        f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id IN({active_ids}) AND phase<>'COMPLETE';",
        " require(l_n=0,'Retirement preflight cannot reconcile another incomplete active migration');"])
    seen = set()
    for item in prefix:
        successors = migrations.successor_chain(item, prefix)
        target = successors[-1] if successors else item
        if target['id'].endswith('-ready') or target['id'] in seen:
            continue
        seen.add(target['id'])
        lines.append(migrations.effective_owner_verification(root, target).strip())
    lines.extend([migrations.deployment_request_index_verification().strip(),
                  " SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE 'KCV\\_%' ESCAPE '\\' AND status='INVALID';",
                  " require(l_n=0,'Retirement prefix contains invalid project objects');",
                  " SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE 'KCV\\_%' ESCAPE '\\' AND attribute='ERROR';",
                  " require(l_n=0,'Retirement prefix contains compilation errors');",
                  ' l_repair:=1;', ' END IF;', ' :repair_required:=l_repair;', 'END;'])
    return '\n'.join(lines)


def builder_driver(root: Path, manifest: dict, route: str, steps: list[tuple[str, str]]) -> str:
    """One failure-stop native script, with locks retained across DDL commits.

    Each canonical migration still acquires its migration lock and records its
    reviewed receipts. All project-table SQL here is dynamic: none exists when
    Oracle first compiles this driver during a fresh installation.
    """
    if route not in ('install', 'upgrade'):
        raise ValueError('Unknown Builder route')
    gate = ''
    retired_guard = None
    if route == 'upgrade':
        known_v2 = [item for item in manifest['migrations'] if tuple(map(int, item['version'].split('.')[:3])) <= (2, 0, 0)]
        if not known_v2:
            raise ValueError('The Builder upgrade needs the reviewed v2 baseline')
        gate = (' PROCEDURE verify_published_v2 IS BEGIN\n'
            + transport_assignment(migrations.installed_contract_gate(
            root, known_v2, manifest['migrations'], effective_owner=True).strip())
            + '\n EXECUTE IMMEDIATE l_step;free_transport_clob(l_step);\n END;\n')
        retired_guard = builder_retired_index_guard(root, manifest)
        if retired_guard and sum(step_id == 'retired-candidate-preflight' for step_id, _ in steps) != 1:
            raise ValueError('Builder retirement requires one canonical replacement preflight')
    prefix = """DECLARE
 l_owner VARCHAR2(128):=SYS_CONTEXT('USERENV','CURRENT_USER');
 l_setup VARCHAR2(128);l_admission PLS_INTEGER;l_result PLS_INTEGER;
 l_setup_locked BOOLEAN:=FALSE;l_admission_locked BOOLEAN:=FALSE;
 l_step CLOB;l_encoded CLOB;l_n NUMBER;l_registry NUMBER;l_app NUMBER;l_workspace NUMBER;l_tablespace VARCHAR2(128);
 l_maintenance_changed BOOLEAN:=FALSE;l_mutation_started BOOLEAN:=FALSE;
 l_prior_state_exists BOOLEAN:=FALSE;l_prior_setting_exists BOOLEAN:=FALSE;
 l_prior_maintenance VARCHAR2(3);l_prior_updated TIMESTAMP WITH TIME ZONE;l_prior_setting VARCHAR2(4000);
 l_retired_repair PLS_INTEGER:=0;
""" + TRANSPORT_DECODER + """
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20300,p_message);END IF;
 END;
 FUNCTION exists_table(p_name VARCHAR2) RETURN BOOLEAN IS n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=p_name;RETURN n=1;
 END;
 PROCEDURE allocate_setup IS PRAGMA AUTONOMOUS_TRANSACTION;BEGIN
  DBMS_LOCK.ALLOCATE_UNIQUE('KCV_DEPLOY_'||l_owner,l_setup);COMMIT;
 END;
 PROCEDURE idle IS n NUMBER;BEGIN
  IF exists_table('KCV_CHAT_SESSIONS') THEN
   EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL' INTO n;
   require(n=0,'APEX_INSTALL_BUSY: Complete or recover the pending answer/refinement before maintenance');END IF;
  IF exists_table('KCV_RESPONSE_RUNS') THEN
   EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_response_runs WHERE status IN(''RUNNING'',''UNCERTAIN'')' INTO n;
   require(n=0,'APEX_INSTALL_BUSY: Complete or recover the pending answer before maintenance');END IF;
  IF exists_table('KCV_PERSONAL_OPERATIONS') THEN
   EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_personal_operations WHERE phase IN(''BUILDING'',''READY'')' INTO n;
   require(n=0,'APEX_INSTALL_BUSY: Complete or recover the pending context operation before maintenance');END IF;
  IF exists_table('KCV_CONTEXT_DELETIONS') THEN
   EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_context_deletions WHERE status=''PENDING''' INTO n;
   require(n=0,'APEX_INSTALL_BUSY: Complete or recover the pending deletion before maintenance');END IF;
  IF exists_table('KCV_DEPLOY_RUNS') THEN
   EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_deploy_runs WHERE status=''RUNNING''' INTO n;
   require(n=0,'APEX_INSTALL_BUSY: Complete or recover the pending setup request');END IF;
 END;
 PROCEDURE maintenance_on IS BEGIN
  IF exists_table('KCV_SETTINGS') THEN
   EXECUTE IMMEDIATE 'MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k) '
    ||'WHEN MATCHED THEN UPDATE SET setting_value=''ON'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''ON'')';
  END IF;
  IF exists_table('KCV_DEPLOY_STATE') THEN
   EXECUTE IMMEDIATE 'UPDATE kcv_deploy_state SET maintenance=''ON'',updated_at=SYSTIMESTAMP WHERE singleton_id=1';
  END IF;COMMIT;
 END;
 PROCEDURE snapshot_maintenance IS BEGIN
  IF exists_table('KCV_DEPLOY_STATE') THEN
   BEGIN EXECUTE IMMEDIATE 'SELECT maintenance,updated_at FROM kcv_deploy_state WHERE singleton_id=1'
    INTO l_prior_maintenance,l_prior_updated;l_prior_state_exists:=TRUE;
   EXCEPTION WHEN NO_DATA_FOUND THEN NULL;END;
  END IF;
  IF exists_table('KCV_SETTINGS') THEN
   BEGIN EXECUTE IMMEDIATE 'SELECT setting_value FROM kcv_settings WHERE setting_key=''APP_MAINTENANCE'''
    INTO l_prior_setting;l_prior_setting_exists:=TRUE;
   EXCEPTION WHEN NO_DATA_FOUND THEN NULL;END;
  END IF;
 END;
 PROCEDURE restore_maintenance IS BEGIN
  -- Only before the first canonical mutation: keep existing ON and absent rows.
  IF l_prior_state_exists THEN
   EXECUTE IMMEDIATE 'UPDATE kcv_deploy_state SET maintenance=:m,updated_at=:t WHERE singleton_id=1'
    USING l_prior_maintenance,l_prior_updated;
  END IF;
  IF exists_table('KCV_SETTINGS') THEN
   IF l_prior_setting_exists THEN
    EXECUTE IMMEDIATE 'UPDATE kcv_settings SET setting_value=:v WHERE setting_key=''APP_MAINTENANCE''' USING l_prior_setting;
   ELSE EXECUTE IMMEDIATE 'DELETE FROM kcv_settings WHERE setting_key=''APP_MAINTENANCE''';END IF;
  END IF;COMMIT;
 END;
 PROCEDURE unlock_all(p_raise BOOLEAN DEFAULT TRUE) IS failure_code NUMBER:=0;BEGIN
  BEGIN
   IF l_admission_locked THEN
    l_result:=DBMS_LOCK.RELEASE(l_admission);
    IF l_result=0 THEN l_admission_locked:=FALSE;ELSE failure_code:=l_result;END IF;
   END IF;
  EXCEPTION WHEN OTHERS THEN failure_code:=SQLCODE;END;
  BEGIN
   IF l_setup_locked THEN
    l_result:=DBMS_LOCK.RELEASE(l_setup);
    IF l_result=0 THEN l_setup_locked:=FALSE;ELSE failure_code:=l_result;END IF;
   END IF;
  EXCEPTION WHEN OTHERS THEN failure_code:=SQLCODE;END;
  IF failure_code<>0 THEN
   DBMS_OUTPUT.PUT_LINE('KCV installer lock cleanup code: '||TO_CHAR(failure_code));
   IF p_raise THEN RAISE_APPLICATION_ERROR(-20302,'APEX_INSTALL_BUSY: Installer lock cleanup needs owner review');END IF;
  END IF;
 END;
""" + gate + """BEGIN
""" + builder_guard() + '\n' + transport_assignment(TRANSPORT_READINESS_SQL) + """
 -- Exercise required built-ins and UTF8 conversion before locks or mutation.
 free_transport_clob(l_step);
 allocate_setup;l_result:=DBMS_LOCK.REQUEST(l_setup,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_result=0,'APEX_INSTALL_BUSY: Another installer/setup operation is active');l_setup_locked:=TRUE;
 l_admission:=DBMS_UTILITY.GET_HASH_VALUE('KCV_WRITE_ADMISSION:'||l_owner,1,1073741823);
 l_result:=DBMS_LOCK.REQUEST(id=>l_admission,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
 require(l_result=0,'APEX_INSTALL_BUSY: A learner write is being admitted');l_admission_locked:=TRUE;
 idle;
 SELECT COUNT(*) INTO l_registry FROM user_tables WHERE table_name='KCV_SCHEMA_MIGRATIONS';
"""
    if route == 'install':
        prefix += """ require(l_registry=0,'APEX_INSTALL_CONFLICT: Existing migration history needs the upgrade or reviewed owner recovery route');
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE 'KCV\\_%' ESCAPE '\\';
 require(l_n=0,'APEX_INSTALL_CONFLICT: Existing project objects need the reviewed upgrade or owner recovery route');
"""
    else:
        allowed_ids = [item['id'] for item in manifest['migrations']]
        for record in migrations.retirement_records(root):
            allowed_ids.extend(entry['migration']['id'] for entry in record['entries'])
        query = 'SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id NOT IN(' + ','.join(migrations.literal(mid) for mid in allowed_ids) + ')'
        prefix += (" require(l_registry=1,'APEX_INSTALL_CONFLICT: Upgrade requires the verified published v2 installation');\n"
                   + ' EXECUTE IMMEDIATE ' + migrations.literal(query) + ' INTO l_n;\n'
                   + " require(l_n=0,'APEX_INSTALL_CONFLICT: Unknown or newer migration history must not be downgraded');\n")
        if retired_guard:
            prefix += (transport_assignment(retired_guard)
                       + '\n EXECUTE IMMEDIATE l_step USING OUT l_retired_repair;free_transport_clob(l_step);\n'
                       + ' IF l_retired_repair=0 THEN verify_published_v2;END IF;\n')
        else:
            prefix += ' verify_published_v2;\n'
    prefix += " snapshot_maintenance;l_maintenance_changed:=TRUE;maintenance_on;idle;\n"
    body = []
    for ordinal, (step_id, sql) in enumerate(steps, 1):
        body.append(f" DBMS_OUTPUT.PUT_LINE({migrations.literal(f'KCV schema step {ordinal}/{len(steps)}: {step_id}')});")
        body.append(transport_assignment(sql.strip()))
        body.append(' l_mutation_started:=TRUE;EXECUTE IMMEDIATE l_step;')
        body.append(' free_transport_clob(l_step);')
        if retired_guard and step_id == 'retired-candidate-preflight':
            body.append(' IF l_retired_repair=1 THEN verify_published_v2;END IF;')
        if step_id == '1.0.0-001-kcv_settings':
            # The fresh route cannot set a settings row before this table exists.
            body.append(' maintenance_on;')
    final = '\n' + builder_guard() + """
 idle;
 l_app:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;
 l_workspace:=apex_custom_auth.get_security_group_id;
 SELECT tablespace_name INTO l_tablespace FROM user_tables WHERE table_name='KCV_SETTINGS';
 require(l_tablespace IS NOT NULL,'APEX_INSTALL_CONFLICT: Prepared project tablespace is unavailable');
 SELECT COUNT(*) INTO l_n FROM user_tablespaces WHERE tablespace_name=l_tablespace;
 require(l_n=1,'APEX_INSTALL_CONFLICT: Prepared project tablespace is unavailable');
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_deploy_state' INTO l_n;
 IF l_n=0 THEN
  EXECUTE IMMEDIATE 'INSERT INTO kcv_deploy_state(singleton_id,schema_owner,workspace_id,application_id,network_tablespace,maintenance) '
   ||'VALUES(1,:o,:w,:a,:t,''ON'')' USING l_owner,l_workspace,l_app,l_tablespace;
 ELSE
  require(l_n=1,'APEX_INSTALL_CONFLICT: Installation binding is not a singleton');
  EXECUTE IMMEDIATE 'UPDATE kcv_deploy_state SET maintenance=''ON'',updated_at=SYSTIMESTAMP WHERE singleton_id=1';
 END IF;
 -- Bind and both maintenance flags commit together. No profile/data is reset.
 maintenance_on;
 DBMS_OUTPUT.PUT_LINE('KCV Supporting Objects completed. Learning remains paused; continue to Deployment setup.');
 unlock_all;
EXCEPTION WHEN OTHERS THEN
 ROLLBACK;
 BEGIN free_transport_clob(l_step);EXCEPTION WHEN OTHERS THEN NULL;END;
 BEGIN free_transport_clob(l_encoded);EXCEPTION WHEN OTHERS THEN NULL;END;
 IF l_mutation_started THEN
  BEGIN maintenance_on;EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('KCV maintenance fence cleanup code: '||TO_CHAR(SQLCODE));END;
 ELSIF l_maintenance_changed THEN
  BEGIN restore_maintenance;EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('KCV maintenance restore code: '||TO_CHAR(SQLCODE));END;
 END IF;
 unlock_all(FALSE);RAISE;
END;
"""
    return prefix + '\n'.join(body) + final


def artifacts(root: Path = ROOT, transport: str = 'schema-owner') -> dict[str, bytes]:
    """Return a complete candidate, validating immutable inputs first."""
    root = Path(root)
    if transport not in ('schema-owner', 'apex-builder'):
        raise ValueError('Unknown Supporting Objects transport')
    manifest = migrations.validate_manifest(root)
    migration_map = {item['id']: item for item in manifest['migrations']}
    routes, files = {}, {}
    metadata = {
        'format_version': 1,
        'product_version': manifest['target_product_version'],
        'ready_checkpoint': manifest['migrations'][-1]['id'],
        'canonical_manifest_sha256': digest(migrations.read(root / 'db/manifest.json').encode()),
        'project_migrations': len(manifest['migrations']),
        'transport': 'canonical-schema-owner' if transport == 'schema-owner' else 'trusted-native-apex-builder',
        'native_apex_execution': 'not_validated',
        'engine_export_generated': False,
        'contains_application_importer': False,
        'route_detection_is_authorization': False,
        'apexlang_path': APEXLANG_PATH,
        'routes': {},
    }
    if transport == 'apex-builder':
        metadata.update({'canonical_steps': {}, 'ddl_is_transactional': False,
                         'one_failure_stop_driver_per_route': True,
                         'initial_v2_upgrade_requires_quiescent_maintenance_window': True,
                         'canonical_sql_transport': 'gzip-base64-utf8-v1',
                         'transport_decoder_sha256': digest(TRANSPORT_DECODER.encode('utf-8')),
                         'transport_max_gzip_bytes': TRANSPORT_MAX_GZIP_BYTES,
                         'transport_max_sql_bytes': TRANSPORT_MAX_SQL_BYTES,
                         'transport_normalizations': ['known-owner-guard-to-authenticated-builder',
                                                      'reviewed-read-only-effective-owner-verification'],
                         'effective_owner_declarations_sha256': migrations.sha(migrations.VERIFY_DECLARATIONS),
                         'public_target_id_source': 'APEX_APPLICATION_INSTALL.GET_APPLICATION_ID'})
    for route, canonical_route in (('install', 'fresh'), ('upgrade', 'upgrade')):
        steps = (builder_steps(root, manifest, canonical_route) if transport == 'apex-builder'
                 else installation_steps(root, manifest, canonical_route))
        routes[route] = [(step_id, executable_script(sql)) for step_id, sql in steps]
        rows = []
        for ordinal, (step_id, sql) in enumerate(routes[route], 1):
            path = f'scripts/{route}/{ordinal:03d}-{step_id}.sql'
            data = sql.encode('utf-8'); files[path] = data
            row = {'ordinal': ordinal, 'sequence': ordinal * 10, 'step_id': step_id,
                   'path': path, 'sha256': digest(data), 'bytes': len(data), 'atomic': True}
            if transport == 'apex-builder':
                row['transport'], _ = transport_payload(steps[ordinal - 1][1].strip())
            if step_id in migration_map:
                item = migration_map[step_id]
                row['migration'] = {key: item[key] for key in
                                    ('id', 'version', 'payload_sha256', 'verification_sha256', 'depends_on')}
                row['receipt_sha256'] = migrations.sha(item['payload_sha256'] + ':' + item['verification_sha256'])
                if transport == 'apex-builder':
                    rendered_verify = migrations.effective_owner_verification(root, item)
                    row['rendered_verification_sha256'] = migrations.sha(rendered_verify)
                    row['verification_identity_normalized'] = row['rendered_verification_sha256'] != item['verification_sha256']
            rows.append(row)
        if transport == 'apex-builder':
            metadata['canonical_steps'][route] = rows
            script = executable_script(builder_driver(root, manifest, route, steps))
            path = f'drivers/{route}.sql'; data = script.encode('utf-8'); files[path] = data
            step_id = 'trusted-installation'
            routes[route] = [(step_id, script)]
            metadata['routes'][route] = [{'ordinal': 1, 'sequence': 10, 'step_id': step_id,
                                          'path': path, 'sha256': digest(data), 'bytes': len(data),
                                          'atomic': True, 'canonical_step_count': len(rows)}]
        else:
            metadata['routes'][route] = rows
    files.update(render_supporting(routes, transport))
    metadata['apexlang_sha256'] = digest(files[APEXLANG_PATH])
    metadata['native_supporting_files'] = [
        {'path': path, 'sha256': digest(data), 'bytes': len(data)}
        for path, data in sorted(files.items()) if path.startswith('supporting-objects/')]
    metadata['largest_atomic_script_bytes'] = max(row['bytes'] for route in metadata['routes'].values() for row in route)
    files['manifest.json'] = (json.dumps(metadata, indent=2) + '\n').encode('utf-8')
    return files


def write_artifacts(output: Path, files: dict[str, bytes], check: bool = False) -> None:
    """Write a new directory, or verify existing bytes without modifying them."""
    output = Path(output)
    if check:
        actual = {path.relative_to(output).as_posix() for path in output.rglob('*') if path.is_file()}
        if actual != set(files):
            raise ValueError('Supporting Objects candidate file inventory differs')
        for name, data in files.items():
            if (output / name).read_bytes() != data:
                raise ValueError('Supporting Objects candidate is stale: ' + name)
    else:
        output.mkdir(parents=True, exist_ok=False)
        for name, data in files.items():
            path = output / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)


def build(output: Path, root: Path = ROOT, check: bool = False, transport: str = 'schema-owner') -> dict:
    """Write only a new candidate directory, or compare an existing one read-only."""
    files = artifacts(root, transport)
    write_artifacts(output, files, check)
    return json.loads(files['manifest.json'])


def replacement_contract_verification(root: Path, prefix: list[dict],
                                      replaces_body_migration: str) -> tuple[str, dict]:
    """Verify history and current objects without hashing the replacement itself.

    Only an explicit, latest historical contract body can lose its physical
    comparison. Its receipt remains mandatory. Every aggregate readiness chain
    must already resolve to a new nonrecursive backend checkpoint.
    """
    own_identity = ('KCV_DEPLOY_CONTRACT', 'PACKAGE BODY')
    identities = {item['id']: migrations.program_identity(
        migrations.read(root / item['payload']).strip()) for item in prefix}
    selected = [item for item in prefix if item['id'] == replaces_body_migration]
    if len(selected) != 1 or identities.get(replaces_body_migration) != own_identity:
        raise ValueError('Replacement requires one explicit historical contract body migration')
    previous = selected[0]
    anchor = prefix[-1]
    if (not anchor['id'].endswith('-backend-ready')
            or prefix.index(previous) >= len(prefix) - 1):
        raise ValueError('Replacement prefix must end at a later backend-ready boundary')
    historical = [item for item in prefix if identities[item['id']] == own_identity]
    for item in historical:
        successors = migrations.successor_chain(item, prefix)
        latest = successors[-1] if successors else item
        if latest['id'] != replaces_body_migration:
            raise ValueError('Ambiguous historical contract bodies or own body included in prefix')
    checkpoints = [item for item in prefix if item['id'].endswith('-ready')]
    if not any(prefix.index(previous) < prefix.index(item) < len(prefix) - 1
               for item in checkpoints):
        raise ValueError('Replacement needs a preceding aggregate readiness checkpoint')
    for item in checkpoints:
        successors = migrations.successor_chain(item, prefix)
        latest = successors[-1] if successors else item
        if latest['id'] != anchor['id']:
            raise ValueError('Every aggregate checkpoint must resolve to the new backend-ready boundary')

    # The new anchor uses the existing canonical literal program-digest form.
    # Its complete program set must match the actual prefix, with only this
    # package body omitted. This rejects stale, missing and self-body digests.
    latest_programs = {}
    for item in prefix:
        identity = identities[item['id']]
        if identity and identity != own_identity:
            latest_programs[identity] = migrations.sha(migrations.canonical_program(
                migrations.read(root / item['payload']).strip()))
    anchor_sql = migrations.effective_owner_verification(root, anchor).strip()
    calls = re.findall(r"check_digest\('([^']+)','([^']+)','([0-9a-f]{64})'\);", anchor_sql)
    if (len(calls) != len(latest_programs)
            or {(name, kind): value for name, kind, value in calls} != latest_programs):
        raise ValueError('Backend-ready digests must verify every current program except the contract body')
    without_spec = re.sub(
        r"(?m)^[ \t]*check_digest\('KCV_DEPLOY_CONTRACT','PACKAGE','[0-9a-f]{64}'\);[ \t]*$",
        '', anchor_sql)
    if re.search(r'KCV_DEPLOY_CONTRACT', without_spec, re.IGNORECASE):
        raise ValueError('Backend-ready verifier cannot reference the old or replacement contract body')

    statements = [migrations.retirement_guard(root)]
    statements.extend(migrations.receipt_check(item) for item in prefix)
    physical, seen = [], set()
    for item in prefix:
        successors = migrations.successor_chain(item, prefix)
        target = successors[-1] if successors else item
        if target['id'] == replaces_body_migration or target['id'] in seen:
            continue
        seen.add(target['id'])
        statements.append(migrations.effective_owner_verification(root, target).strip())
        physical.append({key: target[key] for key in ('id', 'verification_sha256')})
    verification = ('DECLARE\n' + migrations.VERIFY_DECLARATIONS + '\nBEGIN\n'
                    + '\n'.join(statements)
                    + "\n DBMS_OUTPUT.PUT_LINE('KCV replacement-prefix schema verification passed');\nEND;\n")
    metadata = {'replaces_body_migration': replaces_body_migration,
                'historical_body_receipts_retained': [item['id'] for item in historical],
                'physical_body_check_omitted': replaces_body_migration,
                'backend_ready_boundary': anchor['id'],
                'physical_targets_checked_once': physical}
    return verification, metadata


def contract_artifacts(root: Path = ROOT, *, through_migration: str,
                       target_version: str | None = None,
                       target_checkpoint: str | None = None,
                       replaces_body_migration: str | None = None) -> dict[str, bytes]:
    """Generate the read-only readiness contract against an explicit prefix.

    Freeze the contract spec, deployment tables/APIs and their postconditions
    before generating its body. The body verifies that preceding prefix. It must
    not hash/verify itself; the final-ready migration and full standalone schema
    verifier remain responsible for the body and the complete target contract.
    """
    root = Path(root)
    manifest = migrations.validate_manifest(root)
    items = manifest['migrations']
    positions = [index for index, item in enumerate(items) if item['id'] == through_migration]
    if len(positions) != 1:
        raise ValueError('Contract prefix must end at one existing reviewed migration')
    prefix = items[:positions[0] + 1]
    if replaces_body_migration is None:
        for item in prefix:
            if migrations.program_identity(migrations.read(root / item['payload']).strip()) == ('KCV_DEPLOY_CONTRACT', 'PACKAGE BODY'):
                raise ValueError('Contract verifier cannot include its own body in the hashed prefix')
    version = target_version or manifest['target_product_version']
    checkpoint = target_checkpoint or items[-1]['id']
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?', version) or len(version) > 20:
        raise ValueError('Invalid target product version')
    if not re.fullmatch(r'[a-z0-9][a-z0-9._-]{0,100}', checkpoint):
        raise ValueError('Invalid target checkpoint identity')
    if replaces_body_migration is not None and checkpoint in {item['id'] for item in prefix}:
        raise ValueError('Replacement final checkpoint must remain outside the verified prefix')
    prefix_contract = [{key: item[key] for key in ('id', 'payload_sha256', 'verification_sha256', 'depends_on')} for item in prefix]
    prefix_sha256 = digest(json.dumps(prefix_contract, separators=(',', ':'), sort_keys=True).encode())
    spec = """-- GENERATED candidate. Freeze as a new immutable migration before use.
CREATE OR REPLACE PACKAGE kcv_deploy_contract AUTHID DEFINER AS
 PROCEDURE verify_schema;
 FUNCTION target_version RETURN VARCHAR2;
 FUNCTION target_checkpoint RETURN VARCHAR2;
 FUNCTION dataset_ref RETURN VARCHAR2;
 FUNCTION dataset_manifest_sha256 RETURN VARCHAR2;
END kcv_deploy_contract;
/\n"""
    replacement_metadata = None
    if replaces_body_migration is None:
        verify = migrations.verification_block(root, prefix, effective_owner=True)
    else:
        verify, replacement_metadata = replacement_contract_verification(root, prefix, replaces_body_migration)
    if not verify.startswith('DECLARE\n'):
        raise ValueError('Canonical verifier declaration shape changed')
    body = (f'-- GENERATED candidate; verified prefix SHA-256 {prefix_sha256}.\n'
            '-- The final-ready migration/full verifier checks this body separately.\n'
            'CREATE OR REPLACE PACKAGE BODY kcv_deploy_contract AS\n'
            ' PROCEDURE verify_schema IS\n' + verify.removeprefix('DECLARE\n') + '\n')
    for name, value in (('target_version', version), ('target_checkpoint', checkpoint),
                        ('dataset_ref', APPROVED_DATASET_REF),
                        ('dataset_manifest_sha256', APPROVED_DATASET_MANIFEST_SHA256)):
        body += f' FUNCTION {name} RETURN VARCHAR2 IS BEGIN RETURN {migrations.literal(value)}; END;\n'
    body += 'END kcv_deploy_contract;\n/\n'
    files = {'kcv_deploy_contract.spec.sql': spec.encode('utf-8'),
             'kcv_deploy_contract.body.sql': body.encode('utf-8')}
    metadata = {'format_version': 1, 'status': 'candidate_not_frozen_or_executed',
                'product_version': version, 'target_checkpoint': checkpoint,
                'prefix_end': through_migration, 'prefix_sha256': prefix_sha256,
                'verified_migrations': prefix_contract,
                'excludes_own_body': True, 'full_standalone_verifier_still_required': True,
                'verification_execution_owner': 'CURRENT_USER',
                'dataset_ref': APPROVED_DATASET_REF,
                'dataset_manifest_sha256': APPROVED_DATASET_MANIFEST_SHA256,
                'files': {name: {'sha256': digest(data), 'bytes': len(data)} for name, data in files.items()}}
    if replacement_metadata is not None:
        metadata['replacement_contract'] = replacement_metadata
    files['manifest.json'] = (json.dumps(metadata, indent=2) + '\n').encode()
    return files


def build_contract(output: Path, root: Path = ROOT, check: bool = False, **kwargs) -> dict:
    files = contract_artifacts(root, **kwargs)
    write_artifacts(output, files, check)
    return json.loads(files['manifest.json'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--transport', choices=('schema-owner', 'apex-builder'), default='schema-owner')
    parser.add_argument('--contract-through', help='Generate only the deployment contract through this existing migration ID')
    parser.add_argument('--target-version')
    parser.add_argument('--target-checkpoint')
    parser.add_argument('--replaces-body-migration', help='Explicit historical contract body replaced after the new backend-ready prefix')
    args = parser.parse_args()
    if args.contract_through:
        result = build_contract(args.output, check=args.check, through_migration=args.contract_through,
                                target_version=args.target_version, target_checkpoint=args.target_checkpoint,
                                replaces_body_migration=args.replaces_body_migration)
        print(f"Contract generated against {len(result['verified_migrations'])} preceding migrations; not frozen or executed")
    else:
        if args.target_version or args.target_checkpoint or args.replaces_body_migration:
            parser.error('Target overrides apply only with --contract-through')
        result = build(args.output, check=args.check, transport=args.transport)
        print(f"{result['project_migrations']} canonical migrations packaged; full native APEX execution remains unvalidated")
