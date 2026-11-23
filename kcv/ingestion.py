"""Anonymous, content-aware ingestion of the approved public research catalogue.

Raw downloads and extracted passages belong in ignored work/, never a release.
Public metadata can be refreshed only after a successful anonymous body check.
"""
from __future__ import annotations

import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import io
import json
import logging
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
from urllib.request import Request, build_opener

from pypdf import PdfReader

from .pipeline import digest, normalise, read, write
from .public_access import PublicRedirect, inspect_body, public_rule, retained_publisher, validate_url


class ContentHTML(HTMLParser):
    """Visible block extraction; no scripts, menus, forms, or hidden app state."""
    skip_tags = {'script', 'style', 'noscript', 'nav', 'footer', 'form', 'button', 'svg'}
    block_tags = {'p', 'li', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'td', 'dt', 'dd'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.blocks = []
        self.buffer = []
        self.tag = ''
        self.anchor = None
        self.main_seen = False
        self.in_main = 0

    def flush(self):
        text = normalise(' '.join(self.buffer))
        if text:
            self.blocks.append({'text': text, 'heading': self.tag.startswith('h'),
                                'anchor': self.anchor, 'main': self.in_main > 0})
        self.buffer = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        inherited = self.stack[-1][1] if self.stack else False
        hidden = inherited or tag in self.skip_tags or attrs.get('aria-hidden') == 'true' or 'hidden' in attrs
        if tag not in {'meta', 'link', 'br', 'hr', 'input', 'img', 'source', 'wbr', 'area', 'base', 'embed', 'param', 'track'}:
            self.stack.append((tag, hidden))
        if tag in {'main', 'article'} or attrs.get('role') == 'main':
            self.flush(); self.in_main += 1; self.main_seen = True
        if tag in self.block_tags and not hidden:
            self.flush(); self.tag = tag; self.anchor = attrs.get('id')

    def handle_endtag(self, tag):
        if tag in self.block_tags:
            self.flush()
        if tag in {'main', 'article'}:
            self.flush(); self.in_main = max(0, self.in_main - 1)
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                self.stack = self.stack[:i]
                break

    def handle_data(self, text):
        if not self.stack or not self.stack[-1][1]:
            self.buffer.append(text)

    def selected(self):
        self.flush()
        mains = [b for b in self.blocks if b['main']]
        # Some templates have a contentless main shell and real text elsewhere.
        rows = mains if sum(len(b['text']) for b in mains) >= 200 else self.blocks
        seen = set(); result = []
        for row in rows:
            if row['text'] not in seen:
                result.append(row); seen.add(row['text'])
        return result


def extract(body, content_type, source):
    """Return locator-aware segments. Unsupported media are explicit outcomes."""
    url = source['url']; host = urlsplit(url).hostname
    if host in {'www.youtube.com', 'youtube.com', 'youtu.be'}:
        return [], 'video_transcript_not_available'
    if body.startswith(b'%PDF'):
        pdf = PdfReader(io.BytesIO(body))
        if pdf.is_encrypted:
            return [], 'encrypted_pdf_no_text_extraction'
        rows = []
        for number, page in enumerate(pdf.pages, 1):
            text = normalise(page.extract_text() or '')
            if len(text) >= 25:
                rows.append({'text': text, 'pdf_page': number, 'locator_kind': 'pdf_page',
                             'locator_label': f'PDF page {number}', 'locator_url': url + f'#page={number}',
                             'segment_index': number})
        return rows, 'extracted' if rows else 'pdf_without_extractable_text_no_ocr'
    if body.startswith((b'PK\x03\x04', b'\x1f\x8b')):
        return [], 'archive_contents_not_extracted'
    if content_type.startswith(('image/', 'video/', 'audio/')):
        return [], 'visual_or_media_content_not_transcribed'
    text = body.decode('utf-8', errors='replace')
    if '\x00' in text[:4000]:
        return [], 'binary_content_not_extracted'
    raw_repository = host == 'raw.githubusercontent.com'
    if host == 'api.github.com':
        payload = json.loads(text)
        is_blob = '/git/blobs/' in url
        is_encoded_file = isinstance(payload, dict) and payload.get('encoding') == 'base64' and isinstance(payload.get('content'), str)
        if is_blob and not is_encoded_file:
            return [], 'repository_blob_without_supported_content'
        if is_encoded_file:
            decoded = base64.b64decode(payload['content'], validate=False)
            if b'\x00' in decoded[:4000]:
                return [], 'binary_repository_blob_not_extracted'
            text = decoded.decode('utf-8', errors='replace'); raw_repository = True
    if ('html' in content_type or re.search(r'<(?:!doctype html|html)', text[:2000], re.I)) and not raw_repository:
        parser = ContentHTML(); parser.feed(text)
        blocks = parser.selected()
        visible = ' '.join(b['text'] for b in blocks)
        if host == 'github.com' and re.search(r"(?:can.t show files (?:that are )?this big|too (?:large|big) to display|file is too large to display)", visible, re.I):
            return [], 'metadata_page_only'
        if host == 'github.com' and '/blob/' in url and len(visible) < 700:
            # GitHub can put file contents in its embedded JSON rather than
            # visible HTML. Decode that public response; never use its UI
            # filename, sign-in controls or byte-size label as file evidence.
            match = re.search(r'"rawLines"\s*:\s*(\[)', text)
            if match:
                raw_lines, _ = json.JSONDecoder().raw_decode(text[match.start(1):])
                if isinstance(raw_lines, list) and all(isinstance(line, str) for line in raw_lines):
                    file_text = '\n'.join(raw_lines)
                    rows = []
                    for start in range(0, len(raw_lines), 30):
                        value = normalise('\n'.join(raw_lines[start:start + 30]))
                        if value:
                            rows.append({'text': value, 'pdf_page': None, 'locator_kind': 'repository_file',
                                'locator_label': f'File lines {start + 1}-{min(start + 30, len(raw_lines))}',
                                'segment_index': start // 30 + 1, 'locator_url': url})
                    return rows, 'extracted' if rows else 'no_substantive_text'
            if 'File metadata and controls' in visible:
                return [], 'metadata_page_only'
        rows = []; heading = 'Page content'; group = []; section = 0; anchor = None
        def emit():
            nonlocal group, section
            joined = normalise(' '.join(group))
            if len(joined) >= 25:
                section += 1
                rows.append({'text': joined, 'pdf_page': None, 'locator_kind': 'html_section',
                             'locator_label': heading[:250], 'segment_index': section,
                             'locator_url': url + ('#' + anchor if anchor and '#' not in url else '')})
            group = []
        for block in blocks:
            if block['heading'] and len(block['text']) < 250:
                emit(); heading = block['text']; anchor = block['anchor']
            group.append(block['text'])
        emit()
        return rows, 'extracted' if rows else 'no_substantive_visible_text'
    if len(text.strip()) < 25:
        return [], 'no_substantive_text'
    kind = 'repository_file' if raw_repository else 'text_resource'
    rows = []
    lines = text.splitlines()
    for start in range(0, len(lines), 30):
        segment = normalise('\n'.join(lines[start:start + 30]))
        if not segment:
            continue
        end = min(start + 30, len(lines))
        rows.append({'text': segment, 'pdf_page': None, 'locator_kind': kind,
                     'locator_label': f'File lines {start + 1}-{end}', 'segment_index': start // 30 + 1,
                     'locator_url': url})
    return rows, 'extracted'


def chunks(source, segments, chunk_size=1000, overlap=100):
    if not 0 <= overlap < chunk_size <= 1000:
        raise ValueError('Invalid chunk size/overlap')
    result = []
    for segment in segments:
        text = segment['text']; n = segment['segment_index']
        for index, start in enumerate(range(0, len(text), chunk_size - overlap), 1):
            value = text[start:start + chunk_size]
            locator = f'p{n:03d}' if segment['pdf_page'] else f's{n:04d}'
            result.append({**{k: v for k, v in segment.items() if k != 'text'},
                'id': f"{source['version']['id']}-{locator}-c{index:03d}-{digest(value)[:8]}",
                'source_id': source['id'], 'version_id': source['version']['id'],
                'chunk_index': index, 'text': value, 'text_sha256': digest(value),
                'source_sha256': source['version']['sha256'],
                'extractor': 'public-content-text-v1', 'content_kind': 'extracted_source_text'})
            if start + chunk_size >= len(text):
                break
    return result


def summary_input(source, passages):
    """A small, explicitly sampled evidence packet for editorial paraphrasing."""
    if not passages:
        return None
    def score(p):
        text = p['text']; lower = text.casefold()
        penalty = sum(lower.count(term) for term in ('safe harbor', 'forward-looking', 'thank you', 'copyright',
            'privacy policy', 'cookie preferences', 'all rights reserved', 'sign in', 'skip to content')) * 300
        if p.get('pdf_page') and p['pdf_page'] < 3: penalty += 500
        return min(len(text), 1000) - penalty
    first = max(passages, key=score)
    if score(first) < 100:
        return None
    adjacent = next((p for p in passages if p['segment_index'] == first['segment_index'] and p['chunk_index'] == first['chunk_index'] + 1), None)
    selected = [first] + ([adjacent] if adjacent else [])
    return {'source_id': source['id'], 'title': source['title'], 'url': source['url'],
            'version_id': source['version']['id'], 'source_sha256': source['version']['sha256'],
            'evidence': [{'evidence_id': p['id'], **{k: p[k] for k in ('text', 'pdf_page', 'locator_kind', 'locator_label', 'locator_url', 'text_sha256')}} for p in selected]}


def local_candidates(report_path, sources):
    if not report_path:
        return {}
    report_path = Path(report_path).resolve(); report = read(report_path)
    requested = {i for s in sources for i in s.get('report_ids', [])}
    by_id = {}
    for collection in ('records', 'references'):
        for row in report.get(collection, []):
            if row.get('id') not in requested or not row.get('path_href'):
                continue
            relative = unquote(row['path_href']).split('#')[0]
            if '://' in relative:
                continue
            path = (report_path.parent / relative).resolve()
            # A report cannot ask this tool to inspect unrelated local files.
            if not path.is_relative_to(report_path.parent.parent):
                continue
            if path.is_file():
                by_id[row['id']] = path
    return {s['id']: [by_id[i] for i in s.get('report_ids', []) if i in by_id] for s in sources}


def ingest_one(source, policy, checks, cache, candidates, refresh=False):
    sid = source['id']; now = datetime.now(timezone.utc).isoformat()
    result = {'source_id': sid, 'url': source['url'], 'checked_at': now, 'status': 'pending'}
    try:
        validate_url(source['url'])
        rule = public_rule(source['url'], policy['url_prefixes'], source['title'], policy.get('title_rules', []))
        if not rule and not retained_publisher(source['url'], policy):
            raise ValueError('source_awaiting_public_scope_review')
        old = source['version']['sha256']; expected = cache / 'bodies' / old
        body = None; content_type = source.get('format', 'application/octet-stream'); checked = checks.get(sid, {})
        for path in [expected, *candidates]:
            if path.is_file():
                candidate = path.read_bytes()
                if digest(candidate) == old and source['version'].get('hash_basis') == 'source_response':
                    body = candidate; result['acquisition'] = 'verified_existing_public_edition'; break
        if body is None:
            validate_url(source['url'], resolve=True)
            request = Request(source['url'], headers={'User-Agent': 'PublicKnowledgeContent/1.0', 'Accept': '*/*'})
            with build_opener(PublicRedirect()).open(request, timeout=40) as response:
                if response.status != 200:
                    raise ValueError('non_200_response')
                final = response.geturl(); validate_url(final)
                body = response.read(64 * 1024 * 1024 + 1)
                if len(body) > 64 * 1024 * 1024:
                    raise ValueError('size_limit_requires_review')
                content_type = response.headers.get_content_type()
            hosts = {'github.com', 'api.github.com', 'raw.githubusercontent.com'}
            details = inspect_body(body, content_type, public_repository_asset=urlsplit(source['url']).hostname in hosts and urlsplit(final).hostname in hosts,
                manual_public=bool(rule), raw_repository_source=urlsplit(source['url']).hostname == 'raw.githubusercontent.com' and urlsplit(final).hostname == 'raw.githubusercontent.com')
            sha = digest(body)
            checked = {**details, 'source_id': sid, 'checked_at': now, 'http_status': 200,
                'bytes': len(body), 'sha256': sha, 'authentication_used': False, 'cookies_used': False,
                'url': source['url'], 'final_url': final, 'hash_basis': 'source_response', 'access_verified': True,
                'public_rule': rule, 'classification_status': 'manually marked as public' if rule else 'verified public',
                'status': 'manually_marked_public' if rule else 'verified_public'}
            destination = cache / 'bodies' / sha
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists(): destination.write_bytes(body)
            result['acquisition'] = 'anonymous_download'
            if sha != old or source['version'].get('hash_basis') != 'source_response':
                version = int(source['version']['id'].rsplit('-v', 1)[1]) + 1
                result['edition_change'] = {'previous_version': source['version'], 'next_version': {
                    'id': f'{sid}-v{version}', 'sha256': sha, 'hash_basis': 'source_response',
                    'recorded_on': now[:10], 'verified_on': now[:10], 'bytes': len(body)}}
                result['access_check'] = checked
                if not refresh:
                    result['status'] = 'changed_edition_requires_refresh'; return result, [], []
                source = {**source, 'version': result['edition_change']['next_version'], 'format': details['format'],
                    'access_verified': True, 'access_status': checked['status'], 'classification_status': checked['classification_status'],
                    'public_rule': rule, 'verification_error': None}
                result['updated_source'] = source
            result['access_check'] = checked
        segments, status = extract(body, content_type, source)
        passages = chunks(source, segments)
        result.update({'status': status, 'version_id': source['version']['id'], 'sha256': digest(body),
                       'segment_count': len(segments), 'passage_count': len(passages),
                       'text_characters': sum(len(s['text']) for s in segments)})
        write(cache / 'segments' / (source['version']['id'] + '.json'), segments)
        write(cache / 'passages' / (source['version']['id'] + '.json'), passages)
        # First useful segments plus spread across the document for editorial review.
        useful = [s for s in segments if len(s['text']) >= 100 and not re.match(r'^(?:safe harbor|forward.looking|thank you|questions\??$)', s['text'], re.I)]
        sampled = useful[:5]
        for n in (len(useful) // 3, 2 * len(useful) // 3, len(useful) - 1):
            if useful and useful[n] not in sampled: sampled.append(useful[n])
        digest_rows = [{**{k: v for k, v in s.items() if k != 'text'}, 'text': s['text'][:1300]} for s in sampled]
        return result, passages, digest_rows
    except Exception as exc:
        # Error text may include redirect query values; keep report codes only.
        result.update({'status': 'fetch_or_extract_failed', 'error_type': type(exc).__name__,
                       'reason': str(exc) if re.fullmatch(r'[a-z_]+', str(exc)) else type(exc).__name__,
                       'http_status': getattr(exc, 'code', None)})
        return result, [], []


def run(root, report_path=None, workers=8, refresh=False, audit_dir=None):
    root = Path(root); cache = root / 'work/research-content'
    catalogue = read(root / 'data/public-catalog.json'); sources = catalogue['items']
    access = read(root / 'references/public-access-checks.json'); checks = {r['source_id']: r for r in access['checks']}
    policy = read(root / 'references/public-source-policy.json')
    candidates = local_candidates(report_path, sources)
    logging.getLogger('pypdf').setLevel(logging.ERROR)
    results = []; passages = []; digests = []; summary_inputs = []; source_map = {s['id']: s for s in sources}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        jobs = {pool.submit(ingest_one, source, policy, checks, cache, candidates.get(source['id'], []), refresh): source for source in sources}
        for future in as_completed(jobs):
            source = jobs[future]; result, items, sample = future.result()
            results.append(result); passages.extend(items)
            effective = result.get('updated_source', source)
            summary = summary_input(effective, items)
            if summary: summary_inputs.append(summary)
            if result.get('updated_source'): source_map[source['id']] = effective
            if result.get('access_check'): checks[source['id']] = result['access_check']
            digests.append({'source_id': source['id'], 'title': source['title'], 'url': source['url'],
                            'version_id': effective['version']['id'], 'source_sha256': effective['version']['sha256'],
                            'format': effective['format'], 'status': result['status'], 'segments': sample})
            write(cache / 'results' / (source['id'] + '.json'), result)
            if len(results) % 25 == 0:
                write(cache / 'summary-inputs.json', sorted(summary_inputs, key=lambda x: x['source_id']))
                write(root / 'work/catalog-passages.json', sorted(passages, key=lambda p: (p['source_id'], p['segment_index'], p['chunk_index'])))
                print(f'{len(results)}/{len(sources)} sources processed; {len(passages)} passages', flush=True)
    passages.sort(key=lambda p: (p['source_id'], p['segment_index'], p['chunk_index']))
    results.sort(key=lambda r: r['source_id']); digests.sort(key=lambda r: r['source_id'])
    write(root / 'work/catalog-passages.json', passages)
    write(cache / 'summary-inputs.json', sorted(summary_inputs, key=lambda x: x['source_id']))
    write(cache / 'editorial-review-digests.json', digests)
    statuses = {}
    for result in results: statuses[result['status']] = statuses.get(result['status'], 0) + 1
    report = {'format_version': 1, 'generated_at': datetime.now(timezone.utc).isoformat(),
        'source_count': len(sources), 'passage_count': len(passages), 'statuses': statuses,
        'source_count_with_passages': len({p['source_id'] for p in passages}),
        'edition_updates': sum('updated_source' in r for r in results), 'sources': results}
    write(cache / 'ingestion-report.json', report)
    if refresh:
        catalogue['items'] = [source_map[s['id']] for s in sources]
        write(root / 'data/public-catalog.json', catalogue)
        access['checks'] = [checks[r['source_id']] for r in access['checks']]
        access['verified_public_url_count'] = sum(r.get('access_verified') is True for r in access['checks'])
        access['manually_public_unverified_count'] = sum(r.get('access_verified') is not True for r in access['checks'])
        write(root / 'references/public-access-checks.json', access)
        if audit_dir:
            audit_path = Path(audit_dir).resolve() / 'public-research-checks.json'
            if audit_path.is_relative_to(root.resolve()): raise ValueError('Audit must remain outside the Git repository')
            audit = read(audit_path)
            for r in results:
                if r.get('access_check'):
                    check = dict(r['access_check']); check['ok'] = True
                    check['url'] = check.pop('final_url', check['url'])
                    audit[r['url']] = check
            write(audit_path, audit)
    return report
