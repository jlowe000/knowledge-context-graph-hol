"""Wrap the unchanged APEX export blocks for one Database Actions script execution.

Uses supported installation-context APIs. Generated output stays local in work/.
SQL literal ampersands become equivalent CHR(38) expressions to avoid Worksheet
substitution. No application IDs, workspace IDs or private endpoints are bundled.
"""
import argparse
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
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


def build(workspace='KCV_KNOWLEDGE',schema='KCV_LAB',alias='KCV-EXPLORER',output=None):
    for name,value in [('workspace',workspace),('schema',schema)]:
        if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,29}',value):raise ValueError('Invalid '+name)
    if not re.fullmatch(r'[A-Z][A-Z0-9-]{0,50}',alias):raise ValueError('Invalid application alias')
    blocks=list(export_blocks(ROOT/'apex/kcv-explorer.sql'))
    if not all(re.match(r'\s*begin\b',b,re.I) for b in blocks):
        raise ValueError('Expected only engine-generated anonymous PL/SQL export blocks')
    def escape_amp(match):
        return match.group().replace('&',"' || CHR(38) || '")
    # APEX exports use ordinary SQL literals, with doubled apostrophes. Preserve
    # their content exactly; no API names, components or argument values change.
    blocks=[re.sub(r"'(?:''|[^'])*'",escape_amp,b) for b in blocks]
    sql=f"""-- KCV_LAB: Run Script once. Installs a NEW application ID, never overwrites by ID.
DECLARE
 l_app_id NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'{schema}' THEN
   RAISE_APPLICATION_ERROR(-20160,'Use the intended parsing schema');END IF;
 APEX_APPLICATION_INSTALL.SET_WORKSPACE('{workspace}');
 APEX_APPLICATION_INSTALL.SET_SCHEMA('{schema}');
 APEX_APPLICATION_INSTALL.GENERATE_APPLICATION_ID;
 APEX_APPLICATION_INSTALL.GENERATE_OFFSET;
 APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS('{alias}');
 l_app_id:=APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;
"""+'\n'.join(blocks)+"\n DBMS_OUTPUT.PUT_LINE('KCV_APPLICATION_ID='||l_app_id);\nEND;\n/\n"
    if '&' in sql:raise ValueError('Unexpected ampersand outside a quoted export literal')
    target=Path(output) if output else ROOT/'work/worksheet/20_install_apex.sql'
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(sql,encoding='utf-8',newline='\n')
    return target


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--workspace',default='KCV_KNOWLEDGE');p.add_argument('--schema',default='KCV_LAB');p.add_argument('--alias',default='KCV-EXPLORER');p.add_argument('--output',type=Path)
    a=p.parse_args();print(build(a.workspace,a.schema,a.alias,a.output))
