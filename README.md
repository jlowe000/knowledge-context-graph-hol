# Knowledge Context Explorer — use it and understand it

This is the **SQL-first learner distribution**, currently prepared on dev as an unpromoted v2 candidate. Choose the experience that fits what you want to learn:

| Your goal | Start here | What you need |
| --- | --- | --- |
| Use your own learning context | [My Contexts](labs/my-contexts/my-contexts.md) | An existing app URL and app login from your facilitator |
| Learn how the collection works as a developer | [Developer learning lab](labs/understand-collection/understand-collection.md) | A deployed sample and your lab-owner SQL Worksheet access |
| Install into an empty project schema | [Clean installation](docs/fresh-serverless-deployment.md) | An approved ADB Serverless environment and administrator/model access |
| Upgrade an existing installation | [Migration to v2](docs/migrate-to-v2.md) | A supported existing installation, its recorded identities and a recovery plan |
| Build your own adaptation | Select **dev**, then read `docs/build-your-own.md` | The source/preparation/build environment documented on dev |

Read [Choose your learning path](docs/learning-paths.md) if you are unsure. **Release is for both end users and developers learning this knowledge-collection example.** Dev is for people who want to change the example into their own implementation.

For deployment, first choose between [clean installation and migration](docs/installation-paths.md). Both use supplied SQL through Database Actions; neither requires Liquibase, SQLcl or Python. Both routes passed their scoped candidate02 Worksheet/browser rehearsals, including fresh-sign-in reopening, as recorded in [release-path acceptance](db/verification/release-v2-paths-validation.json). The APEX execution instructions are corrected to Run Statement; v2 remains unpromoted and the published v1 release is unchanged.

## What you can experience

Create an owned context or explore a fictional sample, inspect connected sources and answer lineage, clarify an objective or topic, compare answers and record what you learned. Save multiple conversations, explicitly adopt revised context, search your library and return after signing in again. Developers can also inspect the source/version/evidence model, follow the native SPARQL query and exercise the supplied SQL APIs.

Using a hosted app requires no OCI Console, SQL or Python access. Deploying this sample uses SQL through Database Actions and a [short call that loads the dataset directly from GitHub](docs/github-dataset-load.md); no Python, client wallet or local build is needed. The [architecture](docs/architecture.md) explains SPARQL and the role of APEXlang in preparing the deployable app.

## Included sample

- The original nine reviewed sources, the expanded public research catalogue, attributed editorial summaries and three fictional learner contexts. Exact coverage is recorded in generated/build-report.json.
- Ontology, graph/model/agent SQL, scenario APIs and native verification.
- Ordered schema installation/upgrade parts, [GitHub dataset loader](sql/install/10_load_github.sql), new/same-ID APEX installers and [standard APEX export](apex/kcv-explorer.sql).
- Personal contexts, local semantic/keyword search and historical answer evidence; private runtime records are never part of the public dataset.
- Separate user, developer-learning and deployment guides.

The [dataset](docs/release-dataset.md) contains editorial summaries of public pages, not verbatim PDF extracts. Summary IDs/hashes identify that text; follow the original page links to check the source.

The dataset load uses a published release commit and the supplied manifest hash. The commit must contain `data/load/manifest.json` and all its JSON parts; generating a local release does not publish them. The [load guide](docs/github-dataset-load.md) explains choosing the commit, monitoring progress and the retained SQL fallback.

The [validation record](docs/scenario-validation.md) separates historical v1/dev checks from the current v2 release-package rehearsals. Fresh installation and migration need their own evidence; generated artifacts alone do not establish either pass. A facilitator should confirm the installed version, collection and available search mode before a workshop.

The supplied engine-generated APEX export includes the non-PDF evidence display and versioned assets; no separate JavaScript upload is needed after a normal import. The [Casey walkthrough](docs/ui-walkthrough.md#explore-the-expanded-research-with-casey) shows how to add a healthcare focus and inspect added research alongside the original presentation.

[MIT licence](LICENSE.txt) · [attribution](NOTICE.md) · [cleanup](docs/cleanup.md). No WMS/reservation metadata or other upstream workshops are included.

## Licence

An independent project for education, learning and experimentation. Copyright (c) 2026 Jason Lowe. Original project contributions are licensed under [MIT](LICENSE.txt). Third-party material retains its respective licences, including Oracle LiveLabs material under UPL 1.0, Font APEX assets under their upstream terms, and reused [public file-list metadata](third-party/connormcd-misc-scripts/README.md) under Apache 2.0. See [NOTICE.md](NOTICE.md) for attribution and scope.

## Public research catalogue

The graph also includes public research references admitted through recorded access checks or the [manually approved public-source rules](references/public-source-policy.json). Sources matching those rules are labelled **manually marked as public**; their actual access-test results remain separate. Download and open the [searchable catalogue](generated/public-catalog.html), or follow the [catalogue learning steps](docs/public-research-catalog.md) to browse the same source/topic/version relationships through SQL and SPARQL. The [access-check record](references/public-access-checks.json) distinguishes successful verification from failed or unsupported checks. Readable research now contributes actual passages on dev and selected attributed summaries on release. Catalogue-only references remain discovery links; see the content-ingestion record for coverage gaps. Public classification does not transfer source copyright or licences.
