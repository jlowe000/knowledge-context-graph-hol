"""Render a standalone public-source browser without embedding source bodies."""
from html import escape
from pathlib import Path

from .pipeline import ROOT, catalog, read, sources, content_sources


STYLE = """
:root{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#203936;background:#f8f6f1;color-scheme:light}
*{box-sizing:border-box}body{margin:0}main{max-width:1480px;margin:auto;padding:32px 24px 48px}
h1{font-size:clamp(1.8rem,3vw,2.5rem);line-height:1.15;margin:8px 0 16px}h2{font-size:1.15rem}
p{max-width:95ch;line-height:1.6}a{color:#155e69;text-underline-offset:3px}a:hover{color:#073d46}
a:focus-visible,input:focus-visible,select:focus-visible,button:focus-visible{outline:3px solid #ad5b12;outline-offset:3px}
.eyebrow{font-size:.8rem;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:#506865}
.summary{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}.stat{background:#e5eeea;padding:13px 20px;border-radius:7px;min-width:170px}
.stat strong{font-size:1.65rem;display:block}.stat span{font-size:.88rem}
.notice{border-left:4px solid #56786e;padding:10px 18px;background:#eef3ef;margin:16px 0 24px}
.controls{display:grid;grid-template-columns:2fr repeat(4,minmax(125px,1fr));gap:14px;padding:20px;background:#fff;border:1px solid #cbd8d0;border-radius:8px}
label{display:block;font-size:.85rem;font-weight:650;margin-bottom:6px}input,select,button{font:inherit;padding:9px 11px;border:1px solid #8ba29a;border-radius:4px;background:white;color:inherit;width:100%}
button{cursor:pointer;width:auto;font-size:.9rem}button:hover{background:#e5eeea}.toolbar{display:flex;justify-content:space-between;align-items:center;gap:16px;margin:14px 0}
.table-wrap{overflow-x:auto;border:1px solid #cbd8d0;border-radius:8px;background:#fff}table{border-collapse:collapse;width:100%;font-size:.9rem;table-layout:fixed}
caption{text-align:left;padding:16px;font-weight:600}th,td{text-align:left;vertical-align:top;padding:14px;border-top:1px solid #dbe3de;overflow-wrap:anywhere}
thead th{background:#e5eeea;font-size:.82rem}th:nth-child(1){width:40%}th:nth-child(2){width:28%}th:nth-child(3){width:13%}th:nth-child(4){width:19%}
tbody tr:nth-child(even){background:#fbfcfa}tr[hidden]{display:none}.source-id{font:700 .8rem ui-monospace,monospace;color:#58736a;display:block;margin-bottom:7px}
.title{font-weight:650;line-height:1.45}.url{display:block;font-size:.76rem;margin:8px 0;color:#45635c}.tags{display:flex;flex-wrap:wrap;gap:5px;margin:0 0 9px}
.tag{border:1px solid #bed0c5;border-radius:4px;background:#f1f5f0;padding:2px 6px;font-size:.76rem}.domains{font-size:.79rem;line-height:1.5;color:#516b63}
.coverage{display:inline-block;border-radius:4px;padding:4px 7px;font-size:.75rem;font-weight:650;background:#f1e8d4;color:#5b451b}.reviewed{background:#dceee3;color:#214f39}
.date{display:block;margin:9px 0 3px;font-size:.8rem}.format{font-family:ui-monospace,monospace;font-size:.78rem}.muted{font-size:.8rem;color:#52685f}.empty{padding:24px;background:#fff4dc;border:1px solid #d7c391;border-radius:7px}
footer{margin-top:24px;color:#52685f;font-size:.85rem;line-height:1.6}
@media(max-width:1000px){.controls{grid-template-columns:repeat(2,minmax(0,1fr))}.search{grid-column:1/-1}table{min-width:780px}}
@media(max-width:550px){main{padding:20px 12px}.controls{padding:12px;gap:12px}.stat{flex:1;min-width:130px}p{font-size:.95rem}}
@media print{.controls,.toolbar{display:none}main{max-width:none;padding:0}.table-wrap{overflow:visible}table{font-size:8pt;min-width:0}a{color:inherit}.stat{padding:8px}h1{font-size:22pt}}
"""

SCRIPT = """
(() => {
  'use strict';
  const rows = Array.from(document.querySelectorAll('#sources tbody tr'));
  const search = document.getElementById('search');
  const topic = document.getElementById('topic');
  const domain = document.getElementById('domain');
  const format = document.getElementById('format');
  const coverage = document.getElementById('coverage');
  const indexed = rows.map(row => ({row, text: row.textContent.toLocaleLowerCase(),
    topics: Array.from(row.querySelectorAll('[data-topic]'), x => x.dataset.topic),
    domains: Array.from(row.querySelectorAll('[data-domain]'), x => x.dataset.domain)}));
  function filter() {
    const terms = search.value.trim().toLocaleLowerCase().split(/\\s+/).filter(Boolean);
    let shown = 0;
    for (const entry of indexed) {
      const match = terms.every(term => entry.text.includes(term)) &&
        (!topic.value || entry.topics.includes(topic.value)) &&
        (!domain.value || entry.domains.includes(domain.value)) &&
        (!format.value || entry.row.dataset.format === format.value) &&
        (!coverage.value || entry.row.dataset.coverage === coverage.value);
      entry.row.hidden = !match;
      if (match) shown += 1;
    }
    document.getElementById('count').textContent = `Showing ${shown} of ${rows.length} sources`;
    document.getElementById('empty').hidden = shown !== 0;
  }
  search.addEventListener('input', filter);
  [topic, domain, format, coverage].forEach(control => control.addEventListener('change', filter));
  document.getElementById('reset').addEventListener('click', () => {
    [search, topic, domain, format, coverage].forEach(control => { control.value = ''; });
    filter();
    search.focus();
  });
  filter();
})();
"""


def render(root=ROOT):
    """Write deterministic HTML from validated public metadata; no network calls."""
    root = Path(root)
    curated = sources(root)
    additional = catalog(root, curated)
    rows = [(item, item['evidence_coverage']) for item in content_sources(root)]
    rows.sort(key=lambda entry: entry[0]['id'])
    audit = root / 'references/public-access-checks.json'
    access_checks = read(audit).get('checks', []) if audit.is_file() else []
    checks = {check['source_id']: check for check in access_checks}

    def access_state(item):
        checked = checks.get(item['id'], {})
        verified = checked.get('access_verified', item.get('access_verified'))
        if verified is None:
            verified = checked.get('status') == 'verified_public'
        manual = (item.get('access_status') == 'manually_marked_public'
                  or checked.get('status') == 'manually_marked_public'
                  or item.get('classification_status') == 'manually marked as public')
        return checked, verified is True, manual

    verified_count = sum(access_state(item)[1] for item, _ in rows)
    manually_only_count = sum(manual and not verified
                              for checked, verified, manual in (access_state(item) for item, _ in rows))

    def e(value):
        return escape(str(value), quote=True)

    def options(values):
        return ''.join(f'<option value="{e(value)}">{e(value)}</option>'
                       for value in sorted(set(values), key=lambda x: (x.casefold(), x)))

    topic_options = options(t for item, _ in rows for t in item.get('topics', []))
    domain_options = options(d for item, _ in rows for d in item.get('business_domains', []))
    format_options = options(item.get('format', 'Unspecified') for item, _ in rows)
    body = []
    for item, coverage in rows:
        reviewed = coverage != 'catalogue_only'
        label = {'reviewed_pdf_pages':'Reviewed PDF pages',
                 'extracted_source_passages':'Extracted source passages',
                 'attributed_editorial_summary':'Editorial summaries',
                 'mixed_passages':'Mixed passage types'}.get(coverage, 'Catalogue only')
        checked, verified, manual = access_state(item)
        date = checked.get('checked_at') or item['version'].get('verified_on')
        date_label = 'Access verified' if verified else 'Last access attempt'
        if not date:
            date = item['version'].get('recorded_on') or 'Not recorded'
            date_label = 'Recorded'
        classification = '<p class="muted">manually marked as public</p>' if manual else ''
        if verified:
            access_result = 'Anonymous access verified'
        else:
            error = item.get('verification_error') or checked.get('verification_error') or checked.get('reason')
            http_status = checked.get('http_status')
            access_result = 'Access not independently verified'
            if error:
                access_result += ': ' + str(error)
            elif http_status:
                access_result += ': HTTP ' + str(http_status)
        hash_note = ('Metadata hash; content not retrieved'
                     if item['version'].get('hash_basis') == 'catalogue_metadata'
                     else 'Source response hash')
        topics = ''.join(f'<span class="tag" data-topic="{e(t)}">{e(t)}</span>'
                         for t in item.get('topics', []))
        domains = ' · '.join(f'<span data-domain="{e(d)}">{e(d)}</span>'
                             for d in item.get('business_domains', []))
        form = item.get('content_form', '')
        body.append(
            f'<tr data-format="{e(item.get("format", "Unspecified"))}" data-coverage="{coverage}">'
            f'<td><span class="source-id">{e(item["id"])}</span>'
            f'<a class="title" href="{e(item["url"])}" target="_blank" rel="noopener noreferrer">{e(item["title"])}</a>'
            f'<span class="url">{e(item["url"])}</span></td>'
            f'<td><div class="tags">{topics}</div><div class="domains">{domains}</div></td>'
            f'<td><span class="format">{e(item.get("format", "Unspecified"))}</span><p class="muted">{e(form)}</p></td>'
            f'<td><span class="coverage{" reviewed" if reviewed else ""}">{label}</span>'
            f'{classification}<p class="muted">{e(access_result)}</p>'
            f'<span class="date">{date_label}: {e(date)}</span>'
            f'<span class="muted">{e(item["version"]["id"])} · {e(hash_note)}</span></td></tr>'
        )

    audit_link = ('<a href="../references/public-access-checks.json">Public-access check record</a> · '
                  if audit.is_file() else '')
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>Public research catalogue — Knowledge Context Explorer</title><style>{STYLE}</style></head>
<body><main><span class="eyebrow">Knowledge Context Explorer</span><h1>Explore the public research</h1>
<p>Find sources by topic, domain or format, then follow the original public reference. This page contains source metadata and works locally without a server. Opening a source link uses the publisher's website.</p>
<div class="summary" aria-label="Catalogue totals"><div class="stat"><strong>{len(rows)}</strong><span>Included public references</span></div>
<div class="stat"><strong>{verified_count}</strong><span>Anonymous access verified</span></div>
<div class="stat"><strong>{manually_only_count}</strong><span>Manually public; access unverified</span></div></div>
<p>{sum(c == 'catalogue_only' for _, c in rows)} catalogue-only references · {sum(c != 'catalogue_only' for _, c in rows)} sources with supplied passages or summaries</p>
<div class="notice"><strong>Discovery and answer evidence</strong><p>Coverage is computed from the actual dataset. Dev passages contain locally extracted text; release passages contain attributed editorial summaries of selected content. Neither a successful download nor an AI-assisted summary establishes fact checking. Catalogue-only entries have no answer passages. “Manually marked as public” records classification separately from anonymous access verification. A metadata hash identifies the catalogue record when source content was not retrieved.</p></div>
<section aria-label="Source filters"><div class="controls">
<div class="search"><label for="search">Search title, topic, source ID or URL</label><input id="search" type="search" placeholder="For example: multicloud or ontology" autocomplete="off"></div>
<div><label for="topic">Topic</label><select id="topic"><option value="">All topics</option>{topic_options}</select></div>
<div><label for="domain">Domain</label><select id="domain"><option value="">All domains</option>{domain_options}</select></div>
<div><label for="format">Format</label><select id="format"><option value="">All formats</option>{format_options}</select></div>
<div><label for="coverage">Evidence coverage</label><select id="coverage"><option value="">All coverage</option><option value="catalogue_only">Catalogue only</option><option value="reviewed_pdf_pages">Reviewed PDF pages</option><option value="extracted_source_passages">Extracted source passages</option><option value="attributed_editorial_summary">Editorial summaries</option></select></div>
</div><div class="toolbar"><span id="count" role="status" aria-live="polite">Showing {len(rows)} of {len(rows)} sources</span><button id="reset" type="button">Reset filters</button></div></section>
<noscript><p>JavaScript is disabled. All sources remain listed below; filtering requires JavaScript.</p></noscript>
<p id="empty" class="empty" hidden>No sources match these filters. Try fewer search terms or reset the filters.</p>
<div class="table-wrap" tabindex="0" role="region" aria-label="Public sources table; scroll horizontally on smaller screens">
<table id="sources"><caption>Public source references — links open in a new tab</caption>
<thead><tr><th scope="col">Source</th><th scope="col">Topics and domains</th><th scope="col">Content format</th><th scope="col">Coverage and verification</th></tr></thead>
<tbody>{''.join(body)}</tbody></table></div>
<footer>{audit_link}<a href="../data/public-catalog.json">Catalogue metadata</a> · <a href="../data/public-sources.json">Reviewed PDF source metadata</a> · <a href="../docs/public-research-catalog.md">Learner guide</a><p>Topic and domain assignments are editorial navigation aids. This catalogue does not bundle original source bodies. Access and source editions can change after checking.</p></footer>
</main><script>{SCRIPT}</script></body></html>
'''
    target = root / 'generated/public-catalog.html'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding='utf-8', newline='\n')
    return target
