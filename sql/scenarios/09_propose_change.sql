-- Optional model-backed proposal through the change worker; cannot apply edits.
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.ask(:KCV_SESSION_ID,:KCV_QUESTION,'propose_change');
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
