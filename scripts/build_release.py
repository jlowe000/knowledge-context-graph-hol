"""Build the SQL-first learner distribution without copying private work files.

Maintainer utility on dev only. This never modifies a Git branch or database.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from kcv import pipeline
from kcv.worksheet import export
from kcv.github_dataset import generate as generate_github_dataset
from kcv.github_dataset import loader_script
from scripts.build_apex_worksheet import build as build_apex_installer

LABS = ['introduction', 'prepare-environment', 'provision-database',
        'configure-database', 'load-knowledge', 'deploy-explorer',
        'explore-evidence', 'need-help']
DOCS = ['fresh-serverless-deployment.md', 'authentication.md', 'cleanup.md',
        'ui-walkthrough.md', 'screenshots.md', 'livelabs-authoring-alignment.md',
        'upstream-comparison.md']


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')


def summary_passages(root):
    """Own IDs/hashes; never present a paraphrase as a PDF extraction/quotation."""
    sources = {s['id']: s for s in pipeline.sources(root)}
    examples = pipeline.read(root / 'review-examples/examples.json')['examples']
    result = []
    for example in examples:
        source = sources[example['source_id']]
        page = example['pdf_page']
        if page not in source['selected_pdf_pages']:
            raise ValueError('Summary page is outside the reviewed source manifest')
        text = 'Editorial summary, not a quotation: ' + example['expected_statement']
        sha = pipeline.digest(text)
        result.append({'id': f"{source['version']['id']}-summary-p{page:03d}-{sha[:8]}",
            'source_id': source['id'], 'version_id': source['version']['id'],
            'pdf_page': page, 'chunk_index': 1, 'text': text, 'text_sha256': sha,
            'source_sha256': source['version']['sha256'],
            'extractor': 'editorial-summary-v1-not-pdf-extraction',
            'content_kind': 'attributed_editorial_summary',
            'locator_url': source['url'] + f'#page={page}',
            'qualification': 'Author-written summary linked to a public page; not verbatim source text or an accepted extracted claim.'})
    from kcv.editorial import catalogue_summary_passages
    result.extend(catalogue_summary_passages(root))
    if len({p['id'] for p in result}) != len(result):
        raise ValueError('Duplicate summary IDs')
    return result


def validate(folder):
    errors = []
    for p in folder.rglob('*'):
        if not p.is_file(): continue
        if p.suffix in {'.py', '.sh', '.pem', '.key', '.wallet'}:
            errors.append('Unexpected developer/credential file: ' + str(p.relative_to(folder)))
        if p.suffix != '.md': continue
        text = p.read_text(encoding='utf-8')
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text):
            if '://' in target or target.startswith('#'): continue
            link = target.split('#')[0]
            if link and not (p.parent / link).exists():
                errors.append(str(p.relative_to(folder)) + ': missing ' + target)
    if errors: raise ValueError('\n'.join(errors))


def build(output):
    output = Path(output).resolve()
    if output.exists(): raise ValueError('Use a new output folder; existing output is never deleted')
    if (ROOT / 'data/public-content-summaries.json').exists():
        from kcv.editorial import validate_summary_basis
        validate_summary_basis(ROOT)
    # Every source needs an actual access result or an explicit public classification.
    from kcv.public_access import validate_url, public_rule, retained_publisher
    policy = pipeline.read(ROOT / 'references/public-source-policy.json')
    prefixes = policy['url_prefixes']
    checks = {r['source_id']: r for r in pipeline.read(ROOT / 'references/public-access-checks.json')['checks']}
    for source in pipeline.sources(ROOT) + pipeline.catalog(ROOT):
        checked = checks.get(source['id'], {})
        validate_url(source['url'])
        try:
            verified_at = datetime.fromisoformat(checked.get('checked_at',''))
        except (ValueError, TypeError):
            verified_at = None
        def location(url):
            validate_url(url)
            u = urlsplit(url)
            return (u.scheme, u.hostname.lower(), u.path, u.query)
        matched_rule = public_rule(source['url'],prefixes,source['title'],policy.get('title_rules',[]))
        if not matched_rule and not retained_publisher(source['url'],policy):
            raise ValueError('Industry or third-party reference still requires review: ' + source['id'])
        manual = checked.get('status') == 'manually_marked_public' and matched_rule and checked.get('public_rule') == matched_rule
        verified = checked.get('access_verified') is True and checked.get('http_status') == 200
        if (checked.get('status') not in {'verified_public','manually_marked_public'}
                or (checked.get('status') == 'manually_marked_public' and not manual)
                or (not verified and not manual)
                or checked.get('authentication_used') is not False or checked.get('cookies_used') is not False
                or verified_at is None or verified_at.tzinfo is None
                or location(checked.get('url','')) != location(source['url'])
                or checked.get('sha256') != source['version']['sha256']):
            raise ValueError('Missing or mismatched anonymous verification: ' + source['id'])
        if not verified:
            metadata = {k:source[k] for k in ['title','url','topics','business_domains','session_ids']}
            metadata_hash = hashlib.sha256(json.dumps(metadata,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
            if (not source['id'].startswith('R') or source['version'].get('hash_basis') != 'catalogue_metadata'
                    or checked.get('hash_basis') != 'catalogue_metadata' or not checked.get('reason')
                    or metadata_hash != source['version']['sha256']):
                raise ValueError('Unverified manual source must remain explicit catalogue metadata: ' + source['id'])
    with tempfile.TemporaryDirectory(prefix='kcv-release-') as temporary:
        stage = Path(temporary)
        def copy(relative):
            source = ROOT / relative
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir(): shutil.copytree(source, target)
            else: shutil.copy2(source, target)
        for relative in ['.gitattributes', '.gitignore', 'LICENSE.txt', 'NOTICE.md',
                         'data', 'ontology', 'references', 'review-examples', 'sql', 'third-party']:
            copy(relative)
        # This is an explicit publication allowlist, never a copy of work/.
        for name in LABS: copy('labs/' + name)
        for name in DOCS: copy('docs/' + name)
        for name in ['verify_worksheet.sql', 'verify_scenario_native.sql', 'verify_github_dataset.sql',
                     'verify_source_packet_scope.sql']:
            copy('integration-test/' + name)
        copy('apex/kcv-explorer.sql')
        copy('apex/explorer.js')
        for name in ['model.svg']:
            copy('generated/' + name)
        # Release documentation is maintained separately from contributor docs.
        for p in (ROOT / 'release-docs').rglob('*'):
            if p.is_file():
                target = stage / p.relative_to(ROOT / 'release-docs')
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, target)
        passages = summary_passages(stage)
        pipeline.write(stage / 'work/passages.json', passages)
        report = pipeline.build(stage)
        export(stage)
        generate_github_dataset(stage, stage / 'data/load')
        installer = stage / 'sql/install'
        installer.mkdir(parents=True, exist_ok=True)
        manifest_hash = hashlib.sha256((stage / 'data/load/manifest.json').read_bytes()).hexdigest()
        write(installer / '10_load_github.sql', loader_script(manifest_hash))
        loader = (stage / 'work/worksheet/10_load_dataset.sql').read_text(encoding='utf-8')
        loader = loader.replace('-- Contains public-source passage text: keep this generated script local; do not commit it.',
            '-- Contains attributed editorial summaries, not extracted PDF text or source quotations.')
        write(installer / '10_load_dataset.sql', loader)
        shutil.copytree(stage / 'work/worksheet/dataset-parts', installer / 'dataset-parts')
        build_apex_installer(output=installer / '20_install_apex.sql')
        pipeline.write(stage / 'data/release-summaries.json', {
            'content_kind': 'attributed_editorial_summary',
            'not_verbatim_source_text': True, 'passages': passages})
        report.update({'content_kind': 'attributed_editorial_summary',
            'full_source_text_location': 'Not bundled; summaries in data/release-summaries.json',
            'native_serverless_validation': 'release_summary_dataset_not_yet_run',
            'model_extraction': 'not_applicable', 'distribution': 'release'})
        pipeline.write(stage / 'generated/build-report.json', report)
        preview = (stage / 'generated/dataset-preview.md').read_text(encoding='utf-8')
        preview = preview.replace('Generated from real public editions;', 'Editorial summaries attributed to real public editions;')
        preview = preview.replace('real page-aware passages', 'attributed editorial summaries')
        preview = preview.replace('Actual passages are generated locally and not redistributed.',
            'Summary IDs and hashes identify the editorial text. Follow the PDF links to inspect the original pages.')
        write(stage / 'generated/dataset-preview.md', preview)
        # Change only the generated release copies, leaving dev's original path intact.
        for p in (stage / 'labs').rglob('*.md'):
            text = p.read_text(encoding='utf-8')
            text = text.replace('work/worksheet/10_load_dataset.sql', 'sql/install/10_load_dataset.sql')
            text = text.replace('work/worksheet/dataset-parts/', 'sql/install/dataset-parts/')
            text = text.replace('These are your generated files from the preparation lab.', 'These numbered files are supplied with the release; no local generation is needed.')
            text = text.replace('work/worksheet/20_install_apex.sql', 'sql/install/20_install_apex.sql')
            text = text.replace('your Oracle Linux generated files are accessible', 'the release SQL files are accessible')
            text = text.replace('generated `10_load_dataset.sql`', 'supplied `10_load_dataset.sql`')
            text = text.replace('your generated file from the preparation lab', 'the supplied release file checked in with this branch')
            text = text.replace('verified public passages', 'attributed editorial summaries')
            text = text.replace('Public evidence, native graph', 'Attributed summaries, native graph')
            if p.parent.name == 'deploy-explorer':
                start = text.index('If the generated file is missing,')
                end = text.index('## Task 4:', start)
                text = text[:start] + 'Both SQL installation files are included in this branch. No Python, SQLcl or local APEX installation is required. If a file is missing, obtain the complete release download.\n\n' + text[end:]
            if p.parent.name == 'load-knowledge':
                text = text.replace('regenerate the loader with the current project code', 'obtain an unchanged copy of the release loader')
                text = text.replace('regenerated loader', 'release loader')
                text = text.replace('Load verified passages', 'Load attributed editorial summaries')
                text = text.replace('Public evidence', 'Editorial summaries')
                text = text.replace('source data', 'summary data')
            if p.parent.name == 'explore-evidence':
                text = text.replace('complete saved passages', 'complete saved editorial summaries')
                text = text.replace('With the supplied baseline,', 'The release uses summaries rather than the extracted text shown in the screenshots. With the supplied baseline,')
            write(p, text)
        # Turn links to contributor-only references into explicit dev references.
        # This prevents a release README from sending learners to missing tools/docs.
        for p in stage.rglob('*.md'):
            def fix(match):
                label, target = match.group(1), match.group(2)
                if '://' in target or target.startswith('#'): return match.group()
                path = (p.parent / target.split('#')[0]).resolve()
                if path.exists(): return match.group()
                try: relative = path.relative_to(stage).as_posix()
                except ValueError: raise ValueError('Link leaves release tree: ' + target)
                return label + ' (technical reference on the dev branch: `' + relative + '`)'
            write(p, re.sub(r'(?<!!)\[([^\]]*)\]\(([^)]+)\)', fix, p.read_text(encoding='utf-8')))
        # No private runtime or PDF extraction files are copied into the result.
        shutil.rmtree(stage / 'work')
        # Stable byte hashes across Windows/Linux clones; .gitattributes enforces LF.
        for p in stage.rglob('*'):
            if p.is_file() and p.suffix.lower() not in {'.png', '.jpg'}:
                write(p, p.read_text(encoding='utf-8'))
        file_rows = [{'path': p.relative_to(stage).as_posix(),
                      'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                     for p in sorted(stage.rglob('*')) if p.is_file()]
        pipeline.write(stage / 'release-manifest.json', {'format_version': 1,
            'distribution': 'release', 'python_required_for_learner': False,
            'dataset_kind': 'attributed_editorial_summary', 'summary_count': len(passages),
            'source_count': report['source_count'], 'catalogue_count': report['catalog_count'],
            'total_content_count': report['total_content_count'], 'files': file_rows})
        validate(stage)
        shutil.copytree(stage, output)
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'work/release-package')
    args = parser.parse_args()
    print(build(args.output))
