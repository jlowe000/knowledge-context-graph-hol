"""Build the public GitHub dataset from editorial summaries; no raw text export.

Maintainer utility on dev. Learners load the already-built JSON using SQL.
No Git branch, network service or database is changed by this script.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from kcv import pipeline
from kcv.github_dataset import generate, validate, write_loader
from scripts.build_release import summary_passages


def build(output, root=ROOT):
    """Create a temporary isolated summary stage, then emit a public package."""
    root = Path(root)
    if (root / 'data/public-content-summaries.json').exists():
        from kcv.editorial import validate_summary_basis
        validate_summary_basis(root)
    passages = summary_passages(root)
    (root / 'work').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='github-dataset-stage-', dir=root / 'work') as temporary:
        stage = Path(temporary)
        for name in ('data', 'ontology', 'review-examples', 'references'):
            if (root / name).exists():
                shutil.copytree(root / name, stage / name,
                                ignore=shutil.ignore_patterns('load'))
        # Deliberately copy no existing work file or dev generated graph.
        pipeline.write(stage / 'work/passages.json', passages)
        pipeline.build(stage)
        manifest = generate(stage, Path(output))
    validate(output)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'work/github-dataset',
                        help='Package folder (default: ignored work/github-dataset)')
    parser.add_argument('--validate', type=Path, metavar='FOLDER',
                        help='Validate an existing package without rebuilding')
    parser.add_argument('--loader', type=Path, metavar='SQL_FILE',
                        help='Also write a short SQL caller pinned to the generated or validated manifest')
    args = parser.parse_args()
    manifest = validate(args.validate) if args.validate else build(args.output)
    folder = args.validate or args.output
    if args.loader:
        write_loader(folder, args.loader)
    print(json.dumps({'folder': str(folder.resolve()), 'dataset_id': manifest['dataset_id'],
                      'manifest_sha256': pipeline.digest((folder / 'manifest.json').read_bytes()),
                      'graph_sha256': manifest['graph_sha256'], 'counts': manifest['counts'],
                      'file_count': len(manifest['files']),
                      'loader': str(args.loader.resolve()) if args.loader else None,
                      'native_database_validation': 'not_run'}, indent=2))


if __name__ == '__main__':
    main()
