# Build your own knowledge/context collection — dev journey

Use dev when your outcome is a new adaptation: your own source collection, people/organisation contexts, taxonomy/ontology, retrieval or application behaviour. If you want to use the supplied app or learn how this example works through SQL/APEX, use the release learning paths instead. Developer skill level alone does not determine the branch.

## 1. Define the experience and its evidence

Describe the conversations and cohorts you want to support, what is known or unknown about their objectives, and what a useful next question/action looks like. Decide what observations could establish value. Keep source facts, proposed relevance and observed outcomes distinct.

**Outcome:** a concrete scenario and success criteria before selecting technologies or collecting more content.

## 2. Adapt the collection and model

Review `data/public-sources.json`, `data/contexts.json`, `ontology/` and `review-examples/`. Choose public source editions/page locators, privacy-safe example contexts, topic/domain facets and relationships. Retain provenance and versioning; do not relabel editorial summaries as original quotations.

Current code deliberately assumes a particular source host (`static.rainfocus.com`), source-ID format, vocabulary and sample structure. Replacing the collection may require changing those allowlists, validators and fixtures deliberately. Review `kcv/pipeline.py` and preserve equivalent integrity/access controls for your new sources. Never commit private content, credentials or downloaded full-text working files to a public repository.

**Outcome:** a model and attributable dataset suited to your scenario, with its assumptions documented.

## 3. Prepare the implementation environment

Follow [development setup](development.md). The original-source pipeline on dev downloads/verifies PDFs, extracts selected pages, builds RDF and creates ignored Worksheet SQL. Inspect generated output before loading a dedicated database. Runtime does not require a Python service.

**Outcome:** reproducible input artifacts and a separate test environment.

## 4. Adapt retrieval and agent behaviour

Read [architecture](architecture.md), `sql/schema/03_tools.sql`, `sql/extensions/02_scenario_api.sql` and `03_scenario_agents.sql`. The current retrieval is explicit topic intersection over a pinned base plus context overlay, with deterministic bounds. Context weights are not a learned ranking. Change the ontology, query/tool contracts and tests together if your desired semantics differ.

Keep evidence IDs, actual tool-output capture, context ownership, guarded preview/apply and historical immutability. The optional OWL exercise demonstrates class entailment; using inference in normal retrieval would be an explicit design change.

**Outcome:** a defensible answer-selection mechanism with testable limits, not merely different model prose.

## 5. Adapt the application

Author the app definition in APEXlang under `apex/application/` and edit its HTML/CSS/JavaScript as needed. Use the build/validation/import/export sequence in [APEX instructions](../apex/README.md). Regenerate the engine-produced SQL export after source changes. Keep developer setup separate from the learner deployment and app-use instructions.

**Outcome:** an application suited to your users with a reproducible installation artifact.

## 6. Validate the new scenario and learning experience

Update sample-specific assertions intentionally: current tests and expected before/after stories refer to Alex/Sam/Casey, S02/S03/S06/S08 and fixed sample counts. Preserve the behaviours they test while replacing those fixtures. Run local tests, native graph/model checks, citation/trace checks and the actual browser journey. Use the [explicit reset workflow](dev-reset-and-retest.md) only for an authorised disposable lab; Java cannot be disabled afterwards.

Have someone follow your user journey, developer-learning journey and deployment route independently. A source change, retrieval change and UI change need different acceptance evidence.

**Outcome:** a verified adaptation and honest validation record.

## 7. Publish an experience, not the development workspace

Maintain the learner experience in `release-docs/`. It should support end users and developers learning your collection, with deployment offered when needed. Adjust the release data strategy and packaging assumptions for your own content and rights. Generate the summary-only GitHub package on dev, review it, then publish dev for pinned-commit native testing. Keep release unchanged until that acceptance passes; promote the reviewed learner distribution using [branch workflow](branch-workflow.md).

The provided release uses attributed editorial summaries of the original presentations and selected passages from the added research. The dev original-passage pipeline and the release summary dataset are separate modes; validate whichever you distribute. Do not copy raw work directories or merge the complete dev tree into release.

**Outcome:** a usable learner-facing distribution, with dev still available to others who want to build on your implementation.
