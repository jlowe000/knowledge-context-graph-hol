-- No model call. Preview/stage only; inspect returned plan and copy pending_change.
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.stage_change(:KCV_SESSION_ID,:KCV_CHANGE_JSON);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
