# Relationship to the original HOL

This standalone example adapts the workflow of the pinned [Oracle LiveLabs ontology/document workshop](https://github.com/oracle-livelabs/spatial-graph/tree/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag). See [NOTICE](../NOTICE.md) for attribution.

The original uses its Formula 1 domain and database document-ingestion/extraction flow. This release uses fictional learner contexts and attributed editorial summaries of selected real public conference and research content. It does not bundle the Formula 1 dataset, other workshops or WMS/reservation metadata.

Both connect content and concepts through a graph and use agents to work with evidence. This adaptation emphasises context refinement, public page traceability and recorded answer lineage. Public evidence retrieval uses explicit topic membership and deterministic bounded selection; it is separate from local semantic search of owned context drafts. Ontology extraction and OWL classification remain optional SQL exercises outside the main deployment path.

The development branch retains detailed implementation comparisons, original public-PDF preparation and developer tools. The release installs prepared SQL without Python. The current release-package clean/migration paths need separate acceptance; earlier original-passage tests are not proof of those routes.

Current v2 also adds owned My Contexts and durable conversations. The application captures graph evidence before the grounded answer task. Private context-library semantic search is separate from that public topic join. These are adaptation features, not claims about the original workshop.
