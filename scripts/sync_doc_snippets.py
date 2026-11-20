"""Keep short, copyable SQL examples aligned with their downloadable scripts."""
import argparse
import os
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
PATTERN=re.compile(r'<!-- include-sql: ([^\n]+?) -->.*?<!-- /include-sql -->',re.S)


def render(match,document):
    relative=match.group(1).strip()
    source=(ROOT/relative).resolve()
    if not source.is_relative_to(ROOT/'sql') or source.suffix!='.sql':
        raise ValueError('SQL include must be a project SQL file: '+relative)
    lines=[line for line in source.read_text(encoding='utf-8').splitlines()
           if line.strip() and not line.lstrip().startswith('--')]
    if not 0<len(lines)<10:
        raise ValueError(f'{relative}: inline examples require fewer than 10 runnable lines, got {len(lines)}')
    link=os.path.relpath(source,document.parent).replace('\\','/')
    # Nested learner labs follow LiveLabs copy conventions; engineering docs
    # and the older flat labs keep ordinary Markdown code blocks.
    livelabs=(ROOT/'labs') in document.parents and document.parent!=ROOT/'labs'
    statement_files={'sql/schema/00_user_credential_worksheet.sql',
                     'sql/admin/08_create_apex_app_user.sql'}
    if livelabs and relative in statement_files and lines[-1].strip()=='/':
        lines=lines[:-1]  # Run Statement, rather than a slash-delimited script.
    code='\n'.join(lines)
    if livelabs:code='<copy>\n'+code+'\n</copy>'
    return ('<!-- include-sql: '+relative+' -->\n\n'
            +'```sql\n'+code+'\n```\n\n'
            +f'[Script: {source.name}]({link})\n\n<!-- /include-sql -->')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    changed=[];count=0
    for folder in ['docs','labs']:
        for document in (ROOT/folder).rglob('*.md'):
            current=document.read_text(encoding='utf-8')
            count+=len(PATTERN.findall(current))
            updated=PATTERN.sub(lambda m:render(m,document),current)
            if current!=updated:
                changed.append(str(document.relative_to(ROOT)))
                if not args.check:document.write_text(updated,encoding='utf-8',newline='\n')
    if args.check and changed:
        raise SystemExit('Out-of-date SQL snippets: '+', '.join(changed))
    print(f'{count} short SQL snippets checked; {len(changed)} documents '+('need updates' if args.check else 'updated'))


if __name__=='__main__':main()
