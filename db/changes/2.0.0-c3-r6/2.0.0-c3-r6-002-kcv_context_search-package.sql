CREATE OR REPLACE PACKAGE kcv_context_search AUTHID DEFINER AS
 FUNCTION document_text(p_title VARCHAR2,p_body CLOB) RETURN CLOB;
 FUNCTION objective_preview(p_body CLOB) RETURN VARCHAR2;
 PROCEDURE refresh_context(p_context VARCHAR2);
 PROCEDURE reindex_all;
 FUNCTION search_contexts(p_status VARCHAR2,p_search VARCHAR2,
   p_before_id VARCHAR2 DEFAULT NULL,p_limit NUMBER DEFAULT 20) RETURN CLOB;
END;
