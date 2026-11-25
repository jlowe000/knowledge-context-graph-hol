-- Run Statement (Ctrl+Enter), not Run Script, in the ADMIN Worksheet.
-- KCV_SCHEMA/KCV_WORKSPACE/KCV_APP_USER choose the owner, workspace and new app account.
-- Blanks mean KCV_LAB/KCV_KNOWLEDGE/KCV_USER. Enter KCV_APEX_PASSWORD privately.
-- Creates an app end user only; existing accounts are never reset or overwritten.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
  l_workspace VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'KCV_KNOWLEDGE');
  l_app_user VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_APP_USER)),'KCV_USER');
  l_password VARCHAR2(4000):=:KCV_APEX_PASSWORD;
  l_workspace_id NUMBER;n PLS_INTEGER;l_account_id NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
    OR NOT REGEXP_LIKE(l_workspace,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use the chosen KCV_ schema and workspace names');END IF;
  IF NOT REGEXP_LIKE(l_app_user,'^[A-Z][A-Z0-9_.-]{0,127}$','c')
    OR l_app_user IN('ADMIN','NOBODY','APEX_PUBLIC_USER') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use a new app username beginning with a letter, with letters, digits, underscores, dots or hyphens');END IF;
  IF l_password IS NULL OR LENGTH(l_password)<12 THEN
    RAISE_APPLICATION_ERROR(-20010,'Enter a private app password of at least 12 characters; workspace password rules also apply');END IF;
  SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=l_workspace AND schema=l_schema;
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Workspace is not mapped to the chosen project owner');END IF;
  SELECT workspace_id INTO l_workspace_id FROM apex_workspaces WHERE workspace=l_workspace;
  APEX_UTIL.SET_SECURITY_GROUP_ID(l_workspace_id);
  l_account_id:=APEX_UTIL.GET_USER_ID(p_username=>l_app_user);
  IF l_account_id IS NOT NULL THEN RAISE_APPLICATION_ERROR(-20011,'App account already exists; sign in with it rather than recreating or resetting it');END IF;
  APEX_UTIL.CREATE_USER(p_user_name=>l_app_user,p_web_password=>l_password,
    p_developer_privs=>NULL,p_allow_app_building_yn=>'N',p_allow_sql_workshop_yn=>'N',
    p_allow_team_development_yn=>'N',p_change_password_on_first_use=>'N');
  l_password:=NULL;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('KCV_APP_USER_CREATED='||l_app_user);
EXCEPTION WHEN OTHERS THEN l_password:=NULL;ROLLBACK;RAISE;
END;
/
