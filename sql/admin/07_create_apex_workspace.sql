-- ADMIN: Run Statement. KCV_SCHEMA/KCV_WORKSPACE select the intended installation.
-- Blank values mean KCV_LAB/KCV_KNOWLEDGE. No accounts or passwords are created.
-- An existing correctly mapped workspace is retained, never replaced or remapped.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
  l_workspace VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'KCV_KNOWLEDGE');
  n PLS_INTEGER;existing_workspace PLS_INTEGER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
    OR NOT REGEXP_LIKE(l_workspace,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use the chosen KCV_ schema and workspace names');END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema;
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20983,'Project owner must already exist');END IF;
  SELECT COUNT(*) INTO existing_workspace FROM apex_workspaces WHERE workspace=l_workspace;
  IF existing_workspace=0 THEN
    SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE schema=l_schema;
    IF n<>0 THEN RAISE_APPLICATION_ERROR(-20989,'Owner is already mapped to another workspace; keep that workspace or inspect the chosen names');END IF;
    APEX_INSTANCE_ADMIN.ADD_WORKSPACE(p_workspace=>l_workspace,p_primary_schema=>l_schema);
  ELSE
    SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=l_workspace AND schema=l_schema;
    IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Existing workspace is not mapped to the chosen owner; nothing was remapped');END IF;
  END IF;
  -- ADB may provision a workspace inactive; enable it explicitly before app import.
  APEX_INSTANCE_ADMIN.ENABLE_WORKSPACE(p_workspace=>l_workspace);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE(CASE WHEN existing_workspace=0 THEN 'KCV_WORKSPACE_CREATED=' ELSE 'KCV_WORKSPACE_RETAINED=' END||l_workspace);
  DBMS_OUTPUT.PUT_LINE('KCV_WORKSPACE_ENABLED='||l_workspace);
END;
/
