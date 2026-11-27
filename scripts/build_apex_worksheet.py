"""Wrap the unchanged APEX export blocks for one Database Actions statement execution.

Uses supported installation-context APIs. Generated output stays local in work/.
SQL literal ampersands become equivalent CHR(38) expressions to avoid Worksheet
substitution. No application IDs, workspace IDs or private endpoints are bundled.
"""
import argparse
from pathlib import Path
import re
import hashlib
import json

from scripts import build_database_installers as migrations

ROOT=Path(__file__).resolve().parents[1]


def application_source_hash(root=ROOT):
    """Hash the complete authored application tree, with portable text endings."""
    folder=Path(root)/'apex/application'; digest=hashlib.sha256()
    for path in sorted(folder.rglob('*')):
        if not path.is_file():continue
        payload=path.read_text(encoding='utf-8').encode() if path.suffix in {'.apx','.js','.css'} else path.read_bytes()
        digest.update(path.relative_to(folder).as_posix().encode()+b'\0'+hashlib.sha256(payload).digest())
    return digest.hexdigest()


def verify_upgrade_export(root=ROOT):
    """Require the import/export acceptance receipt, not a stale v1 SQL file."""
    root=Path(root);receipt_path=root/'apex/export-validation.json'
    if not receipt_path.exists():
        raise ValueError('No validated v2 engine export: import the authored app, export SQL and record apex/export-validation.json first')
    receipt=json.loads(receipt_path.read_text(encoding='utf-8'))
    sql_hash=hashlib.sha256((root/'apex/kcv-explorer.sql').read_text(encoding='utf-8').encode()).hexdigest()
    if (receipt.get('application_source_sha256')!=application_source_hash(root)
            or receipt.get('export_sql_sha256')!=sql_hash
            or receipt.get('product_version')!=(root/'VERSION').read_text().strip()
            or receipt.get('engine_import_export_verified') is not True):
        raise ValueError('APEX export receipt is missing acceptance or does not match the current source/export/version')
    version=tuple(int(part) for part in (root/'VERSION').read_text().strip().split('.'))
    if version>=(2,1,0) and receipt.get('engine',{}).get('supporting_objects_exported') is not False:
        raise ValueError('SQL-first v2.1 exports must explicitly exclude Supporting Objects; install the canonical schema separately')
    return receipt
def export_blocks(path):
    pending=[]
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.lstrip().startswith('--') or re.match(r'^\s*(set |whenever |prompt |exit\b)',line,re.I):continue
        if line.strip()=='/':
            block='\n'.join(pending).strip()
            if block:yield block
            pending=[]
        else:pending.append(line)
    if any(x.strip() for x in pending):raise ValueError('Unterminated export block')


def schema_verification(root, version):
    """Reuse the canonical receipt/source/shape checks, never a parallel checklist."""
    manifest=migrations.validate_manifest(Path(root))
    items=manifest['migrations']
    if (manifest['target_product_version']!=version or not items
            or items[-1]['version']!=version):
        raise ValueError('The canonical schema checkpoint must match the application version')
    checkpoint=items[-1]
    digest=migrations.sha(checkpoint['payload_sha256']+':'+checkpoint['verification_sha256'])
    return f"""DECLARE l_checkpoint_count NUMBER;
BEGIN
 SELECT COUNT(*) INTO l_checkpoint_count FROM kcv_schema_migrations
  WHERE migration_id={migrations.literal(checkpoint['id'])}
    AND payload_sha256={migrations.literal(digest)} AND product_version={migrations.literal(version)}
    AND phase='COMPLETE' AND completed_at IS NOT NULL AND error_code IS NULL;
 IF l_checkpoint_count<>1 THEN
  RAISE_APPLICATION_ERROR(-20163,'Complete and verify the matching canonical schema installation or upgrade before importing this app');END IF;
{migrations.verification_block(Path(root),items)}END;
"""


def build(workspace='KCV_KNOWLEDGE',schema='KCV_LAB',alias='KCV-EXPLORER',output=None,mode='new',runtime_targets=False,worksheet_script_inputs=False):
    if worksheet_script_inputs and runtime_targets:
        raise ValueError('Choose either Worksheet bind prompts or editable Run Script inputs')
    if worksheet_script_inputs and (workspace,schema,alias)!=('KCV_KNOWLEDGE','KCV_LAB','KCV-EXPLORER'):
        raise ValueError('Run Script inputs are NULL placeholders; set target values in a private copy of the generated file')
    for name,value in [('workspace',workspace),('schema',schema)]:
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,29}',value):raise ValueError('Invalid '+name)
    if not re.fullmatch(r'[A-Z][A-Z0-9-]{0,50}',alias):raise ValueError('Invalid application alias')
    if mode not in {'new','upgrade'}:raise ValueError('Use new or upgrade installation mode')
    version_path=ROOT/'VERSION'
    version=version_path.read_text().strip() if version_path.exists() else '1.0.0'
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)',version):
        raise ValueError('VERSION must contain major.minor.patch')
    if mode=='upgrade' or int(version.split('.')[0])>=2:verify_upgrade_export(ROOT)
    blocks=list(export_blocks(ROOT/'apex/kcv-explorer.sql'))
    if not all(re.match(r'\s*begin\b',b,re.I) for b in blocks):
        raise ValueError('Expected only engine-generated anonymous PL/SQL export blocks')
    def escape_amp(match):
        return match.group().replace('&',"' || CHR(38) || '")
    # APEX exports use ordinary SQL literals, with doubled apostrophes. Preserve
    # their content exactly; no API names, components or argument values change.
    blocks=[re.sub(r"'(?:''|[^'])*'",escape_amp,b) for b in blocks]
    schema_gate=''
    if mode=='upgrade' or int(version.split('.')[0])>=2:
        schema_gate=schema_verification(ROOT,version)
    declarations=''
    target_checks=''
    workspace_sql,schema_sql,alias_sql=(f"'{workspace}'",f"'{schema}'",f"'{alias}'")
    if runtime_targets or worksheet_script_inputs:
        workspace_sql,schema_sql,alias_sql='l_workspace','l_schema','l_alias'
        if worksheet_script_inputs:
            declarations=""" -- Required nonsecret inputs: replace NULL with exact upper-case quoted names.
 -- Keep credentials and passwords out of this file. No target is inferred.
 l_schema VARCHAR2(128):=NULL;
 l_workspace VARCHAR2(128):=NULL;
 l_alias VARCHAR2(128):=NULL;
"""
            if mode=='upgrade':
                declarations+=""" -- Required existing application ID: replace NULL with its positive integer.
 l_existing_app_id NUMBER:=NULL;
"""
        else:
            declarations=f""" l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'{schema}');
 l_workspace VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'{workspace}');
 l_alias VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_APP_ALIAS)),'{alias}');
"""
        target_checks=""" IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
  OR NOT REGEXP_LIKE(l_workspace,'^[A-Z][A-Z0-9_]{0,29}$','c')
  OR NOT REGEXP_LIKE(l_alias,'^[A-Z][A-Z0-9-]{0,50}$','c') THEN
  RAISE_APPLICATION_ERROR(-20165,'Use valid project schema, workspace and application alias names');END IF;
"""
        if worksheet_script_inputs:
            # SQL NULL makes NOT REGEXP_LIKE evaluate to NULL, not TRUE. Reject
            # unset inputs explicitly before verification or installation APIs.
            target_checks=""" IF l_schema IS NULL OR l_workspace IS NULL OR l_alias IS NULL THEN
  RAISE_APPLICATION_ERROR(-20165,'Set all three nonsecret Run Script target inputs before execution');END IF;
"""+target_checks
    install_context=""" APEX_APPLICATION_INSTALL.GENERATE_APPLICATION_ID;
 APEX_APPLICATION_INSTALL.GENERATE_OFFSET;
 l_app_id:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;
"""
    notice='Installs a NEW application ID, never overwrites by ID.'
    if mode=='upgrade':
        notice=('UPGRADE: set the existing application ID in l_existing_app_id before execution.'
                if worksheet_script_inputs else 'UPGRADE: enter the existing application ID in the KCV_APPLICATION_ID bind prompt.')
        app_id_sql='l_existing_app_id' if worksheet_script_inputs else ':KCV_APPLICATION_ID'
        install_context=f""" l_app_id:={app_id_sql};
 IF l_app_id IS NULL OR l_app_id<=0 OR l_app_id<>TRUNC(l_app_id) THEN
   RAISE_APPLICATION_ERROR(-20161,'Supply an existing application ID');END IF;
 SELECT COUNT(*) INTO l_count FROM apex_applications
  WHERE application_id=l_app_id AND workspace={workspace_sql}
    AND owner={schema_sql} AND UPPER(alias)={alias_sql};
 IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20162,'Application, workspace, alias and parsing schema must match');END IF;
 APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(l_app_id);
 APEX_APPLICATION_INSTALL.GENERATE_OFFSET;
"""
    elif runtime_targets or worksheet_script_inputs:
        install_context=f""" SELECT COUNT(*) INTO l_count FROM apex_applications
  WHERE workspace={workspace_sql} AND UPPER(alias)={alias_sql};
 IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20166,'Application alias already exists; use the reviewed upgrade path or a different alias');END IF;
"""+install_context
    target_notice='-- Target binds may be left blank for KCV_LAB / KCV_KNOWLEDGE / KCV-EXPLORER.\n' if runtime_targets else ''
    binding_notice=('-- After import, run sql/install/03_bind_deployment_owner.sql separately with the\n'
                    '-- printed application ID and the same workspace, then complete guided setup.\n') if tuple(map(int,version.split('.'))) >= (2,1,0) else ''
    execution_notice=f"""-- Project schema owner: Run Statement once. {notice}
-- Select the complete DECLARE through final END; block, excluding the final slash (/).
-- Run Statement opens the required target/application-ID bind prompts.
"""
    if worksheet_script_inputs:
        execution_notice=f"""-- Project schema owner: Run Script (F5) once, after editing the required inputs below. {notice}
-- Load the complete file including the final slash (/). No external target binds are used.
-- Keep the edited copy private; do not change the verification or native export below.
-- After a timeout, inspect actual app/import state before retrying or switching delivery modes.
"""
    sql=f"""{execution_notice}\
{binding_notice}\
{target_notice}\
DECLARE
 l_app_id NUMBER;
 l_count NUMBER;
{declarations}\
BEGIN
{target_checks}\
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>{schema_sql}
  OR SYS_CONTEXT('USERENV','SESSION_USER')<>{schema_sql}
  OR USER<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR USER IN ('ADMIN','SYS','SYSTEM') THEN
   RAISE_APPLICATION_ERROR(-20160,'Connect as the intended parsing schema owner');END IF;
{schema_gate}\
 APEX_APPLICATION_INSTALL.SET_WORKSPACE({workspace_sql});
 APEX_APPLICATION_INSTALL.SET_SCHEMA({schema_sql});
{install_context}\
 APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS({alias_sql});
 -- Schema migration/binding are separate SQL-first steps, never an automatic import side effect.
 APEX_APPLICATION_INSTALL.SET_AUTO_INSTALL_SUP_OBJ(FALSE);
"""+'\n'.join(blocks)+"\n DBMS_OUTPUT.PUT_LINE('KCV_APPLICATION_ID='||l_app_id);\nEND;\n/\n"
    if '&' in sql:raise ValueError('Unexpected ampersand outside a quoted export literal')
    target=Path(output) if output else ROOT/('work/worksheet/20_upgrade_apex.sql' if mode=='upgrade' else 'work/worksheet/20_install_apex.sql')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(sql,encoding='utf-8',newline='\n')
    return target


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--workspace',default='KCV_KNOWLEDGE');p.add_argument('--schema',default='KCV_LAB');p.add_argument('--alias',default='KCV-EXPLORER');p.add_argument('--output',type=Path)
    p.add_argument('--mode',choices=['new','upgrade'],default='new')
    p.add_argument('--runtime-targets',action='store_true',help='Prompt for target names in SQL Worksheet; blanks use the supplied defaults')
    p.add_argument('--worksheet-script-inputs',action='store_true',help='Generate required NULL target inputs for a private edited copy run with Worksheet Run Script (F5); no bind prompts')
    a=p.parse_args();print(build(a.workspace,a.schema,a.alias,a.output,a.mode,a.runtime_targets,a.worksheet_script_inputs))
