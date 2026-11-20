# Lab 5 — Same collection, different context

This is the main next exercise after graph loading and verification. Claim extraction and approval are an optional extension, not prerequisites. Use the existing source/passages graph unchanged.

## What you are testing

Given explicit learner context, identify relevant public content, explain why it connects, and retain source limitations. CTX01 represents an exploratory engineering learner; CTX03 represents a healthcare learner asking about availability. These are fictional examples, not real customer profiles. Success means a response grounded in the supplied context and cited passages; it does not establish measured business value.

Start by inspecting what the tools return, as KCV_LAB in Worksheet (no model call):

```sql
SELECT kcv_context_packet('{"context_id":"CTX01"}') AS learner_context FROM dual;
SELECT kcv_evidence_packet('{"context_id":"CTX03"}') AS evidence FROM dual;
```

## Start with a transparent baseline

```bash
.venv/bin/python -m kcv.cli packet --context CTX01
.venv/bin/python -m kcv.cli packet --context CTX03
```

Each command writes the current bounded evidence packet to `work/retrieval-packet.json`. Inspect or save the first before generating the second. Topic preferences are explicit supplied context, not inferred personal interests. The packet includes at most two distinct pages per source, six passages overall; limited retrieval is not a complete source review.

## Add the native agent team

In **KCV_LAB SQL Worksheet**, run `sql/schema/04_agents.sql` once. Then run the individual statements in `sql/queries/04_run_agents.sql` to clarify CTX01 and assess CTX03. Each statement calls the configured model. You can adapt the request JSON to route `analyse_source` with `source_id` S03. The Python agent CLI is optional automation, not a required connection path.

**Copyable agent calls (KCV_LAB Worksheet; run each intended statement individually):**

First create a database conversation as KCV_LAB and copy its returned ID:

<!-- include-sql: sql/queries/00_create_conversation.sql -->

```sql
SELECT DBMS_CLOUD_AI.CREATE_CONVERSATION(
  attributes=>'{"title":"Knowledge context lab","retention_days":7}') AS conversation_id
FROM dual
/
```

[Script: 00_create_conversation.sql](../sql/queries/00_create_conversation.sql)

<!-- /include-sql -->

Each call below supplies `params.conversation_id` explicitly using a bind. Select one SELECT through FROM dual (exclude `/`) and use **Run Statement**, then paste the returned ID into the KCV_CONVERSATION_ID bind dialog. Do not invent a name or generate your own UUID: use the ID returned by CREATE_CONVERSATION. Create another conversation for an independent case; retain the existing ID only when intentionally continuing it. No SET_TEAM call or persistent Worksheet session is required. This avoids missing-conversation `ORA-20053` and invalid-ID `ORA-20050`; it is unrelated to human claim approval.

<!-- include-sql: sql/queries/04_run_agents.sql -->

```sql
SELECT DBMS_CLOUD_AI_AGENT.RUN_TEAM(team_name=>'KCV_TEAM',
  user_prompt=>'{"task":"clarify_context","context_id":"CTX01"}',
  params=>JSON_OBJECT('conversation_id' VALUE :KCV_CONVERSATION_ID)) AS agent_response FROM dual
/
SELECT DBMS_CLOUD_AI_AGENT.RUN_TEAM(team_name=>'KCV_TEAM',
  user_prompt=>'{"task":"assess_context","context_id":"CTX03","question":"What does this material establish about regional availability?"}',
  params=>JSON_OBJECT('conversation_id' VALUE :KCV_CONVERSATION_ID)) AS agent_response FROM dual
/
```

[Script: 04_run_agents.sql](../sql/queries/04_run_agents.sql)

<!-- /include-sql -->

One coordinator routes each request to one of three workers. The source worker reads a bounded public-source packet. The context worker reads the supplied learner context. The relevance worker reads the evidence returned through native RDF paths. Tools do not accept SQL/SPARQL from model output and cannot accept claims or write graph updates.

Inspect `sql/schema/04_agents.sql` and the deterministic functions in `03_tools.sql`. Agent replies remain unreviewed proposals; inspect citations against `work/passages.json` and the original PDF. The direct `extract` command in Lab 4 is the validated candidate-ingestion path. Native source-agent text is not automatically imported as accepted data.

## Compare

### Monitor a running request

The `RUN_TEAM` SELECT returns its final result, rather than streaming a progress display. While it is pending, open a separate Worksheet/session signed in as KCV_LAB and run the following read-only queries. Do not resubmit RUN_TEAM merely to check progress; another call can start additional model work. History visibility may depend on when the service records updates; an empty view alone does not prove that no work is running.

**Recent team runs:**

<!-- include-sql: sql/queries/07_agent_progress.sql -->

```sql
SELECT team_exec_id, state, start_date, end_date
FROM user_ai_agent_team_history
WHERE team_name='KCV_TEAM'
ORDER BY start_date DESC NULLS LAST
FETCH FIRST 10 ROWS ONLY
/
```

[Script: 07_agent_progress.sql](../sql/queries/07_agent_progress.sql)

<!-- /include-sql -->

`RUNNING`/`RESUMING` indicates ongoing processing; `SUCCEEDED` means the run finished; `FAILED` requires diagnostics; `WAITING_FOR_HUMAN` means it paused for input. Human approval is disabled in the supplied tasks, so report that state rather than supplying an invented approval. Match TEAM_EXEC_ID across these queries so you do not confuse an old run with the pending one.

**Task progress and recorded results:**

<!-- include-sql: sql/queries/08_agent_task_history.sql -->

```sql
SELECT team_exec_id, agent_name, task_name, state, start_date, end_date, result
FROM user_ai_agent_task_history
WHERE team_name='KCV_TEAM'
ORDER BY start_date DESC NULLS LAST, task_order DESC
FETCH FIRST 20 ROWS ONLY
/
```

[Script: 08_agent_task_history.sql](../sql/queries/08_agent_task_history.sql)

<!-- /include-sql -->

**Tool calls and diagnostic output:**

<!-- include-sql: sql/queries/09_agent_tool_history.sql -->

```sql
SELECT team_exec_id, tool_name, start_date, end_date, output, tool_output
FROM user_ai_agent_tool_history
WHERE team_exec_id IN (SELECT team_exec_id FROM user_ai_agent_team_history WHERE team_name='KCV_TEAM')
ORDER BY start_date DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY
/
```

[Script: 09_agent_tool_history.sql](../sql/queries/09_agent_tool_history.sql)

<!-- /include-sql -->

If a history view is unavailable, report the Oracle error and database version; do not grant broad administrator privileges to work around it. Oracle documents these columns in [agent history views](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-ai-agent-views-history.html). A long-running request with no changing task/tool history needs investigation; the run state does not provide a percentage complete.

### Evaluate the response

- Does the response explain why knowledge helps this question rather than merely repeating shared tags?
- Does CTX01 retain room for exploration without a defined immediate outcome?
- Does CTX03 retain the healthcare source's geographic and future-product limitations?
- Does any proposed next action follow from the evidence? An unanswered question can be a useful result.

There is no claim that multiple agents outperform the deterministic baseline. Record examples where the extra reasoning helps, adds noise or needs correction.
