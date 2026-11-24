CREATE TABLE kcv_context_search_chunks (
 context_id VARCHAR2(32) NOT NULL REFERENCES kcv_personal_contexts(context_id) ON DELETE CASCADE,
 chunk_no NUMBER NOT NULL,
 content_sha256 VARCHAR2(64) NOT NULL,
 model_key VARCHAR2(128) NOT NULL,
 chunk_text VARCHAR2(2000 CHAR) NOT NULL,
 embedding VECTOR(384,FLOAT32),
 embedding_status VARCHAR2(16) NOT NULL,
 error_code NUMBER,
 refreshed_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 PRIMARY KEY(context_id,chunk_no),
 CONSTRAINT kcv_context_search_state_ck CHECK(embedding_status IN('READY','KEYWORD')),
 CONSTRAINT kcv_context_search_vector_ck CHECK(
  (embedding_status='READY' AND embedding IS NOT NULL) OR
  (embedding_status='KEYWORD' AND embedding IS NULL))
)
