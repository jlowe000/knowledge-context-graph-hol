CREATE OR REPLACE PACKAGE kcv_context_delete AUTHID DEFINER AS
 FUNCTION status(p_context VARCHAR2) RETURN VARCHAR2;
 FUNCTION preview(p_context VARCHAR2) RETURN CLOB;
 FUNCTION delete_context(p_context VARCHAR2,p_expected_version NUMBER,
   p_expected_head VARCHAR2,p_preview_digest VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
END;
