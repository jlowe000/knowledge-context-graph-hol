# Knowledge Context Explorer — use it and understand it

This is the **release branch**. Choose the experience that fits what you want to learn:

| Your goal | Start here | What you need |
| --- | --- | --- |
| Use the knowledge collection | [User experience](labs/explore-evidence/explore-evidence.md) | An existing app URL and app login from your facilitator |
| Learn how the collection works as a developer | [Developer learning lab](labs/understand-collection/understand-collection.md) | A deployed sample and your lab-owner SQL Worksheet access |
| Set up the sample environment | [Deployment walkthrough](docs/fresh-serverless-deployment.md) | An approved ADB Serverless environment and the documented administrator/model access |
| Build your own adaptation | Select **dev**, then read `docs/build-your-own.md` | The source/preparation/build environment documented on dev |

Read [Choose your learning path](docs/learning-paths.md) if you are unsure. **Release is for both end users and developers learning this knowledge-collection example.** Dev is for people who want to change the example into their own implementation.

## What you can experience

Ask a question for a fictional learner, inspect connected sources and answer lineage, clarify an objective or topic, compare the next answer and record what you learned. Developers can also inspect the source/version/evidence model, follow the native SPARQL query and exercise the supplied SQL APIs.

Using a hosted app requires no OCI Console, SQL or Python access. Deploying this sample uses SQL through Database Actions and a [short call that loads the dataset directly from GitHub](docs/github-dataset-load.md); no Python, client wallet or local build is needed. The [architecture](docs/architecture.md) explains SPARQL and the role of APEXlang in preparing the deployable app.

## Included sample

- The original nine reviewed sources, the expanded public research catalogue, attributed editorial summaries and three fictional learner contexts. Exact coverage is recorded in generated/build-report.json.
- Ontology, graph/model/agent SQL, scenario APIs and native verification.
- [GitHub dataset loader](sql/install/10_load_github.sql), [APEX Worksheet installer](sql/install/20_install_apex.sql) and [standard APEX export](apex/kcv-explorer.sql).
- Separate user, developer-learning and deployment guides.

The [dataset](docs/release-dataset.md) contains editorial summaries of public pages, not verbatim PDF extracts. Summary IDs/hashes identify that text; follow the original page links to check the source.

The dataset load uses a published release commit and the supplied manifest hash. The commit must contain `data/load/manifest.json` and all its JSON parts; generating a local release does not publish them. The [load guide](docs/github-dataset-load.md) explains choosing the commit, monitoring progress and the retained SQL fallback.

The [validation record](docs/scenario-validation.md) distinguishes earlier dev application tests from the expanded summary dataset's native SQL acceptance on dev. The GitHub load, graph/scope checks and lock exclusion passed on 23 November 2026; model inference and browser acceptance for these summaries remain pending. Execution from a promoted release commit is separate. A facilitator should confirm which sample is installed before a workshop.

[MIT licence](LICENSE.txt) · [attribution](NOTICE.md) · [cleanup](docs/cleanup.md). No WMS/reservation metadata or other upstream workshops are included.

## Licence

An independent project for education, learning and experimentation. Copyright (c) 2026 Jason Lowe. Original project contributions are licensed under [MIT](LICENSE.txt). Third-party material retains its respective licences, including Oracle LiveLabs material under UPL 1.0 and Font APEX assets under their upstream terms. See [NOTICE.md](NOTICE.md) for attribution and scope.

## Public research catalogue

The graph also includes public research references admitted through recorded access checks or the [manually approved public-source rules](references/public-source-policy.json). Sources matching those rules are labelled **manually marked as public**; their actual access-test results remain separate. Download and open the [searchable catalogue](generated/public-catalog.html), or follow the [catalogue learning steps](docs/public-research-catalog.md) to browse the same source/topic/version relationships through SQL and SPARQL. The [access-check record](references/public-access-checks.json) distinguishes successful verification from failed or unsupported checks. Readable research now contributes actual passages on dev and selected attributed summaries on release. Catalogue-only references remain discovery links; see the content-ingestion record for coverage gaps. Public classification does not transfer source copyright or licences.
