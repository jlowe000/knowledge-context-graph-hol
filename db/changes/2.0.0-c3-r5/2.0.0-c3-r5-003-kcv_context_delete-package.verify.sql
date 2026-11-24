l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE kcv_context_delete AUTHID DEFINER AS
 FUNCTION status(p_context VARCHAR2) RETURN VARCHAR2;
 FUNCTION preview(p_context VARCHAR2) RETURN CLOB;
 FUNCTION delete_context(p_context VARCHAR2,p_expected_version NUMBER,
   p_expected_head VARCHAR2,p_preview_digest VARCHAR2,p_request_token VARCHAR2) RETURN CLOB;
END;
');
 check_program('KCV_CONTEXT_DELETE','PACKAGE',l_expected);
