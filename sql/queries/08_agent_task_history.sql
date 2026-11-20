-- KCV_LAB: correlate TEAM_EXEC_ID with the progress query.
SELECT team_exec_id, agent_name, task_name, state, start_date, end_date, result
FROM user_ai_agent_task_history
WHERE team_name='KCV_TEAM'
ORDER BY start_date DESC NULLS LAST, task_order DESC
FETCH FIRST 20 ROWS ONLY
/
