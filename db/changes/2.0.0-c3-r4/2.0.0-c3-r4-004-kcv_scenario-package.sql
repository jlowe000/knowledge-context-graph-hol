CREATE OR REPLACE PACKAGE kcv_scenario AUTHID DEFINER AS
 FUNCTION actor RETURN VARCHAR2;
 FUNCTION open_session(p_context VARCHAR2) RETURN VARCHAR2;
 FUNCTION context_packet(p_request CLOB) RETURN CLOB;
 FUNCTION qa_instruction RETURN CLOB;
 FUNCTION grounded_instruction RETURN CLOB;
 FUNCTION evidence_packet(p_request CLOB) RETURN CLOB;
 FUNCTION traced_evidence(p_request CLOB) RETURN CLOB;
 FUNCTION traced_proposal(p_request CLOB) RETURN CLOB;
 FUNCTION propose_change(p_request CLOB) RETURN CLOB;
 FUNCTION stage_change(p_session VARCHAR2,p_plan CLOB) RETURN CLOB;
 FUNCTION apply_change(p_session VARCHAR2,p_token VARCHAR2) RETURN CLOB;
 FUNCTION ask(p_session VARCHAR2,p_message CLOB,p_mode VARCHAR2 DEFAULT 'question',p_request_token VARCHAR2 DEFAULT NULL) RETURN CLOB;
 FUNCTION state(p_session VARCHAR2) RETURN CLOB;
 PROCEDURE observe(p_session VARCHAR2,p_method VARCHAR2,p_observation CLOB,p_next_step CLOB DEFAULT NULL,p_request_token VARCHAR2 DEFAULT NULL);
END;
