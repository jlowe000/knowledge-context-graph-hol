-- Lab owner, after 02_scenario_api.sql. Safe to repeat; keeps conversations and old teams.
-- Schema-only installs defer agent registration to 03_scenario_agents.sql after model setup.
DECLARE
  qa_count PLS_INTEGER;
  team_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO qa_count FROM user_ai_agents WHERE agent_name='KCV_SCENARIO_QA';
  IF qa_count=0 THEN
    DBMS_OUTPUT.PUT_LINE('Evidence routing deferred: run 03_scenario_agents.sql after configuring the model profile.');
  ELSE
    DBMS_CLOUD_AI_AGENT.SET_ATTRIBUTE(
      object_name=>'KCV_SCENARIO_QA_TASK',object_type=>'task',
      attribute_name=>'instruction',attribute_value=>kcv_scenario.qa_instruction);
    SELECT COUNT(*) INTO team_count FROM user_ai_agent_teams WHERE agent_team_name='KCV_EVIDENCE_TEAM';
    IF team_count=0 THEN
      DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>'KCV_EVIDENCE_TEAM',
        attributes=>'{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"}]}');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Evidence routing ready: questions use the QA worker; proposal routing is unchanged.');
  END IF;
END;
/
