# Original-workshop scenarios with knowledge and context

This is the extended hands-on route. It retains the original's document → ontology → RDF → question/change agents → chat → optional inference progression, using the existing public-source dataset. You can perform it in SQL Worksheet or the supplied APEX app. There is no per-claim approval gate.

## Where to start in your current environment

If the initial graph and KCV_GENAI greeting already work, **do not recreate the user, tables, profile or initial agent team**. Start with [extension installation](../docs/scenario-setup.md). It adds a separate KCV_EXPLORER_TEAM and scenario tables without replacing KCV_TEAM or rewriting the hashed base graph.

| Original exercise | Adapted exercise | Observable result |
| --- | --- | --- |
| Load and chunk two F1 PDFs | Existing nine public presentations and page-aware passages | Real public URLs, immutable editions and PDF page locators |
| Extract ontology-aligned triples | Optional source-concept extraction below | A separate RDF graph containing model-proposed relationships and passage links |
| Load, query and visualize RDF | Inspect base knowledge and scenario topic overlays | Actual context → topic ← source → version → passage bindings |
| Question and guarded change agents | Evidence question worker and context-change planner | Answers cite returned evidence; changes pass a typed, audited API |
| Chat and change the graph in APEX | Knowledge Context Explorer app | Same tools, source links, visible paths and refinement controls |
| OWL before/after classification | Infer FocusedContext from an explicit topic link | A class membership appears after inference, not a claim of business value |

The ingestion implementation remains an intentional alternative: PDFs are extracted locally with pypdf, not loaded as BLOBs and processed with DBMS_VECTOR_CHAIN. The folder name of the original does not imply it implements embedding/vector retrieval; neither does this route.

## Worksheet conventions

Use KCV_LAB. For a bind-variable block, select DECLARE/BEGIN through END; **excluding the final slash**, and use **Run Statement**. Open DBMS Output for results. Short blocks print at most the first 32,000 characters of a model reply; use APEX or a local CLOB-capable client for a longer response. Pure SELECTs return a CLOB cell you can open or download.

There are three different identifiers: **scenario session** (S…), **context revision** (R…), and the database-created **agent conversation ID**. These scripts require the **scenario session ID**. The package manages registered conversation IDs automatically, including starting a fresh conversation after an applied refinement.

## Scenario A — Alex: discovery, then a narrower focus

**Question:** Which knowledge helps Alex find existing project information, and how does refining the context change what is retrieved?

1. Start a scenario. Supply `CTX01` for KCV_CONTEXT_ID. Copy the printed S… ID.

<!-- include-sql: sql/scenarios/01_start.sql -->

```sql
BEGIN
  DBMS_OUTPUT.PUT_LINE(kcv_scenario.open_session(:KCV_CONTEXT_ID));
END;
/
```

[Script: 01_start.sql](../sql/scenarios/01_start.sql)

<!-- /include-sql -->

2. Inspect state and evidence using that ID for KCV_SESSION_ID. Save the JSON or note the source IDs and graph paths before changing anything.

<!-- include-sql: sql/scenarios/02_inspect.sql -->

```sql
SELECT kcv_scenario.state(:KCV_SESSION_ID) AS scenario_state FROM dual
/
SELECT kcv_scenario.evidence_packet(JSON_OBJECT('scenario_session' VALUE :KCV_SESSION_ID)) AS evidence_and_paths FROM dual
/
```

[Script: 02_inspect.sql](../sql/scenarios/02_inspect.sql)

<!-- /include-sql -->

The initial stored context has an emerging objective and topic preferences including Graph capabilities. Retrieval follows actual topic joins across the immutable base graph and this scenario's context overlay. It is **topic membership with deterministic ordering and page caps**, not weighted semantic ranking. Numeric preference weights are retained in context but are not used for this extension's ordering. Only six pages are returned, at most two per source; not every eligible source fits.

3. Ask `Which sources help me find useful project information, why do they connect, and what remains unknown?` for KCV_QUESTION.

<!-- include-sql: sql/scenarios/03_ask.sql -->

```sql
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.ask(:KCV_SESSION_ID,:KCV_QUESTION,'question');
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
```

[Script: 03_ask.sql](../sql/scenarios/03_ask.sql)

<!-- /include-sql -->

Look for real returned path bindings, evidence IDs and qualifications. These are proposed relevance judgments, not established suitability or measured outcomes.

4. Clarify the objective. Use the following JSON as KCV_CHANGE_JSON in the preview block:

```json
{"operation":"SET_OBJECTIVE","objective":"Find existing project information across documents; document approval and workflow are out of scope."}
```

<!-- include-sql: sql/scenarios/04_preview_change.sql -->

```sql
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.stage_change(:KCV_SESSION_ID,:KCV_CHANGE_JSON);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
```

[Script: 04_preview_change.sql](../sql/scenarios/04_preview_change.sql)

<!-- /include-sql -->

The response contains a pending change token. The preview **has not changed the context or graph**. Inspect the operation and supplied objective, then run the apply block with that token as KCV_PENDING_CHANGE:

<!-- include-sql: sql/scenarios/05_apply_change.sql -->

```sql
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.apply_change(:KCV_SESSION_ID,:KCV_PENDING_CHANGE);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
```

[Script: 05_apply_change.sql](../sql/scenarios/05_apply_change.sql)

<!-- /include-sql -->

Inspect again. A new R… revision and overlay graph should exist; the prior revision remains. An objective-only edit does not change topic joins: unchanged retrieved sources are an expected result, although the explanation can become more focused.

5. Now change a relationship that affects retrieval. Preview and apply:

```json
{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}
```

Repeat the evidence query and original question. Compare the exact eligible paths and source IDs. Sources that depended solely on this topic no longer match; the bounded packet may now include another eligible source. Do not describe this as a measured improvement until evaluated.

6. Add the topic back with `{"operation":"ADD_TOPIC","topic":"Graph capabilities"}`. Inspect before/after and the audit. Each applied change creates another revision, so restoring a topic does not erase the change history. Source passages and the immutable base graph never change.

7. Check the guardrails: reusing the applied token should fail; a topic not in the source vocabulary should fail; a token older than ten minutes or staged against an older revision should fail. No arbitrary SQL/SPARQL is accepted by the change API.

## Scenario B — Sam: evidence and connected concepts

Start another scenario with `CTX02`. Ask: `How could these sources help us inspect the concepts, relationships and evidence behind an answer? What do they not establish about document approval?`

Inspect sources S03–S05 where returned, keeping the two LRN6034 presentations separate. They are different sources with different perspectives. Follow page links; do not infer current product availability from a roadmap.

Optionally use the change planner: ask `Add Embeddings as an area to explore` with the following block. It calls a model but **only proposes a plan**:

<!-- include-sql: sql/scenarios/09_propose_change.sql -->

```sql
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.ask(:KCV_SESSION_ID,:KCV_QUESTION,'propose_change');
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
```

[Script: 09_propose_change.sql](../sql/scenarios/09_propose_change.sql)

<!-- /include-sql -->

Inspect the response. If the plan matches the request, copy the typed ADD_TOPIC operation into the preview/apply blocks. The agent is not given an apply tool. In APEX, use the refinement controls to submit the intended edit. A model suggestion is not treated as the user's confirmation.

Compare retrieved paths after adding Embeddings. This demonstrates divergent exploration; removing it again demonstrates convergence. A change in the six-page packet may also reflect the deterministic retrieval cap, which is a limitation to discuss.

## Scenario C — Casey: useful connections without availability assumptions

Start `CTX03`. Ask: `How do clinical care and enterprise operations connect in this material, and what can I conclude about availability in my region?`

The initial dataset's relevant source is S10. Check that both **PDF page 3 (scope/disclaimer)** and **page 10 (overview)** are present. A helpful response explains the connection and says what additional evidence is needed about region, deployment and current availability. A confident availability claim unsupported by those pages is a failed scenario result.

Capture an actual observation using a source check, a discussion, a dot vote, a practical test or another method. Supply your own observation and next question; example words are not seeded success data.

<!-- include-sql: sql/scenarios/06_observe.sql -->

```sql
BEGIN
  kcv_scenario.observe(:KCV_SESSION_ID,:KCV_METHOD,:KCV_OBSERVATION,:KCV_NEXT_STEP);
END;
/
```

[Script: 06_observe.sql](../sql/scenarios/06_observe.sql)

<!-- /include-sql -->

Allowed KCV_METHOD values: `source_check`, `discussion`, `dot_vote`, `practical_test`, `other`. The saved record is tied to this scenario and context revision. A vote records shared priorities or agreement; it does not make a factual claim true.

<!-- include-sql: sql/scenarios/08_audit.sql -->

```sql
SELECT operation,old_revision,new_revision,actor,recorded_at
FROM kcv_scenario_audit WHERE session_id=:KCV_SESSION_ID ORDER BY audit_id
/
SELECT method,observation,next_step,revision_id,recorded_at
FROM kcv_scenario_observations WHERE session_id=:KCV_SESSION_ID ORDER BY observation_id
/
```

[Script: 08_audit.sql](../sql/scenarios/08_audit.sql)

<!-- /include-sql -->

## Optional — Ontology-aligned extraction of source relationships

Install `sql/extensions/04_domain_extraction.sql` once. Run the block below with `S02` as KCV_SOURCE_ID:

<!-- include-sql: sql/scenarios/07_extract_domain.sql -->

```sql
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_extract_domain(:KCV_SOURCE_ID);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
```

[Script: 07_extract_domain.sql](../sql/scenarios/07_extract_domain.sql)

<!-- /include-sql -->

The supplied ontology permits only existing source-topic labels as endpoints and `usesConcept`, `dependsOn`, `complements` as predicates. The model must cite an exact passage and quote, retaining scope. An unsupported or out-of-vocabulary output fails validation; an empty facts array is valid. There is no manual accept/reject step.

Open the returned KCV_D_… graph in Graph Studio and inspect the concept links and their reified statements, source evidence and qualification. These are **model-proposed relationships in a separate graph**, not accepted claims and not silently added to active relevance retrieval. Matching a quote is structural support, not a proof that the predicate is semantically correct. Discuss whether a relationship is useful and faithful to the source; this is learning/evaluation rather than a publication gate.

## Visual graph exercise and optional OWL inference

Follow [graph exploration](../docs/graph-exploration.md) for Graph Studio and native path queries. For a meaningful inference contrast, use a fresh CTX01 scenario and run [10_owl_inference.sql](../sql/scenarios/10_owl_inference.sql) with Run Statement, supplying KCV_SESSION_ID. Expected: zero FocusedContext memberships before inference and at least one afterwards. This class means only “a context with a topic link”; it does not infer a clear objective, business suitability or value. The script is an explicit native database exercise, pending target validation.

## Use the same scenarios in APEX

Follow the [UI walkthrough](../docs/ui-walkthrough.md) for a learner-facing sequence with exact control labels, copyable questions and expected outcomes at each step.

Install the [chatbot](../apex/README.md), select a learner and start a new conversation. Ask the scenario questions, inspect the graph and source cards, use Preview refinement / Apply this refinement, and capture what you learn. APEX starts its own scenario session; a Worksheet session ID cannot be reused across that authentication/session boundary.

Finish by recording which scenario passed, model/profile/region used, source and context revisions, any guardrail failures, and which questions remain unanswered. Keep real customer data out of this public-sample lab.
