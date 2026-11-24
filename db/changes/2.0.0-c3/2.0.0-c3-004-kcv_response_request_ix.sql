CREATE UNIQUE INDEX kcv_response_request_ix ON kcv_response_runs(
 CASE WHEN request_token IS NOT NULL THEN session_id END,request_token)
