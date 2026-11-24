ALTER TABLE kcv_response_tool_calls ADD (
 call_origin VARCHAR2(16) DEFAULT 'LEGACY' NOT NULL,
 CONSTRAINT kcv_evidence_origin_ck CHECK(call_origin IN ('LEGACY','AGENT','APPLICATION'))
)
