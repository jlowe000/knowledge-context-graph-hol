# Lab 2 — Know what the evidence is

## Objective

Distinguish source identity, a file edition, an extracted passage and an editorial review example.

```bash
.venv/bin/python -m kcv.cli fetch
.venv/bin/python -m kcv.cli prepare
```

The downloader checks HTTPS host, PDF signature and exact SHA-256. Changed bytes cause an explicit stop. The extractor uses only the selected pages in `data/public-sources.json`, retaining one-based PDF page, chunk position, text hash and edition hash. A PDF page number can differ from its printed slide number.

Read one local passage:

```bash
.venv/bin/python - <<'PY'
import json
p=json.load(open('work/passages.json',encoding='utf-8'))
row=next(x for x in p if x['source_id']=='S03' and x['pdf_page']==17)
print(row['id'],row['locator_url'])
print(row['text'])
PY
```

Now open `review-examples/examples.json`. Compare the corresponding editorial paraphrase with the actual page text. They are different evidence types. The paraphrase is a checking aid, not a pre-approved extracted fact.

## Investigate

- S04 and S05 share LRN6034. Compare their titles and hashes: they are distinct documents, not duplicates.
- S03 page 17 qualifies future capability. What would be needed to establish current availability?
- S10 page 10 supplies the healthcare overview; page 3 supplies scope limitations. Read both.

Original documents and full extracted passages remain in ignored local work files. Only public metadata and concise original review examples belong in the publishable source tree. Check source text visually if extraction produces ambiguous layout or warnings; valid hashes do not prove perfect extraction.
