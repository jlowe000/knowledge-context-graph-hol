CREATE TABLE kcv_sources (
  version_id VARCHAR2(128) PRIMARY KEY,
  source_id VARCHAR2(32) NOT NULL,
  sha256 VARCHAR2(64) NOT NULL,
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON)
)
