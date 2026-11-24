CREATE TABLE kcv_context_requests (
 owner_scope VARCHAR2(128) NOT NULL,
 owner_subject VARCHAR2(128) NOT NULL,
 request_token VARCHAR2(80) NOT NULL,
 action VARCHAR2(32) NOT NULL,
 payload_sha256 VARCHAR2(64) NOT NULL,
 result_json CLOB CHECK (result_json IS JSON),
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 CONSTRAINT kcv_context_requests_pk PRIMARY KEY(owner_scope,owner_subject,request_token)
)
