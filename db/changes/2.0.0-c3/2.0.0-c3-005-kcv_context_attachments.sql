CREATE TABLE kcv_context_attachments (
 session_id VARCHAR2(40) NOT NULL REFERENCES kcv_chat_sessions,
 owner_scope VARCHAR2(128) NOT NULL, owner_subject VARCHAR2(128) NOT NULL,
 apex_session_id VARCHAR2(64) NOT NULL,
 attached_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
 PRIMARY KEY(session_id,owner_scope,owner_subject,apex_session_id)
)
