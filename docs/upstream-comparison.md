# Original workshop comparison and next steps

Reviewed 18 November 2026 against upstream commit `e88a08bd3f9df46031fd09bc62bc1cfe528be6a1`, limited to `adb-graph/f1-ontology-vector-rag`. All seven lab Markdown documents were read. This is a comparison with that pinned edition, not a claim that upstream main has not changed.

Technology/status clarification, 23 November: both workshops use native Oracle RDF graphs, SPARQL through SEM_MATCH and optional native OWL2RL inference. This is not a PGQL/property-graph implementation. Our APEX application definition is APEXlang; its deployable artifact is an APEX-generated SQL export. See [language and engine boundaries](architecture.md#languages-and-graph-engine).

## What the original does and what changed

| Original capability | This adaptation | Assessment |
| --- | --- | --- |
| Load PDFs as database BLOBs and extract/chunk with DBMS_VECTOR_CHAIN | Download verified public PDFs and extract selected pages locally with pypdf; load passages through generated Worksheet SQL | Intentional alternative, not equivalent database-native ingestion |
| Ontology-constrained LLM extraction produces subject/predicate/object facts, then loads those facts as RDF | Optional source-concept extraction into separate proposed-relationship graphs, with constrained predicates and passage evidence | Added in the scenario extension; no per-claim approval gate; proposals are not silently mixed into active retrieval |
| Inspect RDF in Graph Studio and run example SPARQL queries | Graph Studio walkthrough, native path-returning tools and APEX relationship view | Native query/scenario and APEX browser checks passed; the Graph Studio walkthrough itself is not a recorded browser pass |
| Supervisor routes to a read-only question agent or guarded change agent | Original KCV_TEAM retained; current v2 retrieves evidence in application code before passing the captured packet to tool-free KCV_GROUNDED_TEAM. KCV_EXPLORER_TEAM remains for context-change proposals | New question evidence records APPLICATION origin before model dispatch; citation/completion checks remain explicit. The planner cannot apply changes |
| Add/delete facts through an allow-listed API with audit records and a confirmation code for deletes | Add/remove topic focus or set objective through revision-bound, expiring preview/apply tokens and audit | Context changes create new overlay graphs; immutable source knowledge is preserved |
| Prepared APEX chatbot and agent-team map | Standalone APEXlang source and engine-generated SQL app export, with context, evidence paths, source links, refinements and observations | v1 browser validation was recorded on 23 November; current v2 coverage and limits are in the [candidate acceptance record](../references/my-contexts-c3-validation.json) |
| Bonus OWL2RL restriction classifies an entity, with before/after queries | FocusedContext restriction and native before/after classification script | Same engine/pattern; original uses owl:hasValue, adaptation uses owl:someValuesFrom plus subclass implication. Native before/after passed 22 November; this does not establish value |
| Prepared sandbox credentials, grants, profile, RDF network and Java | Standalone provisioning and two OCI authentication paths | Added setup necessary outside the reservation sandbox |

The original mentions human supervision in creating its supplied ontology. It does not require our per-candidate accept/reject CLI gate. That is an optional curation extension introduced here.

Despite the workshop folder name, the reviewed main lab documents do not implement an embedding/vector similarity retrieval pipeline. Database text extraction uses DBMS_VECTOR_CHAIN; that is not itself embedding generation or vector search. Adding vector retrieval would be a new extension, not restoration of a missing original exercise.

## What the initial run established

The learner reported successful GenAI profile use, imported four candidate claims, and returned both a context clarification and a relevance assessment through RUN_TEAM. The relevance response cites passages and preserves qualifications. These are successful user-observed executions; they are not evidence that every native script or model case has passed independently captured integration tests.

The legacy KCV_EVIDENCE_PACKET function retains its original bounded baseline behaviour for compatibility. The new KCV_SCENARIO evidence function returns actual bindings across a pinned base graph and a versioned context-topic overlay. Explicit topic edits affect retrieval; an objective-only edit changes stored context without claiming that the topic join changed. Free-text questions do not silently mutate either graph. See [scenario architecture and setup](scenario-setup.md).

## Recommended continuation for this scenario

1. Install the additive [scenario extension](scenario-setup.md) in the working lab schema; inspect compilation before starting scenarios.
2. Run the native acceptance script and [Alex/Sam/Casey exercises](../labs/07_original_workshop_scenarios.md). Compare real paths, qualifications and before/after retrieval, not only model prose.
3. Import the [APEX app](../apex/README.md) into a workspace mapped to KCV_LAB and run the same journeys through the UI.
4. Run source extraction and OWL classification as separate optional learning objectives. Record validation observations without turning agreement into factual truth.

The remaining intentional differences are local rather than database-native PDF extraction, a limited source-concept vocabulary, and context refinements rather than destructive edits to source assertions. The dev native graph/model/refinement flow, optional OWL exercise and APEX browser journey passed the clean-reset/rebuild checks on 21–23 November. Optional extraction/curation and older base-team reasoning were not rerun in that reset; release's editorial-summary dataset needs separate native acceptance. See [the validation record](scenario-validation.md).

## Original references

- [Workshop introduction](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/introduction/introduction.md)
- [Database document ingestion](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/ingest-f1-documents/ingest-f1-documents.md)
- [Ontology-aligned fact extraction](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/extract-rdf-facts/extract-rdf-facts.md)
- [Graph loading, Graph Studio and SPARQL](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/load-rdf-graph/load-rdf-graph.md)
- [Question and guarded change agents](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/build-graph-agents/build-graph-agents.md)
- [APEX chat and agent-team map](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/chat-with-agents/chat-with-agents.md)
- [Bonus OWL inference](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/bonus-owl-inference/bonus-owl-inference.md)
