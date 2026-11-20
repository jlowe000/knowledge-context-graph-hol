# Implementation status

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
| Optional OWL2RL inference | Implemented as an explicit native command; not run |
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

The release uses the approved 17 attributed editorial summaries of nine public presentations, with separate summary IDs/hashes and original page links. It includes prebuilt dataset/APEX Worksheet installers, eight learner lab pages and native SQL verification, without Python/shell tooling, local mocks or original PDF extracts. Local tests verify package completeness, file hashes, provenance boundaries, source/page graph bindings and the documented S06-to-S08 refinement selection. Twenty-one Python checks pass on dev. New summary data and the updated agent instruction still require native Serverless/model/browser acceptance; this work did not redeploy the existing cloud app.

Local branches/commits do not set GitHub's default branch or enforce remote protection. No remote or push is part of this change.
