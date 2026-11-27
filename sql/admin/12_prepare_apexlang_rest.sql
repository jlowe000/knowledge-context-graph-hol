-- ADMIN Worksheet, Run Statement: bind the intended schema and workspace.
-- Required for App Builder APEXlang ZIP import. Review this access change first.
-- Requires metadata-catalog authentication; does not REST-enable any table.
-- Blanks mean KCV_LAB / KCV_KNOWLEDGE; retain an existing installation's names.
DECLARE
 s VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
 w VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'KCV_KNOWLEDGE');n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'ADMIN'
  OR NVL(SYS_CONTEXT('USERENV','PROXY_USER'),'ADMIN') NOT IN('ADMIN','ORDS_PUBLIC_USER') THEN
  RAISE_APPLICATION_ERROR(-20981,'Use the authenticated ADMIN session and ADMIN schema');END IF;
 IF NOT REGEXP_LIKE(s,'^KCV_[A-Z0-9_]{1,26}$','c')
  OR NOT REGEXP_LIKE(w,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use the intended KCV_ schema and workspace names');END IF;
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
