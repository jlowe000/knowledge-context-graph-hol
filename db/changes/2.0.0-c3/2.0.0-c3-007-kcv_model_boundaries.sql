CREATE TABLE kcv_model_boundaries (
 boundary_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 old_conversation VARCHAR2(128), new_conversation VARCHAR2(128) NOT NULL,
 reason VARCHAR2(32) NOT NULL, old_revision VARCHAR2(40), new_revision VARCHAR2(40),
 history_json CLOB CHECK(history_json IS JSON),
 recorded_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
