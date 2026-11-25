-- Optional ADMIN path for OCI Generative AI authentication on ADB Serverless.
-- First configure the ADB dynamic group and compartment-scoped inference policy.
-- Run Statement. KCV_SCHEMA is the chosen existing owner; blank means KCV_LAB.
-- Skip this optional block when using the user-credential authentication path.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');n PLS_INTEGER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use the chosen KCV_ project owner name');END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema;
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20983,'Project owner must already exist');END IF;
  DBMS_CLOUD_ADMIN.ENABLE_RESOURCE_PRINCIPAL(username=>l_schema);
  DBMS_OUTPUT.PUT_LINE('KCV_RESOURCE_PRINCIPAL_ENABLED='||l_schema);
END;
/
