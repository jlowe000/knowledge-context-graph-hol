CREATE OR REPLACE PACKAGE kcv_trace AUTHID DEFINER AS
 PROCEDURE assert_run(p_request CLOB);
 PROCEDURE record_tool(p_request CLOB,p_tool VARCHAR2,p_output CLOB,p_started TIMESTAMP WITH TIME ZONE,p_error NUMBER DEFAULT NULL);
 FUNCTION response_trace(p_session VARCHAR2,p_turn NUMBER) RETURN CLOB;
END;
