CREATE TABLE kcv_response_runs (
  execution_id VARCHAR2(40) PRIMARY KEY, session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
  revision_id VARCHAR2(40) NOT NULL REFERENCES kcv_scenario_revisions, conversation_id VARCHAR2(128) NOT NULL,
  user_turn_id NUMBER NOT NULL REFERENCES kcv_chat_turns, assistant_turn_id NUMBER UNIQUE REFERENCES kcv_chat_turns,
  request_mode VARCHAR2(32) NOT NULL, question CLOB NOT NULL, context_json CLOB NOT NULL CHECK(context_json IS JSON),
  sources_json CLOB NOT NULL CHECK(sources_json IS JSON), history_json CLOB NOT NULL CHECK(history_json IS JSON),
  profile_name VARCHAR2(128), status VARCHAR2(32) NOT NULL, error_code NUMBER,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL, finished_at TIMESTAMP WITH TIME ZONE,
  trace_version VARCHAR2(32) DEFAULT '1.0' NOT NULL,
  retrieval_policy VARCHAR2(128) DEFAULT 'topic-join-v1;6-pages;2-per-source;40-paths' NOT NULL
 )
