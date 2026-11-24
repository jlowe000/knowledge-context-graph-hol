-- Maintained migration inputs. Apply through the dev migration route.
-- Existing events do not claim a newly observed application/agent origin.
ALTER TABLE kcv_response_tool_calls ADD (
 call_origin VARCHAR2(16) DEFAULT 'LEGACY' NOT NULL,
 CONSTRAINT kcv_evidence_origin_ck CHECK(call_origin IN ('LEGACY','AGENT','APPLICATION'))
)
/
ALTER TABLE kcv_response_runs ADD (
 model_started_at TIMESTAMP WITH TIME ZONE
)
/
