SELECT version_id,source_id,sha256 FROM kcv_sources ORDER BY source_id
/
SELECT context_id,snapshot_version FROM kcv_contexts ORDER BY context_id,snapshot_version
/
SELECT graph_name,graph_hash,state FROM kcv_graph_runs ORDER BY created_at
/
SELECT kcv_evidence_packet('{"context_id":"CTX02"}') AS evidence FROM dual
/
