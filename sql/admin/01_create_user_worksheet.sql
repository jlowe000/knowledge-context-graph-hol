-- ADMIN: select DECLARE through END; use Run Statement, without the final slash.
-- KCV_SCHEMA: chosen KCV_ owner name; blank means KCV_LAB.
-- KCV_LAB_PASSWORD: enter privately in the bind dialog. Never save it in SQL/Git.
-- Creates a password-enabled owner for Database Actions; no proxy is granted.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
  l_password VARCHAR2(128):=:KCV_LAB_PASSWORD;
  l_target VARCHAR2(132);
  l_count NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use a KCV_ owner name of 5 to 30 letters, digits or underscores');END IF;
  l_target:=DBMS_ASSERT.ENQUOTE_NAME(l_schema,FALSE);
  IF l_password IS NULL OR NOT REGEXP_LIKE(l_password,'^[A-Za-z0-9_!#$%*+.-]{12,64}$','c') THEN
    RAISE_APPLICATION_ERROR(-20010,'Supply a 12-64 character lab password, without quotes or whitespace');
  END IF;
  SELECT COUNT(*) INTO l_count FROM dba_users WHERE username=l_schema;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20011,'Chosen owner already exists; use the migration path instead of creating or resetting it');END IF;
  SELECT COUNT(*) INTO l_count FROM dba_tablespaces WHERE tablespace_name='DATA' AND contents='PERMANENT' AND status='ONLINE';
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20985,'The online DATA tablespace is required');END IF;
  EXECUTE IMMEDIATE 'CREATE USER '||l_target||' IDENTIFIED BY "'||l_password||'" QUOTA 1G ON DATA';
  l_password:=NULL;
  DBMS_OUTPUT.PUT_LINE('KCV_OWNER_CREATED='||l_schema);
EXCEPTION WHEN OTHERS THEN l_password:=NULL;RAISE;
END;
/
