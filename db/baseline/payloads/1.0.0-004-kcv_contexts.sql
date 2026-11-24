CREATE TABLE kcv_contexts (
  snapshot_id VARCHAR2(128) PRIMARY KEY,
  context_id VARCHAR2(32) NOT NULL,
  snapshot_version NUMBER NOT NULL,
  context_json CLOB NOT NULL CHECK (context_json IS JSON),
  UNIQUE(context_id,snapshot_version)
)
