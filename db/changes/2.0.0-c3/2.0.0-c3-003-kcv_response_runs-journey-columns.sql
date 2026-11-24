ALTER TABLE kcv_response_runs ADD (
 request_token VARCHAR2(40), request_sha256 VARCHAR2(64),
 continuation_json CLOB CHECK (continuation_json IS JSON)
)
