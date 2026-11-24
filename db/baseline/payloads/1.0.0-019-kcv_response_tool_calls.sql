CREATE TABLE kcv_response_tool_calls (
  call_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  execution_id VARCHAR2(40) NOT NULL REFERENCES kcv_response_runs,
  tool_name VARCHAR2(40) NOT NULL, input_json CLOB NOT NULL CHECK(input_json IS JSON),
  output_json CLOB CHECK(output_json IS JSON), status VARCHAR2(16) NOT NULL, error_code NUMBER,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL, finished_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
 )
