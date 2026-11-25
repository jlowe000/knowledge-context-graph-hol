# Load Knowledge and Register Conversations

## Introduction

Load the attributed public summaries and register the prepared conversation services. The complete v2 static schema was installed in the previous lab; this lab does not create those tables/packages again.

Estimated Lab Time: 10–20 minutes plus download/graph preparation time; planning estimate.

### Objectives

- Load a pinned public dataset from GitHub and inspect its graph.
- Register the configured scenario agents once on a clean installation.
- Verify native evidence selection before using the app.

### Prerequisites

[Database configuration](../configure-database/configure-database.md) completed: R7 schema verified, owner-private RDF network, working KCV_GENAI profile and registered AI_PROFILE setting. Use the actual owner Worksheet, normally KCV_LAB.

## Task 1: Load the public dataset

1. Follow [Choose a published version](../../docs/github-dataset-load.md#choose-a-published-version). Use a full commit SHA containing the dataset and the matching manifest hash. A local release build is not a published GitHub object. The package preparer may identify an earlier immutable published dataset commit when its bytes are unchanged; do not select a different dataset yourself to bypass a failed hash.
2. Open [10_load_github.sql](../../sql/install/10_load_github.sql), replace only the commit placeholder using that documented version and run the whole call with F5. The download is anonymous; no GitHub token is needed.
3. Wait for success. Use the progress query in the load guide if necessary; a slow browser is not permission to start another load.
4. Run [01_inspect.sql](../../sql/queries/01_inspect.sql), [verify_worksheet.sql](../../integration-test/verify_worksheet.sql) and [verify_source_packet_scope.sql](../../integration-test/verify_source_packet_scope.sql), each separately with F5. The last test rolls back its own synthetic out-of-graph passage.

**Expected outcome:** SUCCEEDED, a ready ACTIVE_GRAPH and the supplied summary corpus: 834 source references, 762 passages, three fictional contexts and 30,144 triples for this dataset edition. Verify the package's manifest rather than treating these as universal counts. The loader imports no personal contexts, app accounts or conversations. A matched summary has its own text hash and links to the original public material.

If GitHub is unavailable, use the [SQL fallback](../../docs/github-dataset-load.md#sql-fallback). Choose one loading method; never run them concurrently. A migration can retain its existing public dataset and skip loading entirely.

## Task 2: Register conversation services

On a **clean** configured schema, run [03_scenario_agents.sql](../../sql/extensions/03_scenario_agents.sql) with F5 once. The script registers the prepared teams/tasks/tools using the existing profile. Do not rerun raw scenario-object, provenance or application-package creation scripts; the ordered schema installer already installed them.

**Expected outcome:** registration completes. The application retrieves evidence before `KCV_GROUNDED_TEAM` generates an answer. Proposal handling retains the separate explorer team. An existing team is a reason to inspect an earlier run, not drop it. Existing installations use [migration](../../docs/migrate-to-v2.md) and the scoped registration refresh instead.

## Task 3: Verify the scenario

Run the complete block in [verify_scenario_native.sql](../../integration-test/verify_scenario_native.sql) with Run Statement, excluding its slash, and supply the actual owner as KCV_SCHEMA. Review the explicit PASS output and any Oracle errors. This checks the supplied sample's graph/refinement behavior; it does not establish a successful chat answer. No inference is needed for these native read/refinement checks.

Optionally run [verify_github_dataset.sql](../../integration-test/verify_github_dataset.sql) for maintainer acceptance. It performs public downloads and intentionally records wrong-hash/retry cases; do not confuse that expected failed run with an unexplained failure.

**Expected outcome:** native evidence and source-scope checks pass with historical graph data preserved. Complete [local search setup](../../docs/context-search.md#worksheet-setup) if semantic library search is wanted, then continue to [deploy the app](../deploy-explorer/deploy-explorer.md).

## Learn More

- [Dataset semantics](../../docs/release-dataset.md)
- [SQL catalogue](../../docs/sql-catalogue.md)
- [Validation status](../../docs/scenario-validation.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
