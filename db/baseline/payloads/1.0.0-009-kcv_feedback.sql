CREATE TABLE kcv_feedback (
  feedback_id VARCHAR2(64) PRIMARY KEY,
  context_snapshot_id VARCHAR2(128) NOT NULL REFERENCES kcv_contexts(snapshot_id),
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  observer VARCHAR2(200) NOT NULL,
  observation CLOB NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
