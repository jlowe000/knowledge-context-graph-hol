# Knowledge Context Explorer — use it and understand it

This is the **v2.1.0 distribution**, prepared from validated dev sources for release. APEX-led and SQL-first clean installation and populated v2.0.0 upgrade passed on prepared environments, within the scopes in the [v2.1 path record](db/verification/release-v2.1-paths-validation.json). The package retains the tested runtime files. Local release preparation does not publish a GitHub branch or tag.

| Your goal | Start here | What you need |
| --- | --- | --- |
| Try your own learning question | [My Contexts](labs/my-contexts/my-contexts.md) | A facilitator-provided app URL and individual app login |
| Understand the supplied collection as a developer | [Developer learning lab](labs/understand-collection/understand-collection.md) | A deployed sample and authorised owner Worksheet access |
| Install through App Builder | [APEX-led clean installation](docs/apex-led-installation.md) | A prepared supported ADB/workspace and application ZIP |
| Install using Database Actions | [SQL-first clean installation](docs/fresh-serverless-deployment.md) | Administrator and project-owner Worksheet access |
| Upgrade a supported v2.0.0 installation | [Choose the upgrade route](docs/installation-paths.md) | Existing identities, saved work, maintenance window and recovery preparation |
| Build your own adaptation | [DEV-led guide on dev](https://github.com/jlowe000/knowledge-context-graph-hol/blob/dev/docs/build-your-own.md) | The separate source, migration and build environment |

**Using an existing app needs no OCI account, database login, SQL or local tooling.** Choose [your learning path](docs/learning-paths.md). Release is for app users and developers learning this supplied collection; dev is for changing its implementation.

## Three deployment experiences

- **APEX-led:** an administrator prepares ADB and the workspace; the installer imports the supplied application ZIP through App Builder, installs its Supporting Objects and completes guided setup. The ZIP contains backend installation and compilation steps, not credentials or saved learner data.
- **OCI / DBA-led:** use supplied SQL through Database Actions for schema, runtime and app installation, then complete the same binding/readiness gates. No Python, SQLcl, Liquibase client or local wallet is needed.
- **DEV-led:** change sources, ontology, APIs, UI or migrations using dev's own tooling and validation. Those tools are not required to use or deploy this package.

Choose [clean installation or upgrade within the intended experience](docs/installation-paths.md). Do not combine Supporting Objects installation with a second SQL-first schema installation.

## What you can experience

Create an owned context or explore a fictional sample. Ask a question, inspect connected sources and answer lineage, refine your objective or learning focus, and record what you learned. Save multiple conversations, explicitly adopt revised context and reopen historical evidence after signing in again. Local semantic search is optional; the app labels keyword-only matching when its embedding model is unavailable.

Developers can inspect the source/version/evidence model, follow native SPARQL retrieval and exercise the SQL APIs. The [architecture](docs/architecture.md) explains how APEXlang, SQL/PLSQL, the graph and model calls fit together.

## Included material

- Public research catalogue, attributed editorial summaries, ontology and three fictional contexts; coverage is recorded in `generated/build-report.json`.
- APEX-led ZIP with Supporting Objects, SQL-first ordered schema parts, new/same-ID app installers and standard SQL app export. See the [artifact selector](docs/installation-paths.md#use-one-matching-package).
- [Pinned GitHub dataset loader](docs/github-dataset-load.md) and SQL fallback.
- Separate user, developer-learning, administrator and installation guides.

The [dataset](docs/release-dataset.md) contains attributed editorial summaries, not verbatim PDF extraction or private runtime records. The collection is loaded during setup; personal graphs, conversations, credentials and app accounts are not distributed. Keep the approved public dataset commit and manifest hash together; a local build is not a new published GitHub dataset URL. Catalogue-only references remain discovery links; public access does not transfer copyright.

## Validation and limitations

The [validation guide](docs/scenario-validation.md) separates published v2.0.0 SQL-first evidence, earlier r13 tests and this distribution's four passed prepared-environment routes. Results include readiness, learner evidence, saved-answer reopening and bounded preservation checks. SQL-first clean installation used Worksheet for schema/app installation and genuine-owner SQLcl for its successful model test and enablement; it is not an all-Worksheet acceptance claim. Import success alone does not verify those outcomes. Confirm the exact package, active collection, readiness and search mode.

Positive execution of the public administrator preparation templates, new-database provisioning and first Java enablement/restart remain outside the prepared-environment results. Finite privacy checks do not prove every platform log excludes private input. If a bare context-overview link fails after sign-in, open **My Contexts** and select the context again. See [recovery](docs/deployment-recovery.md) before retrying interrupted work.

## Licence

Copyright (c) 2026 Jason Lowe. Original work is under [MIT](LICENSE.txt). Third-party material retains its terms, including Oracle LiveLabs UPL material, Font APEX assets and reused public file-list metadata under Apache 2.0. Keep [NOTICE.md](NOTICE.md) and applicable `third-party/` notices with redistributed packages. See [cleanup](docs/cleanup.md) before retiring an installation. No WMS metadata or other upstream workshops are included.
