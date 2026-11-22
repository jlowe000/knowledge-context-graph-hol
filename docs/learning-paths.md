# Choose your learning path

The branch choice follows your intended outcome. A developer learning to use the knowledge collection can stay on release; you do not need to become a maintainer to understand the implementation.

| Experience | What you do | What you learn | Completion outcome |
| --- | --- | --- | --- |
| Use the collection | Ask, inspect evidence, refine context and save an observation | How knowledge connects to a person's situation and next question | Explain a useful next step and its supporting evidence/limits |
| Understand the collection as a developer | Inspect metadata/ontology, query a scenario, follow the agent tool and trace a response | How the supplied data, SPARQL, SQL/PLSQL, agents and APEX fit together | Explain the path from stored context to returned evidence and answer |
| Deploy the supplied sample | Follow the ordered SQL/ADB/APEX setup | How to install and verify this existing example | A working sample for either learning experience |
| Build your own version — dev | Change the source collection, taxonomy/ontology, retrieval, tools, UI and packaging | How to adapt and validate a new implementation | A separately tested adaptation with its own learner documentation |

## Use an existing application

Start at [Explore evidence](../labs/explore-evidence/explore-evidence.md). Ask your facilitator for the app URL and app login. You do not need a database account, OCI tenancy or the developer environment. Read the actual evidence labels: these release files install editorial summaries, while an earlier hosted demonstration may contain extracted passages and different citation IDs.

## Learn the developer experience

Start at [Understand the collection](../labs/understand-collection/understand-collection.md). Use your own deployed sample or a facilitator-provided lab-owner Worksheet. Follow one source through its metadata, RDF relationships, returned evidence and answer. Exercise the supplied scenario API without changing the implementation or rebuilding the app.

The [architecture](architecture.md) explains the SPARQL query and the role of APEXlang. The [SQL catalogue](sql-catalogue.md) indexes the runnable files. SQL knowledge is useful; the lab explains the specific IDs and outcomes used here.

## Set up an environment only if needed

Follow [Deploy the sample](fresh-serverless-deployment.md) when no suitable environment is supplied. Provisioning is setup work for the experience, not a prerequisite for every end user. Database and model access remain separate permissions.

## Adapt the implementation

Select dev in the repository branch selector and use `docs/build-your-own.md`, followed by `docs/development.md` for the environment. That journey includes replacing the dataset, evolving the ontology and retrieval rules, changing tools/UI and validating your own packaged experience. The supplied defaults and tests contain scenario-specific assumptions; this is more than changing a configuration file.
