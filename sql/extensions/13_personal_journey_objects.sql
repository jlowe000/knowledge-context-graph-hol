-- Private personal-context runtime state; never included in dataset exports.
ALTER TABLE kcv_chat_sessions ADD (
 personal_context_id VARCHAR2(32) REFERENCES kcv_personal_contexts,
 model_revision_id VARCHAR2(40)
)
/
CREATE INDEX kcv_chat_personal_ix ON kcv_chat_sessions(personal_context_id,created_at)
/
ALTER TABLE kcv_response_runs ADD (
 request_token VARCHAR2(40), request_sha256 VARCHAR2(64),
 continuation_json CLOB CHECK (continuation_json IS JSON)
)
/
CREATE UNIQUE INDEX kcv_response_request_ix ON kcv_response_runs(
 CASE WHEN request_token IS NOT NULL THEN session_id END,request_token)
/
CREATE TABLE kcv_context_attachments (
 session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 owner_scope VARCHAR2(128) NOT NULL, owner_subject VARCHAR2(128) NOT NULL,
 apex_session_id VARCHAR2(64) NOT NULL,
 attached_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 PRIMARY KEY(session_id,owner_scope,owner_subject,apex_session_id)
)
/
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
/
CREATE TABLE kcv_model_boundaries (
 boundary_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 old_conversation VARCHAR2(128), new_conversation VARCHAR2(128) NOT NULL,
 reason VARCHAR2(32) NOT NULL, old_revision VARCHAR2(40), new_revision VARCHAR2(40),
 history_json CLOB CHECK(history_json IS JSON),
 recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
