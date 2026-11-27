# Implementation status

## Current v2.1.0 package — 28 November 2026

All four curated-package routes passed on prepared ADB environments: APEX-led clean installation and populated v2.0.0 upgrade, plus SQL-first clean installation and populated v2.0.0 upgrade. The [four-route record](../db/verification/release-v2.1-paths-validation.json) pins the tested artifacts and preserves the exact scopes. Results include learner answers/evidence, stored-history reopening, bounded reviewer checks and protected-build comparisons. SQL-first clean used Worksheet for schema/app installation and genuine-owner SQLcl for its successful model test and enablement. Combined schema-file transport, new-database provisioning and first Java enablement/restart remain outside these passes.

The maintained contract contains 121 project migrations ending at `2.1.0-apl-r4-ready`; the application has 11 pages and 16 maintained assets. Local dev/release commits are authorised; remote publication is separate. The published v2.0.0 tag and earlier validation records retain their historical scope. Four release-route passes do not constitute a new direct DEV-led Liquibase rehearsal.

Start with [development setup](development.md), [database migrations](database-migrations.md) and [APEXlang authoring](apexlang-development.md). Use the [packaging plan](apex-led-release-packaging-plan.md) for the accepted distribution and the [build lifecycle](dev-build-lifecycle.md) for exact-target preservation, replacement and retirement. The learning loop and Explorer evaluation remain separate future epics.

## Historical v2 development checkpoint — 25 November 2026

The following section records the pre-publication state at that checkpoint. Its release-state statements and then-pending checks are historical, not the current status above.

The SQL-first v2 release candidate passed separate clean-installation and published-v1 migration rehearsals recorded in the [release-path record](../db/verification/release-v2-paths-validation.json). The tests used isolated schemas in an existing temporary Serverless database, parameterized ADMIN setup, ordered Worksheet schema parts and an APEX upgrade retaining the existing app ID. Both browser journeys and fresh-sign-in reopening passed. Candidate02 supplied the tested runtime; its bind-bearing APEX installer instruction was corrected to Run Statement without changing the import body. The corrected package instructions do not represent another deployment; v2 remains unpromoted. Private runtime is excluded; migration retained the public collection and stored credential/profile. The browser tests used one account per route and did not establish two-account browser isolation or permanent-delete confirmation. Learning-loop and Explorer-evaluation work stays separate.

R7 adds local semantic/text search over owned saved contexts and a saved-objective preview. Its [validation record](../db/verification/context-search-validation.json) reports 96 COMPLETE project receipts / 97 Liquibase changesets, zero invalid objects, an independent no-change repeat, native search regressions and a nine-page APEX import. Browser semantic/title matches, status filtering and clearing the query passed; all 27 captured preexisting runtime table count/hash assertions remained unchanged within the recorded exclusions. The R6 long-multibyte-token failure remains recorded and is corrected by the appended R7 body. That historical R7 record predates the separate SQL Worksheet fresh/migration rehearsal; use the release-path record for the newer route acceptance. The separate [R5 deletion record](../db/verification/context-delete-validation.json) retains successful native tests and browser review/Cancel, with permanent-delete confirmation still pending.

The preceding v2.0.0 R4 My Contexts candidate passed a separate [fresh deployment](../db/verification/fresh-dev-validation.json): 80 COMPLETE project receipts / 81 Liquibase changesets, zero invalid objects, an unchanged-receipt repeat, public dataset loading, native APEX checks and three strict model requests including provider expiry. The authenticated personal/sample browser journeys also passed, with three actual UI questions and preserved historical evidence. That engine export/receipt included the local **Sample Contexts** label and navigation fixes.

All 58 recorded assertions for the existing installations remained unchanged after browser testing; the app reimport also preserved 25 captured fresh-runtime hashes. These are scoped checks, not a whole-database audit. The historical [R4 verification](../db/verification/c3-r4-validation.json) and [journey record](../references/my-contexts-c3-validation.json) retain the earlier browser expiry pass and separate malformed-JSON native failure. The historical R4 receipt did not cover the current Worksheet distribution. The later release-path record covers its isolated-schema installation and migration tests; provisioning a new ADB instance is not established by those rehearsals. Release is unchanged.

Start current dev work with [development setup](development.md), [database migrations](database-migrations.md) and [APEXlang authoring](apexlang-development.md). Test the experience with the [My Contexts manual review](my-contexts-manual-test.md). The published release remains v1; the learning loop and Explorer evaluation remain separate future epics. Dataset counts are recorded in [build-report.json](../generated/build-report.json) and the distributed dataset manifest, which describe different preparation modes.

## Historical milestones

The dated sections below preserve the state observed at each earlier milestone. Their pending checks, commands and publication statements are not the current dev setup or acceptance status. Use the matching v1 tag/release for the legacy SQL-first instructions.

18 November 2026. The folder is an independent local Git repository on branch main. No remote has been configured and no publication has occurred.

| Plan area | State |
| --- | --- |
| Standalone project, public-only inputs, upstream notice | Implemented |
| F1 example removed from ingestion | Implemented; upstream recorded only as implementation reference |
| Replace ambiguous notes with actual passages and separate review examples | Implemented |
| Oracle Linux/Bash artifact generation | Executed and verified |
| Taxonomy, ontology, RDF and context baseline artifacts | Generated; 547 triples, 3 contexts |
| Candidate validation and explicit acceptance/rejection | Optional extension; learner imported four live proposals; no acceptance implied |
| User creation, grants, Java readiness and model profile setup | Learner reports lab objects created and profile greeting successful; Java readiness directly checked earlier |
| Native graph load and bounded evidence functions | Compiled and native scenario acceptance passed on Serverless |
| Three worker agents plus routing coordinator | Learner returned context and relevance responses through RUN_TEAM; broader native validation still pending |
| Versioned native graph/context history and feedback | Native before/after topic refinement passed; observation component checks passed locally |
| Optional OWL2RL inference | Native before/after exercise passed on Serverless, 22 November; class entailment only |
| Standalone augmented HOL | Initial labs plus original-style Alex/Sam/Casey scenarios, source relationship extraction, Graph Studio and before/after OWL exercise |
| Copyable short SQL | 37 inline examples across setup, authentication, deployment and labs; generated from retained scripts and checked during artifact builds |
| OCI Generative AI authentication | User-key profile/model call reported successful by learner; resource-principal alternative documented, not exercised |
| Local checks | 17 Python checks passed; scenario/extraction/APEX callback component scripts passed in isolated Oracle schema with explicit service mocks |
| Original-style scenario extension | Versioned context overlays, actual path bindings, guarded refinement tokens, audit and validation observations implemented; native Serverless graph acceptance passed; real Casey model response checked |
| APEX chatbot | Standalone source and engine-generated SQL export; local APEX import and session/callback validation passed. Browser UI checked with fixtures; app imported to Serverless APEX 26.1.6; authenticated cloud browser flow passed start, real questions, two refinements and saved observation |
| Database Actions route | Implemented: user/grants, profile, generated dataset-load SQL, extraction, agents, feedback and inference; client DB driver is optional |
| Serverless readiness | After authorised Java enablement and user restart: JAVAVM VALID, Java 11.0.33; SEM_APIS/SEM_MATCH resolve to valid RDF_APIS/RDF_MATCH objects. Learner subsequently created lab objects. |
| Integration checks | 4 opt-in tests skipped without Serverless configuration; no pass implied |

The standalone anonymous downloader was separately exercised with a public source and exact-edition verification. Full PDFs and extracted text are kept only in ignored work files. The publishable files were scanned for private source URLs and local Markdown links were checked.

The live cloud browser flow passed, including the follow-up after refinement. Remaining optional acceptance work is relationship extraction and OWL inference. Native graph/context evolution and a real Casey model response have passed. See [original-workshop comparison and next steps](upstream-comparison.md). Successful user-reported scenarios do not establish that the whole HOL is end-to-end validated.


## Two epics deployed and validated — 19 November 2026

EPIC-01 adds actual per-response tool snapshots and historical Sources/Answer lineage popups. EPIC-02 delivers the Traditional workspace in Iris, with Conversation, Evidence, Context and Observations. Both are deployed to the temporary ADB Serverless app and exercised as KCV_USER. Two real answers, graph/source inspection, before/after refinement, historical persistence after reload, observation save, keyboard interaction and narrow-screen layout checks passed. See [release/upgrade details](epics-upgrade.md) and [validation evidence](scenario-validation.md). No publication or Git remote change was performed.


## Beginner deployment documentation — 19 November 2026

The [fresh Serverless route](fresh-serverless-deployment.md) is the primary entry point. Eight LiveLabs-style pages cover preparation, provisioning, account changes, Java, grants, user-key or resource-principal authentication, loading, deployment, evidence exploration and recovery. Short SQL stays synchronized with retained scripts. Two real application screenshots are included; platform capture requirements are tracked separately. See [authoring alignment](livelabs-authoring-alignment.md). A new empty-instance rehearsal and first-time learner walkthrough remain pending; this documentation review is not another deployment test.


## Development and learner distributions — 21 November 2026

The project is organised into `dev` (complete source, original-PDF preparation, optional tools, tests and contributor documentation) and `release` (SQL-first learner distribution). Contributor setup is in [development.md](development.md); [branch-workflow.md](branch-workflow.md) explains controlled promotion. Release documentation is maintained separately under `release-docs/` and assembled by `scripts/build_release.py` with an explicit publication allowlist.

The release uses the approved 17 attributed editorial summaries of nine public presentations, with separate summary IDs/hashes and original page links. It includes prebuilt dataset/APEX Worksheet installers, eight learner lab pages and native SQL verification, without Python/shell tooling, local mocks or original PDF extracts. Local tests verify package completeness, file hashes, provenance boundaries, source/page graph bindings and the documented S06-to-S08 refinement selection. Twenty-one Python checks pass on dev. At that stage, the summary data and updated agent instruction still required native Serverless/model/browser acceptance; that packaging work did not redeploy the cloud app. Subsequent expanded-data acceptance is recorded separately in the [23 November validation](../references/expanded-ui-validation.json).

Local branches/commits do not set GitHub's default branch or enforce remote protection. No remote or push is part of this change.


## Clean dev reset and native retest — 21–23 November 2026

The requested project teardown and clean checkpoint passed while retaining VALID JAVAVM. The dev original-passage dataset, schema, native graph, both teams and APEX app were rebuilt. Native base/scenario checks, a real model greeting, two real answer/provenance/refinement tests, historical immutability, observation save and optional OWL before/after inference passed. The app imported successfully on APEX 26.1.6; signed-in browser acceptance passed on 23 November: both explanation graphs, objective/topic preview and apply, real follow-up, preserved historical evidence after reload and observation save. See [reset workflow](dev-reset-and-retest.md) and [detailed validation](scenario-validation.md). This did not re-provision the database, re-enable Java, test the release summary dataset, publish a repository or push changes.
