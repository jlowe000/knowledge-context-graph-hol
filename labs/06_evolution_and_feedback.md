# Lab 6 — Let understanding evolve

## Revise context without rewriting history

Edit a fictional context in `data/contexts.json`. Refine its question or topic preferences and increment snapshot_version. Keep the change explicit; do not claim the revised context is an actual customer's statement.

```bash
.venv/bin/python -m kcv.cli build
.venv/bin/python -m kcv.cli worksheet
```

Run the new load script in **KCV_LAB SQL Worksheet**. The loader rejects a changed context body under the same snapshot identity. A new snapshot and graph build preserve the older database state. Compare the proposed recommendations before and after; the underlying public source statements have not changed merely because the learner asks a different question.

## Record your actual observation

After evaluating a result, use your own observation rather than a pre-written success claim. In Worksheet, fill in the observer and observation in `sql/queries/05_record_feedback.sql`, run it, then inspect `sql/queries/02_feedback.sql`.

**Copyable feedback inspection (KCV_LAB):**

<!-- include-sql: sql/queries/02_feedback.sql -->

```sql
SELECT feedback_id,context_snapshot_id,graph_name,observer,recorded_at
 FROM kcv_feedback ORDER BY recorded_at
/
```

[Script: 02_feedback.sql](../sql/queries/02_feedback.sql)

<!-- /include-sql -->

Feedback records the context and native graph snapshot. It does not rewrite a source claim or prove financial value. If removing a previously accepted claim, record a rejection, rebuild and load a new snapshot; the old graph remains historical evidence.

## Optional: formal inference

In Worksheet, run `sql/queries/06_inference.sql` explicitly.

This creates a separate OWL2RL inferred graph over the current native snapshot. The ontology declares Topic as a subclass of SKOS Concept: that supports class entailment, not business suitability or value. This optional native step needs Serverless validation and does not run in artifact-only mode.

## Finish

Run `integration-test/verify_worksheet.sql` and inspect the agent replies/citations. The Python integration suite is optional if direct DB connectivity is available. Record what was actually tested, which model/region/profile was used, and any failed/skipped checks. Use [cleanup.md](../docs/cleanup.md) to retire temporary resources deliberately.
