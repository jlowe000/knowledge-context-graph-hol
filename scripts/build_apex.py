"""Synchronize application assets without rewriting directly authored APEXlang.

Page definitions under apex/application/pages are authoritative. Cache-version
references are explicit source edits: a stale reference is reported, never fixed
by regenerating a page from an HTML snapshot.
"""
from pathlib import Path
import argparse
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ('explorer.js', 'explorer.css')


def build(check=False, root=ROOT):
    root = Path(root)
    assets = root / 'apex'
    application = assets / 'application'
    destination = application / 'shared-components/static-files'
    pages = list((application / 'pages').glob('*.apx'))
    if not pages:
        raise ValueError('No directly authored APEXlang pages found')
    errors = []
    version_file = root / 'VERSION'
    app_file = application / 'application.apx'
    if version_file.exists() and app_file.exists():
        product_version = version_file.read_text(encoding='utf-8').strip()
        declared = re.search(r'^\s+version:\s*([^\r\n]+)', app_file.read_text(encoding='utf-8'), re.MULTILINE)
        app_version = declared.group(1).strip().strip('"') if declared else None
        if app_version not in (product_version, product_version + '-dev'):
            errors.append('APEX application version must match VERSION, optionally followed by -dev')
    for filename in ASSETS:
        content = (assets / filename).read_text(encoding='utf-8')
        target = destination / filename
        if check:
            if not target.exists() or target.read_text(encoding='utf-8') != content:
                errors.append('APEX static asset is stale: ' + filename)
        else:
            destination.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding='utf-8', newline='\n')
        expected = hashlib.sha256(content.encode()).hexdigest()[:12]
        found = False
        pattern = re.compile(r'#APP_FILES#' + re.escape(filename) + r'\?v=([A-Za-z0-9_.-]+)')
        for page in pages:
            for actual in pattern.findall(page.read_text(encoding='utf-8')):
                found = True
                if actual != expected:
                    errors.append(f'{page.relative_to(root)}: set {filename} cache version to {expected}')
        if not found:
            errors.append(f'No versioned {filename} reference in authored pages')
    if errors:
        raise ValueError('\n'.join(errors))
    return 'APEX assets synchronized; directly authored pages preserved'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print(build(args.check))
