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
