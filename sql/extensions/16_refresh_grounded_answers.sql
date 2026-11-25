-- Lab owner, after the matching scenario API migration. Safe to repeat.
-- Keeps existing teams, tools and conversations; no inference or data changes.
-- Schema-only installs defer registration to 03_scenario_agents.sql after model setup.
DECLARE
  qa_count PLS_INTEGER;
  task_count PLS_INTEGER;
  team_count PLS_INTEGER;
  task_attributes JSON_OBJECT_T:=JSON_OBJECT_T.parse('{"tools":[],"enable_human_tool":false}');
BEGIN
  SELECT COUNT(*) INTO qa_count FROM user_ai_agents WHERE agent_name='KCV_SCENARIO_QA';
  IF qa_count=0 THEN
    DBMS_OUTPUT.PUT_LINE('Grounded answers deferred: run 03_scenario_agents.sql after configuring the model profile.');
  ELSE
    task_attributes.put('instruction',kcv_scenario.grounded_instruction);
    SELECT COUNT(*) INTO task_count FROM user_ai_agent_tasks WHERE task_name='KCV_GROUNDED_QA_TASK';
    IF task_count=0 THEN
      DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>'KCV_GROUNDED_QA_TASK',attributes=>task_attributes.to_clob());
    ELSE
      DBMS_CLOUD_AI_AGENT.SET_ATTRIBUTES(object_name=>'KCV_GROUNDED_QA_TASK',object_type=>'task',attributes=>task_attributes.to_clob());
    END IF;
    SELECT COUNT(*) INTO team_count FROM user_ai_agent_teams WHERE agent_team_name='KCV_GROUNDED_TEAM';
    IF team_count=0 THEN
      DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>'KCV_GROUNDED_TEAM',
        attributes=>'{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_GROUNDED_QA_TASK"}]}');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Grounded answers ready: the application retrieves evidence before the answer task.');
  END IF;
END;
/
