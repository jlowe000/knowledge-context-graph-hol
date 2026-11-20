-- Run Statement (Ctrl+Enter), not Run Script, in the ADMIN Worksheet.
-- The user enters and submits the private password in the bind dialog.
-- Creates an app end user only; fails rather than resetting an existing user.
BEGIN
  APEX_UTIL.SET_SECURITY_GROUP_ID(APEX_UTIL.FIND_SECURITY_GROUP_ID('KCV_KNOWLEDGE'));
  APEX_UTIL.CREATE_USER(p_user_name=>'KCV_USER',p_web_password=>:KCV_APEX_PASSWORD,
    p_developer_privs=>NULL,p_allow_app_building_yn=>'N',p_allow_sql_workshop_yn=>'N',
    p_allow_team_development_yn=>'N',p_change_password_on_first_use=>'N');
  COMMIT;
END;
/
