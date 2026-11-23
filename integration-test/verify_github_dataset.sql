-- KCV_LAB, after the first GitHub load succeeds. Run Script (F5).
-- Uses the latest successful public repository/default-owner load.
-- Makes anonymous HTTPS requests and adds expected test records to the run log.
-- No model inference, credentials or destructive reset is required.
DECLARE
  l_ref VARCHAR2(40); l_hash VARCHAR2(64); l_graph VARCHAR2(128);
  l_before VARCHAR2(128); l_after VARCHAR2(128); l_phase VARCHAR2(128);
  l_rejected BOOLEAN := FALSE;
BEGIN
  SELECT source_ref,manifest_sha256,graph_name INTO l_ref,l_hash,l_graph
    FROM kcv_dataset_runs WHERE status='SUCCEEDED'
    ORDER BY completed_at DESC FETCH FIRST 1 ROW ONLY;
  SELECT setting_value INTO l_before FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
  IF l_before<>l_graph THEN
    RAISE_APPLICATION_ERROR(-20080,'Run immediately after the intended GitHub load');
  END IF;

  -- Repeating the same immutable manifest must reuse its ready graph.
  kcv_dataset.load_github(l_ref,l_hash);
  SELECT setting_value INTO l_after FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
  SELECT phase INTO l_phase FROM kcv_dataset_runs WHERE status='SUCCEEDED'
    ORDER BY completed_at DESC FETCH FIRST 1 ROW ONLY;
  IF l_after<>l_before OR l_phase<>'REUSED_READY_GRAPH' THEN
    RAISE_APPLICATION_ERROR(-20081,'Repeat load did not reuse the ready graph');
  END IF;

  BEGIN
    kcv_dataset.load_github('release',l_hash);
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE=-20070 THEN l_rejected:=TRUE; ELSE RAISE; END IF;
  END;
  IF NOT l_rejected THEN RAISE_APPLICATION_ERROR(-20082,'Mutable branch ref was accepted'); END IF;

  -- Wrong manifest digest must fail before changing active data.
  l_rejected:=FALSE;
  BEGIN
    kcv_dataset.load_github(l_ref,RPAD('0',64,'0'));
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE=-20070 THEN l_rejected:=TRUE; ELSE RAISE; END IF;
  END;
  SELECT setting_value INTO l_after FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
  IF NOT l_rejected OR l_after<>l_before THEN
    RAISE_APPLICATION_ERROR(-20083,'Digest failure did not preserve the active graph');
  END IF;
  -- A good retry verifies that the failed request released its session lock.
  kcv_dataset.load_github(l_ref,l_hash);
  DBMS_OUTPUT.PUT_LINE('PASS: repeat load, immutable ref, digest rejection and retry');
END;
/
