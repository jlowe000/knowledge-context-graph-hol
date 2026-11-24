# Install the original-style scenario extension

**Version scope:** use this raw-script sequence only from a published v1 checkout (`release` or `v1.0.0`). The current dev package sources depend on additional My Contexts objects and must be installed through the [migration guide](database-migrations.md), followed by the [v2 APEX deployment sequence](../apex/README.md#deploy-the-v2-dev-candidate). Do not rerun this sequence against a migration-managed schema.

**This starts after base installation.** For a new database or a first ADB deployment, follow the [beginner route](fresh-serverless-deployment.md); it installs this extension at the appropriate point. For an existing explorer installation, use [the upgrade guide](epics-upgrade.md).

Target: ADB Serverless 26ai with the initial dataset loaded, Java/RDF available, KCV_GENAI working, and Database Actions enabled for KCV_LAB. The existing user/grants/profile setup is retained. The local test container is not the minimum full-HOL runtime.

Run [00_readiness.sql](../sql/extensions/00_readiness.sql) as KCV_LAB. Confirm ACTIVE_GRAPH and AI_PROFILE settings, valid initial tools, and the APEX version if installing the UI. Record the profile's actual model/region. The working model name reported in this session was `openai.gpt-6.1-terra`; this is a user-observed result, not a promise of availability for every tenancy or region.

## One-time extension setup

Run each file as KCV_LAB using **Run Script (F5)**, inspect errors and stop at the first failure:

| Order | Script | Purpose |
| --- | --- | --- |
| 1 | [01_scenario_objects.sql](../sql/extensions/01_scenario_objects.sql) | Isolated scenario sessions, immutable revisions, proposed changes, audit, chat turns and observations |
| 2 | [06_response_provenance.sql](../sql/extensions/06_response_provenance.sql) | Additive response-run and actual tool-output capture tables/API |
| 3 | [02_scenario_api.sql](../sql/extensions/02_scenario_api.sql) | Public graph evidence, explicit context revisions and guarded apply API |
| 4 | [03_scenario_agents.sql](../sql/extensions/03_scenario_agents.sql) | New KCV_EXPLORER_TEAM: question worker, change planner and coordinator |
| Optional | [04_domain_extraction.sql](../sql/extensions/04_domain_extraction.sql) | Original-style concept relationship extraction into a separate proposed graph |
| APEX | [05_apex_api.sql](../sql/extensions/05_apex_api.sql) | Authenticated AJAX adapter for the chatbot |

These are initial object creation scripts, not blanket rerunnable migrations. CREATE OR REPLACE package/function bodies can be reapplied to fix implementation errors, but do not rerun CREATE TABLE or agent registrations over an already installed extension. Do not drop the existing KCV_TEAM to install the new one. A model-backed change planner suggests an operation only; it cannot call the apply API.

Check compilation:

```sql
SELECT name,type,line,text FROM user_errors
WHERE name IN ('KCV_TRACE','KCV_SCENARIO','KCV_APEX','KCV_EXTRACT_DOMAIN','KCV_SCENARIO_EVIDENCE','KCV_SCENARIO_PROPOSE')
ORDER BY name,sequence;
```

No rows means no recorded compile errors for those objects. It is not a native graph/model execution test. Run [the scenarios](../labs/07_original_workshop_scenarios.md) next; start with CTX01 and inspect evidence before invoking the model.

## Optional Graph Studio access

If the Graph Studio card is unavailable to KCV_LAB, ADMIN can grant its specific role:

```sql
GRANT GRAPH_DEVELOPER TO KCV_LAB;
```

This is optional UI access, separate from the package grants used by Worksheet. Oracle lists the [role required for Database Actions tools](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/connect-database-actions.html). Follow the managed service's account setup if its Graph Studio login requires further configuration; do not use DBA grants as a substitute.

## Runtime behaviour and boundaries

- KCV_G_… is the immutable base snapshot. New context revisions get KCV_O_… overlay graphs; source passages and the base graph are never edited by the scenario API.
- Each scenario pins a base graph. Reloading another base snapshot does not silently change an existing scenario; start a new scenario to use it.
- Applied refinements create a new registered conversation, so earlier model assumptions do not override the new stored context. Prior turns remain in the transcript with their original revision IDs.
- Topic changes affect native graph retrieval. Objective-only edits change context but not the topic intersection. Weight values are retained but not used in the bounded alphabetical ordering.
- The apply API validates the signed-in owner and, for APEX, the application and session. Expiring, one-use change tokens are bound to the expected context revision. A per-session mutation lease survives RDF API commits. Failed graph operations may leave an unreferenced, lab-owned graph to inspect; no automated purge runs.
- The published APEX export is produced by APEX 26.1.5. Select KCV_LAB as its parsing schema on import. No provider credentials go into browser code or APEX application files.

## What has been tested

See [extension validation](scenario-validation.md) for exact checks and limits. Local package compilation and component tests use a separate KCV_HOL_TEST schema and explicitly mocked native/model services. Never install anything under `integration-test/mocks/` into KCV_LAB. Full native RDF/GenAI scenario acceptance is a separate Serverless task; no pass is implied by a local mock test.

For an already-installed extension, use the [two-epic upgrade sequence](epics-upgrade.md); do not rerun initial table or agent creation.
