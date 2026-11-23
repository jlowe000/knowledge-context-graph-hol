"""Anonymous public-source checks. No cookies, sign-in sessions or credentials."""
from __future__ import annotations

import hashlib
from html.parser import HTMLParser
import io
import ipaddress
import re
import socket
import unicodedata
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from pypdf import PdfReader

BLOCKED_HOST_PARTS = ('sharepoint', 'onedrive', 'seismic', 'confluence',
    'oraclecorp', 'oraweb', 'stbeehive', 'beehive', 'slack.com', 'outlook.',
    'my.oracle.', 'login.', 'signin.', 'sso.', 'identity.', 'localhost')
BLOCKED_HOSTS = {'1drv.ms', 'onedrive.live.com', 'aka.ms', 'bit.ly', 't.co',
                 'login.microsoftonline.com', 'reg.rf.oracle.com'}
PRIVATE_MARKING = re.compile(
    r'confidential\s*[:\-–·]?\s*(?:oracle\s*)?(?:internal|restricted|highly restricted|do not distribute)'
    r'|oracle\s+(?:internal|restricted)\s*[:\\/]?\s*(?:use only|employees only)'
    r'|(?:oracle|it convergence)\s+confidential'
    r'|(?:confidential|proprietary)\s*[·\-–:]?\s*do not distribute'
    r'|confidential\s+and\s+proprietary'
    r'|confidential\s*[–—·|:\-]?\s*(?:draft|do not (?:duplicate|distribute))'
    r'|(?:company|onsemi|mastercard|intel|tcs|docusign)\s+(?:proprietary\s+and\s+)?confidential'
    r'|(?:^|\n|\|)\s*(?:confidential|proprietary)\s*(?:\||\n|$)'
    r'|NDA\s+Only'
    r'|not\s+(?:be\s+)?distributed\s+outside\s+Oracle', re.I)
GATE_TITLE = re.compile(r'^(?:sign[ -]?in|log[ -]?in|access denied|forbidden|403\b|404\b|'
    r'page not found|just a moment|attention required|verify you are human|robot check)', re.I)


def public_rule(url, prefixes, title='', title_rules=()):
    """Match the stated host/path, never a lookalike host or a query parameter."""
    validate_url(url)
    u=urlsplit(url); path=unquote(u.path).rstrip('/')
    if any(part in {'.','..'} for part in path.split('/')): return None
    for prefix in prefixes:
        p=urlsplit(prefix); base=p.path.rstrip('/')
        if u.scheme==p.scheme and u.hostname==p.hostname and (path==base or path.startswith(base+'/')):
            return prefix
    normalized=' '.join(unicodedata.normalize('NFKC',title or '').split()).casefold()
    for rule in title_rules:
        required=' '.join(rule['title_contains'].split()).casefold()
        if re.search(r'(?<!\w)'+re.escape(required)+r'(?!\w)',normalized) and public_rule(url,[rule['url_prefix']]):
            return rule['url_prefix']+' | title contains '+rule['title_contains']
    return None


def validate_url(url, resolve=False):
    u = urlsplit(url)
    host = (u.hostname or '').lower().rstrip('.')
    if u.scheme != 'https' or not host or u.username or u.password or u.port not in (None, 443):
        raise ValueError('not_public_https')
    if host in BLOCKED_HOSTS or any(x in host for x in BLOCKED_HOST_PARTS):
        raise ValueError('excluded_host')
    decoded = unquote(url).lower()
    if any(x in decoded for x in ('sharepoint', 'onedrive', 'seismic', '1drv.ms')):
        raise ValueError('excluded_reference')
    if re.search(r'[?&](?:access_token|token|sig|signature|x-amz-signature|x-goog-signature|password|secret)=', decoded):
        raise ValueError('signed_or_credential_url')
    try:
        if not ipaddress.ip_address(host).is_global:
            raise ValueError('private_address')
    except ValueError as exc:
        if str(exc) == 'private_address': raise
    if resolve:
        for address in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM):
            if not ipaddress.ip_address(address[4][0]).is_global:
                raise ValueError('private_address')
    return url


def retained_publisher(url, policy):
    """Previously verified Oracle publications; other publishers await review."""
    validate_url(url)
    u=urlsplit(url); host=u.hostname
    if any(host==d or host.endswith('.'+d) for d in policy.get('verified_publisher_domains',[])):
        return True
    parts=unquote(u.path).strip('/').split('/')
    if any(p in {'.','..'} for p in parts): return False
    owner=None
    if host in {'github.com','raw.githubusercontent.com'} and parts: owner=parts[0]
    if host=='api.github.com' and len(parts)>=2 and parts[0]=='repos': owner=parts[1]
    return owner in policy.get('verified_repository_owners',[])


class PublicRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        validate_url(newurl, resolve=True)
        return super().redirect_request(request, fp, code, msg, headers, newurl)


class PageText(HTMLParser):
    def __init__(self):
        super().__init__(); self.parts=[]; self.titles=[]; self.skip=0; self.title=False
    def handle_starttag(self, tag, attrs):
        if tag in {'script','style','noscript'}: self.skip += 1
        if tag == 'title': self.title=True
    def handle_endtag(self, tag):
        if tag in {'script','style','noscript'}: self.skip=max(0,self.skip-1)
        if tag == 'title': self.title=False
    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)
            if self.title: self.titles.append(data)


def inspect_body(body, content_type, reviewed_marking=False, public_repository_asset=False, manual_public=False, raw_repository_source=False):
    """Require actual content, reject access gates and restrictive markings."""
    if body.startswith(b'%PDF'):
        reader=PdfReader(io.BytesIO(body))
        if reader.is_encrypted:
            if manual_public:
                return {'format':'application/pdf','access_scope':'download_only','marking_check':'encrypted_document_not_inspected'}
            raise ValueError('encrypted_pdf')
        text=unicodedata.normalize('NFKC','\n'.join(page.extract_text() or '' for page in reader.pages))
        if len(text.strip()) < 100 and not manual_public: raise ValueError('unreadable_pdf_markings_not_checked')
        marked=bool(PRIVATE_MARKING.search(text))
        if marked and not (reviewed_marking or manual_public): raise ValueError('restrictive_marking')
        return {'format':'application/pdf','access_scope':'document','page_count':len(reader.pages),
                'marking_check':('manually_marked_as_public_by_url_rule' if manual_public and (marked or len(text.strip())<100) else 'user_reviewed_template_footer_exact_edition' if reviewed_marking else 'all_pages_extracted_text_no_matching_restriction')}
    text=body.decode('utf-8',errors='replace')
    if raw_repository_source and content_type.startswith('text/') and '\x00' not in text[:2000] and len(text.strip())>=20:
        # A repository's HTML login-page example is source code, not an access gate.
        marked=bool(PRIVATE_MARKING.search(unicodedata.normalize('NFKC',text)))
        if marked and not manual_public: raise ValueError('restrictive_marking')
        return {'format':content_type,'access_scope':'public_repository_source',
                'marking_check':'manually_marked_as_public_by_url_rule' if marked else 'source_text_no_matching_restriction'}
    if 'html' in content_type or re.search(r'<(?:!doctype html|html)',text[:2000],re.I):
        parser=PageText();parser.feed(text)
        title=' '.join(' '.join(parser.titles).split())
        visible=unicodedata.normalize('NFKC',' '.join(' '.join(parser.parts).split()))
        if GATE_TITLE.search(title) or len(visible)<100: raise ValueError('login_error_or_empty_page')
        if re.search(r'(?:enable javascript and cookies to continue|verify (?:that )?you are human|please complete the security check|you need to enable javascript to run this app)',visible,re.I):
            raise ValueError('challenge_or_script_shell')
        # Check rendered text, not scripts or security documentation examples in HTML source.
        marked=bool(PRIVATE_MARKING.search(visible))
        if marked and not manual_public: raise ValueError('restrictive_marking')
        return {'format':'text/html','access_scope':'public_page_only','observed_title':title[:500],
                'marking_check':'manually_marked_as_public_by_url_rule' if marked else 'visible_text_no_matching_restriction'}
    if content_type.startswith('image/'):
        if public_repository_asset and (body.startswith((b'\x89PNG\r\n\x1a\n',b'\xff\xd8\xff',b'GIF8',b'RIFF')) or b'<svg' in body[:1000]):
            return {'format':content_type,'access_scope':'public_repository_asset',
                    'marking_check':'catalogue_link_only_visual_content_not_transcribed_or_redistributed'}
        raise ValueError('image_requires_visual_marking_review')
    if content_type.startswith(('video/','audio/')):
        raise ValueError('media_requires_playback_and_marking_review')
    if manual_public and body.startswith((b'PK\x03\x04',b'\x1f\x8b')):
        return {'format':content_type,'access_scope':'archive_download_only',
                'marking_check':'manually_public_archive_contents_not_inspected_or_redistributed'}
    if '\x00' in text[:2000] or len(text.strip())<20:
        raise ValueError('unsupported_or_empty_content')
    marked=bool(PRIVATE_MARKING.search(unicodedata.normalize('NFKC',text)))
    if marked and not manual_public: raise ValueError('restrictive_marking')
    return {'format':content_type or 'text/plain','access_scope':'public_text_resource',
            'marking_check':'manually_marked_as_public_by_url_rule' if marked else 'text_no_matching_restriction'}


def check(url, timeout=25, max_bytes=64*1024*1024, marking_exception_hash=None, public_prefixes=(), source_title='', title_rules=()):
    validate_url(url, resolve=True)
    req=Request(url, headers={'User-Agent':'PublicKnowledgeCatalog/1.0', 'Accept':'*/*'})
    with build_opener(PublicRedirect()).open(req,timeout=timeout) as response:
        final=response.geturl(); validate_url(final)
        if response.status!=200: raise ValueError('non_200_response')
        body=response.read(max_bytes+1)
        if len(body)>max_bytes: raise ValueError('size_limit_requires_review')
        reviewed=marking_exception_hash is not None and hashlib.sha256(body).hexdigest()==marking_exception_hash
        github_hosts={'raw.githubusercontent.com','github.com','api.github.com'}
        repository_asset=urlsplit(url).hostname in github_hosts and urlsplit(final).hostname in github_hosts
        manual_public=bool(public_rule(url,public_prefixes,source_title,title_rules))
        raw_source=urlsplit(url).hostname=='raw.githubusercontent.com' and urlsplit(final).hostname=='raw.githubusercontent.com'
        result=inspect_body(body,response.headers.get_content_type(),reviewed,repository_asset,manual_public,raw_source)
    return {**result,'url':final,'http_status':200,'bytes':len(body),
            'sha256':hashlib.sha256(body).hexdigest(),'authentication_used':False,'cookies_used':False}
