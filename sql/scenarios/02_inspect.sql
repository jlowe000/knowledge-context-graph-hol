-- Read-only. Use the scenario session ID, not the agent conversation ID.
SELECT kcv_scenario.state(:KCV_SESSION_ID) AS scenario_state FROM dual
/
SELECT kcv_scenario.evidence_packet(JSON_OBJECT('scenario_session' VALUE :KCV_SESSION_ID)) AS evidence_and_paths FROM dual
/
