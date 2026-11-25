from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from . import pipeline as p


def main():
    parser=argparse.ArgumentParser(description='Independent public knowledge/context graph lab')
    parser.add_argument('command',choices=['fetch','prepare','build','packet','review','worksheet','import-candidates','check-db','apply-sql','load-db','extract','agent','provision','configure-profile','feedback','infer'])
    parser.add_argument('--context',default='CTX02')
    parser.add_argument('--question',default='Which knowledge could help with this context, and what remains unknown?')
    parser.add_argument('--source',default='S03')
    parser.add_argument('--candidate')
    parser.add_argument('--decision',choices=['accept','reject'])
    parser.add_argument('--reviewer')
    parser.add_argument('--reason')
    parser.add_argument('--observer')
    parser.add_argument('--observation')
    parser.add_argument('--file',type=Path)
    parser.add_argument('--admin',action='store_true')
    parser.add_argument('--schema',help='Explicit existing owner for ADMIN apply-sql of sql/admin/02_grants.sql')
    parser.add_argument('--task',choices=['analyse_source','clarify_context','assess_context'],default='assess_context')
    args=parser.parse_args()
    if args.schema is not None and args.command!='apply-sql':
        parser.error('--schema applies only to the parameterized ADMIN grants script')
    if args.command=='fetch': result=p.fetch()
    elif args.command=='prepare': result={'passages':len(p.prepare())}
    elif args.command=='build': result=p.build();p.render_svg()
    elif args.command=='worksheet':
        from .worksheet import export
        result=export()
    elif args.command=='import-candidates':
        if args.file is None:parser.error('--file required')
        allowed={t for s in p.sources() for t in s['topics']}
        candidates=p.validate_candidates(p.read(args.file),p.read(p.ROOT/'work/passages.json'),allowed)
        target=p.ROOT/'work/candidates.json'
        previous=p.read(target) if target.exists() else []
        merged={c['id']:c for c in previous}
        merged.update({c['id']:{**c,'origin':'SQL Worksheet output imported for explicit review','response_sha256':p.digest(args.file.read_bytes())} for c in candidates})
        p.write(target,list(merged.values()))
        result={'imported_proposals':len(candidates),'accepted':False}
    elif args.command=='packet':
        result=p.packet(args.context,args.question)
        p.write(p.ROOT/'work/retrieval-packet.json',result)
        result={'context':args.context,'evidence_ids':[x['id'] for x in result['evidence']],'output':'work/retrieval-packet.json'}
    elif args.command=='review':
        if not all([args.candidate,args.decision,args.reviewer,args.reason]):parser.error('review requires candidate, decision, reviewer and reason')
        p.review(args.candidate,args.decision,args.reviewer,args.reason);result={'decision_recorded':True,'rebuild_required':True}
    else:
        from . import database as db
        if args.command=='check-db': result=db.preflight()
        elif args.command=='apply-sql':
            if args.file is None:parser.error('--file required')
            grant_script=(p.ROOT/'sql/admin/02_grants.sql').resolve()
            bindings=None
            if args.file.resolve()==grant_script:
                if not args.admin or not args.schema or not re.fullmatch(r'KCV_[A-Z0-9_]{1,26}',args.schema):
                    parser.error('02_grants.sql requires --admin and --schema with the intended upper-case KCV_ owner')
                bindings={'KCV_SCHEMA':args.schema}
            elif args.schema is not None:
                parser.error('--schema is supported only for sql/admin/02_grants.sql; use Worksheet binds for other setup scripts')
            result={'applied':str(args.file),'query_results':db.apply(args.file,args.admin,bindings)}
        elif args.command=='load-db':result=db.load()
        elif args.command=='extract':result=db.extract(args.source)
        elif args.command=='provision':result=db.provision()
        elif args.command=='configure-profile':result=db.configure_profile()
        elif args.command=='feedback':result=db.add_feedback(args.context,args.observer,args.observation)
        elif args.command=='infer':result=db.infer()
        else:result={'response':db.run_team({'task':args.task,'context_id':args.context,'source_id':args.source,'question':args.question})}
    print(json.dumps(result,ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
