# Choose your learning path

The branch choice follows your intended outcome. A developer learning to use the knowledge collection can stay on release; you do not need to become a maintainer to understand the implementation.

| Experience | What you do | What you learn | Completion outcome |
| --- | --- | --- | --- |
| Use the collection | Create or copy a context, ask, inspect evidence, refine deliberately and reopen saved work | How knowledge connects to a person's situation and next question | Explain a useful next step and its supporting evidence/limits |
| Understand the collection as a developer | Inspect metadata/ontology, query a scenario, follow application retrieval and trace a response | How the supplied data, SPARQL, SQL/PLSQL, agents and APEX fit together | Explain the path from stored context to returned evidence and answer |
| Install the supplied sample | Follow the clean-installation SQL/ADB/APEX route | How to install into an empty project schema | A new working sample for either learning experience |
| Migrate an existing installation | Verify its starting version, apply ordered SQL upgrades and update the existing app | How to upgrade while retaining existing work | A verified v2 installation with its existing application identity and history |
| Build your own version — dev | Change the source collection, taxonomy/ontology, retrieval, tools, UI and packaging | How to adapt and validate a new implementation | A separately tested adaptation with its own learner documentation |

## Use an existing application

Start at [My Contexts](../labs/my-contexts/my-contexts.md) for your own question, or [Explore evidence](../labs/explore-evidence/explore-evidence.md) for the fictional sample. Ask your facilitator for the app URL and your individual app login. Sharing a login shares its personal library. You do not need a database account, OCI tenancy or the developer environment. Read the actual evidence labels: these release files install editorial summaries, while an earlier hosted demonstration may contain extracted passages and different citation IDs.

## Learn the developer experience

Start at [Understand the collection](../labs/understand-collection/understand-collection.md). Use your own deployed sample or a facilitator-provided lab-owner Worksheet. Follow one source through its metadata, RDF relationships, returned evidence and answer. Exercise the supplied scenario API without changing the implementation or rebuilding the app.

The [architecture](architecture.md) explains the SPARQL query and the role of APEXlang. The [SQL catalogue](sql-catalogue.md) indexes the runnable files. SQL knowledge is useful; the lab explains the specific IDs and outcomes used here.

## Set up an environment only if needed

Choose an [installation path](installation-paths.md): [clean installation](fresh-serverless-deployment.md) for an empty project schema, or [migration](migrate-to-v2.md) for an existing supported installation. Both use Database Actions SQL Worksheet. The version 2.0.0 routes passed separate clean-installation and migration rehearsals; the [acceptance record](../db/verification/release-v2-paths-validation.json) states the tested scope and remaining limitations.

Provisioning is setup work for the experience, not a prerequisite for every end user. Database and model access remain separate permissions. A new schema on an approved existing database can be a clean installation; an existing project schema is a migration even if the database itself is temporary.

## Adapt the implementation

Select dev in the repository branch selector and use `docs/build-your-own.md`, followed by `docs/development.md` for the environment. That journey includes replacing the dataset, evolving the ontology and retrieval rules, changing tools/UI and validating your own packaged experience. The supplied defaults and tests contain scenario-specific assumptions; this is more than changing a configuration file.
