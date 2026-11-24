-- Read-only migration preflight. Connect as the isolated project schema owner.
-- This is not a profile/credential or source-data probe.
DECLARE
 n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR SYS_CONTEXT('USERENV','SESSION_USER') IN ('ADMIN','SYS','SYSTEM') THEN
  RAISE_APPLICATION_ERROR(-20300,'Connect as the intended project schema owner');
 END IF;
 SELECT COUNT(*) INTO n FROM session_privs
  WHERE privilege IN ('CREATE TABLE','CREATE PROCEDURE');
 IF n<>2 THEN RAISE_APPLICATION_ERROR(-20300,'Missing static schema creation privileges');END IF;
 SELECT COUNT(*) INTO n FROM nls_session_parameters
  WHERE parameter='NLS_LENGTH_SEMANTICS' AND value='BYTE';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20300,'Baseline requires BYTE semantics for unspecified VARCHAR2 lengths');END IF;
 FOR p IN (SELECT 'DBMS_CRYPTO' name FROM dual UNION ALL SELECT 'DBMS_LOCK' FROM dual) LOOP
  SELECT COUNT(*) INTO n FROM all_tab_privs WHERE grantee IN (USER,'PUBLIC')
   AND table_name=p.name AND privilege='EXECUTE';
  IF n=0 THEN RAISE_APPLICATION_ERROR(-20300,'Direct/PUBLIC execute grant required: '||p.name);END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Static migration prerequisite checks passed; native execution and runtime services still require acceptance.');
END;
/
