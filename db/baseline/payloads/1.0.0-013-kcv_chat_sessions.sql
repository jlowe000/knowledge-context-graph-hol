CREATE TABLE kcv_chat_sessions (
 session_id VARCHAR2(40) PRIMARY KEY, owner_name VARCHAR2(255) NOT NULL,
 apex_app_id VARCHAR2(32), apex_session_id VARCHAR2(64), conversation_id VARCHAR2(128) NOT NULL,
 context_id VARCHAR2(32) NOT NULL, revision_id VARCHAR2(40) NOT NULL REFERENCES kcv_scenario_revisions,
 mutation_token VARCHAR2(40),
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
