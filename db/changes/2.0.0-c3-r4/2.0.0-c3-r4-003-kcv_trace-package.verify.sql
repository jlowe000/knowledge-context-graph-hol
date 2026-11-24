l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE kcv_trace AUTHID DEFINER AS
 PROCEDURE assert_run(p_request CLOB);
 PROCEDURE record_tool(p_request CLOB,p_tool VARCHAR2,p_output CLOB,p_started TIMESTAMP WITH TIME ZONE,p_error NUMBER DEFAULT NULL,p_origin VARCHAR2 DEFAULT ''AGENT'');
 FUNCTION response_trace(p_session VARCHAR2,p_turn NUMBER) RETURN CLOB;
END;
');
 check_program('KCV_TRACE','PACKAGE',l_expected);
