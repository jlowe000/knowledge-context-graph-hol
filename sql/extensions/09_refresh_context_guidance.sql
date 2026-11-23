-- KCV_LAB, Run Script (F5), after reinstalling 02_scenario_api.sql.
-- Existing installations only. Updates the task instruction without recreating the team.
-- Start a new app conversation afterwards; historical answers are retained unchanged.
BEGIN
  DBMS_CLOUD_AI_AGENT.SET_ATTRIBUTE(
    object_name=>'KCV_SCENARIO_QA_TASK',object_type=>'task',
    attribute_name=>'instruction',attribute_value=>kcv_scenario.qa_instruction);
END;
/
