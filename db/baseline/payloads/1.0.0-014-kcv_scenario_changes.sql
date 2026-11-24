CREATE TABLE kcv_scenario_changes (
 change_token VARCHAR2(40) PRIMARY KEY, session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 expected_revision VARCHAR2(40) NOT NULL, operation VARCHAR2(32) NOT NULL,
 plan_json CLOB NOT NULL CHECK(plan_json IS JSON), state VARCHAR2(16) NOT NULL,
 requested_by VARCHAR2(255) NOT NULL, created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 applied_at TIMESTAMP WITH TIME ZONE, resulting_revision VARCHAR2(40)
)
