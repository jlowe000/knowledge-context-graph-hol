-- KCV_LAB: each statement below invokes model reasoning. Run individually.
-- First run 00_create_conversation.sql and copy its returned ID.
-- Select each SELECT through FROM dual, excluding slash; use Run Statement.
-- Supply the returned ID for the KCV_CONVERSATION_ID bind. Do not invent an ID.
SELECT DBMS_CLOUD_AI_AGENT.RUN_TEAM(team_name=>'KCV_TEAM',
  user_prompt=>'{"task":"clarify_context","context_id":"CTX01"}',
  params=>JSON_OBJECT('conversation_id' VALUE :KCV_CONVERSATION_ID)) AS agent_response FROM dual
/
SELECT DBMS_CLOUD_AI_AGENT.RUN_TEAM(team_name=>'KCV_TEAM',
  user_prompt=>'{"task":"assess_context","context_id":"CTX03","question":"What does this material establish about regional availability?"}',
  params=>JSON_OBJECT('conversation_id' VALUE :KCV_CONVERSATION_ID)) AS agent_response FROM dual
/
