 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('FUNCTION kcv_scenario_evidence(p_request CLOB) RETURN CLOB AUTHID DEFINER IS
BEGIN RETURN kcv_scenario.traced_evidence(p_request); END;
');
 check_program('KCV_SCENARIO_EVIDENCE','FUNCTION',l_expected);
