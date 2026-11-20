-- Worksheet owner can inspect all lab sessions. APEX exposes only the signed-in session.
SELECT operation,old_revision,new_revision,actor,recorded_at
FROM kcv_scenario_audit WHERE session_id=:KCV_SESSION_ID ORDER BY audit_id
/
SELECT method,observation,next_step,revision_id,recorded_at
FROM kcv_scenario_observations WHERE session_id=:KCV_SESSION_ID ORDER BY observation_id
/
