"""Page-aware public-source pipeline; no dependency on the original collection."""
from __future__ import annotations

import hashlib
import html
import json
import logging
import platform
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, build_opener

from pypdf import PdfReader
from rdflib import Graph, Literal, Namespace, RDF, RDFS, URIRef
from rdflib.namespace import SKOS

K = Namespace('https://example.org/kcv/')
ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    temporary.replace(path)


def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else value.encode()).hexdigest()


def slug(value):
    return re.sub(r'[^A-Za-z0-9]+', '-', value).strip('-')


def sources(root=ROOT):
    rows = read(root / 'data/public-sources.json')['sources']
    if len({r['id'] for r in rows}) != len(rows):
        raise ValueError('Duplicate source identities')
    for row in rows:
        u = urlsplit(row['url'])
        if u.scheme != 'https' or u.hostname != 'static.rainfocus.com':
            raise ValueError('Source is outside the public manifest host')
        if not re.fullmatch(r'S\d{2}', row['id']) or not re.fullmatch(r'[0-9a-f]{64}', row['version']['sha256']):
            raise ValueError('Invalid source ID/hash')
    return rows


def catalog(root=ROOT, curated=None):
    """Verified public discovery metadata, separate from reviewed passage evidence."""
    path = root / 'data/public-catalog.json'
    if not path.exists():
        return []
    rows = read(path)['items']
    if not isinstance(rows, list) or len({r['id'] for r in rows}) != len(rows):
        raise ValueError('Invalid or duplicate public catalogue identities')

    def public_key(raw):
        from .public_access import validate_url
        validate_url(raw)
        u = urlsplit(raw)
        host = (u.hostname or '').lower().rstrip('.')
        return (u.scheme, host, u.path, u.query)

    # The curated source identity wins when the same public edition is present
    # in both inputs. Fragment-only page locators do not create new documents.
    seen_urls = {public_key(r['url']) for r in (sources(root) if curated is None else curated)}
    result = []
    for row in sorted(rows, key=lambda r: r['id']):
        if (not re.fullmatch(r'R\d{4,6}', row['id'])
                or not re.fullmatch(re.escape(row['id']) + r'-v[1-9]\d*', row['version']['id'])
                or not re.fullmatch(r'[0-9a-f]{64}', row['version']['sha256'])
                or row.get('access_status') not in {'verified_public','manually_marked_public'}):
            raise ValueError('Catalogue entry lacks a valid identity, edition hash or public verification')
        if not isinstance(row.get('title'), str) or not row['title'].strip():
            raise ValueError('Catalogue entry lacks a title')
        for field in ('topics', 'business_domains', 'session_ids'):
            values = row.get(field, [])
            if not isinstance(values, list) or any(not isinstance(v, str) or not v.strip() for v in values):
                raise ValueError('Invalid catalogue ' + field)
        key = public_key(row['url'])
        if key not in seen_urls:
            result.append(row)
            seen_urls.add(key)
    return result


class PublicRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        target = urlsplit(newurl)
        if target.scheme != 'https' or target.hostname != 'static.rainfocus.com':
            raise ValueError('Redirect left the public-source allowlist')
        return super().redirect_request(request, fp, code, msg, headers, newurl)


def fetch(root=ROOT):
    results = []
    for row in sources(root):
        target = root / 'work/originals' / (row['id'] + '.pdf')
        if target.exists():
            body = target.read_bytes()
            mode = 'verified_cache'
        else:
            with build_opener(PublicRedirect()).open(row['url'], timeout=60) as response:
                body = response.read()
            mode = 'anonymous_download'
        if not body.startswith(b'%PDF') or digest(body) != row['version']['sha256']:
            raise ValueError(f"{row['id']}: wrong format or changed edition; review the manifest")
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            target.write_bytes(body)
        results.append({'source_id': row['id'], 'sha256': digest(body), 'mode': mode})
    write(root / 'work/fetch-report.json', results)
    return results


def normalise(text):
    return re.sub(r'\s+', ' ', text).strip()


def page_texts(file, numbers):
    warnings=[]
    class Capture(logging.Handler):
        def emit(self, record):
            warnings.append(record.getMessage())
    logger=logging.getLogger('pypdf')
    handler=Capture();propagate=logger.propagate
    logger.addHandler(handler);logger.propagate=False
    try:
        pdf=PdfReader(file)
        result=[]
        for number in numbers:
            if not 1<=number<=len(pdf.pages):
                raise ValueError('Page is outside the verified edition')
            text=normalise(pdf.pages[number-1].extract_text() or '')
            if not text:
                raise ValueError('Selected page has no text; OCR is not implicit')
            result.append((number,text))
        return result,warnings
    finally:
        logger.removeHandler(handler);logger.propagate=propagate


def prepare(root=ROOT, chunk_size=1000, overlap=100):
    if not 0 <= overlap < chunk_size:
        raise ValueError('Overlap must be smaller than chunk size')
    passages = []
    extraction_warnings=[]
    for row in sources(root):
        file = root / 'work/originals' / (row['id'] + '.pdf')
        if not file.exists() or digest(file.read_bytes()) != row['version']['sha256']:
            raise ValueError(f"{row['id']}: fetch verified original first")
        extracted,warnings=page_texts(file,row['selected_pdf_pages'])
        if warnings:
            extraction_warnings.append({'source_id':row['id'],'warnings':warnings})
        for number,text in extracted:
            for index, start in enumerate(range(0, len(text), chunk_size - overlap), 1):
                chunk = text[start:start + chunk_size]
                passages.append({'id': f"{row['version']['id']}-p{number:03d}-c{index:03d}-{digest(chunk)[:8]}",
                    'source_id': row['id'], 'version_id': row['version']['id'], 'pdf_page': number,
                    'chunk_index': index, 'text': chunk, 'text_sha256': digest(chunk),
                    'source_sha256': row['version']['sha256'], 'extractor': 'pypdf-7.1.0-normalised-v1',
                    'locator_url': row['url'] + f'#page={number}'})
                if start + chunk_size >= len(text):
                    break
    write(root / 'work/passages.json', passages)
    write(root / 'work/extraction-report.json',{'warnings':extraction_warnings,'review_note':'Recovered parser warnings do not by themselves establish perfect text extraction. Spot-check ambiguous source pages.'})
    return passages


def load_passages(root=ROOT):
    """Combine local extraction inputs without importing dev text into a release.

    Release builds provide only work/passages.json. The optional catalogue file
    is local ingestion output and is never copied into the learner distribution.
    IDs identify immutable text and its exact source edition.
    """
    from .public_access import validate_url
    source_rows = {s['id']: s for s in sources(root) + catalog(root)}
    combined = {}
    for name in ('passages.json', 'catalog-passages.json'):
        path = root / 'work' / name
        if not path.exists():
            continue
        for passage in read(path):
            source = source_rows.get(passage.get('source_id'))
            if source is None or passage.get('version_id') != source['version']['id']:
                raise ValueError('Passage refers to an unknown source edition')
            if (passage.get('source_sha256') != source['version']['sha256']
                    or source['version'].get('hash_basis', 'source_response') != 'source_response'):
                raise ValueError('Passage must identify the verified source response hash')
            text = passage.get('text')
            if not isinstance(text, str) or not text.strip() or digest(text) != passage.get('text_sha256'):
                raise ValueError('Passage text/hash mismatch')
            identifier = passage.get('id', '')
            if (not isinstance(identifier, str) or len(identifier) > 200
                    or not re.fullmatch(re.escape(passage['version_id']) + r'-[A-Za-z0-9_-]+', identifier)):
                raise ValueError('Invalid passage identity')
            page = passage.get('pdf_page')
            if page is not None and (type(page) is not int or page < 1):
                raise ValueError('PDF page must be a positive integer or null')
            if type(passage.get('chunk_index')) is not int or passage['chunk_index'] < 1:
                raise ValueError('Invalid passage chunk index')
            validate_url(passage.get('locator_url', ''))
            locator, original = urlsplit(passage['locator_url']), urlsplit(source['url'])
            if (locator.scheme, locator.netloc, locator.path, locator.query) != (original.scheme, original.netloc, original.path, original.query):
                raise ValueError('Passage locator must refer to its source URL')
            if page is None and (not passage.get('locator_kind') or not passage.get('locator_label')):
                raise ValueError('Non-PDF passage requires an explicit locator')
            if identifier in combined and combined[identifier] != passage:
                raise ValueError('Conflicting passage records reuse an immutable ID')
            combined[identifier] = passage
    # Every raw chunk remains available for graph inspection and local authoring.
    # Answer retrieval uses the actually inspected summary basis, rather than
    # assuming the first page/section of every source contains useful evidence.
    selected = {}
    summary_path = root / 'data/public-content-summaries.json'
    if summary_path.exists():
        for entry in read(summary_path)['summaries']:
            ids, hashes = entry['basis_passage_ids'], entry['basis_text_sha256']
            if len(ids) != len(hashes):
                raise ValueError('Editorial basis IDs and hashes differ in length')
            for identifier, text_hash in zip(ids, hashes):
                basis = (entry['source_id'], entry['version_id'], entry['source_sha256'], text_hash)
                if identifier in selected and selected[identifier] != basis:
                    raise ValueError('Editorial basis gives conflicting passage provenance')
                selected[identifier] = basis
    result=[]
    for passage in combined.values():
        actual = (passage['source_id'], passage['version_id'], passage['source_sha256'], passage['text_sha256'])
        basis = selected.get(passage['id'])
        if basis is not None and basis != actual:
            raise ValueError('Retrieval basis does not match its source passage')
        eligible = (passage['source_id'].startswith('S')
                    or passage.get('content_kind') == 'attributed_editorial_summary'
                    or basis == actual)
        result.append({**passage, 'retrieval_eligible': eligible})
    return sorted(result, key=lambda p: (p['source_id'], p.get('pdf_page') or 0, p['chunk_index'], p['id']))


def evidence_coverage(passages):
    """Describe available text without implying that extraction is fact checking."""
    if not passages:
        return 'catalogue_only'
    if all(p.get('content_kind') == 'attributed_editorial_summary' for p in passages):
        return 'attributed_editorial_summary'
    return 'extracted_source_passages'


def content_sources(root=ROOT, passages=None):
    """Return runtime source metadata describing this build's actual evidence."""
    if passages is None:
        passages = load_passages(root)
    grouped = {}
    for passage in passages:
        grouped.setdefault(passage['source_id'], []).append(passage)
    rows=[]
    for source in sources(root) + catalog(root):
        actual = grouped.get(source['id'], [])
        coverage = evidence_coverage(actual)
        if source['id'].startswith('S') and coverage == 'extracted_source_passages':
            coverage = 'reviewed_pdf_pages'
        row = {**source, 'evidence_coverage': coverage, 'passage_count': len(actual),
               'retrieval_eligible_passage_count': sum(p.get('retrieval_eligible', False) for p in actual)}
        if actual and source['id'].startswith('R'):
            row['limitations'] = ('Attributable passages are available for this source edition. '
                'Extraction and editorial summaries do not establish factual correctness, current availability or observed value. '
                'Topic classifications remain editorial. Follow each passage locator to inspect its source.')
        rows.append(row)
    return rows


def validate_candidates(payload, passages, allowed_topics):
    """Structural/evidence checks; acceptance still requires human review."""
    if not isinstance(payload, dict) or set(payload) != {'claims'} or not isinstance(payload['claims'], list):
        raise ValueError('Expected exactly a claims array')
    if len(payload['claims']) > 20:
        raise ValueError('Too many claims per response')
    by_id = {p['id']: p for p in passages}
    checked = []
    for claim in payload['claims']:
        if not isinstance(claim, dict) or set(claim) != {'statement', 'topic_labels', 'evidence_id', 'quote'}:
            raise ValueError('Unexpected claim fields')
        statement, quote = claim['statement'], claim['quote']
        if not isinstance(statement, str) or not 1 <= len(statement) <= 1500:
            raise ValueError('Invalid statement')
        p = by_id.get(claim['evidence_id'])
        if p is None:
            raise ValueError('Unknown evidence ID')
        if not isinstance(quote, str) or not 10 <= len(quote) <= 240 or normalise(quote) not in normalise(p['text']):
            raise ValueError('Quote is absent from cited passage or outside allowed length')
        labels = claim['topic_labels']
        if not isinstance(labels, list) or not labels or any(not isinstance(t, str) or t not in allowed_topics for t in labels):
            raise ValueError('Unknown/empty topic labels')
        checked.append({**claim, 'id': 'C-' + digest(statement + p['id'])[:20],
                        'source_id': p['source_id'], 'version_id': p['version_id'],
                        'review_status': 'proposed'})
    return checked


def assess(context, source_rows, limit=3):
    preferences = context['topic_preferences']
    ranked = []
    for row in source_rows:
        matched = [t for t in row['topics'] if t in preferences]
        score = sum(preferences[t] for t in matched)
        if score:
            ranked.append({'source_id': row['id'], 'version_id': row['version']['id'],
                           'score': score, 'matched_topics': matched,
                           'rationale': 'Matches explicitly supplied context topics: ' + ', '.join(matched),
                           'limitations': row['limitations'], 'url': row['url']})
    ranked.sort(key=lambda r: (-r['score'], r['source_id']))
    return {'context_id': context['id'], 'context_version': context['snapshot_version'],
            'method': 'deterministic_topic_baseline_not_agent_result', 'status': 'proposed',
            'observed_value': None, 'recommendations': ranked[:limit]}


def packet(context_id, question, root=ROOT):
    contexts = read(root / 'data/contexts.json')['contexts']
    context = next((c for c in contexts if c['id'] == context_id), None)
    if context is None:
        raise ValueError('Unknown context')
    ranking = assess(context, sources(root))
    passages = load_passages(root)
    selected = []
    for row in ranking['recommendations']:
        pages_seen = set()
        for p in [p for p in passages if p['source_id'] == row['source_id']]:
            locator = (p.get('pdf_page'), p.get('locator_label'))
            if locator not in pages_seen:
                selected.append(p); pages_seen.add(locator)
            if len(pages_seen) == 2:
                break
    return {'context': context, 'question': question, 'baseline': ranking, 'evidence': selected,
            'instruction': 'Answer only from these passages. Distinguish source facts from relevance judgement. Cite evidence IDs. State missing evidence. Never treat roadmap material as current availability.'}


def build(root=ROOT):
    passages = load_passages(root)
    all_sources = content_sources(root, passages)
    source_rows = [s for s in all_sources if s['id'].startswith('S')]
    catalog_rows = [s for s in all_sources if s['id'].startswith('R')]
    by_source = {}
    for passage in passages:
        by_source.setdefault(passage['source_id'], []).append(passage)
    examples = read(root / 'review-examples/examples.json')['examples']
    contexts = read(root / 'data/contexts.json')['contexts']
    g = Graph().parse(root / 'ontology/kcv.ttl', format='turtle')
    g.bind('kcv', K); g.bind('skos', SKOS)
    def literal(subject, predicate, value):
        if value is not None:
            g.add((subject, K[predicate], Literal(value)))
    def entity(identifier, kind, label=None):
        n = K[identifier]; g.add((n, RDF.type, K[kind]))
        if label:
            g.add((n, RDFS.label, Literal(label)))
        return n
    for s in source_rows:
        item = entity(s['id'], 'ContentItem', s['title'])
        v = entity(s['version']['id'], 'ContentVersion')
        g.add((item, K.hasVersion, v)); g.add((v, K.sourceURL, URIRef(s['url'])))
        literal(v, 'sha256', s['version']['sha256']); literal(v, 'limitations', s['limitations'])
        literal(item, 'evidenceCoverage', s['evidence_coverage'])
        literal(v, 'evidenceCoverage', s['evidence_coverage'])
        for label in s['topics']:
            t = entity('topic-' + slug(label), 'Topic', label); g.add((item, K.coversTopic, t))
        for label in s['business_domains']:
            t = entity('domain-' + slug(label), 'Domain', label); g.add((item, K.hasDomain, t))
        t = entity('purpose-' + slug(s['proposed_lab_purpose']), 'ContributionPurpose', s['proposed_lab_purpose'])
        g.add((item, K.hasPurpose, t)); literal(item, 'classificationStatus', 'lab_editorial_assignment')
        for session in s['session_ids']:
            activity = entity(session, 'LearningOpportunity', session)
            g.add((activity, K.describedBy, item))
    for s in catalog_rows:
        item = entity(s['id'], 'ContentItem', s['title'])
        v = entity(s['version']['id'], 'ContentVersion')
        g.add((item, K.hasVersion, v)); g.add((v, K.sourceURL, URIRef(s['url'])))
        literal(v, 'sha256', s['version']['sha256'])
        literal(v, 'verifiedOn', s['version'].get('verified_on'))
        literal(v, 'accessStatus', s['access_status'])
        literal(v, 'hashBasis', s['version'].get('hash_basis','source_response'))
        literal(v, 'accessVerified', s.get('access_verified',True))
        literal(v, 'publicClassification', s.get('classification_status','verified public'))
        literal(v, 'verificationError', s.get('verification_error'))
        literal(v, 'mediaType', s.get('format'))
        literal(v, 'limitations', s.get('limitations'))
        literal(item, 'contentForm', s.get('content_form'))
        literal(item, 'classificationStatus', 'research_catalogue_editorial_assignment')
        coverage = evidence_coverage(by_source.get(s['id'], []))
        literal(item, 'evidenceCoverage', coverage)
        literal(v, 'evidenceCoverage', coverage)
        for label in s.get('topics', []):
            t = entity('topic-' + slug(label), 'Topic', label); g.add((item, K.coversTopic, t))
        for label in s.get('business_domains', []):
            t = entity('domain-' + slug(label), 'Domain', label); g.add((item, K.hasDomain, t))
        for session in s.get('session_ids', []):
            activity = entity(session, 'LearningOpportunity', session)
            g.add((activity, K.describedBy, item))
        # Access alone creates no evidence; only validated local passages below
        # create hasPassage links. Neither extraction nor summaries accept claims.
    for p in passages:
        n = entity(p['id'], 'EvidencePassage'); g.add((K[p['version_id']], K.hasPassage, n))
        literal(n, 'pdfPage', p.get('pdf_page')); literal(n, 'chunkIndex', p['chunk_index'])
        literal(n, 'textHash', p['text_sha256']); g.add((n, K.sourceURL, URIRef(p['locator_url'])))
        literal(n, 'sourceHash', p['source_sha256'])
        literal(n, 'locatorKind', p.get('locator_kind', 'pdf_page' if p.get('pdf_page') else None))
        literal(n, 'locatorLabel', p.get('locator_label', f"PDF page {p['pdf_page']}" if p.get('pdf_page') else None))
        literal(n, 'contentKind', p.get('content_kind', 'extracted_source_text'))
        literal(n, 'extractor', p.get('extractor'))
        literal(n, 'retrievalEligible', p['retrieval_eligible'])
        literal(n, 'reviewStatus', p.get('review_status'))
        for basis_id in p.get('basis_passage_ids', []):
            # Provenance identifier only; raw passages are not invented as nodes
            # in a release that distributes only attributed editorial summaries.
            literal(n, 'basisPassageId', basis_id)
        basis_hashes = p.get('basis_text_sha256', [])
        if isinstance(basis_hashes, str):
            basis_hashes = [basis_hashes]
        for basis_hash in basis_hashes:
            literal(n, 'basisTextHash', basis_hash)
        # Full source text stays in ignored local work files.
    for e in examples:
        n = entity(e['id'], 'ReviewExample'); literal(n, 'statement', e['expected_statement'])
        literal(n, 'reviewStatus', 'editorial_paraphrase_not_extracted_claim')
        matching = [p for p in by_source.get(e['source_id'], []) if p.get('pdf_page') == e['pdf_page']]
        if not matching:
            raise ValueError('Review example has no real source page')
        for p in matching:
            g.add((n, K.reviewPage, K[p['id']]))
    assessments = []
    for c in contexts:
        snapshot_id = c['id'] + '-v' + str(c['snapshot_version'])
        snapshot = entity(snapshot_id, 'ContextSnapshot')
        person = entity(c['id'] + '-person', 'Person', c['person'])
        org = entity(c['id'] + '-org', 'Organisation', c['organisation'])
        engagement = entity(c['id'] + '-engagement', 'Engagement')
        g.add((snapshot, K.forEngagement, engagement)); g.add((snapshot, K.focalPerson, person))
        g.add((engagement, K.involvedOrganisation, org)); literal(snapshot, 'fictional', True)
        literal(snapshot, 'representedRole', c['role']); literal(snapshot, 'objectiveClarity', c['objective_clarity'])
        literal(snapshot, 'learningPurpose', c['learning_purpose'])
        question = entity(snapshot_id + '-question', 'Question', c['question'])
        g.add((snapshot, K.raisesQuestion, question))
        if c.get('objective'):
            goal = entity(snapshot_id + '-objective', 'Objective', c['objective']); g.add((snapshot, K.hasObjective, goal))
        a = assess(c, source_rows); assessments.append(a)
        n = entity('assessment-' + snapshot_id, 'RelevanceAssessment')
        g.add((n, K.forContext, snapshot)); literal(n, 'method', a['method']); literal(n, 'reviewStatus', 'proposed')
        for recommendation in a['recommendations']:
            g.add((n, K.recommendsVersion, K[recommendation['version_id']]))
    accepted_file = root / 'work/accepted-claims.json'
    accepted = read(accepted_file) if accepted_file.exists() else []
    allowed = {t for s in source_rows + catalog_rows for t in s['topics']}
    for claim in accepted:
        if not claim.get('reviewer') or not claim.get('review_reason'):
            raise ValueError('Accepted claim lacks review record')
        fields = {k:claim[k] for k in ['statement','topic_labels','evidence_id','quote']}
        validate_candidates({'claims': [fields]}, passages, allowed)
        n = entity(claim['id'], 'Claim'); literal(n, 'statement', claim['statement'])
        literal(n, 'reviewStatus', 'accepted'); literal(n, 'reviewer', claim['reviewer'])
        g.add((n, K.supportedBy, K[claim['evidence_id']]))
        for t in claim['topic_labels']:
            g.add((n, K.coversTopic, K['topic-' + slug(t)]))
    generated = root / 'generated'; generated.mkdir(exist_ok=True)
    # Sorted N-Triples is valid Turtle and gives repeatable, reviewable output.
    text = ''.join(sorted(g.serialize(format='nt').splitlines(keepends=True)))
    if any(len(term.n3().encode('utf-8'))>4000 for triple in g for term in triple):
        raise ValueError('An RDF term exceeds the native staging-table byte limit; shorten/split it explicitly')
    (generated / 'knowledge.ttl').write_text(text, encoding='utf-8', newline='\n')
    write(generated / 'assessments.json', assessments)
    summary = {'source_count': len(source_rows), 'catalog_count': len(catalog_rows),
               'total_content_count': len(source_rows) + len(catalog_rows),
               'passage_count': len(passages), 'review_example_count': len(examples),
               'catalog_passage_count': sum(len(by_source.get(s['id'], [])) for s in catalog_rows),
               'retrieval_eligible_passage_count': sum(p['retrieval_eligible'] for p in passages),
               'sources_with_retrieval_evidence': sum(any(p['retrieval_eligible'] for p in rows) for rows in by_source.values()),
               'catalog_sources_with_passages': sum(s['id'] in by_source for s in catalog_rows),
               'catalog_sources_without_passages': sum(s['id'] not in by_source for s in catalog_rows),
               'sources_with_extracted_passages': sum(any(p.get('content_kind') != 'attributed_editorial_summary' for p in rows) for rows in by_source.values()),
               'sources_with_editorial_summaries': sum(any(p.get('content_kind') == 'attributed_editorial_summary' for p in rows) for rows in by_source.values()),
               'sources_catalogue_only': sum(s['id'] not in by_source for s in all_sources),
               'accepted_claim_count': len(accepted), 'context_count': len(contexts), 'triple_count': len(g),
               'graph_sha256': digest(text), 'native_serverless_validation': 'not_run',
               'model_extraction': 'not_run' if not (root / 'work/candidates.json').exists() else 'see_work_run_log',
               'full_source_text_location': 'ignored work/passages.json and work/catalog-passages.json', 'independent_of_original_collection': True}
    report_file=root/'work/extraction-report.json'
    if report_file.exists():
        summary['source_parser_warning_counts']={r['source_id']:len(r['warnings']) for r in read(report_file)['warnings']}
    write(generated / 'build-report.json', summary)
    lines = ['# Generated dataset preview', '', 'Generated from real public editions; contexts are fictional. No model or Serverless execution is implied.', '',
             '| Source | Session | Public presentation | Review pages |', '| --- | --- | --- | --- |']
    for s in source_rows:
        lines.append(f"| {s['id']} | {', '.join(s['session_ids'])} | [{s['title']}]({s['url']}) | {', '.join(map(str,s['selected_pdf_pages']))} |")
    lines.extend(['', '## Public research catalogue', '',
                  f"{len(catalog_rows)} additional public catalogue records; {len(source_rows) + len(catalog_rows)} total content items including the curated sources.", '',
                  f"{summary['catalog_sources_with_passages']} catalogue sources have {summary['catalog_passage_count']} attributable passages; {summary['catalog_sources_without_passages']} remain `evidenceCoverage=catalogue_only`. Only sources with passages can supply answer evidence. Manual public classifications and actual access results remain separate; metadata-only hashes do not identify downloaded content. Extraction and editorial summaries do not create accepted claims.", '',
                  'The complete title, public URL, edition hash and verification metadata are in [public-catalog.json](../data/public-catalog.json).' if catalog_rows else 'No additional public catalogue is bundled in this build.'])
    lines.extend(['', '## Context comparisons', ''])
    for a in assessments:
        lines.append(f"- {a['context_id']}: " + ', '.join(x['source_id'] for x in a['recommendations']) + ' (topic baseline; proposed).')
    lines.extend(['', f"{len(passages)} attributable passages with source locators; {len(examples)} curated review examples; {len(accepted)} accepted extracted claims.", '',
                  'Review examples are separate from Claim nodes. Actual passages are generated locally and not redistributed.'])
    (generated / 'dataset-preview.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    from .catalog_html import render
    render(root)
    return summary


def review(candidate_id, decision, reviewer, reason, root=ROOT):
    if decision not in {'accept','reject'} or not reviewer.strip() or not reason.strip():
        raise ValueError('Explicit decision, reviewer and rationale required')
    candidates = read(root / 'work/candidates.json')
    claim = next((x for x in candidates if x['id'] == candidate_id), None)
    if claim is None:
        raise ValueError('Unknown candidate')
    accepted_file = root / 'work/accepted-claims.json'
    accepted = read(accepted_file) if accepted_file.exists() else []
    accepted = [x for x in accepted if x['id'] != candidate_id]
    reviewed_at=datetime.now(timezone.utc).isoformat()
    if decision == 'accept':
        accepted.append({**claim, 'reviewer':reviewer, 'review_reason':reason, 'review_status':'accepted','reviewed_at':reviewed_at})
    write(accepted_file, accepted)
    log = root / 'work/reviews.jsonl'
    with log.open('a', encoding='utf-8') as f:
        f.write(json.dumps({'candidate_id':candidate_id,'decision':decision,'reviewer':reviewer,'reason':reason,'reviewed_at':reviewed_at}) + '\n')


def render_svg(root=ROOT):
    labels = [('People / organisations',80,50),('Context snapshot',80,170),('Question / objective',80,290),
              ('Relevance assessment',450,170),('Content version',820,50),('Source passage',820,170),('Claim / evidence',820,290)]
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="440" viewBox="0 0 1120 440">',
             '<rect width="1120" height="440" fill="#faf6ee"/>',
             '<style>text{font-family:Arial,sans-serif;fill:#203d3a}path{stroke:#688782;stroke-width:2;fill:none}rect.node{stroke:#3d7c72;stroke-width:2;fill:#e3eee5}</style>']
    for a,b in [(0,1),(1,2),(1,3),(3,5),(4,5),(5,6)]:
        _,x,y=labels[a];_,xx,yy=labels[b]
        parts.append(f'<path d="M {x+110} {y+50} L {xx+110} {yy}"/>')
    for label,x,y in labels:
        parts.append(f'<rect class="node" x="{x}" y="{y}" width="220" height="50" rx="9"/><text x="{x+110}" y="{y+30}" text-anchor="middle" font-size="16">{html.escape(label)}</text>')
    parts.append('<text x="560" y="405" text-anchor="middle" font-size="18">Public knowledge + explicit context → proposed relevance → observed feedback</text></svg>')
    (root/'generated/model.svg').write_text(''.join(parts),encoding='utf-8')
