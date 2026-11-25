-- ADMIN: permit only the named project schema to load its own embedding model.
-- Run Statement. KCV_SCHEMA is the intended existing owner; blank means KCV_LAB.
-- No model, directory, external credential or network ACL is created here.
DECLARE
 l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
 l_target VARCHAR2(132);n PLS_INTEGER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
  RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
 IF l_schema IS NULL OR NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use an upper-case project schema identifier');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20983,'Project schema must already exist');END IF;
 l_target:=DBMS_ASSERT.ENQUOTE_NAME(l_schema,FALSE);
 EXECUTE IMMEDIATE 'GRANT CREATE MINING MODEL TO '||l_target;
 EXECUTE IMMEDIATE 'GRANT EXECUTE ON SYS.DBMS_VECTOR TO '||l_target;
 DBMS_OUTPUT.PUT_LINE('Context search model privileges ready.');
 DBMS_OUTPUT.PUT_LINE('KCV_CONTEXT_SEARCH_GRANTS_READY='||l_schema);
END;
/
