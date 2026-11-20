-- Explicit user action. Token belongs to this session/revision and expires in 10 minutes.
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.apply_change(:KCV_SESSION_ID,:KCV_PENDING_CHANGE);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
