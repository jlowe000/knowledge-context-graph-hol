# Lab 3 — Connect the collection and the context

## Objective

Explore taxonomy facets and defined relationships before asking a model to interpret them.

```bash
.venv/bin/python -m kcv.cli build
```

Inspect `ontology/kcv.ttl`, `generated/knowledge.ttl`, `generated/model.svg` and `generated/assessments.json`.

- ContentItem identifies a resource; ContentVersion identifies its exact edition.
- EvidencePassage identifies a real page/chunk. The shareable graph contains its locator/hash, not the complete passage text.
- ReviewExample is deliberately different from Claim.
- ContextSnapshot records what the learner has supplied, including unknowns.
- RelevanceAssessment links a context to candidate content versions. The initial method is a transparent topic baseline, not an agent result or measured value.

## Query the local RDF artifact

```bash
.venv/bin/python - <<'PY'
from rdflib import Graph
g=Graph().parse('generated/knowledge.ttl',format='turtle')
q='''SELECT ?version WHERE {
 ?a <https://example.org/kcv/forContext> <https://example.org/kcv/CTX03-v1> ;
    <https://example.org/kcv/recommendsVersion> ?version . }'''
for row in g.query(q): print(row[0])
PY
```

This RDFLib query validates the artifact's local semantics; it does not validate Oracle SEM_APIS.

## Load native RDF on Serverless

After completing setup, generate the SQL load artifact locally:

```bash
.venv/bin/python -m kcv.cli worksheet
```

In **KCV_LAB SQL Worksheet**, open/run `work/worksheet/10_load_dataset.sql`, then `sql/queries/01_inspect.sql` and `integration-test/verify_worksheet.sql`. No client database connection is required. The loader creates a graph snapshot and only then updates ACTIVE_GRAPH. Rerunning the same graph hash reuses it. Follow the evidence packet's PDF page URLs. Native queries use SEM_MATCH over the loaded graph to select passage identities and retrieve their stored text.

**Copyable inspection queries (KCV_LAB):**

<!-- include-sql: sql/queries/01_inspect.sql -->

```sql
SELECT version_id,source_id,sha256 FROM kcv_sources ORDER BY source_id
/
SELECT context_id,snapshot_version FROM kcv_contexts ORDER BY context_id,snapshot_version
/
SELECT graph_name,graph_hash,state FROM kcv_graph_runs ORDER BY created_at
/
SELECT kcv_evidence_packet('{"context_id":"CTX02"}') AS evidence FROM dual
/
```

[Script: 01_inspect.sql](../sql/queries/01_inspect.sql)

<!-- /include-sql -->

## Questions

Why can a general source be useful without a specific implementation objective? Why does a shared topic not establish applicability? Why does graph creation not mean a claim has been verified?
