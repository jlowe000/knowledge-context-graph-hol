CREATE OR REPLACE FUNCTION kcv_scenario_propose(p_request CLOB) RETURN CLOB AUTHID DEFINER IS
BEGIN RETURN kcv_scenario.traced_proposal(p_request); END;
