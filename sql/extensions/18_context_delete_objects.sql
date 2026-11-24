-- Deletion is recoverable, not a transaction spanning native RDF/AI DDL.
-- Keep the manifest until all native resources and application rows are removed.
-- The final receipt retains identifiers/counts only, never context or answer text.
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
/
CREATE TABLE kcv_context_delete_resources (
 context_id VARCHAR2(32) NOT NULL REFERENCES kcv_context_deletions(context_id),
 resource_kind VARCHAR2(16) NOT NULL,
 resource_id VARCHAR2(128) NOT NULL,
 status VARCHAR2(16) DEFAULT 'PENDING' NOT NULL,
 finished_at TIMESTAMP WITH TIME ZONE,
 PRIMARY KEY (context_id,resource_kind,resource_id),
 CONSTRAINT kcv_delete_kind_ck CHECK (resource_kind IN ('OVERLAY','CONVERSATION')),
 CONSTRAINT kcv_delete_res_status_ck CHECK (status IN ('PENDING','REMOVED'))
)
/
