"""Assemble the self-contained SQLcl APEXlang source from project UI assets."""
from pathlib import Path
import argparse
import hashlib

ROOT=Path(__file__).resolve().parents[1]


def build(check=False):
    assets=ROOT/'apex'
    html=(assets/'region.html').read_text(encoding='utf-8')
    generated_assets=assets/'application/shared-components/static-files'
    generated_assets.mkdir(parents=True,exist_ok=True)
    for filename in ['explorer.js','explorer.css']:
        target_asset=generated_assets/filename
        content=(assets/filename).read_text(encoding='utf-8')
        if check:
            if not target_asset.exists() or target_asset.read_text(encoding='utf-8')!=content:
                raise ValueError('APEX static asset is stale: '+filename)
        else:target_asset.write_text(content,encoding='utf-8',newline='\n')
    page='''page 1 (
 name: Knowledge Context Explorer
 alias: HOME
 title: Knowledge Context Explorer
 javaScript {
  fileUrls: #APP_FILES#explorer.js?v=__JS_VERSION__
 }
 css {
  fileUrls: #APP_FILES#explorer.css?v=__CSS_VERSION__
 }
 appearance {
  pageTemplate: @/standard
  templateOptions: #DEFAULT#
 }
 security {
  pageAccessProtection: argumentsMustHaveChecksum
  formAutoComplete: false
 }
 region knowledge-explorer (
  name: Knowledge Context Explorer
  type: staticContent
  layout {
   sequence: 10
   slot: body
  }
  source {
   htmlCode:
    ```html
__HTML__
    ```
  }
 )
 process kcv-explorer (
  name: KCV_EXPLORER
  type: executeCode
  source {
   plsqlCode:
    ```plsql
    begin kcv_apex.dispatch; end;
    ```
  }
  execution {
   sequence: 10
   point: ajaxCallback
  }
 )
)
'''.replace('__HTML__',html).replace('__JS_VERSION__',hashlib.sha256((assets/'explorer.js').read_text(encoding='utf-8').encode()).hexdigest()[:12]).replace('__CSS_VERSION__',hashlib.sha256((assets/'explorer.css').read_text(encoding='utf-8').encode()).hexdigest()[:12])
    target=assets/'application/pages/p00001-home.apx'
    target.parent.mkdir(parents=True,exist_ok=True)
    if check:
        if not target.exists() or target.read_text(encoding='utf-8')!=page:
            raise ValueError('APEX page source is stale; run python scripts/build_apex.py')
    else:
        target.write_text(page,encoding='utf-8',newline='\n')
    return str(target.relative_to(ROOT))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    print(build(args.check))
