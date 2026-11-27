"""Package a native APEXlang export with explicit portable application identity.

First export the isolated application with SQLcl using -exptype APEXLANG and
-expsupportingobjects Y. Point --source at the resulting application-alias
directory. The ZIP uses the browser export's flat root and retained component bytes; it is
not a repository-source ZIP or a wrapper around a SQL application export.
Portable archives retain only app.id from the reviewed native default deployment
file. The importer chooses the actual target ID. Other deployment settings/files
are omitted unless explicitly retained for private reproduction.
The application declaration receives the intended deployment alias (default
KCV-EXPLORER), so an isolated staging alias cannot silently become the public
application alias. Original/packaged hashes and aliases are recorded separately.
Actual connected validation and browser import remain separate acceptance gates.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import zipfile


# Verified in the bundled SQLcl26.3.1 APEXlang ZipSafetyLimits defaults. Do not
# change runtime safety settings to admit a generated package that exceeds them.
ZIP_ENTRY_LIMIT = 10 * 1024 * 1024
ZIP_TOTAL_LIMIT = 30 * 1024 * 1024
ZIP_COUNT_LIMIT = 1024


def validate_default_zip_budget(files: dict[str, bytes]) -> dict:
    largest = max((len(data) for data in files.values()), default=0)
    total = sum(len(data) for data in files.values())
    if len(files) > ZIP_COUNT_LIMIT or largest > ZIP_ENTRY_LIMIT or total > ZIP_TOTAL_LIMIT:
        raise ValueError('Native APEXlang ZIP default safety limit exceeded; reduce the reviewed transport size')
    return {'max_entry_uncompressed_bytes': ZIP_ENTRY_LIMIT,
            'max_total_uncompressed_bytes': ZIP_TOTAL_LIMIT, 'max_entry_count': ZIP_COUNT_LIMIT,
            'actual_largest_entry_bytes': largest, 'actual_total_uncompressed_bytes': total,
            'actual_entry_count': len(files)}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def portable_application_alias(files: dict[str, bytes], intended_alias: str) -> dict:
    """Change only the leading native app identifier; never rewrite references.

    The native unquoted identifier form is deliberately bounded. An unfamiliar
    export form requires review instead of a broad textual alias replacement.
    """
    if not isinstance(intended_alias, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,254}', intended_alias):
        raise ValueError('Use a reviewed application alias containing letters, digits, underscore or hyphen')
    path = 'application.apx'
    original = files[path]
    pattern = rb'\Aapp[ \t]+(?P<alias>[A-Za-z][A-Za-z0-9_-]{0,254})[ \t]+\('
    match = re.match(pattern, original)
    if not match:
        raise ValueError('Unsupported native application declaration; inspect its alias before packaging')
    source_alias = match['alias'].decode('ascii')
    start, end = match.span('alias')
    files[path] = original[:start] + intended_alias.encode('ascii') + original[end:]
    return {'policy': 'explicit-intended-application-alias', 'path': path,
            'source_alias': source_alias, 'intended_alias': intended_alias,
            'alias_normalized': files[path] != original,
            'source_sha256': digest(original), 'packaged_sha256': digest(files[path])}


def portable_deployment(files: dict[str, bytes]) -> tuple[list[str], dict]:
    """Retain native source identity without workspace, schema, salts or URLs.

    Missing/default-invalid IDs are rejected rather than invented. This packager
    takes a reviewed native export, not a newly generated ID-less application.
    """
    path = 'deployments/default.json'
    if path not in files:
        raise ValueError('Reviewed native default deployment file is missing; re-export the application')

    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate key in native deployment metadata')
            result[key] = value
        return result

    original = files[path]
    try:
        source = json.loads(original, object_pairs_hook=unique_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError('Native default deployment metadata is not valid JSON') from exc
    app = source.get('app') if isinstance(source, dict) else None
    app_id = app.get('id') if isinstance(app, dict) else None
    if type(app_id) is not int or app_id <= 0:
        raise ValueError('Reviewed native source application ID must be a positive integer')
    minimal = {'app': {'id': app_id}}
    # Already-minimal native metadata remains byte-identical for the diagnostic
    # single-variable archive test. Never retain arbitrary neighboring settings.
    normalized = source != minimal
    files[path] = ((json.dumps(minimal, indent=2) + '\n').encode('utf-8')
                   if normalized else original)
    omitted = sorted(name for name in files if name.startswith('deployments/') and name != path)
    for name in omitted:
        del files[name]
    return omitted, {'policy': 'native-source-app-id-only', 'path': path,
                     'source_application_id': app_id, 'metadata_normalized': normalized,
                     'source_sha256': digest(original), 'packaged_sha256': digest(files[path])}


def safe_relative(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if (not value or '\\' in value or path.is_absolute() or ':' in value
            or any(part in ('', '.', '..') for part in value.split('/'))):
        raise ValueError('Unsafe export-relative path: ' + value)
    return path


def collect_files(source: Path) -> dict[str, bytes]:
    source = Path(source)
    if source.is_symlink() or not source.is_dir():
        raise ValueError('Use a real native APEXlang application directory')
    resolved = source.resolve()
    files: dict[str, bytes] = {}
    folded: set[str] = set()
    allowed = {'.apex', 'deployments', 'pages', 'shared-components', 'supporting-objects'}
    for path in sorted(source.rglob('*')):
        if path.is_symlink() or not path.resolve().is_relative_to(resolved):
            raise ValueError('Export cannot contain links or paths outside its application')
        if not path.is_file():
            continue
        name = path.relative_to(source).as_posix()
        parts = safe_relative(name).parts
        if parts[0] not in allowed and name != 'application.apx':
            raise ValueError('Unexpected file outside native application components: ' + name)
        if name.casefold() in folded:
            raise ValueError('Case-insensitive duplicate export path: ' + name)
        folded.add(name.casefold())
        if path.suffix.lower() == '.sql' and not name.startswith('supporting-objects/'):
            raise ValueError('SQL application exports are not APEXlang application ZIP input')
        files[name] = path.read_bytes()
    for required in ('application.apx', '.apex/apexlang.json',
                     'supporting-objects/supporting-objects.apx'):
        if required not in files:
            raise ValueError('Native APEXlang export is incomplete: ' + required)
    if not re.search(r'(?m)^app\s+[^\n]+\(', files['application.apx'].decode('utf-8')):
        raise ValueError('Application definition is not a native APEXlang app')
    return files


def supporting_scripts(files: dict[str, bytes]) -> dict[str, list[dict]]:
    """Inspect native split script definitions and resolve their content files."""
    result = {}
    referenced = set()
    for route, kind in (('install', 'installScript'), ('upgrade', 'upgradeScript')):
        definition = f'supporting-objects/{route}-scripts.apx'
        if definition not in files:
            raise ValueError('Native supporting script definitions missing: ' + definition)
        text = files[definition].decode('utf-8')
        records = []
        pattern = (r'(?ms)^' + kind + r'\s+(?:"([^"]+)"|([\w.-]+))\s*\(\s*'
                   r'execution\s*\{\s*sequence:\s*(\d+)\s*\}\s*'
                   r'script\s*\{\s*contentFile:\s*(?:"([^"]+)"|([^\s]+))\s*\}\s*\)')
        matches = list(re.finditer(pattern, text))
        if not matches or len(matches) != len(re.findall(r'(?m)^' + kind + r'\s', text)):
            raise ValueError('Unsupported or missing native supporting script definition: ' + definition)
        for match in matches:
            name = match[1] or match[2]
            relative = safe_relative(match[4] or match[5])
            content_path = f'supporting-objects/{route}-scripts/{relative.as_posix()}'
            if content_path not in files or content_path in referenced:
                raise ValueError('Missing or duplicate supporting script file: ' + content_path)
            referenced.add(content_path)
            records.append({'name': name, 'sequence': int(match[3]), 'path': content_path,
                            'sha256': digest(files[content_path]), 'bytes': len(files[content_path])})
        records.sort(key=lambda item: item['sequence'])
        if len({item['sequence'] for item in records}) != len(records):
            raise ValueError('Supporting script execution sequences must be unique')
        result[route] = records
    actual = {name for name in files if re.match(r'^supporting-objects/(?:install|upgrade)-scripts/', name)}
    if actual != referenced:
        raise ValueError('Unreferenced supporting script content is present')
    return result


def static_assets(files: dict[str, bytes], expected_assets: Path | None) -> list[str]:
    definition = files.get('shared-components/static-files.apx', b'').decode('utf-8')
    # The native engine omits quotes for identifier-safe names such as
    # explorer.js, while retaining quotes around directories and other names.
    names = [match[1] or match[2] for match in re.finditer(
        r'(?m)^file\s+(?:"([^"]+)"|([A-Za-z0-9_.-]+))\s*\(', definition)]
    if len(names) != len(re.findall(r'(?m)^file\s', definition)):
        raise ValueError('Unsupported native static application file definition')
    if len(names) != len(set(names)):
        raise ValueError('Duplicate static application file definition')
    declared = {'shared-components/static-files/' + safe_relative(name).as_posix() for name in names}
    actual = {name for name in files if name.startswith('shared-components/static-files/')}
    if declared != actual:
        raise ValueError('Static application definitions and asset files differ')
    if expected_assets is not None:
        root = Path(expected_assets)
        if not root.is_dir() or root.is_symlink():
            raise ValueError('Reviewed maintained asset directory is unavailable')
        expected = {}
        for path in sorted(root.rglob('*')):
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('Expected assets cannot contain links')
            if path.is_file():
                expected['shared-components/static-files/' + path.relative_to(root).as_posix()] = path.read_bytes()
        if set(expected) != actual or any(expected[name] != files[name] for name in actual):
            raise ValueError('Native export assets differ from the reviewed maintained assets')
    return sorted(actual)


def verify_canonical(files: dict[str, bytes], routes: dict[str, list[dict]], candidate: Path) -> None:
    """Compare round-tripped native scripts to the canonical packaging candidate.

    APEX removes the final newline when externalizing a script. No other SQL
    normalization is permitted: interior bytes, slash boundaries and order match.
    """
    candidate = Path(candidate)
    manifest = json.loads((candidate / 'manifest.json').read_bytes())
    for route in ('install', 'upgrade'):
        expected = manifest['routes'][route]
        actual = routes[route]
        if len(actual) != len(expected):
            raise ValueError('Native export lost supporting scripts: ' + route)
        for found, wanted in zip(actual, expected):
            expected_name = f"{route}-{wanted['ordinal']:03d}-{wanted['step_id']}"
            path = candidate / safe_relative(wanted['path'])
            if not path.resolve().is_relative_to(candidate.resolve()):
                raise ValueError('Canonical script path is outside its candidate')
            content = path.read_bytes()
            if digest(content) != wanted['sha256']:
                raise ValueError('Canonical candidate script was changed: ' + wanted['path'])
            if (found['name'] != expected_name or found['sequence'] != wanted['sequence']
                    or files[found['path']].rstrip(b'\n') != content.rstrip(b'\n')):
                raise ValueError('Native supporting script differs from canonical input: ' + found['name'])


def archive_bytes(files: dict[str, bytes], archive_root: str | None = None) -> bytes:
    if archive_root is not None and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', archive_root):
        raise ValueError('Use the native application-alias directory as archive root')
    # Actual App Builder exports application.apx directly at the ZIP root.
    # SQLcl accepts an alias directory too, but that does not prove browser import.
    prefix = archive_root + '/' if archive_root is not None else ''
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(prefix + name, (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
    content = output.getvalue()
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        if archive.testzip() is not None:
            raise ValueError('Archive failed its CRC check')
        if set(archive.namelist()) != {prefix + name for name in files}:
            raise ValueError('Archive file inventory differs')
        for name, data in files.items():
            if archive.read(prefix + name) != data:
                raise ValueError('Archive changed native application bytes')
    return content


def build(source: Path, output: Path, *, expected_assets: Path | None = None,
          canonical_candidate: Path | None = None, check: bool = False,
          include_deployments: bool = False,
          application_alias: str = 'KCV-EXPLORER') -> dict:
    source, output = Path(source), Path(output)
    if output.resolve().is_relative_to(source.resolve()) or output.suffix.lower() != '.zip':
        raise ValueError('Write the ZIP outside its native source directory')
    files = collect_files(source)
    alias = portable_application_alias(files, application_alias)
    omitted_deployments = []
    deployment = {'policy': 'private-all-native-metadata', 'metadata_normalized': False}
    if not include_deployments:
        omitted_deployments, deployment = portable_deployment(files)
    mmd = json.loads(files['.apex/apexlang.json'])['mmdVersion']
    if not re.fullmatch(r'\d+\.\d+\.\d+\+\d+', mmd):
        raise ValueError('Native APEXlang metadata version is unavailable')
    routes = supporting_scripts(files)
    assets = static_assets(files, expected_assets)
    if canonical_candidate is not None:
        verify_canonical(files, routes, canonical_candidate)
    budget = validate_default_zip_budget(files)
    content = archive_bytes(files)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        entries = archive.infolist()
        total_compressed = sum(entry.compress_size for entry in entries)
        if (any(entry.compress_size > ZIP_ENTRY_LIMIT
                or entry.file_size / max(entry.compress_size, 1) > 200 for entry in entries)
                or total_compressed > ZIP_TOTAL_LIMIT
                or budget['actual_total_uncompressed_bytes'] / max(total_compressed, 1) > 300):
            raise ValueError('Native APEXlang ZIP default compressed safety limit exceeded')
        budget['actual_total_compressed_bytes'] = total_compressed
    report = {'format_version': 1, 'format': 'APEXLANG', 'archive_root': '',
              'layout': 'native-browser-flat-root', 'source_application_directory': source.name,
              'mmd_version': mmd, 'archive_sha256': digest(content), 'archive_bytes': len(content),
              'entry_count': len(files),
              'native_file_bytes_preserved': not deployment['metadata_normalized'] and not alias['alias_normalized'],
              'native_component_bytes_preserved': not alias['alias_normalized'],
              'native_non_application_component_bytes_preserved': True,
              'application_alias': alias,
              'supporting_scripts': routes, 'owned_static_assets': assets,
              'canonical_script_roundtrip_checked': canonical_candidate is not None,
              'native_default_zip_budget': budget,
              'maintained_assets_checked': expected_assets is not None,
              'includes_deployment_metadata': True,
              'includes_private_deployment_metadata': include_deployments,
              'deployment': deployment,
              'omitted_deployment_files': omitted_deployments,
              'native_zip_validation': 'pending', 'browser_import': 'pending',
              'files': {name: {'sha256': digest(data), 'bytes': len(data)} for name, data in sorted(files.items())}}
    metadata = (json.dumps(report, indent=2) + '\n').encode('utf-8')
    report_path = output.with_suffix('.manifest.json')
    if check:
        if output.read_bytes() != content or report_path.read_bytes() != metadata:
            raise ValueError('ZIP or audit manifest is stale')
    else:
        if output.exists() or report_path.exists():
            raise FileExistsError('Use a new archive filename; existing artifacts are not overwritten')
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open('xb') as target:
            target.write(content)
        with report_path.open('xb') as target:
            target.write(metadata)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected-assets', type=Path)
    parser.add_argument('--canonical-candidate', type=Path)
    parser.add_argument('--application-alias', default='KCV-EXPLORER',
                        help='Intended imported application alias; default KCV-EXPLORER. Never use an isolated staging alias for distribution.')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--include-deployments', action='store_true',
                        help='Private reproduction only: retain environment-specific deployment metadata')
    args = parser.parse_args()
    result = build(args.source, args.output, expected_assets=args.expected_assets,
                   canonical_candidate=args.canonical_candidate, check=args.check,
                   include_deployments=args.include_deployments,
                   application_alias=args.application_alias)
    print(f"APEXlang ZIP: {result['entry_count']} files; SHA256 {result['archive_sha256']}; browser acceptance pending")
