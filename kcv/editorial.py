"""Validate attributed editorial summaries without publishing extracted source bodies."""
from . import pipeline as p
from .public_access import validate_url


def catalogue_summary_passages(root=p.ROOT):
    path = root / 'data/public-content-summaries.json'
    if not path.exists():
        return []
    sources = {s['id']: s for s in p.catalog(root)}
    result = []
    for entry in p.read(path)['summaries']:
        source = sources.get(entry['source_id'])
        if source is None or not source.get('access_verified'):
            raise ValueError('Summary needs an anonymously verified catalogue source')
        if (entry['version_id'] != source['version']['id']
                or entry['source_sha256'] != source['version']['sha256']):
            raise ValueError('Summary refers to a different source edition: ' + entry['source_id'])
        text = entry['summary'].strip()
        if not 20 <= len(text) <= 1800:
            raise ValueError('Summary must contain a concise, substantive paraphrase')
        validate_url(entry['locator_url'])
        if entry['locator_url'].split('#')[0] != source['url'].split('#')[0]:
            raise ValueError('Summary locator must refer to its public source')
        for locator in entry.get('basis_locators', []):
            validate_url(locator['locator_url'])
            if locator['locator_url'].split('#')[0] != source['url'].split('#')[0]:
                raise ValueError('Summary basis locator must refer to its public source')
        if not entry.get('basis_passage_ids') or not entry.get('basis_text_sha256'):
            raise ValueError('Summary needs traceable extracted passage IDs and hashes')
        if len(entry['basis_passage_ids']) != len(entry['basis_text_sha256']):
            raise ValueError('Summary basis IDs and hashes must have equal length')
        if entry.get('review_status') != 'ai_assisted_editorial_not_independently_fact_checked':
            raise ValueError('Summary review status must not imply human fact checking')
        labelled = 'Editorial summary, not a quotation: ' + text
        sha = p.digest(labelled)
        result.append({
            'id': f"{entry['version_id']}-summary-{sha[:16]}",
            'source_id': entry['source_id'], 'version_id': entry['version_id'],
            'pdf_page': entry.get('pdf_page'), 'chunk_index': 1,
            'text': labelled, 'text_sha256': sha, 'source_sha256': entry['source_sha256'],
            'extractor': 'ai-assisted-editorial-summary-v1-not-source-extraction',
            'content_kind': 'attributed_editorial_summary',
            'locator_kind': entry['locator_kind'], 'locator_label': entry['locator_label'],
            'locator_url': entry['locator_url'],
            'basis_locators': entry.get('basis_locators', []),
            'basis_passage_ids': entry['basis_passage_ids'],
            'basis_text_sha256': entry['basis_text_sha256'],
            'review_status': entry['review_status'],
            'qualification': 'AI-assisted paraphrase of the identified source passage(s), not the complete document. Not independently fact checked; inspect the original before relying on technical or availability claims.'})
    if len({x['id'] for x in result}) != len(result):
        raise ValueError('Duplicate editorial summaries')
    return result


def validate_summary_basis(root=p.ROOT):
    """Maintainer check against ignored raw chunks; release users need no raw files."""
    summaries = catalogue_summary_passages(root)
    raw = {x['id']: x for x in p.read(root / 'work/catalog-passages.json')}
    for summary in summaries:
        locators = []
        for identity, sha in zip(summary['basis_passage_ids'], summary['basis_text_sha256']):
            passage = raw.get(identity)
            if (passage is None or passage['text_sha256'] != sha
                    or passage['source_id'] != summary['source_id']
                    or passage['version_id'] != summary['version_id']
                    or passage['source_sha256'] != summary['source_sha256']):
                raise ValueError('Summary basis does not match extracted content: ' + summary['id'])
            locator = {key:passage.get(key) for key in ('locator_kind','locator_label','locator_url','pdf_page')}
            if locator not in locators:
                locators.append(locator)
        if (summary['basis_locators'] != locators
                or summary['locator_url'] != locators[0]['locator_url']
                or summary['pdf_page'] != locators[0]['pdf_page']):
            raise ValueError('Summary locators differ from extracted evidence: ' + summary['id'])
    return {'summary_count': len(summaries), 'basis_hashes_verified': True}
