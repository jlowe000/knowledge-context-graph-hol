"""Deterministic, summary-only JSON packages for the GitHub database loader.

The dataset identity is SHA-256 of the canonical manifest without ``dataset_id``.
Canonical JSON uses UTF-8, sorted keys, no ASCII escaping and compact separators,
with no terminating newline. Files on disk append exactly one LF. The manifest
has no generated timestamp: identical inputs and part size give identical bytes.

This module never downloads content, changes Git or connects to a database.
"""
from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import re
import tempfile

from rdflib import Graph, Literal, RDF, URIRef
from rdflib.util import from_n3

from . import pipeline
from .public_access import validate_url

ROLES = ('sources', 'passages', 'contexts', 'triples')
MAX_FILE_BYTES = 1_500_000
_HASH = re.compile(r'[0-9a-f]{64}')
_PART = re.compile(r'(sources|passages|contexts|triples)-[0-9]{3,6}\.json')
_MANIFEST_KEYS = {'format_version', 'dataset_id', 'graph_sha256', 'counts', 'files'}


def canonical_bytes(value):
    """Return the exact bytes used for dataset identity (without trailing LF)."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':'), allow_nan=False).encode('utf-8')


def dataset_identifier(manifest):
    """Hash every manifest field except the self-referential dataset_id."""
    return pipeline.digest(canonical_bytes({k: v for k, v in manifest.items()
                                             if k != 'dataset_id'}))


def graph_bytes(graph):
    """Match pipeline.build's sorted N-Triples, also valid Turtle."""
    return ''.join(sorted(graph.serialize(format='nt').splitlines(keepends=True))).encode('utf-8')


def _manifest(manifest):
    if (not isinstance(manifest, dict) or set(manifest) != _MANIFEST_KEYS
            or type(manifest['format_version']) is not int or manifest['format_version'] != 1):
        raise ValueError('Unsupported dataset manifest')
    for key in ('dataset_id', 'graph_sha256'):
        if not isinstance(manifest[key], str) or not _HASH.fullmatch(manifest[key]):
            raise ValueError('Invalid manifest hash: ' + key)
    if dataset_identifier(manifest) != manifest['dataset_id']:
        raise ValueError('Dataset identifier does not match manifest')
    if (not isinstance(manifest['counts'], dict) or set(manifest['counts']) != set(ROLES)
            or any(type(v) is not int or v < 1 for v in manifest['counts'].values())):
        raise ValueError('Invalid manifest counts')
    if not isinstance(manifest['files'], list) or not 4 <= len(manifest['files']) <= 256:
        raise ValueError('Manifest needs between 4 and 256 dataset files')
    last_role = -1
    indices = Counter()
    seen = set()
    for item in manifest['files']:
        if not isinstance(item, dict) or set(item) != {'role', 'path', 'sha256', 'bytes', 'rows'}:
            raise ValueError('Invalid dataset file record')
        role, name = item['role'], item['path']
        if (role not in ROLES or not isinstance(name, str) or not _PART.fullmatch(name)
                or name in seen or not name.startswith(role + '-')):
            raise ValueError('Unsafe or duplicate dataset file path')
        indices[role] += 1
        if name != f'{role}-{indices[role]:03d}.json' or ROLES.index(role) < last_role:
            raise ValueError('Dataset parts are not in dependency order')
        if (type(item['bytes']) is not int or not 0 < item['bytes'] <= MAX_FILE_BYTES
                or type(item['rows']) is not int or item['rows'] < 1
                or not isinstance(item['sha256'], str) or not _HASH.fullmatch(item['sha256'])):
            raise ValueError('Invalid dataset file size, rows or hash')
        seen.add(name)
        last_role = ROLES.index(role)


def _rows_integrity(rows, graph_sha256):
    def scalar_limits(value):
        if isinstance(value, str) and len(value.encode('utf-8')) > 32767:
            raise ValueError('JSON scalar exceeds native VARCHAR2 byte limit')
        if isinstance(value, dict):
            for child in value.values():
                scalar_limits(child)
        elif isinstance(value, list):
            for child in value:
                scalar_limits(child)

    def identifier(value, limit):
        if not isinstance(value, str) or not value or len(value.encode('utf-8')) > limit:
            raise ValueError('Identifier exceeds native column limit')

    scalar_limits(rows)
    sources, passages, contexts = {}, {}, {}
    for source in rows['sources']:
        sid, version = source['id'], source['version']
        vid = version['id']
        identifier(sid, 32)
        identifier(vid, 128)
        if sid in {s['id'] for s in sources.values()} or vid in sources:
            raise ValueError('Duplicate source identity or edition')
        if not _HASH.fullmatch(version['sha256']):
            raise ValueError('Invalid source edition hash')
        validate_url(source['url'])
        sources[vid] = source
    actual_counts, eligible_counts = Counter(), Counter()
    for passage in rows['passages']:
        identifier(passage['id'], 200)
        source = sources.get(passage['version_id'])
        if (source is None or source['id'] != passage['source_id']
                or source['version']['sha256'] != passage['source_sha256']):
            raise ValueError('Passage refers to an unknown or mismatched source edition')
        if passage['id'] in passages:
            raise ValueError('Duplicate passage identity')
        if (passage.get('content_kind') != 'attributed_editorial_summary'
                or not passage['text'].startswith('Editorial summary, not a quotation: ')):
            raise ValueError('Public dataset packages allow only labelled editorial summaries')
        if pipeline.digest(passage['text']) != passage['text_sha256']:
            raise ValueError('Passage text/hash mismatch')
        if len(passage['text']) > 16000:
            raise ValueError('Passage text exceeds native loader character limit')
        if type(passage.get('retrieval_eligible')) is not bool:
            raise ValueError('Passage needs an explicit retrieval eligibility flag')
        if (type(passage['chunk_index']) is not int or passage['chunk_index'] < 1
                or (passage.get('pdf_page') is not None
                    and (type(passage['pdf_page']) is not int or passage['pdf_page'] < 1))):
            raise ValueError('Invalid passage locator index')
        validate_url(passage['locator_url'])
        if passage['locator_url'].split('#')[0] != source['url'].split('#')[0]:
            raise ValueError('Passage locator does not identify its source')
        for locator in passage.get('basis_locators', []):
            validate_url(locator['locator_url'])
            if locator['locator_url'].split('#')[0] != source['url'].split('#')[0]:
                raise ValueError('Passage basis locator does not identify its source')
        passages[passage['id']] = passage
        actual_counts[passage['version_id']] += 1
        eligible_counts[passage['version_id']] += passage['retrieval_eligible']
    for vid, source in sources.items():
        if (source['passage_count'] != actual_counts[vid]
                or source['retrieval_eligible_passage_count'] != eligible_counts[vid]):
            raise ValueError('Source evidence counts differ from packaged passages')
    for context in rows['contexts']:
        identifier(context['id'], 32)
        if (type(context['snapshot_version']) is not int
                or not 1 <= context['snapshot_version'] <= 9999999999):
            raise ValueError('Invalid context snapshot version')
        snapshot = context['id'] + '-v' + str(context['snapshot_version'])
        identifier(snapshot, 128)
        if snapshot in contexts:
            raise ValueError('Duplicate context snapshot')
        contexts[snapshot] = context
    graph = Graph()
    for row in rows['triples']:
        if set(row) != {'s', 'p', 'o'}:
            raise ValueError('Invalid RDF staging row')
        if any(not isinstance(row[k], str) or len(row[k].encode('utf-8')) > 4000 for k in ('s', 'p', 'o')):
            raise ValueError('RDF term exceeds native staging limits')
        try:
            subject, predicate, obj = (from_n3(row[k]) for k in ('s', 'p', 'o'))
        except Exception as error:
            raise ValueError('Invalid RDF term') from error
        # The current ontology uses explicit IRIs throughout. Named resources
        # avoid blank-node identities changing when RDF is parsed and reloaded.
        if (not isinstance(subject, URIRef) or not isinstance(predicate, URIRef)
                or not isinstance(obj, (URIRef, Literal))):
            raise ValueError('RDF needs explicit subject/predicate IRIs and a literal or IRI object')
        if any(term.n3() != row[key] for term, key in zip((subject, predicate, obj), ('s', 'p', 'o'))):
            raise ValueError('RDF terms are not normalized native staging values')
        graph.add((subject, predicate, obj))
    if len(graph) != len(rows['triples']):
        raise ValueError('Duplicate RDF staging triples')
    if pipeline.digest(graph_bytes(graph)) != graph_sha256:
        raise ValueError('RDF staging triples do not reconstruct the graph hash')
    k = pipeline.K
    for vid, source in sources.items():
        if (k[source['id']], k.hasVersion, k[vid]) not in graph:
            raise ValueError('Source edition is absent from graph')
    for pid, passage in passages.items():
        if ((k[passage['version_id']], k.hasPassage, k[pid]) not in graph
                or (k[pid], k.retrievalEligible, Literal(passage['retrieval_eligible'])) not in graph
                or (k[pid], k.textHash, Literal(passage['text_sha256'])) not in graph):
            raise ValueError('Passage provenance or eligibility differs from graph')
    for snapshot in contexts:
        if (k[snapshot], RDF.type, k.ContextSnapshot) not in graph:
            raise ValueError('Context snapshot is absent from graph')
    return graph


def validate_package(manifest, files):
    """Pure validation of manifest plus {basename: bytes}; return parsed rows.

    Checks part hashes/byte limits/counts, dataset identity, source/passage/context
    relationships, editorial-only content and exact RDF graph reconstruction.
    No files, network connections or database sessions are opened.
    """
    _manifest(manifest)
    expected = {entry['path'] for entry in manifest['files']}
    if set(files) != expected:
        raise ValueError('Dataset file set differs from manifest')
    rows = {role: [] for role in ROLES}
    for item in manifest['files']:
        body = files[item['path']]
        if not isinstance(body, bytes) or len(body) != item['bytes'] or pipeline.digest(body) != item['sha256']:
            raise ValueError('Dataset file size/hash mismatch: ' + item['path'])
        payload = json.loads(body.decode('utf-8'))
        if (not isinstance(payload, dict) or set(payload) != {'format_version', 'rows'}
                or type(payload['format_version']) is not int or payload['format_version'] != 1
                or not isinstance(payload['rows'], list) or len(payload['rows']) != item['rows']
                or not all(isinstance(row, dict) for row in payload['rows'])):
            raise ValueError('Invalid dataset payload: ' + item['path'])
        if body != canonical_bytes(payload) + b'\n':
            raise ValueError('Dataset payload is not canonical UTF-8 JSON plus LF')
        rows[item['role']].extend(payload['rows'])
    if {role: len(rows[role]) for role in ROLES} != manifest['counts']:
        raise ValueError('Dataset row counts differ from manifest')
    try:
        _rows_integrity(rows, manifest['graph_sha256'])
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('Dataset row is missing required typed fields') from error
    return rows


def validate(folder):
    """Read and validate one local package, returning its manifest."""
    folder = Path(folder)
    manifest = pipeline.read(folder / 'manifest.json')
    _manifest(manifest)
    files = {}
    for item in manifest['files']:
        path = folder / item['path']
        if path.is_symlink() or path.resolve().parent != folder.resolve():
            raise ValueError('Dataset file cannot be a symbolic link')
        files[item['path']] = path.read_bytes()
    validate_package(manifest, files)
    return manifest


def loader_script(manifest_sha256):
    """Return a short caller pinned to exact manifest bytes and a commit SHA.

    The public commit is filled in after publication, avoiding a self-referential
    Git commit hash in a committed file. Neither dev nor release is accepted as
    a moving branch reference by the database loader.
    """
    if not isinstance(manifest_sha256, str) or not _HASH.fullmatch(manifest_sha256):
        raise ValueError('The caller requires a SHA-256 manifest digest')
    return (
        '-- KCV_LAB: install sql/schema/06_dataset_import.sql first. Run Script (F5).\n'
        '-- Replace the commit placeholder with the full 40-character published commit SHA.\n'
        '-- This exact commit must contain the matching data/load/manifest.json.\n'
        '-- Public data only; no GitHub token or Python is required.\n'
        'BEGIN\n'
        '  KCV_DATASET.LOAD_GITHUB(\n'
        "    p_ref => 'PASTE_FULL_40_CHARACTER_COMMIT_SHA',\n"
        f"    p_expected_manifest_sha256 => '{manifest_sha256}');\n"
        'END;\n/\n')


def write_loader(package_folder, target):
    """Validate a local package and create its short SQL caller."""
    package_folder, target = Path(package_folder), Path(target)
    validate(package_folder)
    if target.suffix.lower() != '.sql':
        raise ValueError('The dataset caller output must be a SQL file')
    manifest_sha256 = pipeline.digest((package_folder / 'manifest.json').read_bytes())
    target.parent.mkdir(parents=True, exist_ok=True)
    _atomic_write(target, loader_script(manifest_sha256).encode('utf-8'))
    return target


def _parts(role, rows, max_bytes):
    prefix, suffix = b'{"format_version":1,"rows":[', b']}\n'
    current, size = [], len(prefix) + len(suffix)
    for row in rows:
        body = canonical_bytes(row)
        if len(prefix) + len(body) + len(suffix) > max_bytes:
            raise ValueError('One dataset row exceeds the file byte budget')
        if current and size + 1 + len(body) > max_bytes:
            yield prefix + b','.join(current) + suffix, len(current)
            current, size = [], len(prefix) + len(suffix)
        size += len(body) + bool(current)
        current.append(body)
    if current:
        yield prefix + b','.join(current) + suffix, len(current)


def _atomic_write(path, body):
    if path.is_symlink():
        raise ValueError('Refusing to overwrite a symbolic link')
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.kcv-dataset-', delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(body)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def write_package(folder, rows, graph_sha256, max_bytes=MAX_FILE_BYTES):
    """Validate and write a bounded package; retire only prior manifest parts."""
    if type(max_bytes) is not int or not 100 <= max_bytes <= MAX_FILE_BYTES:
        raise ValueError('Dataset part size must be between 100 and 1,500,000 bytes')
    if set(rows) != set(ROLES):
        raise ValueError('Dataset must provide each role')
    folder = Path(folder)
    files, entries = {}, []
    for role in ROLES:
        for index, (body, count) in enumerate(_parts(role, rows[role], max_bytes), 1):
            if index > 999999:
                raise ValueError('Too many dataset parts')
            name = f'{role}-{index:03d}.json'
            files[name] = body
            entries.append({'role': role, 'path': name, 'sha256': pipeline.digest(body),
                            'bytes': len(body), 'rows': count})
    manifest = {'format_version': 1, 'graph_sha256': graph_sha256,
                'counts': {role: len(rows[role]) for role in ROLES}, 'files': entries}
    manifest['dataset_id'] = dataset_identifier(manifest)
    validate_package(manifest, files)
    previous = set()
    if folder.is_symlink():
        raise ValueError('Dataset output folder cannot be a symbolic link')
    manifest_path = folder / 'manifest.json'
    if manifest_path.exists():
        if manifest_path.is_symlink():
            raise ValueError('Dataset manifest cannot be a symbolic link')
        old = pipeline.read(manifest_path)
        _manifest(old)
        previous = {entry['path'] for entry in old['files']}
    for name in set(files) | previous:
        path = folder / name
        if path.is_symlink() or (path.exists() and name not in previous):
            raise ValueError('Refusing to overwrite an unrelated dataset file: ' + name)
        if path.exists() and not path.is_file():
            raise ValueError('Dataset part path is not a regular file')
    folder.mkdir(parents=True, exist_ok=True)
    for name, body in files.items():
        _atomic_write(folder / name, body)
    _atomic_write(manifest_path, canonical_bytes(manifest) + b'\n')
    for name in previous - set(files):
        (folder / name).unlink(missing_ok=True)
    return manifest


def generate(root=pipeline.ROOT, output=None, max_bytes=MAX_FILE_BYTES):
    """Package a prepared summary-only stage; raw developer passages are refused."""
    root = Path(root)
    passages = pipeline.load_passages(root)
    if any(p.get('content_kind') != 'attributed_editorial_summary' for p in passages):
        raise ValueError('Public dataset packages allow only labelled editorial summaries; use the summary-stage CLI')
    graph_path = root / 'generated/knowledge.ttl'
    graph = Graph().parse(graph_path, format='turtle')
    triples = [{'s': s.n3(), 'p': p.n3(), 'o': o.n3()}
               for s, p, o in sorted(graph, key=lambda t: tuple(x.n3() for x in t))]
    rows = {'sources': sorted(pipeline.content_sources(root, passages), key=lambda s: s['id']),
            'passages': passages,
            'contexts': sorted(pipeline.read(root / 'data/contexts.json')['contexts'],
                               key=lambda c: (c['id'], c['snapshot_version'])),
            'triples': triples}
    return write_package(output or root / 'data/load', rows,
                         pipeline.digest(graph_path.read_bytes()), max_bytes)
