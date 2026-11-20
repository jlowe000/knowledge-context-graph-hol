-- KCV_LAB: Run Statement on BEGIN through END; without slash. Copy returned ID.
BEGIN
  DBMS_OUTPUT.PUT_LINE(kcv_scenario.open_session(:KCV_CONTEXT_ID));
END;
/
