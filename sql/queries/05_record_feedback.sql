-- KCV_LAB: replace NULL values with an actual observer/observation before running.
DECLARE
  l_observer VARCHAR2(200):=NULL;
  l_observation CLOB:=NULL;
  l_context VARCHAR2(32):='CTX01';
BEGIN
  IF l_observer IS NULL OR l_observation IS NULL THEN
    RAISE_APPLICATION_ERROR(-20013,'Record your actual observation; no pre-written success is supplied');
  END IF;
  INSERT INTO kcv_feedback(feedback_id,context_snapshot_id,graph_name,observer,observation)
    SELECT RAWTOHEX(SYS_GUID()),gc.snapshot_id,gc.graph_name,l_observer,l_observation
    FROM kcv_graph_contexts gc JOIN kcv_contexts c ON c.snapshot_id=gc.snapshot_id
    JOIN kcv_settings a ON a.setting_key='ACTIVE_GRAPH' AND a.setting_value=gc.graph_name
    WHERE c.context_id=l_context;
  IF SQL%ROWCOUNT<>1 THEN RAISE_APPLICATION_ERROR(-20014,'Expected exactly one active context snapshot'); END IF;
  COMMIT;
END;
/
