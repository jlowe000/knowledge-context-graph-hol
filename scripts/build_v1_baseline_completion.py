"""Generate the narrow SQL adapter for the published minimal v1 learning path.

This does not alter a frozen migration, connect to a database or adopt receipts.
The generated learner SQL only adds two absent optional baseline objects after
checking all required v1 contracts and any already-present optional objects.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts import build_database_installers as migration


OPTIONAL = {
    '1.0.0-020-kcv_domain_runs': ('KCV_DOMAIN_RUNS', 'TABLE', 'l_table_present'),
    '1.0.0-033-kcv_extract_domain-function': ('KCV_EXTRACT_DOMAIN', 'FUNCTION', 'l_function_present'),
}
OUTPUT = 'sql/install/00_complete_v1_optional.sql'


def render(root: Path = ROOT) -> str:
    manifest = migration.validate_manifest(root)
    baseline = [item for item in manifest['migrations'] if item['group'] == 'baseline']
    if len(baseline) != 36 or not set(OPTIONAL).issubset({item['id'] for item in baseline}):
        raise ValueError('Review the supported published v1 baseline before changing this adapter')
    parts = [
        '-- GENERATED: complete only optional objects omitted by the published v1 beginner path.',
        '-- Run as the existing password-enabled project owner before baseline adoption.',
        '-- No existing object is replaced, no model is invoked and no migration receipt is written.',
        '-- DDL commits independently. If interrupted, inspect the error and rerun only after resolving it.',
        'DECLARE',
        ' l_lock VARCHAR2(128);l_result PLS_INTEGER;l_sql CLOB;',
        ' l_table_present PLS_INTEGER;l_function_present PLS_INTEGER;l_added PLS_INTEGER:=0;',
        migration.VERIFY_DECLARATIONS,
        'BEGIN',
        " require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')",
        "  AND REGEXP_LIKE(SYS_CONTEXT('USERENV','SESSION_USER'),'^KCV_[A-Z0-9_]{1,26}$','c')",
        "  AND SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL,'Sign in as the existing project owner outside the APEX app');",
        " DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);",
        ' l_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);',
        " require(l_result=0,'Another migration or baseline completion is active');",
        " SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name='KCV_SCHEMA_MIGRATIONS';",
        " require(l_n=0,'A migration registry already exists; use the existing migration/recovery path, not v1 completion');",
        ' -- Verify every required object before considering either optional CREATE.',
    ]
    for item in baseline:
        if item['id'] not in OPTIONAL:
            parts.append(migration.read(root / item['verification']).strip())
    parts.append(' -- Existing optional objects must match exactly before any DDL is allowed.')
    selected = [item for item in baseline if item['id'] in OPTIONAL]
    for item in selected:
        name, kind, present = OPTIONAL[item['id']]
        parts.extend([
            f" SELECT COUNT(*) INTO {present} FROM user_objects WHERE object_name='{name}';",
            f' IF {present}>0 THEN',
            f"  SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name='{name}' AND object_type='{kind}';",
            f"  require(l_n=1,'The optional name {name} is occupied by an incompatible object');",
            migration.read(root / item['verification']).strip(),
            ' END IF;',
        ])
    parts.append(" DBMS_OUTPUT.PUT_LINE('KCV_V1_REQUIRED_CONTRACTS=PASS');")
    for item in selected:
        name, kind, present = OPTIONAL[item['id']]
        payload = migration.read(root / item['payload']).strip()
        if kind == 'TABLE':
            if not re.match(r'^CREATE\s+TABLE\s+kcv_domain_runs\b', payload, re.I):
                raise ValueError('Optional table payload identity changed')
        else:
            if migration.program_identity(payload) != ('KCV_EXTRACT_DOMAIN', 'FUNCTION'):
                raise ValueError('Optional function payload identity changed')
            # Never replace a function created concurrently or customized by a user.
            payload = re.sub(r'^CREATE\s+OR\s+REPLACE\s+', 'CREATE ', payload, count=1, flags=re.I)
        parts.extend([
            f' IF {present}=0 THEN',
            migration.clob_assignment('l_sql', payload),
            '  EXECUTE IMMEDIATE l_sql;',
            '  l_added:=l_added+1;',
            migration.read(root / item['verification']).strip(),
            ' END IF;',
        ])
    parts.extend([
        " DBMS_OUTPUT.PUT_LINE('KCV_V1_OPTIONAL_COMPLETION=PASS; objects_created='||l_added);",
        " DBMS_OUTPUT.PUT_LINE('Next: run the strict v1 baseline adoption script. No receipts were created by this helper.');",
        ' l_result:=DBMS_LOCK.RELEASE(l_lock);',
        'EXCEPTION WHEN OTHERS THEN',
        ' IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;',
        ' RAISE;',
        'END;',
        '/',
    ])
    return '\n'.join(parts) + '\n'


def build(root: Path = ROOT, check: bool = False) -> Path:
    target = root / OUTPUT
    migration.write_checked(target, render(root), check)
    print('Published v1 optional-object completion helper ' + ('checked' if check else 'written'))
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    build(check=parser.parse_args().check)
