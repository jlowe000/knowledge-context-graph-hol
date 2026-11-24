# From Drawing Connections to Testing Them

**Choose the matching branch experience.** Current dev setup starts with [development](../docs/development.md), [migrations](../docs/database-migrations.md) and the [My Contexts manual review](../docs/my-contexts-manual-test.md). For the published v1 SQL-first HOL, use its release/tag checkout and [beginner deployment route](../docs/fresh-serverless-deployment.md). The numbered files below retain the original sample exercises and technical reference; their raw initialization commands are not an alternative v2 migration sequence.

This lab asks: which knowledge may help this person, in this context, and why?

You will use nine real public presentations and three fictional learners to build a small graph. The two LRN6034 decks remain distinct; a roadmap stays qualified; a healthcare overview is read alongside its regional disclaimer. Context can change a recommendation without changing the source facts.

## Route through the lab

The [extended original-workshop scenarios](07_original_workshop_scenarios.md) add visible graph paths, guarded context changes, a real APEX app export and a meaningful optional inference comparison. If the initial graph is already loaded, start there after installing the additive scenario extension; do not repeat provisioning.

1. [Getting Started](01_getting_started.md): Oracle Linux, artifacts and standard Serverless setup.
2. [Sources and passages](02_sources_and_passages.md): verify editions and inspect real evidence.
3. [Taxonomy, ontology and RDF](03_graph.md): generate and load the connected model.
4. [Context and agents](05_context_and_agents.md): inspect deterministic retrieval before agent reasoning.
5. [Evolution and feedback](06_evolution_and_feedback.md): revise understanding and record observations.

Optional extension: [Extract and review](04_extract_and_review.md) demonstrates claim curation. It is not a gate for the main route.

Artifact generation needs only the Python environment. Full database exercises require **ADB Serverless 26ai**, Java/RDF and model access. Native scenario and application checks passed on the temporary instance; see [current validation](../docs/scenario-validation.md) for the remaining clean-install rehearsal and optional exercise limits.

## What carries over from the original workshop

Document ingestion -> ontology-guided extraction -> RDF -> questions/agents. We replace the original F1 scenario with public conference knowledge and explicit learner context. The original lab remains a reference, not a content item for ingestion. We add the provisioning instructions that the prepared LiveLabs sandbox previously supplied implicitly.

There is no need for the author's existing knowledge collection infrastructure, a LiveLabs reservation, WMS registration or the original APEX chatbot.
