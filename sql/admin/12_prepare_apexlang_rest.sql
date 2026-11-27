-- ADMIN Worksheet, Run Statement: bind the intended schema and workspace.
-- Required for App Builder APEXlang ZIP import. Review this access change first.
-- Requires metadata-catalog authentication; does not REST-enable any table.
DECLARE
 s VARCHAR2(128):=UPPER(TRIM(:KCV_SCHEMA));
 w VARCHAR2(128):=UPPER(TRIM(:KCV_WORKSPACE));n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
  RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
 IF s IS NULL OR w IS NULL OR NOT REGEXP_LIKE(s,'^KCV_V[0-9]+_[0-9]{3}$','c') OR w<>s THEN
  RAISE_APPLICATION_ERROR(-20982,'Use matching KCV_V<major>_<build> schema and workspace names');END IF;
 SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=w AND schema=s;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Verify the exact workspace/schema mapping first');END IF;
 SELECT COUNT(*) INTO n FROM dba_ords_schemas WHERE parsing_schema=s;
 IF n=0 THEN
  ORDS_ADMIN.ENABLE_SCHEMA(p_enabled=>TRUE,p_schema=>s,p_url_mapping_type=>'BASE_PATH',
   p_url_mapping_pattern=>LOWER(s),p_auto_rest_auth=>TRUE);
  COMMIT;
 ELSE
  DBMS_OUTPUT.PUT_LINE('Existing ORDS configuration retained; verify status and metadata authentication.');
 END IF;
 DBMS_OUTPUT.PUT_LINE('APEXlang REST schema preparation complete. No table API was enabled.');
END;
/
