-- KCV_LAB: inputs/outputs may contain source passages; keep diagnostic exports local.
SELECT team_exec_id, tool_name, start_date, end_date, output, tool_output
FROM user_ai_agent_tool_history
WHERE team_exec_id IN (SELECT team_exec_id FROM user_ai_agent_team_history WHERE team_name='KCV_TEAM')
ORDER BY start_date DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY
/
