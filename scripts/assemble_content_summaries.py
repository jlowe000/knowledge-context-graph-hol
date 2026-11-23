"""Assemble maintainer-written paraphrases with exact local extraction provenance.

The input maps contain original editorial prose, never source-body substitutes.
This script joins and validates them; it does not generate prose from titles.
"""
import argparse
from collections import Counter
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from kcv import pipeline as p
from kcv.editorial import validate_summary_basis


def assemble(parts, overrides=(), root=ROOT):
    prose = {}
    for file in parts:
        for key, text in p.read(file).items():
            if key in prose:
                raise ValueError('Duplicate summary assignment: ' + key)
            prose[key] = text
    basis = {x['source_id']: [e['evidence_id'] for e in x['evidence']]
             for x in p.read(root / 'work/research-content/summary-inputs.json')}
    for file in overrides:
        basis.update(p.read(file))
    raw = {x['id']: x for x in p.read(root / 'work/catalog-passages.json')}
    summaries = []
    for identity, text in sorted(prose.items()):
        chosen = [raw[key] for key in basis[identity]]
        first = chosen[0]
        if any(x['source_id'] != identity or x['version_id'] != first['version_id'] for x in chosen):
            raise ValueError('One summary must use one verified source edition: ' + identity)
        locators = []
        for item in chosen:
            locator = {key:item.get(key) for key in ('locator_kind','locator_label','locator_url','pdf_page')}
            if locator not in locators:
                locators.append(locator)
        if 'http://' in text or 'https://' in text:
            raise ValueError('Keep source links in attribution fields, not prose')
        summaries.append({
            'source_id': identity, 'version_id': first['version_id'],
            'source_sha256': first['source_sha256'],
            'pdf_page': first.get('pdf_page'), 'locator_kind': first['locator_kind'],
            'locator_label': '; '.join(x['locator_label'] for x in locators), 'locator_url': first['locator_url'],
            'basis_locators': locators,
            'basis_passage_ids': [x['id'] for x in chosen],
            'basis_text_sha256': [x['text_sha256'] for x in chosen],
            'summary': text,
            'review_status': 'ai_assisted_editorial_not_independently_fact_checked'})
    p.write(root / 'data/public-content-summaries.json', {
        'schema_version': 1, 'content_kind': 'attributed_editorial_summary',
        'authorship': 'AI-assisted editorial paraphrases prepared for Jason Lowe; not source quotations.',
        'scope': 'Selected identified passages only, not exhaustive summaries of the sources. No automatic acceptance as Claim nodes.',
        'summaries': summaries})
    validated = validate_summary_basis(root)
    ingestion = p.read(root / 'work/research-content/ingestion-report.json')
    rows = []
    for item in ingestion['sources']:
        rows.append({
            'source_id': item['source_id'], 'status': item['status'],
            'extracted_passage_count': item.get('passage_count', 0),
            'release_summary_count': int(item['source_id'] in prose),
            'release_coverage': 'attributed_editorial_summary' if item['source_id'] in prose else 'catalogue_only'})
    p.write(root / 'references/content-ingestion-checks.json', {
        'schema_version': 1, 'generated_at': ingestion['generated_at'],
        'source_count': len(rows), 'extracted_passage_count': sum(x['extracted_passage_count'] for x in rows),
        'release_summary_count': len(summaries),
        'statuses': dict(Counter(x['status'] for x in rows)),
        'limitations': 'Dev extraction is not fact checking. Release uses selected editorial paraphrases. Failures and unsupported formats remain references without invented content. Full source bodies and private audit details are not distributed.',
        'sources': rows})
    return validated


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parts', type=Path, nargs='+', required=True)
    parser.add_argument('--overrides', type=Path, nargs='*', default=[])
    args = parser.parse_args()
    print(assemble(args.parts, args.overrides))
