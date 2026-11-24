-- New team; existing KCV_TEAM is retained. Run once as KCV_LAB.
CREATE OR REPLACE FUNCTION kcv_scenario_evidence(p_request CLOB) RETURN CLOB AUTHID DEFINER IS
BEGIN RETURN kcv_scenario.traced_evidence(p_request); END;
/
CREATE OR REPLACE FUNCTION kcv_scenario_propose(p_request CLOB) RETURN CLOB AUTHID DEFINER IS
BEGIN RETURN kcv_scenario.traced_proposal(p_request); END;
/
DECLARE
 profile VARCHAR2(128);qa_task JSON_OBJECT_T;grounded_task JSON_OBJECT_T;
 FUNCTION attrs(p_role VARCHAR2,p_supervisor BOOLEAN DEFAULT FALSE) RETURN CLOB IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put('profile_name',profile);j.put('role',p_role);j.put('enable_human_tool',FALSE);
   IF p_supervisor THEN j.put('supervisor',TRUE);END IF;RETURN j.to_clob();
 END;
BEGIN
 SELECT setting_value INTO profile FROM kcv_settings WHERE setting_key='AI_PROFILE';
 DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name=>'KCV_SCENARIO_EVIDENCE',description=>'Read public evidence and actual topic graph paths for the current scenario',
   attributes=>'{"function":"KCV_SCENARIO_EVIDENCE","instruction":"Pass the original request JSON unchanged.","tool_inputs":[{"name":"p_request","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}');
 DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name=>'KCV_SCENARIO_PROPOSE',description=>'Propose one context edit; never applies a change',
   attributes=>'{"function":"KCV_SCENARIO_PROPOSE","instruction":"Pass the original request JSON unchanged. This tool cannot apply changes.","tool_inputs":[{"name":"p_request","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}');
 qa_task:=JSON_OBJECT_T.parse('{"tools":["KCV_SCENARIO_EVIDENCE"],"enable_human_tool":false}');
 qa_task.put('instruction',kcv_scenario.qa_instruction);
 DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>'KCV_SCENARIO_QA_TASK',attributes=>qa_task.to_clob());
 grounded_task:=JSON_OBJECT_T.parse('{"tools":[],"enable_human_tool":false}');
 grounded_task.put('instruction',kcv_scenario.grounded_instruction);
 DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>'KCV_GROUNDED_QA_TASK',attributes=>grounded_task.to_clob());
 DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>'KCV_SCENARIO_CHANGE_TASK',attributes=>q'~{"instruction":"For {query}, call KCV_SCENARIO_PROPOSE once with the original JSON. Return its proposed_plan JSON unchanged, including any clarification message. State that no change has been applied. The user must inspect and submit a structured refinement outside the agent. Never call another tool, invent a confirmation or claim success.","tools":["KCV_SCENARIO_PROPOSE"],"enable_human_tool":false}~');
 DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>'KCV_SCENARIO_QA',attributes=>attrs('Explain contextual relevance from public evidence and actual graph paths. Read only.'));
 DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>'KCV_SCENARIO_PLANNER',attributes=>attrs('Propose one allowed context change. Never apply or confirm changes.'));
 DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>'KCV_SCENARIO_ROUTER',attributes=>attrs('Route task question to KCV_SCENARIO_QA and task propose_change to KCV_SCENARIO_PLANNER. Pass the full request unchanged to exactly one worker and return its result.',TRUE));
 DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>'KCV_EXPLORER_TEAM',attributes=>'{"supervisor_agent":"KCV_SCENARIO_ROUTER","process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"},{"name":"KCV_SCENARIO_PLANNER","task":"KCV_SCENARIO_CHANGE_TASK"}]}');
 -- Questions already have a known task; execute the QA worker without optional routing.
 DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>'KCV_EVIDENCE_TEAM',attributes=>'{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"}]}');
 -- Application retrieval precedes this answer task; no optional model tool call is needed.
 DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>'KCV_GROUNDED_TEAM',attributes=>'{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_GROUNDED_QA_TASK"}]}');
END;
/
