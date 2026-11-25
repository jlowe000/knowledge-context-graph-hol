"""Package complete, ordered Worksheet migration parts without changing migrations.

The size target is soft: an indivisible verification/migration block may exceed it.
The output is a candidate until its actual Worksheet transport is tested.
"""
from pathlib import Path
import hashlib
import json

from scripts import build_database_installers as migrations

PART_TARGET_BYTES = 1024 * 1024


def installation_steps(root, manifest, route):
    items = manifest['migrations']
    baseline = [item for item in items if item['group'] == 'baseline']
    selected = items if route == 'fresh' else [item for item in items if item['group'] == 'feature']
    steps = [('bootstrap', migrations.BOOTSTRAP)]
    preflight = migrations.retired_candidate_preflight(root, items)
    if preflight:
        steps.append(('retired-candidate-preflight', preflight))
    if route == 'upgrade':
        steps.append(('verified-baseline-gate', migrations.installed_contract_gate(root, baseline, items)))
    steps.extend((item['id'], migrations.worksheet_step(root, item, items)) for item in selected)
    steps.append(('final-schema-verification', migrations.verification_block(root, items)))
    return steps


def group_steps(steps, target_bytes=PART_TARGET_BYTES):
    """Keep every PL/SQL step whole; never split inside a literal or transaction."""
    groups, pending = [], []
    for step in steps:
        trial = pending + [step]
        size = len(migrations.worksheet_bundle([s for _, s in trial], '').encode('utf-8'))
        if pending and size > target_bytes:
            groups.append(pending)
            pending = [step]
        else:
            pending = trial
    if pending:
        groups.append(pending)
    return groups


def build(root, output, target_bytes=PART_TARGET_BYTES):
    root, output = Path(root), Path(output)
    manifest = migrations.validate_manifest(root)
    output.mkdir(parents=True, exist_ok=False)
    result = {'format_version': 1, 'product_version': manifest['target_product_version'],
              'ready_checkpoint': manifest['migrations'][-1]['id'],
              'project_migrations': len(manifest['migrations']),
              'grouping_target_bytes': target_bytes,
              'size_limit_is_strict': False,
              'execution_acceptance': 'not established by generation', 'routes': {}}
    for route in ('fresh', 'upgrade'):
        groups = group_steps(installation_steps(root, manifest, route), target_bytes)
        rows = []
        for index, group in enumerate(groups, 1):
            path = output / route / f'{index:03d}.sql'
            path.parent.mkdir(exist_ok=True)
            marker = f'KCV_SCHEMA_PART_COMPLETE={route}:{index:03d}/{len(groups):03d}'
            finish = "BEGIN DBMS_OUTPUT.PUT_LINE('" + marker + "');END;"
            header = (f'-- {route.upper()} part {index:03d} of {len(groups):03d}. Run Script as the project owner.\n'
                      '-- Run in manifest order. Stop after any error; do not skip ahead.\n'
                      '-- An oversized atomic step is retained intact to preserve its checks.\n')
            text = migrations.worksheet_bundle([sql for _, sql in group] + [finish], header)
            path.write_text(text, encoding='utf-8', newline='\n')
            data = text.encode('utf-8')
            rows.append({'ordinal': index, 'path': path.relative_to(output).as_posix(),
                         'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
                         'exceeds_grouping_target': len(data) > target_bytes,
                         'steps': [name for name, _ in group], 'success_marker': marker})
        result['routes'][route] = rows
    (output/'manifest.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8', newline='\n')
    (output/'README.md').write_text(
        '# Ordered schema installation parts\n\n'
        'Choose **fresh** for an empty project schema. Choose **upgrade** only after the existing '
        'v1 schema has passed the documented optional-baseline completion and `../00_adopt_schema_baseline.sql` checks, '
        'or when it already has valid migration receipts. '
        'Do not run both routes.\n\n'
        'Open each numbered `.sql` file in the chosen directory in order. Run its complete contents with '
        'SQL Worksheet **Run Script (F5)** as the project schema owner. Stop on any error. Each file is one '
        'outer PL/SQL block so later steps in that file do not execute after a failure. DDL can already '
        'have committed: inspect the receipt and use the documented recovery process before retrying. '
        'The last part performs full schema verification. Do not also run the combined installer.\n\n'
        '`manifest.json` records exact order, step IDs, file sizes, SHA-256 hashes and success markers. '
        'The grouping target is one MiB, not a hard ceiling. Complete verification/migration blocks '
        'larger than that remain intact. Generation alone does not establish browser upload limits or '
        'native execution acceptance. See the release validation record.\n', encoding='utf-8', newline='\n')
    return result


def package_recovery(root, output, manifest):
    """Retain the reviewed per-step reconciliation SQL without adding a database dependency."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    rows = []
    for item in manifest['migrations']:
        source = Path(root)/'db/recovery'/f"{item['id']}.sql"
        text = migrations.read(source)
        if text != migrations.recovery(Path(root), item):
            raise ValueError('Stale recovery artifact: '+item['id'])
        target = output/source.name
        target.write_text(text, encoding='utf-8', newline='\n')
        rows.append({'migration_id': item['id'], 'path': target.name,
                     'sha256': hashlib.sha256(text.encode()).hexdigest()})
    (output/'manifest.json').write_text(json.dumps({'format_version': 1, 'steps': rows}, indent=2)+'\n',
                                       encoding='utf-8', newline='\n')
    (output/'README.md').write_text(
        '# Reconcile an interrupted migration receipt\n\n'
        'These are facilitator recovery scripts, not installation steps. Diagnose the failed migration '
        'first. Run only its matching file as the project schema owner after the intended physical '
        'objects are complete. The script verifies exact postconditions and hashes before reconciling '
        'a receipt. It does not rerun missing DDL or clear a live migration lock. Never manually mark a '
        'migration complete, reset checksums, or run all recovery files. Then retry the failed installation '
        'part and finish the normal verification.\n', encoding='utf-8', newline='\n')
