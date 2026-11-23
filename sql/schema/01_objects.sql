-- KCV_LAB only. Initial schema creation; do not run over an unrelated schema.
CREATE TABLE kcv_settings (
  setting_key VARCHAR2(64) PRIMARY KEY,
  setting_value VARCHAR2(4000) NOT NULL
)
/
INSERT INTO kcv_settings VALUES ('SCHEMA_VERSION','1')
/
CREATE TABLE kcv_sources (
  version_id VARCHAR2(128) PRIMARY KEY,
  source_id VARCHAR2(32) NOT NULL,
  sha256 VARCHAR2(64) NOT NULL,
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON)
)
/
CREATE TABLE kcv_passages (
  passage_id VARCHAR2(200) PRIMARY KEY,
  version_id VARCHAR2(128) NOT NULL REFERENCES kcv_sources(version_id),
  -- Non-PDF evidence uses locator_kind/locator_label in metadata_json.
  pdf_page NUMBER CHECK (pdf_page>0 AND pdf_page=TRUNC(pdf_page)),
  chunk_index NUMBER NOT NULL CHECK (chunk_index>0),
  text_sha256 VARCHAR2(64) NOT NULL,
  passage_text CLOB NOT NULL,
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON)
)
/
CREATE TABLE kcv_contexts (
  snapshot_id VARCHAR2(128) PRIMARY KEY,
  context_id VARCHAR2(32) NOT NULL,
  snapshot_version NUMBER NOT NULL,
  context_json CLOB NOT NULL CHECK (context_json IS JSON),
  UNIQUE(context_id,snapshot_version)
)
/
CREATE TABLE kcv_graph_runs (
  graph_name VARCHAR2(128) PRIMARY KEY,
  graph_hash VARCHAR2(64) NOT NULL,
  state VARCHAR2(16) NOT NULL CHECK (state IN ('LOADING','READY')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_rdf_stage (
  RDF$STC_SUB VARCHAR2(4000),
  RDF$STC_PRED VARCHAR2(4000),
  RDF$STC_OBJ VARCHAR2(4000)
)
/
CREATE TABLE kcv_graph_sources (
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  version_id VARCHAR2(128) NOT NULL REFERENCES kcv_sources(version_id),
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON),
  PRIMARY KEY(graph_name,version_id)
)
/
CREATE TABLE kcv_graph_contexts (
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  snapshot_id VARCHAR2(128) NOT NULL REFERENCES kcv_contexts(snapshot_id),
  PRIMARY KEY(graph_name,snapshot_id)
)
/
CREATE TABLE kcv_feedback (
  feedback_id VARCHAR2(64) PRIMARY KEY,
  context_snapshot_id VARCHAR2(128) NOT NULL REFERENCES kcv_contexts(snapshot_id),
  graph_name VARCHAR2(128) NOT NULL REFERENCES kcv_graph_runs(graph_name),
  observer VARCHAR2(200) NOT NULL,
  observation CLOB NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
