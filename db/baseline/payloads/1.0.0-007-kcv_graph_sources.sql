CREATE TABLE kcv_graph_sources (
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  version_id VARCHAR2(128) NOT NULL REFERENCES kcv_sources(version_id),
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON),
  PRIMARY KEY(graph_name,version_id)
)
