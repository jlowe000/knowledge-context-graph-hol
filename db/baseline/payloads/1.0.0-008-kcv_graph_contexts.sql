CREATE TABLE kcv_graph_contexts (
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  snapshot_id VARCHAR2(128) NOT NULL REFERENCES kcv_contexts(snapshot_id),
  PRIMARY KEY(graph_name,snapshot_id)
)
