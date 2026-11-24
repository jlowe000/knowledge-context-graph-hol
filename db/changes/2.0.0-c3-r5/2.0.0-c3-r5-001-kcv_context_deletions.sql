CREATE TABLE kcv_context_deletions (
 context_id VARCHAR2(32) PRIMARY KEY,
 owner_scope VARCHAR2(128) NOT NULL,
 owner_subject VARCHAR2(128) NOT NULL,
 status VARCHAR2(16) DEFAULT 'PENDING' NOT NULL,
 request_token VARCHAR2(80) NOT NULL,
 expected_version NUMBER NOT NULL,
 expected_head VARCHAR2(40),
 preview_digest VARCHAR2(64) NOT NULL,
 title VARCHAR2(200 CHAR),
 counts_json CLOB NOT NULL CHECK (counts_json IS JSON),
 error_code NUMBER,
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 finished_at TIMESTAMP WITH TIME ZONE,
 CONSTRAINT kcv_delete_status_ck CHECK (status IN ('PENDING','DELETED')),
 CONSTRAINT kcv_delete_token_uq UNIQUE (owner_scope,owner_subject,request_token)
)
