# Upgrade: response explanations and traditional workspace

Implemented 19 November 2026. Target: the existing standalone Serverless schema and APEX app, with the initial scenario extension already installed. Preserve the working profile, credential, source data and registered KCV_EXPLORER_TEAM. No new OCI service or IAM policy is required.

For the expanded research content, also follow the [non-PDF evidence migration and application-file update](content-ingestion-upgrade.md). This includes a nullable page locator and a required JavaScript replacement while the engine re-export is pending.

## Upgrade order in KCV_LAB Worksheet

Back up the existing app with APEX_EXPORT or App Builder and retain the earlier package sources before replacement. The deployment performed for this lab stores the original app export in the private-schema KCV_DEPLOY_BACKUPS table, separate from the published repo. Keep private instance URLs and export/rollback details in ignored work files.

Use **Run Script (F5)** for each file, checking errors after each:

1. [06_response_provenance.sql](../sql/extensions/06_response_provenance.sql): additive run/tool tables and KCV_TRACE API. Rerunning retains existing capture data.
2. [02_scenario_api.sql](../sql/extensions/02_scenario_api.sql): execution correlation, pinned graph evidence, durable tool capture and request/refinement lease guards.
3. [07_trace_tool_wrappers.sql](../sql/extensions/07_trace_tool_wrappers.sql): replace the two registered tools' PL/SQL wrapper functions. Their registered names and original-JSON instructions are unchanged; do not rerun CREATE_TEAM or CREATE_TOOL on the existing registrations.
4. [05_apex_api.sql](../sql/extensions/05_apex_api.sql): stable turn IDs and an authorized historical trace endpoint.

```sql
SELECT name,type,line,text FROM user_errors
WHERE name IN ('KCV_TRACE','KCV_SCENARIO','KCV_SCENARIO_EVIDENCE','KCV_SCENARIO_PROPOSE','KCV_APEX')
ORDER BY name,sequence;
```

No rows means these objects compiled; a real tool/model/browser test is still required. For a fresh installation, create the scenario objects first, then the provenance migration, then the scenario API, initial agent registrations and APEX API. The numeric filenames are not the full dependency order.

## Import the UI

Regenerate source with `python scripts/build_apex.py`; it writes the HTML region and application static-file assets. In an isolated compatible APEX workspace, validate/import the APEXlang app and export the engine-generated SQL. Use [the installation guide](../apex/README.md) for the import and schema mapping. For an upgrade, explicitly select this lab's existing application ID after verifying its alias/workspace/schema; never overwrite an unrelated app. The Worksheet builder defaults to a new app ID to prevent accidental replacement; the task-specific deployment script pins the verified ID privately.

The app uses Universal Theme 26.1 with **Iris**. The content inherits APEX theme variables with scoped fallback colors. A theme change applies to the native shell and supported theme values; custom graph behavior remains application code. CSS and JS are packaged as APEX application static files so the HTML region remains below APEXlang's string-size limit. Their page URLs include content hashes to invalidate stale browser copies after updates. New imports may expire the app login.

## What is retained for an answer

KCV_RESPONSE_RUNS pairs question/answer turn IDs with the pinned revision, conversation, context, source metadata, prior application turn IDs, profile label, timestamps and status. KCV_RESPONSE_TOOL_CALLS stores each actual correlated evidence/proposal call and exact JSON output before it returns to the agent framework. The current-page graph query does not generate trace events. Full credentials and provider prompts are not captured.

Capture is bounded to one million characters per tool result; exceeding the bound fails explicitly rather than silently truncating the trace. Repeated tool calls are retained. Successful model returns without recorded tools are marked INCOMPLETE. Failed model calls retain a FAILED run and release their execution lease; they do not create a fabricated assistant answer. They can be inspected in Worksheet even though there is no failed-run dashboard in the UI.

Historical turns from before this feature show a legacy notice. They are not backfilled with today's evidence. The UI returns the most recent 20 turns; older run records remain in the database but a cross-login history browser is outside this feature.

## Interrupted execution recovery

ASK and APPLY share the scenario's mutation lease. Normal completion/error clears its own lease. A killed process can leave a RUNNING execution and lease. An administrator must first check actual agent/database activity, then mark that specific abandoned run failed and clear only its matching execution token. Do not clear every lease by age while a model request may still be running. There is no automatic recovery job. Use an explicit reviewed Worksheet operation for the identified run.

## Validation and rollback

Follow [the UI walkthrough](ui-walkthrough.md), then open a new answer's explanation, inspect source nodes and actual passages, and inspect Answer lineage. Refine Graph capabilities away, ask again and reopen the first answer: its old paths/evidence must remain unchanged. Check the current-context Evidence view separately. Opening/reopening a popup makes no model call and does not mutate context or draft text.

The isolated [provenance component suite](../integration-test/verify_response_trace.sql) covers paired capture, historical immutability, matched/unknown citations, repeated and absent tools, model failure, lease guards, proposals, legacy turns and APEX session isolation. It uses explicit mocks; real Serverless tool correlation is a separate acceptance check.

Rollback restores the prior app export and prior KCV_SCENARIO, tool wrappers and KCV_APEX sources. Retain provenance tables for inspection/export; their presence does not modify curated graphs. Remove them only through an explicit ownership/dependency review after any desired records have been exported. Application deletion/import does not remove run records, source graphs or model credentials.


## Deployment acceptance completed

The live KCV_USER session passed the original/refined answer flow, source and lineage node inspection, persisted historical evidence after reload, draft/Escape handling, observation save and keyboard tab navigation. Narrow-screen checks observed 360 CSS pixels without page or popup horizontal overflow. The full application export includes the final responsive and asset-versioning corrections. Optional extraction/OWL exercises and a formal accessibility audit remain separate from these epics.

Citation metadata is derived from explicit citation arrays throughout structured answer JSON, including fenced responses with leading whitespace. Unknown IDs remain flagged. If parsing is unavailable, lineage displays Matching unavailable / Not determined rather than a misleading zero count. The saved raw answer and tool output remain unchanged.
