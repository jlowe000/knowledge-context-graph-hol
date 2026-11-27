-- Two-connection native test, connection A. Prepared; not an acceptance result.
-- Use the isolated KCV_V2_002/003 owner after canonical schema/setup installation,
-- with maintenance OFF. No model calls or application rows are created.
-- When ADMISSION_HOLDER_READY appears, run the contender in connection B.
SET AUTOCOMMIT OFF
SET SERVEROUTPUT ON
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN('KCV_V2_002','KCV_V2_003')
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR SYS_CONTEXT('APEX$SESSION','APP_ID') IS NOT NULL OR SYS_CONTEXT('APEX$SESSION','APP_USER') IS NOT NULL THEN
  RAISE_APPLICATION_ERROR(-20990,'Use a separate authenticated isolated owner connection');END IF;
 kcv_access.assert_writable;
END;
/
PROMPT ADMISSION_HOLDER_READY: write admission is held until the next commit
BEGIN DBMS_SESSION.SLEEP(30);COMMIT;END;
/
PROMPT ADMISSION_HOLDER_RELEASED
