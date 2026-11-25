-- ADMIN: read-only checks. Run Statement without the final slash.
-- KCV_SCHEMA/KCV_WORKSPACE select the installation; blanks mean KCV_LAB/KCV_KNOWLEDGE.
-- Counts only: no credentials, endpoint URLs or private context rows are returned.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
  l_workspace VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'KCV_KNOWLEDGE');n PLS_INTEGER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
    OR NOT REGEXP_LIKE(l_workspace,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use the chosen KCV_ schema and workspace names');END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema;
  DBMS_OUTPUT.PUT_LINE('KCV_OWNER_EXISTS='||n);
  SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema AND authentication_type='PASSWORD';
  DBMS_OUTPUT.PUT_LINE('KCV_PASSWORD_OWNER='||n);
  SELECT COUNT(*) INTO n FROM dba_registry WHERE comp_id='JAVAVM' AND status='VALID';
  DBMS_OUTPUT.PUT_LINE('KCV_JAVAVM_VALID='||n);
  SELECT COUNT(*) INTO n FROM dba_objects WHERE owner=l_schema AND object_name LIKE 'KCV\_%' ESCAPE '\' AND status='INVALID';
  DBMS_OUTPUT.PUT_LINE('KCV_INVALID_PROJECT_OBJECTS='||n);
  SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=l_workspace AND schema=l_schema;
  DBMS_OUTPUT.PUT_LINE('KCV_WORKSPACE_MAPPED='||n);
  SELECT COUNT(*) INTO n FROM apex_applications WHERE workspace=l_workspace AND owner=l_schema;
  DBMS_OUTPUT.PUT_LINE('KCV_APPS_IN_WORKSPACE='||n);
END;
/
