"""Build/check immutable SQL migrations and Worksheet bundles from an ordered manifest.

This is a local build utility, never a database runner. It does not discover credentials,
connect to a database, modify Git refs, or make a native-validation claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = 'http://www.liquibase.org/xml/ns/dbchangelog'


def sha(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def read(path: Path) -> str:
    return path.read_text(encoding='utf-8').replace('\r\n', '\n')


def sql_units(text: str) -> list[str]:
    """Only the project's slash-delimited source convention; no general SQL parser."""
    result, pending = [], []
    for line in text.splitlines():
        if line.lstrip().startswith('--'):
            continue
        if line.strip() == '/':
            unit = '\n'.join(pending).strip()
            if unit:
                result.append(unit)
            pending = []
        else:
            pending.append(line)
    if any(line.strip() for line in pending):
        raise ValueError('SQL source has an unterminated unit; use slash separators')
    return result


def literal(text: str) -> str:
    # Runtime SQL is local reviewed source, never a downloaded remote payload.
    return "'" + text.replace("'", "''").replace('&', "' || CHR(38) || '") + "'"


def clob_assignment(name: str, text: str) -> str:
    parts = [f" {name}:=TO_CLOB('');"]
    for start in range(0, len(text), 700):
        parts.append(f' {name}:={name}||TO_CLOB({literal(text[start:start+700])});')
    return '\n'.join(parts)


def canonical_program(unit: str) -> str:
    source = re.sub(r'^CREATE\s+OR\s+REPLACE\s+', '', unit, flags=re.I)
    return '\n'.join(line.rstrip() for line in source.splitlines()
                     if line.strip() and not line.lstrip().startswith('--')).strip() + '\n'


def program_identity(unit: str):
    match = re.match(r'CREATE\s+OR\s+REPLACE\s+(PACKAGE\s+BODY|PACKAGE|FUNCTION|PROCEDURE)\s+(\w+)', unit, re.I)
    return (match[2].upper(), ' '.join(match[1].upper().split())) if match else None


VERIFY_DECLARATIONS = r"""
 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN (' ',CHR(9),CHR(10),CHR(13),'"') THEN r:=r||UPPER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status='VALID';
  require(n=1,'Missing or invalid program: '||p_name||' '||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute='ERROR';
  require(n=0,'Compilation errors: '||p_name||' '||p_type);
  FOR r IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>'--' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||' ')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,'Installed source differs: '||p_name||' '||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_column VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string('name');cols:=t.get_array('columns');cs:=t.get_array('constraints');
  wanted_temp:=t.get_string('temporary');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,'Missing or incompatible table: '||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,'Column count differs: '||name);
  FOR i IN 0..cols.get_size-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string('name');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identity_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,'Missing column: '||name||'.'||c.get_string('name')); END;
   require(actual_type=c.get_string('type'),'Column type differs: '||name||'.'||c.get_string('name'));
   require(actual_nullable=c.get_string('nullable'),'Column nullability differs: '||name||'.'||c.get_string('name'));
   IF c.has('length') THEN
    require(len=c.get_number('length'),'Column length differs: '||name||'.'||c.get_string('name'));
    require(char_semantics=c.get_string('char_used'),'Column character semantics differ: '||name||'.'||c.get_string('name'));
   END IF;
   IF c.get_string('type')='NUMBER' THEN
    require(NVL(prec,-1)=NVL(c.get_number('precision'),-1) AND NVL(sc,-99)=NVL(c.get_number('scale'),-99),'Number precision differs: '||name||'.'||c.get_string('name'));
   END IF;
   require(ident=c.get_string('identity'),'Column identity differs: '||name||'.'||c.get_string('name'));
   IF ident='NO' THEN d:=def;require(NVL(compact(d),'#NULL#')=NVL(compact(c.get_string('default')),'#NULL#'),'Column default differs: '||name||'.'||c.get_string('name'));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;wanted_constraint:=c.get_string('type');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status='ENABLED' AND validated='VALIDATED'
      AND deferrable='NOT DEFERRABLE' AND (constraint_type<>'R' OR (delete_rule='NO ACTION' AND r_owner=USER))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_columns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type='C' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string('expression')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_string('columns') THEN
     IF r.constraint_type='R' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string('reference_table') AND refcols=c.get_string('reference_columns') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
   require(found,'Missing or incompatible constraint: '||name||' '||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r.constraint_type<>'C' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),'^[A-Z][A-Z0-9_$]*ISNOTNULL$') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,'Unexpected constraints: '||name);
 END;
"""


def table_verification(contract: dict) -> str:
    return clob_assignment('l_expected', json.dumps(contract, separators=(',', ':'))) + '\n check_table(l_expected);'


def program_verification(unit: str) -> str:
    identity = program_identity(unit)
    if not identity:
        raise ValueError('Not a program source')
    return clob_assignment('l_expected', canonical_program(unit)) + f'\n check_program({literal(identity[0])},{literal(identity[1])},l_expected);'


def validate_manifest(root: Path = ROOT) -> dict:
    manifest = json.loads(read(root / 'db/manifest.json'))
    if manifest['format_version'] != 1:
        raise ValueError('Unsupported migration manifest format')
    if (root / 'VERSION').exists() and manifest['target_product_version'] != read(root / 'VERSION').strip():
        raise ValueError('Migration target does not match the maintained product VERSION')
    seen = set()
    retired = {target for item in manifest['migrations'] for target in item.get('supersedes', [])}
    retired_once = set()
    for item in manifest['migrations']:
        if item['id'] in seen or not re.fullmatch(r'[a-z0-9][a-z0-9._-]{0,100}', item['id']):
            raise ValueError('Invalid or duplicate migration ID')
        if any(dep not in seen for dep in item['depends_on']):
            raise ValueError('Migration dependency must appear earlier: ' + item['id'])
        for target in item.get('supersedes', []):
            if target not in seen or target in retired_once:
                raise ValueError('Supersession must uniquely replace an earlier postcondition: ' + item['id'])
            retired_once.add(target)
        for key in ('payload', 'verification'):
            path = (root / item[key]).resolve()
            if not path.is_relative_to((root / 'db').resolve()) or not path.is_file():
                raise ValueError('Migration path must be a local db/ file')
            if sha(read(path)) != item[key + '_sha256']:
                raise ValueError('Immutable migration hash mismatch: ' + item[key])
        if item['group'] == 'feature' and 'source_unit' in item and item['id'] not in retired:
            source = (root / item['source_path']).resolve()
            if not source.is_relative_to((root / 'sql').resolve()):
                raise ValueError('Maintained SQL source must be under sql/')
            units = sql_units(read(source))
            if units[item['source_unit']].strip() != read(root / item['payload']).strip():
                raise ValueError('Current SQL differs from latest frozen payload: ' + item['source_path'])
        seen.add(item['id'])
    validate_retirements(root, manifest)
    return manifest


def retirement_records(root: Path) -> list[dict]:
    manifest = json.loads(read(root / 'db/manifest.json'))
    return [json.loads(read(root / entry['path'])) for entry in manifest.get('retirements', [])]


def validate_retirements(root: Path, manifest: dict):
    """Retain an unaccepted failed candidate without rewriting applied history."""
    active = {item['id']: item for item in manifest['migrations']}
    records = {}
    def checked_file(path: str, digest: str):
        target = (root / path).resolve()
        if not target.is_relative_to((root / 'db').resolve()) or not target.is_file():
            raise ValueError('Retirement audit path must be a local db/ file')
        if sha(read(target)) != digest:
            raise ValueError('Immutable retirement audit hash mismatch: ' + path)
    for reference in manifest.get('retirements', []):
        checked_file(reference['path'], reference['sha256'])
        record = json.loads(read(root / reference['path']))
        if record['id'] in records:
            raise ValueError('Duplicate retirement audit ID')
        records[record['id']] = record
        checked_file(record['original_manifest'], record['original_manifest_sha256'])
        original = json.loads(read(root / record['original_manifest']))['migrations']
        prefix_count = record['applied_prefix_count']
        if manifest['migrations'][:prefix_count] != original[:prefix_count]:
            raise ValueError('Applied migration prefix differs from retirement audit')
        retired = [entry['migration'] for entry in record['entries']]
        if retired != original[prefix_count:]:
            raise ValueError('Retirement must describe the exact original unaccepted suffix')
        for path, digest in record['applied_wrapper_hashes'].items():
            checked_file(path, digest)
        for entry in record['entries']:
            item = entry['migration']
            if item['id'] in active:
                raise ValueError('Retired migration cannot remain in the active chain')
            for kind in ('payload', 'verification'):
                checked_file(item[kind], item[kind + '_sha256'])
            for path, digest in entry['artifact_hashes'].items():
                checked_file(path, digest)
            if entry['allowed_registry_state'] not in ('ABSENT', 'ABSENT_OR_FAILED'):
                raise ValueError('Unsupported retired migration state')
            if entry['allowed_registry_state'] == 'ABSENT_OR_FAILED' and not isinstance(entry.get('error_code'), int):
                raise ValueError('Retired failed migration requires an exact error code')
        if any(mid not in active for mid in record['replacement_migrations']):
            raise ValueError('Retirement replacement is missing from active migrations')
        first = active[record['replacement_migrations'][0]]
        if first['depends_on'] != [original[prefix_count - 1]['id']]:
            raise ValueError('Replacement must follow the preserved applied prefix')
        for mid in (record['replacement_migrations'][0], record['replacement_migrations'][-1]):
            if record['id'] not in active[mid].get('retirement_guards', []):
                raise ValueError('Replacement and checkpoint require retirement guards')
    for item in manifest['migrations']:
        if any(rid not in records for rid in item.get('retirement_guards', [])):
            raise ValueError('Migration references an unknown retirement guard')


def retirement_guard(root: Path, ids: list[str] | None = None) -> str:
    """Read-only, exact audit-state guard. A failed receipt is never completed."""
    statements = []
    for record in retirement_records(root):
        if ids is not None and record['id'] not in ids:
            continue
        for entry in record['entries']:
            item = entry['migration']
            mid = literal(item['id'])
            digest = sha(item['payload_sha256'] + ':' + item['verification_sha256'])
            statements.append(f' SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={mid};')
            if entry['allowed_registry_state'] == 'ABSENT_OR_FAILED':
                statements.extend([' IF l_n<>0 THEN',
                    f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={mid} AND payload_sha256={literal(digest)} AND product_version={literal(item['version'])} AND phase='FAILED' AND error_code={entry['error_code']} AND completed_at IS NULL;",
                    f" require(l_n=1,'Retired migration audit differs: {item['id']}');",
                    ' END IF;'])
            else:
                statements.append(f" require(l_n=0,'Unexecuted retired migration has a receipt: {item['id']}');")
            # Worksheet-only installs have no Liquibase ledger. If it exists,
            # none of these unaccepted IDs may have an executed ledger row.
            statements.extend([" SELECT COUNT(*) INTO l_n FROM user_tables WHERE table_name='DATABASECHANGELOG';",
                ' IF l_n=1 THEN',
                f" EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM databasechangelog WHERE id=:retired_id' INTO l_n USING {mid};",
                f" require(l_n=0,'Retired migration appears in Liquibase history: {item['id']}');",
                ' END IF;'])
    return '\n'.join(statements) + ('\n' if statements else '')


BOOTSTRAP = """DECLARE n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR SYS_CONTEXT('USERENV','SESSION_USER') IN ('ADMIN','SYS','SYSTEM') THEN
  RAISE_APPLICATION_ERROR(-20300,'Connect as the intended project schema owner'); END IF;
 SELECT COUNT(*) INTO n FROM user_tables WHERE table_name='KCV_SCHEMA_MIGRATIONS';
 IF n=0 THEN EXECUTE IMMEDIATE 'CREATE TABLE kcv_schema_migrations (
  migration_id VARCHAR2(128) PRIMARY KEY, payload_sha256 VARCHAR2(64) NOT NULL,
  product_version VARCHAR2(20) NOT NULL, phase VARCHAR2(16) NOT NULL,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE, error_code NUMBER,
  CHECK(phase IN (''RUNNING'',''COMPLETE'',''FAILED'')))'; END IF;
 SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name='KCV_SCHEMA_MIGRATIONS' AND
  ((column_name='MIGRATION_ID' AND data_type='VARCHAR2' AND char_length=128 AND nullable='N') OR
   (column_name='PAYLOAD_SHA256' AND data_type='VARCHAR2' AND char_length=64 AND nullable='N') OR
   (column_name='PRODUCT_VERSION' AND data_type='VARCHAR2' AND char_length=20 AND nullable='N') OR
   (column_name='PHASE' AND data_type='VARCHAR2' AND char_length=16 AND nullable='N') OR
   (column_name='STARTED_AT' AND data_type='TIMESTAMP(6) WITH TIME ZONE' AND nullable='N') OR
   (column_name='COMPLETED_AT' AND data_type='TIMESTAMP(6) WITH TIME ZONE') OR
   (column_name='ERROR_CODE' AND data_type='NUMBER'));
 IF n<>7 THEN RAISE_APPLICATION_ERROR(-20300,'Migration registry structure differs'); END IF;
 SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name='KCV_SCHEMA_MIGRATIONS';
 IF n<>7 THEN RAISE_APPLICATION_ERROR(-20300,'Migration registry has unexpected columns'); END IF;
 SELECT COUNT(*) INTO n FROM user_constraints c JOIN user_cons_columns k ON k.constraint_name=c.constraint_name
  WHERE c.table_name='KCV_SCHEMA_MIGRATIONS' AND c.constraint_type='P' AND c.status='ENABLED'
  AND c.validated='VALIDATED' AND k.column_name='MIGRATION_ID' AND k.position=1;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20300,'Migration registry primary key differs'); END IF;
END;"""


def wrapper(root: Path, item: dict) -> str:
    payload = read(root / item['payload']).strip()
    verify = read(root / item['verification']).strip()
    digest = sha(item['payload_sha256'] + ':' + item['verification_sha256'])
    predecessor = ''
    audit_guard = retirement_guard(root, item.get('retirement_guards', []))
    all_steps = {m['id']: m for m in json.loads(read(root / 'db/manifest.json'))['migrations']}
    for dep in item['depends_on']:
        prior = all_steps[dep]
        prior_hash = sha(prior['payload_sha256'] + ':' + prior['verification_sha256'])
        predecessor += f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(dep)} AND payload_sha256={literal(prior_hash)} AND phase='COMPLETE';\n require(l_n=1,'Required prior migration is incomplete: {dep}');\n"
    return f"""-- Generated from immutable local SQL; do not edit this wrapper.
DECLARE
 l_sql CLOB; l_hash VARCHAR2(64); l_phase VARCHAR2(16); l_started BOOLEAN:=FALSE;
 l_lock VARCHAR2(128); l_lock_result PLS_INTEGER; l_error NUMBER;
{VERIFY_DECLARATIONS}
BEGIN
 require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM'),'Connect as the intended project schema owner');
 DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);
 l_lock_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_lock_result=0,'Another schema migration is active');
{predecessor}{audit_guard}
 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id={literal(item['id'])};
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash={literal(digest)},'Migration payload/verification changed: {item['id']}');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: {item['id']}');
{verify}
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES({literal(item['id'])},{literal(digest)},{literal(item['version'])},'RUNNING');
  COMMIT;l_started:=TRUE;
{clob_assignment('l_sql', payload)}
  EXECUTE IMMEDIATE l_sql;
{verify}
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id={literal(item['id'])};
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id={literal(item['id'])};COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;\n"""


def write_checked(path: Path, content: str, check: bool):
    if check:
        if not path.exists() or read(path) != content:
            raise ValueError('Generated migration artifact is stale: ' + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8', newline='\n')


def worksheet_bundle(steps: list[str], header: str) -> str:
    # One outer block stops immediately on the first error even if Run Script
    # would otherwise continue with later slash-delimited blocks. Oracle DDL
    # still commits; step receipts/recovery remain necessary.
    body = [header.rstrip(), 'DECLARE l_step CLOB;', 'BEGIN']
    for step in steps:
        body.extend([clob_assignment('l_step', step.strip()), ' EXECUTE IMMEDIATE l_step;'])
    body.extend(['END;', '/', ''])
    return '\n'.join(body)


def receipt_check(item: dict) -> str:
    digest = sha(item['payload_sha256'] + ':' + item['verification_sha256'])
    return f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(item['id'])} AND payload_sha256={literal(digest)} AND phase='COMPLETE';\n require(l_n=1,'Missing or incompatible completion receipt: {item['id']}');"


def successor_chain(item: dict, items: list[dict]) -> list[dict]:
    replacements = {target: step for step in items for target in step.get('supersedes', [])}
    result, target = [], item['id']
    while target in replacements:
        step = replacements[target]
        if step in result:
            raise ValueError('Cyclic postcondition supersession')
        result.append(step)
        target = step['id']
    return result


def worksheet_step(root: Path, item: dict, items: list[dict]) -> str:
    successors = successor_chain(item, items)
    if not successors:
        return wrapper(root, item)
    lines = ['DECLARE', ' l_sql CLOB;l_replaced BOOLEAN:=FALSE;', VERIFY_DECLARATIONS, 'BEGIN']
    # Prefer the newest fully recorded successor. A failed/incomplete successor
    # cannot hide either history or physical drift: the prior live contract must
    # still pass, or the operator must recover the interrupted change first.
    for successor in reversed(successors):
        digest = sha(successor['payload_sha256'] + ':' + successor['verification_sha256'])
        lines.extend([" IF NOT l_replaced THEN",
            f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(successor['id'])} AND payload_sha256={literal(digest)} AND phase='COMPLETE';",
            ' IF l_n=1 THEN', read(root / successor['verification']).strip(), receipt_check(item),
            ' l_replaced:=TRUE;END IF;END IF;'])
    lines.extend([' IF NOT l_replaced THEN', clob_assignment('l_sql', wrapper(root, item).strip()),
                  ' EXECUTE IMMEDIATE l_sql;END IF;', 'END;\n'])
    return '\n'.join(lines)


def liquibase_needs_historical_step(root: Path, item: dict, items: list[dict]) -> str:
    """Return 0 only for a physically verified successor and historical receipt.

    This precondition lets a Worksheet installation enter Liquibase without
    replaying superseded SQL. It does not alter the old sqlFile/checksum. An
    absent successor returns 1 (normal execution); a corrupt completed state
    raises an error and HALTs rather than being marked as ran.
    """
    lines = ['WITH FUNCTION kcv_needs_historical_step RETURN NUMBER IS', VERIFY_DECLARATIONS, 'BEGIN']
    for successor in reversed(successor_chain(item, items)):
        digest = sha(successor['payload_sha256'] + ':' + successor['verification_sha256'])
        lines.extend([
            f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(successor['id'])} AND payload_sha256={literal(digest)} AND phase='COMPLETE';",
            ' IF l_n=1 THEN', read(root / successor['verification']).strip(), receipt_check(item),
            ' RETURN 0;END IF;'])
    lines.extend([' RETURN 1;', 'END;', 'SELECT kcv_needs_historical_step FROM dual'])
    return '\n'.join(lines)


def verification_block(root: Path, items: list[dict], receipts: bool = True) -> str:
    statements = [retirement_guard(root)] if receipts else []
    for item in items:
        successors = successor_chain(item, items)
        target = successors[-1] if successors else item
        if successors and receipts:
            statements.append(receipt_check(target))
        statements.append(read(root / target['verification']).strip())
        if receipts:
            statements.append(receipt_check(item))
    return 'DECLARE\n' + VERIFY_DECLARATIONS + '\nBEGIN\n' + '\n'.join(statements) + "\n DBMS_OUTPUT.PUT_LINE('KCV schema verification passed');\nEND;\n"


def retired_candidate_preflight(root: Path, items: list[dict]) -> str | None:
    """Repair only the reviewed failed candidate before a Worksheet replay.

    The normal baseline gate cannot validate a package left invalid by the
    recorded failed candidate. Its distinct replacement still checks the exact
    retirement audit, schema-owner session, lock and completed predecessor.
    Fresh installations do not take this branch. No failed receipt is updated.
    """
    records = retirement_records(root)
    if not records:
        return None
    active = {item['id']: item for item in items}
    lines = ['DECLARE l_sql CLOB;', VERIFY_DECLARATIONS, 'BEGIN', retirement_guard(root)]
    for record in records:
        failed_ids = [entry['migration']['id'] for entry in record['entries']
                      if entry['allowed_registry_state'] == 'ABSENT_OR_FAILED']
        if not failed_ids:
            continue
        ids = ','.join(literal(mid) for mid in failed_ids)
        lines.extend([f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id IN ({ids}) AND phase='FAILED';",
                      ' IF l_n>0 THEN'])
        for mid in record['replacement_migrations']:
            lines.extend([clob_assignment('l_sql', worksheet_step(root, active[mid], items).strip()),
                          ' EXECUTE IMMEDIATE l_sql;'])
        lines.append(' END IF;')
    lines.append('END;\n')
    return '\n'.join(lines)


def installed_contract_gate(root: Path, required: list[dict], all_items: list[dict]) -> str:
    """Verify required history against the newest *completed* live contract.

    Upgrade starts on either the original adopted v1, C2, or a completed later
    version. Requiring only the original table/program shape would reject an
    additive upgrade on its second run. Requiring the newest planned successor
    instead would reject its first run. Only an exact COMPLETE successor receipt
    can select a newer physical check, and the original receipt remains required.
    A partially applied successor must be recovered; this gate never writes or
    infers a receipt from object presence.
    """
    statements = []
    for item in required:
        successors = successor_chain(item, all_items)
        if not successors:
            statements.extend([read(root / item['verification']).strip(), receipt_check(item)])
            continue
        lines = [' DECLARE l_replaced BOOLEAN:=FALSE;BEGIN']
        for successor in reversed(successors):
            digest = sha(successor['payload_sha256'] + ':' + successor['verification_sha256'])
            lines.extend([
                ' IF NOT l_replaced THEN',
                f" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(successor['id'])} AND payload_sha256={literal(digest)} AND phase='COMPLETE';",
                ' IF l_n=1 THEN', read(root / successor['verification']).strip(),
                ' l_replaced:=TRUE;END IF;END IF;'])
        lines.extend([' IF NOT l_replaced THEN', read(root / item['verification']).strip(),
                      ' END IF;', receipt_check(item), ' END;'])
        statements.append('\n'.join(lines))
    return ('DECLARE\n' + VERIFY_DECLARATIONS + '\nBEGIN\n' + '\n'.join(statements)
            + "\n DBMS_OUTPUT.PUT_LINE('KCV installed baseline contract verified');\nEND;\n")


def adoption(root: Path, items: list[dict]) -> str:
    verification = '\n'.join(read(root / item['verification']).strip() for item in items)
    inserts = []
    for item in items:
        digest = sha(item['payload_sha256'] + ':' + item['verification_sha256'])
        inserts.append(f""" SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(item['id'])};
 IF l_n=0 THEN
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase,completed_at)
   VALUES({literal(item['id'])},{literal(digest)},'1.0.0','COMPLETE',SYSTIMESTAMP);
 ELSE
  SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(item['id'])} AND payload_sha256={literal(digest)} AND phase='COMPLETE';
  require(l_n=1,'Existing baseline receipt differs; use deliberate recovery');
 END IF;""")
    receipt_step = 'DECLARE\n l_lock VARCHAR2(128);l_result PLS_INTEGER;\n' + VERIFY_DECLARATIONS + "\nBEGIN\n DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);\n l_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);\n require(l_result=0,'Another migration is active');\n" + verification + '\n' + '\n'.join(inserts) + "\n COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);\n DBMS_OUTPUT.PUT_LINE('Verified v1 baseline receipts recorded. Continue with the documented ordered upgrade for your deployment route.');\nEXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;\nEND;"
    return worksheet_bundle([verification_block(root, items, False), BOOTSTRAP, receipt_step], '-- Adopt only a structurally and source-verified v1 baseline. Never creates application tables.')


def recovery(root: Path, item: dict) -> str:
    digest = sha(item['payload_sha256'] + ':' + item['verification_sha256'])
    verify = read(root / item['verification']).strip()
    return f"""-- Reconcile only physically complete work, after investigating the failure.
-- Acquires the same migration lock. Does not rerun DDL, clear a live lock or skip postconditions.
DECLARE
 l_lock VARCHAR2(128);l_result PLS_INTEGER;
{VERIFY_DECLARATIONS}
BEGIN
 require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM'),'Connect as the intended project schema owner');
 DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);
 l_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_result=0,'Another migration is active');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id={literal(item['id'])}
  AND payload_sha256={literal(digest)} AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
{verify}
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id={literal(item['id'])} AND payload_sha256={literal(digest)};
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/\n"""


def build(root: Path = ROOT, check: bool = False):
    manifest = validate_manifest(root)
    groups = {'baseline': [], 'feature': []}
    for item in manifest['migrations']:
        groups[item['group']].append(item)
        write_checked(root / f"db/generated/{item['id']}.sql", wrapper(root, item), check)
        write_checked(root / f"db/recovery/{item['id']}.sql", recovery(root, item), check)
    write_checked(root / 'db/generated/bootstrap.sql', BOOTSTRAP + '\n', check)
    for group, items in groups.items():
        changelog = ET.Element('databaseChangeLog', {'xmlns': NS, 'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
            'xsi:schemaLocation': NS + ' https://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.0.xsd'})
        if group == 'baseline':
            cs = ET.SubElement(changelog, 'changeSet', {'id': 'kcv-migration-registry-v1', 'author': 'Jason Lowe', 'runInTransaction': 'false'})
            ET.SubElement(cs, 'sqlFile', {'path': '../generated/bootstrap.sql', 'relativeToChangelogFile': 'true', 'splitStatements': 'false', 'stripComments': 'false'})
        for item in items:
            cs = ET.SubElement(changelog, 'changeSet', {'id': item['id'], 'author': 'Jason Lowe', 'runInTransaction': 'false'})
            if successor_chain(item, manifest['migrations']):
                pre = ET.SubElement(cs, 'preConditions', {'onFail': 'MARK_RAN', 'onError': 'HALT'})
                check_sql = ET.SubElement(pre, 'sqlCheck', {'expectedResult': '1'})
                check_sql.text = liquibase_needs_historical_step(root, item, manifest['migrations'])
            ET.SubElement(cs, 'sqlFile', {'path': '../generated/' + item['id'] + '.sql', 'relativeToChangelogFile': 'true', 'splitStatements': 'false', 'stripComments': 'false'})
        ET.indent(changelog)
        output = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(changelog, encoding='unicode') + '\n'
        write_checked(root / f'db/{group}/changelog.xml', output, check)
    top = '''<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog https://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.0.xsd">
 <include file="baseline/changelog.xml" relativeToChangelogFile="true"/>
 <include file="feature/changelog.xml" relativeToChangelogFile="true"/>
</databaseChangeLog>
'''
    write_checked(root / 'db/changelog.xml', top, check)
    all_items = manifest['migrations']
    write_checked(root / 'db/baseline/verify.sql', verification_block(root, groups['baseline'], False) + '/\n', check)
    write_checked(root / 'db/baseline/adopt.sql', adoption(root, groups['baseline']), check)
    write_checked(root / 'sql/install/00_adopt_schema_baseline.sql', adoption(root, groups['baseline']), check)
    write_checked(root / 'sql/install/02_verify_schema.sql', verification_block(root, all_items) + '/\n', check)
    for name, items in [('00_install_schema.sql', all_items), ('01_upgrade_schema.sql', groups['feature'])]:
        header = '-- GENERATED: local reviewed migration payloads. Run Script as the project schema owner.\n-- Check the final verification result; do not continue after an error.\n'
        if name.startswith('01'):
            header += '-- Requires successful v1 baseline adoption first; this script never guesses a baseline.\n'
        steps = [BOOTSTRAP]
        preflight = retired_candidate_preflight(root, all_items)
        if preflight:
            steps.append(preflight)
        if name.startswith('01'):
            steps.append(installed_contract_gate(root, groups['baseline'], all_items))
        steps.extend(worksheet_step(root, item, all_items) for item in items)
        steps.append(verification_block(root, all_items))
        output = worksheet_bundle(steps, header)
        write_checked(root / 'sql/install' / name, output, check)
    print(f'{len(all_items)} migration payloads verified; generated wrappers/changelogs/Worksheet bundles ' + ('checked' if check else 'written'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    build(check=args.check)
