# Relationship to the original HOL

This standalone example adapts the workflow of the pinned [Oracle LiveLabs ontology/document workshop](https://github.com/oracle-livelabs/spatial-graph/tree/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag). See [NOTICE](../NOTICE.md) for attribution.

The original uses its Formula 1 domain and database document-ingestion/extraction flow. This release uses fictional learner contexts and attributed editorial summaries of selected real public conference and research content. It does not bundle the Formula 1 dataset, other workshops or WMS/reservation metadata.

Both connect content and concepts through a graph and use agents to work with evidence. This adaptation emphasises context refinement, public page traceability and recorded answer lineage. It does not claim vector similarity retrieval: the active path uses explicit topic membership and deterministic bounded selection. Ontology extraction and OWL classification remain optional SQL exercises outside the main deployment path.

The development branch retains detailed implementation comparisons, original public-PDF preparation and developer tools. The release installs prepared SQL without Python. Its summary dataset needs separate native acceptance; earlier original-passage tests are not proof of this distribution's end-to-end validation.
