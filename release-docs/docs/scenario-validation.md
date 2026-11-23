# Release validation status

## Existing application evidence

The dev original-passage version was fully torn down (retaining JAVAVM), rebuilt on the temporary ADB Serverless instance and browser-tested through 23 November with APEX 26.1.6. Real model answers, native graph paths, context refinement, saved observations, per-response Sources/Answer lineage, historical persistence after reload and narrow-screen interaction were exercised. The native OWL before/after exercise also passed. These are supporting implementation results; they do not replace acceptance of the release summary dataset. Detailed records remain on dev.

## Summary release

This distribution uses attributed editorial summaries with distinct IDs/hashes, including selected passages from the expanded research. It includes a prebuilt dataset loader and Worksheet APEX installer. Build checks verify the publication allowlist, relative documentation links, generated SQL, graph/source/context integrity, native-query selection against RDFLib and manifest hashes. These are local checks, not a native Oracle database or inference pass.

## Required native acceptance before a validated release tag

1. Follow the beginner route on a fresh approved ADB Serverless database using only release files.
2. As KCV_LAB run [verify_worksheet.sql](../integration-test/verify_worksheet.sql) and [verify_scenario_native.sql](../integration-test/verify_scenario_native.sql). Inspect PASS and USER_ERRORS. These native checks make no model inference request.
3. Deploy the supplied installer, sign in as KCV_USER and complete Alex's question, Sources and Answer lineage inspection, topic removal, another question and observation save. Check summary labels and IDs; answers must preserve roadmap/availability limits.
4. Reload and verify the historical answer retains its original evidence while the new answer uses the refined context. Check Casey retains both overview and regional disclaimer pages. Record actual versions and observed results.
5. Capture the remaining platform screenshots and have a first-time ADB learner complete the documented path. Review accessibility and a second user's isolation on the target separately.

No new cloud database or model call is implied by packaging this release. The optional OWL/extraction exercises are not part of the main acceptance result.


## Acceptance of the learning experiences

The app-user route assumes a facilitator-provided URL/login and does not require deployment work. The developer-learning route follows the data/model, SPARQL evidence tool, supplied scenario API and APEX deployment artifacts. These new learning-path documents have packaging/link checks; they still need a first-time reader walkthrough against the release summary dataset. The build-your-own adaptation journey is documented separately on dev.

## Public catalogue expansion — 23 November 2026

Anonymous source checks and the explicit [public-source classification rules](../references/public-source-policy.json) govern the distributable corpus. The graph includes references admitted by verification or manual public classification. Readable added research supplies locally extracted passages on dev and selected attributed editorial summaries on release; items without supplied text remain discovery nodes. S05 and S07 are retained following explicit user review of their public event editions and template footers. Detailed source conflicts remain outside the public repository. The [catalogue guide](public-research-catalog.md) explains the evidence boundary and includes SQL/SPARQL queries.

Local tests cover catalogue node/URL/version integrity, absence of fabricated passages, original Alex source priority and retention of Casey's S10 qualifications alongside additional matches, prepared SQL, public-reference scans and release manifest hashes. The chatbot API limits its topic selector and source list to versions with passages. The expanded summary dataset later passed the native GitHub acceptance below; model and browser acceptance for this dataset remain pending. The earlier model/browser results describe the earlier sample only.

The expanded Worksheet loader uses bounded PL/SQL batches, progress messages and guarded graph activation. Local generation/parsing checks do not establish native compilation or completion in Database Actions; include that check in acceptance. The engine-produced app export requires the documented explorer.js static-file update for non-PDF locators.

Manual public classification does not turn a failed access test into a success. Catalogue-only references with unverified access retain their error, decision rule and a clearly labelled metadata hash; they do not supply chatbot evidence. Conflict decisions and the separate `to_be_reviewed` array stay outside the Git repositories.


## Content pipeline acceptance — 23 November 2026

All 825 added references were attempted. Dev contains 17,099 passages in total; release contains 762 attributed summaries across 754 sources. The other 80 release references remain catalogue only. The full 49-test suite passed, followed by three new Worksheet-part tests and a repeat of release validation: 52 distinct local tests passed. The six release SQL parts are each below 2 MB and reproduce the complete loader's SQL units exactly. Source hashes, actual locators, graph-scoped retrieval eligibility and publication separation are checked locally.

See the [content-build validation record](../references/content-pipeline-validation.json) and [ingestion coverage](../references/content-ingestion-checks.json). No deployment occurred during that content build. Subsequent native GitHub loading and queries passed as recorded below; the fallback SQL batches, live model/browser acceptance for the expanded summaries and an engine re-export remain pending. Follow the documented static-file replacement after importing the existing APEX export.

## GitHub summary-dataset native acceptance — 23 November 2026

The summary package passed native SQL acceptance on the existing temporary ADB Serverless instance using published dev code/data commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`. The [sanitized run record](../references/github-dataset-validation.json) pins manifest SHA-256 `dae8efdcd9e99874c8dfc3d9a3ccaf4a861f76b3b5442f71f075a6d9b64ef8ad` and distinguishes that tested commit from later documentation-only commits.

The importer, source tools, scenario and APEX backend packages compiled without errors. The GitHub load installed 834 sources, 762 passages, three contexts and 30,144 triples in an observed 9.528 seconds. The new graph was activated and its predecessor preserved. The four supplied native scripts passed: GitHub reuse/rejection/retry, source-packet graph scope, Worksheet evidence and scenario refinement. A competing session was rejected while the importer lock was held, and the final retry after lock release succeeded with `REUSED_READY_GRAPH`. One failed run-log entry is intentional: the wrong-hash test returned `-20070` at `FETCHING_MANIFEST` without changing the active graph.

JAVAVM was VALID, DBMS_CRYPTO/DBMS_LOCK execution grants were applied, and the download needed no network ACL changes with ROUTE_OUTBOUND_CONNECTIONS unset. The database reported version 23.26.4.1.0 and APEX 26.1.6. Version inspection is not a UI test. No GenAI inference or browser flow was run with this expanded summary dataset. Interrupted loading, fallback SQL batches, the fresh learner deployment and execution from a promoted release commit remain untested in this acceptance. This result does not itself promote or push release.
