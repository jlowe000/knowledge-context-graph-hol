"""Wrap the unchanged APEX export blocks for one Database Actions script execution.

Uses supported installation-context APIs. Generated output stays local in work/.
SQL literal ampersands become equivalent CHR(38) expressions to avoid Worksheet
substitution. No application IDs, workspace IDs or private endpoints are bundled.
"""
import argparse
from pathlib import Path
import re
import hashlib
import json

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


def build(workspace='KCV_KNOWLEDGE',schema='KCV_LAB',alias='KCV-EXPLORER',output=None,mode='new'):
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
        schema_gate=""" EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:1 AND product_version=:2 AND phase=:3'
  INTO l_count USING '2.0.0-c3-r4-ready','2.0.0','COMPLETE';
 IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20163,'Apply and verify the v2 personal journey schema migration before importing this app');END IF;
 SELECT COUNT(*) INTO l_count FROM user_objects
  WHERE object_name IN ('KCV_ACCESS','KCV_PERSONAL_CONTEXT_API','KCV_PERSONAL_JOURNEY','KCV_SCENARIO','KCV_TRACE','KCV_APEX')
    AND object_type IN ('PACKAGE','PACKAGE BODY') AND status='VALID';
 IF l_count<>12 THEN RAISE_APPLICATION_ERROR(-20164,'Required personal journey and conversation APIs must compile before app installation');END IF;
"""
    install_context=""" APEX_APPLICATION_INSTALL.GENERATE_APPLICATION_ID;
 APEX_APPLICATION_INSTALL.GENERATE_OFFSET;
 l_app_id:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;
"""
    notice='Installs a NEW application ID, never overwrites by ID.'
    if mode=='upgrade':
        notice='UPGRADE: enter the existing application ID in the KCV_APPLICATION_ID bind prompt.'
        install_context=f""" l_app_id:=:KCV_APPLICATION_ID;
 IF l_app_id IS NULL OR l_app_id<=0 OR l_app_id<>TRUNC(l_app_id) THEN
   RAISE_APPLICATION_ERROR(-20161,'Supply an existing application ID');END IF;
 SELECT COUNT(*) INTO l_count FROM apex_applications
  WHERE application_id=l_app_id AND workspace='{workspace}'
    AND owner='{schema}' AND UPPER(alias)='{alias}';
 IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20162,'Application, workspace, alias and parsing schema must match');END IF;
 APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(l_app_id);
 APEX_APPLICATION_INSTALL.GENERATE_OFFSET;
"""
    sql=f"""-- KCV_LAB: Run Script once. {notice}
DECLARE
 l_app_id NUMBER;
 l_count NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'{schema}' THEN
   RAISE_APPLICATION_ERROR(-20160,'Use the intended parsing schema');END IF;
{schema_gate}\
 APEX_APPLICATION_INSTALL.SET_WORKSPACE('{workspace}');
 APEX_APPLICATION_INSTALL.SET_SCHEMA('{schema}');
{install_context}\
 APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS('{alias}');
"""+'\n'.join(blocks)+"\n DBMS_OUTPUT.PUT_LINE('KCV_APPLICATION_ID='||l_app_id);\nEND;\n/\n"
    if '&' in sql:raise ValueError('Unexpected ampersand outside a quoted export literal')
    target=Path(output) if output else ROOT/('work/worksheet/20_upgrade_apex.sql' if mode=='upgrade' else 'work/worksheet/20_install_apex.sql')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(sql,encoding='utf-8',newline='\n')
    return target


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--workspace',default='KCV_KNOWLEDGE');p.add_argument('--schema',default='KCV_LAB');p.add_argument('--alias',default='KCV-EXPLORER');p.add_argument('--output',type=Path)
    p.add_argument('--mode',choices=['new','upgrade'],default='new')
    a=p.parse_args();print(build(a.workspace,a.schema,a.alias,a.output,a.mode))
