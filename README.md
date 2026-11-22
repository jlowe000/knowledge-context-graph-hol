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

Using a hosted app requires no OCI Console, SQL or Python access. Deploying this sample uses the supplied SQL through Database Actions; no Python, client wallet or local build is needed. The [architecture](docs/architecture.md) explains SPARQL and the role of APEXlang in preparing the deployable app.

## Included sample

- Nine public-source records, 17 attributed editorial summaries and three fictional learner contexts.
- Ontology, graph/model/agent SQL, scenario APIs and native verification.
- [Dataset installer](sql/install/10_load_dataset.sql), [APEX Worksheet installer](sql/install/20_install_apex.sql) and [standard APEX export](apex/kcv-explorer.sql).
- Separate user, developer-learning and deployment guides.

The [dataset](docs/release-dataset.md) contains editorial summaries of public pages, not verbatim PDF extracts. Summary IDs/hashes identify that text; follow the original page links to check the source.

The [validation record](docs/scenario-validation.md) distinguishes related dev application tests from the still-pending native acceptance of this summary dataset. A facilitator should confirm which sample is installed before a workshop.

[UPL 1.0 licence](LICENSE.txt) · [attribution](NOTICE.md) · [cleanup](docs/cleanup.md). No WMS/reservation metadata or other upstream workshops are included.
