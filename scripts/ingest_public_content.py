"""Fetch and chunk approved public catalogue content; developer workflow only."""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from kcv.ingestion import run

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Optional external download report; reuse exact verified bytes only')
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--refresh-editions', action='store_true', help='Adopt newly checked public editions and increment version IDs')
    parser.add_argument('--audit-dir', type=Path, help='Existing private audit folder outside this repository')
    args = parser.parse_args()
    report = run(ROOT, args.report, args.workers, args.refresh_editions, args.audit_dir)
    print(json.dumps({k: v for k, v in report.items() if k != 'sources'}, indent=2))
