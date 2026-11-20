-- Record an actual observation, not an invented successful outcome.
BEGIN
  kcv_scenario.observe(:KCV_SESSION_ID,:KCV_METHOD,:KCV_OBSERVATION,:KCV_NEXT_STEP);
END;
/
