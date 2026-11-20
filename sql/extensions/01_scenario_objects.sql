-- KCV_LAB, once. Additive extension: does not replace the working initial lab.
CREATE TABLE kcv_scenario_revisions (
 revision_id VARCHAR2(40) PRIMARY KEY, parent_revision VARCHAR2(40),
 context_id VARCHAR2(32) NOT NULL, base_graph VARCHAR2(128) NOT NULL,
 overlay_graph VARCHAR2(128) NOT NULL UNIQUE, context_json CLOB NOT NULL CHECK(context_json IS JSON),
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_chat_sessions (
 session_id VARCHAR2(40) PRIMARY KEY, owner_name VARCHAR2(255) NOT NULL,
 apex_app_id VARCHAR2(32), apex_session_id VARCHAR2(64), conversation_id VARCHAR2(128) NOT NULL,
 context_id VARCHAR2(32) NOT NULL, revision_id VARCHAR2(40) NOT NULL REFERENCES kcv_scenario_revisions,
 mutation_token VARCHAR2(40),
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_scenario_changes (
 change_token VARCHAR2(40) PRIMARY KEY, session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 expected_revision VARCHAR2(40) NOT NULL, operation VARCHAR2(32) NOT NULL,
 plan_json CLOB NOT NULL CHECK(plan_json IS JSON), state VARCHAR2(16) NOT NULL,
 requested_by VARCHAR2(255) NOT NULL, created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 applied_at TIMESTAMP WITH TIME ZONE, resulting_revision VARCHAR2(40)
)
/
CREATE TABLE kcv_scenario_audit (
 audit_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, session_id VARCHAR2(40) NOT NULL,
 actor VARCHAR2(255) NOT NULL, operation VARCHAR2(32) NOT NULL, old_revision VARCHAR2(40),
 new_revision VARCHAR2(40), details CLOB, recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_chat_turns (
 turn_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 revision_id VARCHAR2(40) NOT NULL, role VARCHAR2(16) NOT NULL, body CLOB NOT NULL,
 recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_scenario_observations (
 observation_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions, revision_id VARCHAR2(40) NOT NULL,
 actor VARCHAR2(255) NOT NULL, method VARCHAR2(32) NOT NULL,
 observation CLOB NOT NULL, next_step CLOB, recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
