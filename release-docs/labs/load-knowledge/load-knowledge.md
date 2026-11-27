# Inspect the Loaded Knowledge and Conversation Services

## Introduction

Normal setup loads attributed public summaries and registers conversation services through the app's **Deployment setup** after app import and owner binding. This lab explains inspection and separately chosen owner-SQL alternatives. It does not repeat a successful app load or create the static tables/packages again.

Estimated Lab Time: 10–20 minutes plus download/graph preparation time; planning estimate.

### Objectives

- Load a pinned public dataset from GitHub and inspect its graph.
- Register the configured scenario agents once on a clean installation.
- Prepare native scenario verification for after deployment readiness is enabled.

### Prerequisites

Complete [app deployment and guided setup](../deploy-explorer/deploy-explorer.md) first for the normal path. Expect the verified static schema, owner-private RDF network, configured KCV_GENAI profile, registered components and READY collection. Use the actual owner Worksheet for inspections. The alternative SQL load requires the network, and SQL registration requires the configured profile; neither should run before its dependency exists.

## Task 1: Inspect the public dataset

If **Load approved public collection** already succeeded in Deployment setup, skip the loader in steps 1–3 below and perform step 4's inspections only. Check readiness and the active collection. Do not repeat a public download to follow this lab mechanically.

The following loader steps are a **headless/diagnostic alternative**, not prerequisites to app import:

1. Follow [Choose a published version](../../docs/github-dataset-load.md#choose-a-published-version). Use a full commit SHA containing the dataset and the matching manifest hash. A local release build is not a published GitHub object. The package preparer may identify an earlier immutable published dataset commit when its bytes are unchanged; do not select a different dataset yourself to bypass a failed hash.
2. Open [10_load_github.sql](../../sql/install/10_load_github.sql), replace only the commit placeholder using that documented version and run the whole call with F5. The download is anonymous; no GitHub token is needed.
3. Wait for success. Use the progress query in the load guide if necessary; a slow browser is not permission to start another load.
4. Run [01_inspect.sql](../../sql/queries/01_inspect.sql), [verify_worksheet.sql](../../integration-test/verify_worksheet.sql) and [verify_source_packet_scope.sql](../../integration-test/verify_source_packet_scope.sql), each separately with F5. The last test rolls back its own synthetic out-of-graph passage.

**Expected outcome:** SUCCEEDED, a ready ACTIVE_GRAPH and the supplied summary corpus: 834 source references, 762 passages, three fictional contexts and 30,144 triples for this dataset edition. Verify the package's manifest rather than treating these as universal counts. The loader imports no personal contexts, app accounts or conversations. A matched summary has its own text hash and links to the original public material.

If GitHub is unavailable, use the [SQL fallback](../../docs/github-dataset-load.md#sql-fallback). Choose one loading method; never run them concurrently. A migration can retain its existing public dataset and skip loading entirely.

## Task 2: Check conversation services

If **Prepare conversation components** already succeeded in Deployment setup, inspect that READY check and skip the standalone registration script. The app's action verifies/creates these components after the profile is ready.

For the separately chosen manual alternative:

On a **clean** configured schema, run [03_scenario_agents.sql](../../sql/extensions/03_scenario_agents.sql) with F5 once. The script registers the prepared teams/tasks/tools using the existing profile. Do not rerun raw scenario-object, provenance or application-package creation scripts; the ordered schema installer already installed them.

**Expected outcome:** registration completes. The application retrieves evidence before `KCV_GROUNDED_TEAM` generates an answer. Proposal handling retains the separate explorer team. An existing team is a reason to inspect an earlier run, not drop it. Existing installations use [migration](../../docs/migrate-to-v2.1.md) and the scoped registration refresh instead.

## Task 3: Complete deployment before scenario verification

First confirm [app import, binding and explicit learning enablement](../deploy-explorer/deploy-explorer.md) are complete. The new readiness gate also applies to scenario operations; do not try to bypass it with native tests. Afterward, run the complete block in [verify_scenario_native.sql](../../integration-test/verify_scenario_native.sql) with Run Statement, excluding its slash, and supply the actual owner as KCV_SCHEMA. Review the explicit PASS output and any Oracle errors. This checks the supplied sample's graph/refinement behavior; it does not establish a successful chat answer. No inference is needed for these native read/refinement checks.

Optionally run [verify_github_dataset.sql](../../integration-test/verify_github_dataset.sql) for maintainer acceptance. It performs public downloads and intentionally records wrong-hash/retry cases; do not confuse that expected failed run with an unexplained failure.

**Expected outcome:** collection/registration checks pass; scenario checks run after readiness is enabled. Complete [local search setup](../../docs/context-search.md#worksheet-setup) if semantic library search is wanted, then continue to [My Contexts](../my-contexts/my-contexts.md).

## Learn More

- [Dataset semantics](../../docs/release-dataset.md)
- [SQL catalogue](../../docs/sql-catalogue.md)
- [Validation status](../../docs/scenario-validation.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
