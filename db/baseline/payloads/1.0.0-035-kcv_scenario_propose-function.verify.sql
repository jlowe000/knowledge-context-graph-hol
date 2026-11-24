 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('FUNCTION kcv_scenario_propose(p_request CLOB) RETURN CLOB AUTHID DEFINER IS
BEGIN RETURN kcv_scenario.traced_proposal(p_request); END;
');
 check_program('KCV_SCENARIO_PROPOSE','FUNCTION',l_expected);
