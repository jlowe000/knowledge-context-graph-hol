CREATE TABLE kcv_passages (
  passage_id VARCHAR2(200) PRIMARY KEY,
  version_id VARCHAR2(128) NOT NULL REFERENCES kcv_sources(version_id),
  pdf_page NUMBER CHECK (pdf_page>0 AND pdf_page=TRUNC(pdf_page)),
  chunk_index NUMBER NOT NULL CHECK (chunk_index>0),
  text_sha256 VARCHAR2(64) NOT NULL,
  passage_text CLOB NOT NULL,
  metadata_json CLOB NOT NULL CHECK (metadata_json IS JSON)
)
