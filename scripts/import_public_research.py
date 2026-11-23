"""Verify research references anonymously and export only allowlisted metadata.

The input report and failed-source details stay outside the public distribution.
Successful source bodies are inspected in memory, never copied to the release.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone, timedelta
import json
import hashlib
import logging
from pathlib import Path
import re
import sys
from urllib.error import HTTPError
from urllib.parse import urlsplit, urlunsplit, unquote

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from kcv.public_access import check, validate_url, public_rule, retained_publisher
from kcv.pipeline import read, write

DOMAINS={'OCI','AI','Data Management','Analytics','Infrastructure','Security','SaaS',
         'IGU','NetSuite','Partners','General','Unclassified'}
TOPICS={
 'Knowledge graphs':r'knowledge graph|\bgraph\b', 'Ontology':r'ontolog',
 'Semantic retrieval':r'vector|retrieval|\brag\b|semantic search',
 'AI agents':r'agent', 'Business context':r'business context|business knowledge',
 'Database migration':r'migrat', 'Multicloud':r'multicloud|multi.cloud|database@',
 'Security and patching':r'secur|patch|zero.trust|vulnerab',
 'Hybrid deployment':r'hybrid|cloud@customer|on.prem',
 'Developer experience':r'develop|\bapi\b|devops|java|python|helidon|apex|microservice',
 'Healthcare':r'health|clinical|patient|ehr', 'Energy and utilities':r'energy|utilit|power grid',
 'Construction and engineering':r'construction|engineering|aconex|primavera',
 'AI infrastructure':r'gpu|supercluster|supercomputer|inference|training|nvidia|amd|openai',
 'Data integration':r'data integration|iceberg|lakehouse|aidp|data platform|data intelligence',
 'Partnerships':r'partner|collaborat|alliance', 'Autonomous database':r'autonomous',
 'Business applications':r'fusion|netsuite|\berp\b|\bhcm\b|\bscm\b',
}


def candidates(report, public_prefixes=(), title_rules=(), policy=None):
    found={}; excluded=Counter()
    for row in report['records']+report['references']:
        url=row.get('source_url') or ''
        try: validate_url(url)
        except (ValueError,TypeError): excluded['excluded_or_missing_url']+=1;continue
        url=urlunsplit(urlsplit(url)._replace(fragment=''))
        rule=public_rule(url,public_prefixes,str(row.get('title') or ''),title_rules)
        public_repository=urlsplit(url).hostname in {'raw.githubusercontent.com','github.com','api.github.com'} or bool(rule)
        review_reason=None
        if not rule and not retained_publisher(url,policy or {}):
            review_reason='industry_or_third_party_review_required'
        if not rule and any(urlsplit(url).hostname==urlsplit(r['url_prefix']).hostname for r in title_rules):
            review_reason='title_does_not_match_public_rule'
        # Never export acquisition annotations: public items can have private lineage.
        scope=str(row.get('usage_scope') or '').lower()
        access=str(row.get('access_scope') or '').lower()
        classification=str(row.get('classification') or '').lower()
        if not public_repository and (row.get('external_delivery_allowed') is False or 'internal only' in scope):
            excluded['restricted_handling']+=1;continue
        if not public_repository and row.get('content_type') in {'Go To Market','Engineering','Event Management','Event management'}:
            excluded['restricted_handling']+=1;continue
        if not public_repository and any(x in access for x in ('internal access-controlled','authorized internal','employees only','authenticated internal')):
            excluded['restricted_handling']+=1;continue
        if not public_repository and classification.startswith(('internal ','oracle confidential','oracle internal','restricted','highly restricted')):
            excluded['restricted_handling']+=1;continue
        if url not in found: found[url]={'row':row,'report_ids':[],'review_reason':review_reason}
        elif review_reason: found[url]['review_reason']=review_reason
        found[url]['report_ids'].append(str(row['id']))
    return found,excluded


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--workers',type=int,default=8)
    parser.add_argument('--resume',action='store_true',help='Reuse this run\'s saved successful checks')
    parser.add_argument('--reuse-results',action='store_true',help='Rebuild metadata from saved checks including failures; preserves their original verification dates')
    parser.add_argument('--audit-dir',type=Path,default=ROOT.parent/'private-public-access-audit',
                        help='Private check/conflict directory outside the public repository')
    args=parser.parse_args()
    report=read(args.report)
    policy=read(ROOT/'references/public-source-policy.json')
    prefixes=policy['url_prefixes']
    title_rules=policy.get('title_rules',[])
    rows,excluded=candidates(report,prefixes,title_rules,policy)
    def rule_for(url):
        return public_rule(url,prefixes,str(rows[url]['row'].get('title') or ''),title_rules)
    audit_dir=args.audit_dir.resolve()
    if audit_dir.is_relative_to(ROOT):
        raise ValueError('Keep check/conflict details outside the public repository')
    audit_dir.mkdir(parents=True,exist_ok=True)
    checkpoint=audit_dir/'public-research-checks.json'
    prior=read(checkpoint) if (args.resume or args.reuse_results) and checkpoint.exists() else {}
    checked={url:v for url,v in prior.items() if url in rows and (v.get('ok') or args.reuse_results)}
    manual_file=audit_dir/'manual-exclusions.json'
    manual=read(manual_file) if manual_file.exists() else []
    if isinstance(manual,dict): manual=manual.get('exclusions',[])
    manual_by_id={identifier:entry for entry in manual for identifier in entry.get('report_ids',[])}
    editions_file=audit_dir/'reviewed-public-editions.json'
    editions=read(editions_file).get('editions',[]) if editions_file.exists() else []
    reviewed={e['url']:e for e in editions if e.get('decision')=='include_public_event_edition'}
    for url,record in rows.items():
        match=next((manual_by_id[i] for i in record['report_ids'] if i in manual_by_id),None)
        if match and not rule_for(url):
            previous_check=checked.get(url,prior.get(url,{}))
            checked[url]={'ok':False,'checked_at':previous_check.get('checked_at',datetime.now(timezone.utc).isoformat()),
                          'reason':'restrictive_marking_manual_review'}
    for url in reviewed:
        if url in rows and url in checked and not checked[url].get('ok'):
            del checked[url]  # Reverify access and exact approved edition, never just override HTTP failure.
    for url,value in list(checked.items()):
        rule=rule_for(url)
        if rule and not value.get('ok') and value.get('public_rule_attempted')!=rule:
            del checked[url]
            continue
        if urlsplit(url).hostname in {'raw.githubusercontent.com','github.com','api.github.com'} and value.get('reason')=='image_requires_visual_marking_review':
            del checked[url]
    todo=[url for url in rows if url not in checked]
    logging.getLogger('pypdf').setLevel(logging.ERROR)
    def verify(url):
        stamp=datetime.now(timezone.utc).isoformat()
        attempt={'checked_at':stamp,'public_rule_attempted':rule_for(url)}
        try: return {'ok':True,**attempt,**check(url,marking_exception_hash=reviewed.get(url,{}).get('source_sha256'),public_prefixes=prefixes,source_title=str(rows[url]['row'].get('title') or ''),title_rules=title_rules)}
        except HTTPError as exc: return {'ok':False,**attempt,'reason':'http_'+str(exc.code),'http_status':exc.code}
        except Exception as exc:
            reason=str(exc) if isinstance(exc,ValueError) else type(exc).__name__
            if len(reason)>100 or 'http' in reason: reason=type(exc).__name__
            return {'ok':False,**attempt,'reason':reason}
    print(f'Checking {len(todo)} candidate URLs; {len(checked)} verified checks resumed.',flush=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs={pool.submit(verify,url):url for url in todo}
        for index,future in enumerate(as_completed(jobs),1):
            checked[jobs[future]]=future.result()
            if index%25==0 or index==len(todo):
                write(checkpoint,checked)
                print(f'Checked {index}/{len(todo)}; successful {sum(v["ok"] for v in checked.values())}',flush=True)
    curated=read(ROOT/'data/public-sources.json')['sources']
    curated_urls={s['url']:s for s in curated}
    existing_file=ROOT/'data/public-catalog.json'
    old_catalog=read(existing_file) if existing_file.exists() else {}
    existing=old_catalog.get('items',[])
    retired_ids=set(old_catalog.get('retired_ids',[]))
    previous={r['url']:r for r in existing}
    identities={url:r['id'] for url,r in previous.items()}
    next_id=max([int(r['id'][1:]) for r in existing]+[int(x[1:]) for x in retired_ids]+[0])+1
    items=[]; audits=[]; final_seen={}; held=Counter(); conflict_rows=[]
    old_conflicts_file=audit_dir/'public-release-conflicts.json'
    old_conflicts=read(old_conflicts_file).get('conflicts',[]) if old_conflicts_file.exists() else []
    historical_reasons={r['url']:r.get('original_reason',r.get('reason')) for r in old_conflicts}
    for url,result in checked.items():
        rule=rule_for(url)
        original_reason=historical_reasons.get(url)
        review_reason=rows[url].get('review_reason') if not rule else None
        if not result['ok'] or original_reason or review_reason:
            conflict_rows.append({'report_ids':rows[url]['report_ids'],'title':rows[url]['row'].get('title'),
              'url':url,'site':urlsplit(url).hostname,'original_reason':original_reason or review_reason or result.get('reason'),
              'reason':review_reason or (result.get('reason') if not result['ok'] else None),
              'access_error':result.get('reason') if not result['ok'] else None,
              'checked_at':result['checked_at'],
              'status':'manually marked as public' if rule else 'to be reviewed',
              'matched_rule':rule,'access_verified':bool(result['ok']),
              'needs_access_recheck':not result['ok'],
              'http_status':result.get('http_status'),
              'included_in_catalogue':bool((result['ok'] or rule) and not review_reason)})
    for requested in sorted(rows):
        result=checked[requested]
        rule=rule_for(requested)
        review_reason=rows[requested].get('review_reason') if not rule else None
        if review_reason: held[review_reason]+=1;continue
        if not result['ok'] and not rule: held[result['reason']]+=1;continue
        final=requested if rule else urlunsplit(urlsplit(result['url'])._replace(fragment=''))
        row=rows[requested]['row']
        if final in final_seen:
            final_seen[final]['report_ids'].extend(rows[requested]['report_ids']);continue
        cur=curated_urls.get(final) or curated_urls.get(requested)
        identifier=cur['id'] if cur else identities.get(final)
        if not identifier:
            identifier=f'R{next_id:04d}';next_id+=1
        title=' '.join(str(row.get('title') or result.get('observed_title') or 'Public research reference').split())[:700]
        # Bibliographic title and controlled facets only, never research free text.
        title=re.sub(r'https?://\S+','',title).strip()
        if not title:
            title=result.get('observed_title') or unquote(urlsplit(final).path.rstrip('/').rsplit('/',1)[-1]) or urlsplit(final).hostname
        title=' '.join(title.split())[:700]
        topics=[name for name,pattern in TOPICS.items() if re.search(pattern,title,re.I)]
        domains=[d for d in row.get('domains',[]) if d in DOMAINS]
        if not topics: topics=['General research']
        session=row.get('session_id') or ''
        session_ids=re.findall(r'\b(?:HOL|LRN|THR|KEY|BOO|OUT)\d{3,5}\b',str(session))
        # A failed retrieval has a metadata snapshot hash, never a fabricated body hash.
        metadata={'title':title,'url':final,'topics':topics,'business_domains':domains,'session_ids':session_ids}
        observed_hash=result['sha256'] if result['ok'] else hashlib.sha256(json.dumps(metadata,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
        version_id=identifier+'-v1'
        if final in previous:
            old=previous[final]['version']; version_id=old['id']
            if old['sha256']!=observed_hash:
                version_id=identifier+'-v'+str(int(old['id'].rsplit('-v',1)[1])+1)
        recorded_on=datetime.fromisoformat(result['checked_at']).astimezone(timezone(timedelta(hours=10))).date().isoformat()
        version={'id':version_id,'sha256':observed_hash,'hash_basis':'source_response' if result['ok'] else 'catalogue_metadata',
                 'recorded_on':recorded_on}
        if result['ok']: version.update({'bytes':result['bytes'],'verified_on':recorded_on})
        state='manually_marked_public' if rule else 'verified_public'
        item={'id':identifier,'title':title,'url':final,'format':result.get('format','unverified_reference'),
            'version':version,
            'report_ids':rows[requested]['report_ids'],'access_status':state,'access_verified':bool(result['ok']),
            'classification_status':'manually marked as public' if rule else 'verified public',
            'public_rule':rule,'verification_error':result.get('reason') if not result['ok'] else None,
            'evidence_coverage':'catalogue_only','topics':topics,'business_domains':domains,
            'session_ids':session_ids,'content_form':'Public research reference',
            'editorial_classification':True,'classification_basis':'Title-derived topic facets; report broad domains retained as editorial metadata.',
            'limitations':('Public access verified at the recorded time. ' if result['ok'] else 'Manually designated public by the stated URL rule; automated retrieval did not verify content access. The version hash identifies catalogue metadata only. ')+
                          'Catalogue metadata provides discovery, not reviewed answer evidence or a claim of current availability.'}
        final_seen[final]=item
        audits.append({'source_id':identifier,**{k:v for k,v in result.items() if k not in {'ok','observed_title','url','public_rule_attempted'}},
                       'url':final,'final_url':result.get('url') if result['ok'] else None,
                       'sha256':observed_hash,'hash_basis':version['hash_basis'],
                       'authentication_used':False,'cookies_used':False,
                       'access_verified':bool(result['ok']),'public_rule':rule,
                       'classification_status':item['classification_status'],'status':state})
        if cur:
            if not result['ok'] or observed_hash!=cur['version']['sha256']:
                raise ValueError('Curated source edition changed: '+identifier)
        else: items.append(item)
    # Curated sources must be independently verified, not silently grandfathered.
    curated_checks={a['source_id']:a for a in audits if a['source_id'].startswith('S')}
    curated_held=[s['id'] for s in curated if s['id'] not in curated_checks]
    snapshot={'schema_version':1,'generated_at':datetime.now(timezone.utc).isoformat(),
       'checked_at':max((a['checked_at'] for a in audits),default=None),
       'verification_date_timezone':'Australia/Brisbane',
       'research_report_generated_at':report.get('generated_at'),
       'scope':'All records and references with eligible URLs were checked; derived copies are not separate primary sources.',
       'candidate_url_count':len(rows),'included_public_url_count':len(audits),
       'verified_public_url_count':sum(a['access_verified'] for a in audits),
       'manually_marked_public_count':sum(a['status']=='manually_marked_public' for a in audits),
       'manually_public_unverified_count':sum(not a['access_verified'] for a in audits),
       'catalogue_count':len(items),'curated_verified_count':len(curated_checks),
       'held_by_reason':dict(sorted(held.items())),'excluded_input_counts':dict(excluded),
       'curated_sources_requiring_review':curated_held,
       'method':'Anonymous HTTPS GET without cookies or credentials; actual access outcomes recorded separately from user public-classification rules. Matching source conflicts are manually marked as public. Failed or unsupported retrievals under a rule remain catalogue metadata only, with a metadata hash. PDF text checks are not OCR; webpage access does not verify linked media playback.',
       'checks':audits}
    retired_ids.update(set(identities.values())-{r['id'] for r in items})
    write(ROOT/'data/public-catalog.json',{'schema_version':1,'retired_ids':sorted(retired_ids),'items':items})
    write(ROOT/'references/public-access-checks.json',snapshot)
    write(audit_dir/'public-release-conflicts.json',{'report_generated_at':report.get('generated_at'),
      'policy':'User URL rules resolve public classification; actual access results and outstanding reviews remain separate.',
      'public_rules':policy,'conflicts':conflict_rows,
      'manually_marked_public':[r for r in conflict_rows if r['status']=='manually marked as public'],
      'to_be_reviewed':sorted((r for r in conflict_rows if r['status']=='to be reviewed'),
                             key=lambda r:(r['site'].casefold(),(r.get('report_ids') or [''])[0].casefold(),r['url']))})
    print(json.dumps({k:v for k,v in snapshot.items() if k not in {'checks','method','scope'}},indent=2),flush=True)


if __name__=='__main__':main()
