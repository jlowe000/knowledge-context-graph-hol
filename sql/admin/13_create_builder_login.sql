-- ADMIN Worksheet, Run Statement: enter KCV_BUILDER_PASSWORD privately.
-- Creates only a database login for ADB's Builder SSO. Workspace roles/accounts
-- are separate. Existing accounts are not reset or granted new privileges.
DECLARE
 p VARCHAR2(128):=:KCV_BUILDER_PASSWORD;n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
  RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username='KCV_INSTALLER';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'KCV_INSTALLER exists; verify its current access instead of recreating it');END IF;
 IF p IS NULL OR NOT REGEXP_LIKE(p,'^[A-Za-z0-9_!#$%*+.-]{12,64}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use 12-64 letters, numbers or _ ! # $ % * + . -; database complexity rules also apply');END IF;
 EXECUTE IMMEDIATE 'CREATE USER KCV_INSTALLER IDENTIFIED BY "'||p||'"';
 p:=NULL;
 EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO KCV_INSTALLER';
 DBMS_OUTPUT.PUT_LINE('KCV_INSTALLER database login created with CREATE SESSION only.');
EXCEPTION WHEN OTHERS THEN p:=NULL;RAISE;
END;
/
