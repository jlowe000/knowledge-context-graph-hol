-- ADMIN: bind KCV_DEV_SCHEMA and KCV_DEV_WORKSPACE to upper-case KCV_ identifiers.
-- The schema must be the unmapped, schema-only dev owner. No APEX accounts are created.
DECLARE
  l_schema VARCHAR2(128):=:KCV_DEV_SCHEMA;
  l_workspace VARCHAR2(128):=:KCV_DEV_WORKSPACE;
  l_count PLS_INTEGER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');
  END IF;
  IF l_schema IS NULL OR NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
    OR l_workspace IS NULL OR NOT REGEXP_LIKE(l_workspace,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use upper-case KCV_ identifiers of 5 to 30 characters');
  END IF;
  SELECT COUNT(*) INTO l_count FROM apex_workspaces WHERE workspace=l_workspace;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20987,'Target workspace already exists; nothing was changed');END IF;
  SELECT COUNT(*) INTO l_count FROM dba_users WHERE username=l_schema AND authentication_type='NONE';
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20988,'Create the schema-only dev owner first');END IF;
  SELECT COUNT(*) INTO l_count FROM proxy_users WHERE proxy='ADMIN' AND client=l_schema;
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20988,'The dev owner must have its explicit ADMIN proxy grant');END IF;
  SELECT COUNT(*) INTO l_count FROM apex_workspace_schemas WHERE schema=l_schema;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20989,'Schema is already mapped; existing workspaces are preserved');END IF;
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(p_workspace=>l_workspace,p_primary_schema=>l_schema);
  -- ADB can leave the newly provisioned workspace inactive until enabled.
  APEX_INSTANCE_ADMIN.ENABLE_WORKSPACE(p_workspace=>l_workspace);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('KCV_DEV_WORKSPACE_CREATED='||l_workspace);
  DBMS_OUTPUT.PUT_LINE('KCV_DEV_WORKSPACE_ENABLED='||l_workspace);
END;
/
