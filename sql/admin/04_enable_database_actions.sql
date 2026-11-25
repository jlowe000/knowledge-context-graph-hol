-- ADMIN: Run Statement. KCV_SCHEMA is the chosen existing owner; blank means KCV_LAB.
-- The authenticated route is the lowercase owner name; no endpoint is stored here.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');n PLS_INTEGER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use the chosen KCV_ project owner name');END IF;
  SELECT COUNT(*) INTO n FROM dba_users WHERE username=l_schema AND authentication_type='PASSWORD';
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20983,'Database Actions requires the existing password-enabled project owner');END IF;
  ORDS_ADMIN.ENABLE_SCHEMA(p_enabled=>TRUE,p_schema=>l_schema,
    p_url_mapping_type=>'BASE_PATH',p_url_mapping_pattern=>LOWER(l_schema),p_auto_rest_auth=>TRUE);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('KCV_DATABASE_ACTIONS_READY='||l_schema);
END;
/
