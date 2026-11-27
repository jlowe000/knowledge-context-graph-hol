-- ADMIN Worksheet, Run Statement: KCV_INSTALLER_USER defaults to KCV_INSTALLER.
-- Enter KCV_BUILDER_PASSWORD privately; use the intended workspace installer name.
-- Creates only a database login for ADB's Builder SSO. Workspace roles/accounts
-- are separate. Existing accounts are not reset or granted new privileges.
DECLARE
 u VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_INSTALLER_USER)),'KCV_INSTALLER');
 p VARCHAR2(128):=:KCV_BUILDER_PASSWORD;n NUMBER;q VARCHAR2(132);
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'ADMIN'
  OR NVL(SYS_CONTEXT('USERENV','PROXY_USER'),'ADMIN') NOT IN('ADMIN','ORDS_PUBLIC_USER') THEN
  RAISE_APPLICATION_ERROR(-20981,'Use the authenticated ADMIN session and ADMIN schema');END IF;
 IF NOT REGEXP_LIKE(u,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use the intended KCV_ workspace installer username');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username=u;
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Installer database login exists; verify its access instead of recreating it');END IF;
 IF p IS NULL OR NOT REGEXP_LIKE(p,'^[A-Za-z0-9_!#$%*+.-]{12,64}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use 12-64 letters, numbers or _ ! # $ % * + . -; database complexity rules also apply');END IF;
 q:=DBMS_ASSERT.ENQUOTE_NAME(u,FALSE);
 EXECUTE IMMEDIATE 'CREATE USER '||q||' IDENTIFIED BY "'||p||'"';
 p:=NULL;
 EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO '||q;
 DBMS_OUTPUT.PUT_LINE('Installer database login created with CREATE SESSION only. Workspace roles are separate.');
EXCEPTION WHEN OTHERS THEN p:=NULL;RAISE;
END;
/
