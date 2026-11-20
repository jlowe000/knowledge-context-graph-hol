-- Model call. Run Statement on DECLARE through END; excludes slash.
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_scenario.ask(:KCV_SESSION_ID,:KCV_QUESTION,'question');
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
