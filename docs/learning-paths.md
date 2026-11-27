# Choose your learning path

Learning and deployment are separate choices. You can use or understand this collection without becoming its maintainer.

| Learning goal | Start here | Outcome |
| --- | --- | --- |
| Try your own learning question | [My Contexts](../labs/my-contexts/my-contexts.md) | Explain a useful next step and its evidence/limits |
| Explore fictional samples | [Explore evidence](../labs/explore-evidence/explore-evidence.md) | Connect context, sources and recorded answer lineage |
| Understand the implementation | [Developer learning lab](../labs/understand-collection/understand-collection.md) | Follow context, source/version metadata, SPARQL retrieval and returned evidence |
| Change the implementation | [Build your own version on dev](https://github.com/jlowe000/knowledge-context-graph-hol/blob/dev/docs/build-your-own.md) | Produce and validate your own adaptation |

## Use an existing application

Ask your facilitator for the app URL and an individual app login. You need **no OCI account, database login, SQL, wallet or local developer tools**. Sharing an account shares its personal library. Start in My Contexts, save or copy a draft, review/apply it, ask a question and inspect **Sources** and **Answer lineage**. Return to the saved conversation after signing in again.

Read the evidence labels. This distribution supplies attributed editorial summaries; earlier hosted demonstrations may contain extracted passages with different IDs. Proposed relevance is not an observed business outcome. Semantic library search is optional; a keyword-only banner is expected when its local model is unavailable.

## Understand the collection as a developer

Use a deployed sample and an authorised project-owner Worksheet to follow the [developer lab](../labs/understand-collection/understand-collection.md). Exercise your own SQL scenario rather than taking over an APEX user's session. The [architecture](architecture.md) and [SQL catalogue](sql-catalogue.md) explain the supplied implementation. This remains a release learning experience; you do not need to author migrations or rebuild the app.

## Deploy only when an environment is needed

| Deployment experience | Main activity | Preparation |
| --- | --- | --- |
| **APEX-led** | Import the app ZIP in App Builder; run Supporting Objects and guided setup | A facilitator prepares ADB, grants, workspace and model permissions |
| **OCI / DBA-led** | Install schema/app through Database Actions SQL, bind, then configure model/runtime through Deployment setup | A technical facilitator uses ADMIN/owner Worksheet and a separate installer APEX account |
| **DEV-led** | Change content, schema, ontology, tools, UI or packaging | Maintainers use separate dev tooling and tests |

Select [clean installation or upgrade](installation-paths.md) within the chosen experience. Both release routes require a supported ADB, but neither requires every learner to have OCI access. A new schema on an approved existing database can be a clean installation; an existing project schema is an upgrade even on a temporary database.

This v2.1.0 distribution has four passed prepared-environment routes. Its [four-route record](../db/verification/release-v2.1-paths-validation.json) retains the execution and coverage limits separately from earlier r13 and v2.0.0 results.
