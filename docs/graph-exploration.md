# See the knowledge and context graphs

## In the chatbot

The app's connection view shows only edges present in the evidence tool's returned bindings: scenario context → focusesOn → topic ← coversTopic ← content item → version → passage. Open Exact graph paths for identifiers and the source cards for public PDF pages. The graph is not generated from the model's narrative. Unreturned topics/sources may still exist outside the bounded packet.

## In SQL Worksheet

Run `sql/scenarios/02_inspect.sql`. Open the evidence_and_paths CLOB. Compare `graph_paths` before and after a topic refinement. The base graph and public passage hashes should be unchanged; context_revision and overlay_graph should change. Adding/removing a topic changes eligible paths; clarifying an objective alone does not.

To inspect the original metadata graph directly, copy the base_graph name from the scenario state into the following example, replacing KCV_G_REPLACE:

```sql
SELECT s,p,o FROM TABLE(SEM_MATCH(
 'SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 50',
 SEM_MODELS('KCV_G_REPLACE'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,
 USER,'KCV_NET'));
```

SPARQL is fixed in this exercise; the model never supplies arbitrary SQL/SPARQL to execute. The source/edition/page relationships are asserted provenance. Context/topic selection links are supplied scenario preferences, not facts about a real person.

## In Graph Studio

1. Open Graph Studio from your Autonomous Database tools and sign in as KCV_LAB. If unavailable, see the optional role in [extension setup](scenario-setup.md).
2. Open Graphs → RDF Graph. Select the base KCV_G_… graph, then Query.
3. Run this small visual query. Use a limit first rather than expanding every node:

```sparql
CONSTRUCT { ?s ?p ?o }
WHERE { ?s ?p ?o }
LIMIT 80
```

4. Follow a content item to its topic, version and passage locator. Locate S03 and distinguish its public source identity from the lab's topic classification.
5. Select the scenario's KCV_O_… graph and run the same query. It contains the current context revision and its explicit focusesOn edges. Compare it to the prior overlay graph after a refinement; both remain available.
6. If you ran domain extraction, open that run's KCV_D_… graph. Inspect concept relationships, the reified statement, model_proposal status, qualification and supporting passage. It is a separate proposed-relationship graph and is not silently merged into retrieval.

Graph Studio controls vary with service version; the original [RDF visualization exercise](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/load-rdf-graph/load-rdf-graph.md) documents the reference flow. The chatbot's returned path view is the simpler way to inspect joins across the base and scenario overlay together.

## Optional inference: what is and is not inferred

The bonus rule classifies a context with an explicit topic link as FocusedContext. Its meaning is deliberately narrow. It does not infer that a topic is important, a product is available, a source is authoritative, stakeholders agree, or a recommendation delivers value. Run the before/after scenario in the walkthrough and retain the generated rule/inference graph names for cleanup.
