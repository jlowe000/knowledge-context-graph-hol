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
    passages = read(root / 'work/passages.json')
    selected = []
    for row in ranking['recommendations']:
        pages_seen = set()
        for p in [p for p in passages if p['source_id'] == row['source_id']]:
            if p['pdf_page'] not in pages_seen:
                selected.append(p); pages_seen.add(p['pdf_page'])
            if len(pages_seen) == 2:
                break
    return {'context': context, 'question': question, 'baseline': ranking, 'evidence': selected,
            'instruction': 'Answer only from these passages. Distinguish source facts from relevance judgement. Cite evidence IDs. State missing evidence. Never treat roadmap material as current availability.'}


def build(root=ROOT):
    source_rows = sources(root)
    passages = read(root / 'work/passages.json')
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
        for label in s['topics']:
            t = entity('topic-' + slug(label), 'Topic', label); g.add((item, K.coversTopic, t))
        for label in s['business_domains']:
            t = entity('domain-' + slug(label), 'Domain', label); g.add((item, K.hasDomain, t))
        t = entity('purpose-' + slug(s['proposed_lab_purpose']), 'ContributionPurpose', s['proposed_lab_purpose'])
        g.add((item, K.hasPurpose, t)); literal(item, 'classificationStatus', 'lab_editorial_assignment')
        for session in s['session_ids']:
            activity = entity(session, 'LearningOpportunity', session)
            g.add((activity, K.describedBy, item))
    for p in passages:
        n = entity(p['id'], 'EvidencePassage'); g.add((K[p['version_id']], K.hasPassage, n))
        literal(n, 'pdfPage', p['pdf_page']); literal(n, 'chunkIndex', p['chunk_index'])
        literal(n, 'textHash', p['text_sha256']); g.add((n, K.sourceURL, URIRef(p['locator_url'])))
        # Full source text stays in ignored local work files.
    for e in examples:
        n = entity(e['id'], 'ReviewExample'); literal(n, 'statement', e['expected_statement'])
        literal(n, 'reviewStatus', 'editorial_paraphrase_not_extracted_claim')
        matching = [p for p in passages if p['source_id'] == e['source_id'] and p['pdf_page'] == e['pdf_page']]
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
    allowed = {t for s in source_rows for t in s['topics']}
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
    summary = {'source_count': len(source_rows), 'passage_count': len(passages), 'review_example_count': len(examples),
               'accepted_claim_count': len(accepted), 'context_count': len(contexts), 'triple_count': len(g),
               'graph_sha256': digest(text), 'native_serverless_validation': 'not_run',
               'model_extraction': 'not_run' if not (root / 'work/candidates.json').exists() else 'see_work_run_log',
               'full_source_text_location': 'ignored work/passages.json', 'independent_of_original_collection': True}
    report_file=root/'work/extraction-report.json'
    if report_file.exists():
        summary['source_parser_warning_counts']={r['source_id']:len(r['warnings']) for r in read(report_file)['warnings']}
    write(generated / 'build-report.json', summary)
    lines = ['# Generated dataset preview', '', 'Generated from real public editions; contexts are fictional. No model or Serverless execution is implied.', '',
             '| Source | Session | Public presentation | Review pages |', '| --- | --- | --- | --- |']
    for s in source_rows:
        lines.append(f"| {s['id']} | {', '.join(s['session_ids'])} | [{s['title']}]({s['url']}) | {', '.join(map(str,s['selected_pdf_pages']))} |")
    lines.extend(['', '## Context comparisons', ''])
    for a in assessments:
        lines.append(f"- {a['context_id']}: " + ', '.join(x['source_id'] for x in a['recommendations']) + ' (topic baseline; proposed).')
    lines.extend(['', f"{len(passages)} real page-aware passages; {len(examples)} curated review examples; {len(accepted)} accepted extracted claims.", '',
                  'Review examples are separate from Claim nodes. Actual passages are generated locally and not redistributed.'])
    (generated / 'dataset-preview.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
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
