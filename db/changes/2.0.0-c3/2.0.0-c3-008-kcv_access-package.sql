CREATE OR REPLACE PACKAGE kcv_access AUTHID DEFINER AS
 PROCEDURE capture_identity;
 FUNCTION owner_scope RETURN VARCHAR2;
 FUNCTION owner_subject RETURN VARCHAR2;
 PROCEDURE assert_context(p_context VARCHAR2);
 PROCEDURE assert_session(p_session VARCHAR2,p_write BOOLEAN DEFAULT FALSE);
 PROCEDURE assert_writable;
 FUNCTION topic_options(p_graph VARCHAR2) RETURN CLOB;
 PROCEDURE assert_topic(p_graph VARCHAR2,p_label VARCHAR2);
END;
