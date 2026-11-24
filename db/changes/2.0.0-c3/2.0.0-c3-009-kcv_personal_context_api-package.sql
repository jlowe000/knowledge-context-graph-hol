CREATE OR REPLACE PACKAGE kcv_personal_context_api AUTHID DEFINER AS
 FUNCTION validate_body(p_body CLOB,p_graph VARCHAR2) RETURN CLOB;
 FUNCTION list_contexts(p_status VARCHAR2 DEFAULT NULL,p_search VARCHAR2 DEFAULT NULL,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB;
 FUNCTION get_context(p_context VARCHAR2) RETURN CLOB;
 FUNCTION topic_options(p_context VARCHAR2 DEFAULT NULL) RETURN CLOB;
 FUNCTION save_draft(p_context VARCHAR2,p_title VARCHAR2,p_body CLOB,
   p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION duplicate_context(p_context VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION copy_sample(p_sample VARCHAR2,p_title VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION archive_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
 FUNCTION restore_context(p_context VARCHAR2,p_expected_version NUMBER,p_request_token VARCHAR2) RETURN CLOB;
END;
