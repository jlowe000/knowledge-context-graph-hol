CREATE TABLE kcv_personal_operations (
 operation_id VARCHAR2(40) PRIMARY KEY,
 context_id VARCHAR2(32) NOT NULL REFERENCES kcv_personal_contexts,
 session_id VARCHAR2(40), action VARCHAR2(32) NOT NULL,
 request_sha256 VARCHAR2(64) NOT NULL,
 expected_version NUMBER NOT NULL, expected_head VARCHAR2(40), expected_revision VARCHAR2(40),
 target_graph VARCHAR2(128) NOT NULL, body_json CLOB NOT NULL CHECK(body_json IS JSON),
 phase VARCHAR2(20) DEFAULT 'PREVIEW' NOT NULL,
 revision_id VARCHAR2(40), overlay_graph VARCHAR2(128), model_conversation_id VARCHAR2(128), error_code NUMBER,
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 finished_at TIMESTAMP WITH TIME ZONE,
 CONSTRAINT kcv_personal_op_phase CHECK(phase IN ('PREVIEW','BUILDING','READY','APPLIED','FAILED','ABANDONED'))
)
