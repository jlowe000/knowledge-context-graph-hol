-- ADMIN Worksheet: select DECLARE through END; excluding the slash, Run Statement.
-- Fresh APEX-led installation only. KCV_SCHEMA defaults to KCV_LAB.
-- Creates a schema-only owner with 1G quota on DATA; no password or proxy access.
-- Next run 02_grants.sql and 07_create_apex_workspace.sql with the same owner.
-- For a password-enabled Worksheet owner use 01_create_user_worksheet.sql instead.
-- Existing owners are never changed: retain their names and use the upgrade path.
DECLARE
 s VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
 q VARCHAR2(132);n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'ADMIN'
  OR NVL(SYS_CONTEXT('USERENV','PROXY_USER'),'ADMIN') NOT IN('ADMIN','ORDS_PUBLIC_USER') THEN
  RAISE_APPLICATION_ERROR(-20981,'Use the authenticated ADMIN session and ADMIN schema');END IF;
 IF NOT REGEXP_LIKE(s,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use the intended KCV_ project owner name');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username=s;
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Owner already exists; preserve it and use the upgrade path');END IF;
 SELECT COUNT(*) INTO n FROM dba_registry WHERE comp_id='JAVAVM' AND status='VALID';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20984,'JAVAVM must already be VALID; this script does not enable or restart it');END IF;
 SELECT COUNT(*) INTO n FROM dba_tablespaces WHERE tablespace_name='DATA' AND contents='PERMANENT' AND status='ONLINE';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20985,'The online DATA tablespace is required');END IF;
 q:=DBMS_ASSERT.ENQUOTE_NAME(s,FALSE);
 EXECUTE IMMEDIATE 'CREATE USER '||q||' NO AUTHENTICATION QUOTA 1G ON DATA';
 DBMS_OUTPUT.PUT_LINE('KCV_APEX_OWNER_CREATED='||s);
END;
/
