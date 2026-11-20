-- KCV_LAB: run in a second Worksheet/session; does not start model calls.
SELECT team_exec_id, state, start_date, end_date
FROM user_ai_agent_team_history
WHERE team_name='KCV_TEAM'
ORDER BY start_date DESC NULLS LAST
FETCH FIRST 10 ROWS ONLY
/
