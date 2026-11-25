# Knowledge, Context and Value — a standalone graph lab

Explore how the same public knowledge can help different people for different reasons. Build a page-linked evidence collection, represent it as RDF, compare explicit learner contexts, and add reviewed AI extraction and specialist agents.

This adapts only Oracle's [ontology-grounded document workshop](https://github.com/oracle-livelabs/spatial-graph/tree/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag). The original F1 lab is an implementation reference, outside our ingestion dataset. No other workshops or LiveLabs WMS metadata are included. See [attribution](NOTICE.md).

## Development branch

This is the **dev branch**, for people building their own adaptation of the knowledge collection or contributing implementation changes. Start with [Build your own version](docs/build-your-own.md), then [development environment setup](docs/development.md). It covers changing the sources, taxonomy/ontology, retrieval, tools, UI and validation—not just running build utilities.

**v2.0.0 development:** R7 combines saved-detail text and local semantic search, with objective previews. The [numbered-build deployment and retirement checks](docs/dev-build-lifecycle.md#validation-scope) and [SQL-first clean/migration rehearsals](db/verification/release-v2-paths-validation.json) passed within their recorded scope. Use the [fresh dev guide](docs/fresh-dev-deployment.md), [build lifecycle](docs/dev-build-lifecycle.md), [migration guide](docs/database-migrations.md) and [manual review](docs/my-contexts-manual-test.md). The [deletion record](db/verification/context-delete-validation.json) retains its pending permanent-delete browser confirmation. The learning loop and Explorer evaluation remain separate future epics; use each branch's own documentation for its learning/deployment experience.

The preceding [fresh deployment](db/verification/fresh-dev-validation.json) passed native/model and personal/sample browser checks, including provider-expiry continuation and scoped preservation. The [sample navigation followup](db/verification/sample-navigation-validation.json) passed separately. Those records retain their tested R4 scope; the historical [R4 record](db/verification/c3-r4-validation.json) also retains its earlier malformed-JSON native failure.

Select **release** to use the supplied app or follow its developer learning experience: understand the model, inspect SPARQL/tool evidence and exercise the existing SQL APIs. Its deployment guide is needed only when an environment has not been supplied. The branch distinction is the intended outcome, not whether you are a developer. Release experiences are maintained separately under `release-docs/`; see [branch workflow](docs/branch-workflow.md) for promotion.

## What is ready

**New to ADB? Use the `release` branch for the published SQL-first learning experience.** Its [fresh Serverless deployment walkthrough](https://github.com/jlowe000/knowledge-context-graph-hol/blob/release/docs/fresh-serverless-deployment.md) explains the accounts, screens, SQL execution controls and expected results in order. For the exact v1 baseline, check out `v1.0.0`. Current dev installation uses the migration route below; do not combine its files with the older raw-schema setup sequence.

- Nine reviewed public presentation sources, exact edition hashes and selected PDF pages.
- Three fictional learner contexts, with optional/emerging objectives.
- Executable download, page extraction, RDF/artifact generation and context-topic baseline.
- Ontology, review examples, explicit candidate validation and human acceptance/rejection.
- Serverless user/grant/schema, RDF loading and native scenario agents, exercised on the temporary database.
- Beginner deployment labs, plus [technical and optional exercises](labs/00_introduction.md).
- Deployed APEX explorer with per-response Sources and Answer lineage graphs.

**Minimum database for the full implementation: ADB Serverless 26ai with Java/RDF and Select AI configured.** The existing local container is suitable only for compatible component tests. Artifact generation does not require any database or model. All supported shell examples run in Oracle Linux/Bash.

## Generate and inspect artifacts first

Use Python 3.11+ in Oracle Linux. `KCV_PYTHON` selects the installed interpreter; the default is python3.12.

```bash
bash scripts/bootstrap.sh
bash scripts/build_artifacts.sh
```

Read [generated/dataset-preview.md](generated/dataset-preview.md), [generated/assessments.json](generated/assessments.json), [generated/build-report.json](generated/build-report.json) and [generated/knowledge.ttl](generated/knowledge.ttl). View [generated/model.svg](generated/model.svg).

The initial graph has **zero accepted extracted claims**. Its content metadata, real passage locators, editorial review examples and proposed baseline assessments are intentionally distinct. Actual PDF text is in ignored `work/passages.json`, not in the published graph. Original PDFs remain in ignored `work/originals/`.

The published learner route uses **Database Actions → SQL Worksheet**; v2 schema development uses SQLcl/Liquibase through the migration guide above. The [direct GitHub dataset load](docs/github-dataset-load.md) fetches JSON data from a pinned public commit and validates it before activating the graph. Dev includes a publishable summary package under `data/load/` and its short caller in `sql/install/10_load_github.sql`. Publish and test that candidate using the full **dev commit SHA** before promoting it to release. Its evidence is attributed editorial summaries, separate from the extracted authoring passages in ignored `work/` files. The Worksheet route needs no client database driver or wallet; SQLcl has a separate private database connection. `requirements-db.txt` and the Python DB commands are optional automation.

The GitHub load and expanded summary dataset passed [native ADB Serverless acceptance](references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`: 834 sources, 762 passages, three contexts and 30,144 RDF triples. Import/retry, graph scope, source isolation and two-session locking passed. A subsequent [real-model and signed-in APEX check](references/expanded-ui-validation.json) passed Alex refinement, historical evidence, Casey's added research, non-PDF links and observations, with four real model calls. The tested app and citation-parser fixes are identified by artifact hashes. Release remains unchanged; follow the [testing and promotion sequence](docs/branch-workflow.md#maintainer-promotion).

The current engine-generated APEX export includes the expanded content's non-PDF evidence display and versioned assets. New imports do not need a separate JavaScript upload. See the [upgrade guide](docs/content-ingestion-upgrade.md#update-the-application) for existing installations and the [Casey walkthrough](docs/ui-walkthrough.md#explore-the-expanded-research-with-casey) for an added-research example.

## Understand the data

| File | Meaning |
| --- | --- |
| [data/public-sources.json](data/public-sources.json) | Public source metadata, hashes and selected pages; lab editorial topic/purpose tags |
| [data/contexts.json](data/contexts.json) | Explicit fictional learner context, questions, topic preferences and snapshot versions |
| [review-examples/examples.json](review-examples/examples.json) | 17 short original paraphrases for inspecting extraction quality; not raw source text or accepted claims |
| [data/load/manifest.json](data/load/manifest.json) and its JSON parts | Publishable summary dataset for pinned-commit loading and native acceptance on dev; counts describe this package, separately from the raw authoring build |
| `work/passages.json` | Actual normalised text from the verified PDF pages, generated locally |
| `work/candidates.json` | Model-proposed claims with verified quote/locator structure; still awaiting review |
| `work/accepted-claims.json` | Only claims with an explicit reviewer and rationale |

The same LRN6034 session has two different presentations; they remain different sources. Roadmap and regional availability qualifications stay visible. No customer conversations, private annotations, internal content or internal source URLs are included. The example does not depend on the author's collection, report, applications or databases.

## Continue on ADB Serverless

**Current dev candidate:** start with [fresh dev deployment](docs/fresh-dev-deployment.md) for a new `KCV_V<major>_<build>` schema/workspace, or the [migration guide](docs/database-migrations.md) for an existing installation. The [build lifecycle](docs/dev-build-lifecycle.md) explains replacement, retirement and local cleanup. Complete the runtime prerequisites, native APEXlang import and [manual review](docs/my-contexts-manual-test.md). Do not run the legacy raw table/package installation sequence against a migration-managed schema.

**Learner experience:** use the `release` checkout and its own clean-installation or migration guide. Use the `v1.0.0` tag when deliberately reproducing v1. Historical v1 guides retained on dev are references; their linked current SQL files are not an alternative v2 migration path.

The main path is sources → graph → context → relevant content → refinement. [Claim extraction and human review](labs/04_extract_and_review.md) is an optional curation extension; no claim approval is required for the main path. The older [setup reference](docs/setup.md) and [technical labs](labs/00_introduction.md) provide deeper exercises. Java enablement is a deliberate database-wide operation, never an automatic side effect of a build.

The executable implementation is `kcv/`; the HOL explains it in `labs/`. `sql/` holds Worksheet-ready database artifacts and `integration-test/verify_worksheet.sql` holds functional SQL checks. Optional Python integration checks are also included. Local RDFLib execution validates generated RDF and graph queries, not Oracle SEM_APIS compatibility.

SQL examples shorter than 10 runnable lines are included inline where used, with a link to the complete script. Longer scripts remain linked files. To refresh these copyable examples after editing SQL, run `python scripts/sync_doc_snippets.py`; the artifact build checks that documentation and scripts agree.

## Agents

Current v2 retrieves and records question evidence in application code, then sends the packet to the tool-free `KCV_GROUNDED_TEAM` answer task. Context-change proposals retain `KCV_EXPLORER_TEAM`. The lineage distinguishes application retrieval from agent tool calls and historical events with an unrecorded trigger. The older optional KCV_TEAM defines three workers plus a coordinator:

- **Source analyst:** proposes claims from public passages.
- **Context planner:** clarifies only the context supplied.
- **Evidence/relevance analyst:** explains relevance and limitations using bounded graph-linked evidence.

These are logical roles, not separate model-hosting services. Their tools cannot accept claims or update the graph. Candidate validation and publication are ordinary code plus explicit review. [Architecture](docs/architecture.md).

## Status and prerequisites

Read [current scenario and application validation](docs/scenario-validation.md), with [earlier baseline validation](docs/validation.md) retained separately. Native graph retrieval, real model calls and the application were exercised on the temporary Serverless instance. The new beginner route still needs a full rehearsal on another empty database and a first-time learner review; optional extraction/inference checks retain their separately recorded limits.

See the [plan-to-implementation status](docs/implementation-status.md) for completed artifacts and pending acceptance work.

External services for the database walkthrough: ADB Serverless and one supported model endpoint (OCI Generative AI in the provided profile path), with appropriate IAM/network access. APEX 26.1+ is used for the supplied optional chatbot. Object Storage, external graph/vector databases and queues are not required.

## Public source lineage

The design follows the author's public series:

- [Exploring More And Cutting Out The Noise](https://www.linkedin.com/pulse/exploring-more-cutting-out-noise-jason-lowe-ohavc/)
- [Seeing The Patterns (Through The Noise)](https://www.linkedin.com/pulse/seeing-patterns-through-noise-jason-lowe-05vvc/)
- [Where do I start? Does it matter?](https://www.linkedin.com/pulse/where-do-i-start-does-matter-jason-lowe-miwic/)

Public availability does not transfer presentation copyright. This repo links to and downloads originals for local exercises rather than committing those documents or extracted full text.

**Using the app:** follow the [UI walkthrough](docs/ui-walkthrough.md) to start with Alex, inspect evidence, refine the context and capture a useful next step. Each step explains the expected outcome.

**Implemented features:** [two implementation epics](docs/implementation-epics.md) cover response explanations and Oracle-style layout/styling. See the [release and upgrade guide](docs/epics-upgrade.md).

## Licence

An independent project for education, learning and experimentation. Copyright (c) 2026 Jason Lowe. Original project contributions are licensed under [MIT](LICENSE.txt). Third-party material retains its respective licences, including Oracle LiveLabs material under UPL 1.0, Font APEX assets under their upstream terms, and reused [public file-list metadata](third-party/connormcd-misc-scripts/README.md) under Apache 2.0. See [NOTICE.md](NOTICE.md) for attribution and scope.

## Public research catalogue

The graph also includes public research references admitted through recorded access checks or the [manually approved public-source rules](references/public-source-policy.json). Sources matching those rules are labelled **manually marked as public**; their actual access-test results remain separate. Download and open the [searchable catalogue](generated/public-catalog.html), or follow the [catalogue learning steps](docs/public-research-catalog.md) to browse the same source/topic/version relationships through SQL and SPARQL. The [access-check record](references/public-access-checks.json) distinguishes successful verification from failed or unsupported checks. Readable research now contributes actual passages on dev and selected attributed summaries on release. Catalogue-only references remain discovery links; see the content-ingestion record for coverage gaps. Public classification does not transfer source copyright or licences.
