# Understand the Knowledge Collection as a Developer

## Introduction

Follow one question through the supplied knowledge collection. Inspect its data and graph, call its scenario API and connect those results to the application's evidence explanation. This is a developer learning experience using the existing example; building a different implementation is the dev-branch journey.

Estimated Lab Time: 45–60 minutes plus model response time; planning estimate.

### Objectives

In this lab, you will:

- Distinguish source identity, version, editorial summary, learner context and observed value.
- Explain the SPARQL relationship pattern and the agent's evidence tool.
- Exercise the supplied scenario API and a guarded refinement.
- Explain APEXlang's role in preparing the supplied SQL deployment.

### Prerequisites

A working sample deployment, private KCV_LAB SQL Worksheet access to your own lab, and the release files. Use the [deployment route](../../docs/fresh-serverless-deployment.md) if an environment has not been supplied. OCI Console access is not needed to use an existing configured deployment. Calls to the model can incur inference charges. No Python/build environment is required.

## Task 1: Follow a source into the collection

1. Open [public-sources.json](../../data/public-sources.json) and locate S02. Identify its public PDF, source-version ID, edition hash, selected pages and editorial topic tags.

2. Open [release-summaries.json](../../data/release-summaries.json) and locate a summary for that source. Compare its own ID/text hash and original page locator. A PDF hash identifies an edition; a summary hash identifies the editorial text supplied to the agent.

3. Open [contexts.json](../../data/contexts.json). Compare Alex and Casey: topics, objective clarity, question and constraints differ. Read the [ontology](../../ontology/kcv.ttl) and [architecture](../../docs/architecture.md) to connect those records to content, versions, evidence and context relationships.

**Expected outcome:** you can trace an attributed summary back to a public source page and explain why a source-topic connection and observed business value are different concepts.

## Task 2: Inspect native graph retrieval through the SQL API

**Where:** Database Actions SQL Worksheet. **Account:** KCV_LAB.

1. Run `SELECT USER FROM dual;` and confirm KCV_LAB. Open a new scenario using **Run Statement** on the following block without a slash. Supply `CTX01` for KCV_CONTEXT_ID. Display DBMS Output if necessary and retain the returned scenario session ID.

```sql
<copy>
BEGIN
  DBMS_OUTPUT.PUT_LINE(kcv_scenario.open_session(:KCV_CONTEXT_ID));
END;
</copy>
```

[Retained SQL script](../../sql/scenarios/01_start.sql)

2. Run each statement below separately using Run Statement. Supply that returned ID for KCV_SESSION_ID. This ID differs from the underlying agent conversation ID. Create your own Worksheet scenario; do not copy an APEX user's session identifier into SQL.

```sql
<copy>
SELECT kcv_scenario.state(:KCV_SESSION_ID) AS scenario_state FROM dual
</copy>
```

```sql
<copy>
SELECT kcv_scenario.evidence_packet(JSON_OBJECT('scenario_session' VALUE :KCV_SESSION_ID)) AS evidence_and_paths FROM dual
</copy>
```

[Retained SQL script](../../sql/scenarios/02_inspect.sql)

3. Read the returned context, base/overlay graph identities, graph_paths and evidence. Then read the SPARQL in [02_scenario_api.sql](../../sql/extensions/02_scenario_api.sql). It connects context → topic ← content → version → evidence. `SEM_MATCH` exposes those graph bindings as SQL rows; PL/SQL retrieves the matching text/metadata and returns bounded JSON.

**Expected outcome:** you can explain why the initial S02/S03/S06 evidence is eligible and why the packet has at most six pages/two per source. These read operations make no model request. Weights stored in context do not drive this retrieval's ordering.

## Task 3: Ask a question and inspect the tool boundary

1. Run the block below with Run Statement. Use your scenario ID and a question such as: Which supplied sources could help Alex find existing project information, and what do they not establish? **This invokes the real model.**

```sql
<copy>
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.ask(:KCV_SESSION_ID,:KCV_QUESTION,'question');
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
</copy>
```

[Retained SQL script](../../sql/scenarios/03_ask.sql)

2. Inspect its evidence IDs and limitations. Compare them with the packet from Task 2. Read the registered tools/tasks in [03_scenario_agents.sql](../../sql/extensions/03_scenario_agents.sql) and the captured-run API in [06_response_provenance.sql](../../sql/extensions/06_response_provenance.sql).

3. Follow the [application experience](../explore-evidence/explore-evidence.md) in a separate app conversation and open How was this answer built? Connect its Sources and Answer lineage nodes to those same backend concepts. Worksheet and APEX conversations have separate ownership/session boundaries; the UI does not open your Worksheet conversation.

**Expected outcome:** you can distinguish a question, application-defined SPARQL tool call, actual evidence payload, generated answer and matched citation. The model calls the supplied tool; it does not generate arbitrary graph SQL in this flow. Matching a citation does not establish factual correctness.

## Task 4: Exercise a guarded context change

1. Return to your Worksheet scenario. Run the preview block with KCV_CHANGE_JSON set to `{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}`. Inspect the returned plan and retain its pending_change token. The preview alone must not change the active context.

```sql
<copy>
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.stage_change(:KCV_SESSION_ID,:KCV_CHANGE_JSON);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
</copy>
```

[Retained SQL script](../../sql/scenarios/04_preview_change.sql)

2. Only after reviewing the proposed operation, apply it with your scenario ID and that token using Run Statement:

```sql
<copy>
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.apply_change(:KCV_SESSION_ID,:KCV_PENDING_CHANGE);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
</copy>
```

[Retained SQL script](../../sql/scenarios/05_apply_change.sql)

3. Repeat the two read statements in Task 2. Compare revisions and evidence: S06 should leave and S08 enter the bounded selection. The source knowledge stays unchanged. If you ask the model again, that is another inference request. In the app's separate conversation, compare an earlier answer's saved explanation after refinement/reload.

**Expected outcome:** you can explain which context data changed, why the selection changed and why historical evidence remains useful. An objective-only refinement can change the stored objective while leaving topic-based selection unchanged.

## Task 5: Connect deployment artifacts to the running experience

1. Read [APEX deployment notes](../../apex/README.md) and the [architecture](../../docs/architecture.md). APEXlang (`.apx`) defines the application during authoring. The supplied APEX-generated SQL export and Worksheet installer deploy that prepared app. You do not need SQLcl or APEXlang authoring tools to install this release.

2. Identify the responsibilities: APEX handles the signed-in experience; SQL/PLSQL owns the API and data; SPARQL supplies graph bindings; the registered agents interpret bounded evidence; the response trace records observable inputs/tool returns.

3. Decide your next step. Use the sample to explore another question, inspect the optional SQL exercises in the [catalogue](../../docs/sql-catalogue.md), or select dev and follow `docs/build-your-own.md` to replace the collection/model or change application behaviour.

**Expected outcome:** you can explain and use this example as a developer, and distinguish that learning outcome from building and validating your own adaptation.

## Learn More

- [Learning paths](../../docs/learning-paths.md)
- [Dataset semantics](../../docs/release-dataset.md)
- [Validation status](../../docs/scenario-validation.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
