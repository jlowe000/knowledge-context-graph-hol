ALTER TABLE kcv_chat_sessions ADD (
 personal_context_id VARCHAR2(32) REFERENCES kcv_personal_contexts,
 model_revision_id VARCHAR2(40)
)
