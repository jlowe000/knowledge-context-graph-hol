-- ADMIN: read-only deployment checks for the temporary Serverless instance.
SELECT USER AS signed_in_as,version_no AS apex_version FROM apex_release
/
SELECT privilege FROM session_privs WHERE privilege IN
 ('CREATE ANY TABLE','CREATE ANY PROCEDURE','CREATE ANY TYPE','CREATE ANY SEQUENCE') ORDER BY privilege
/
SELECT object_name,object_type,status FROM all_objects WHERE owner='KCV_LAB'
 AND object_name IN ('KCV_SETTINGS','KCV_SOURCES','KCV_PASSAGES','KCV_SCENARIO','KCV_APEX','KCV_CHAT_SESSIONS')
 ORDER BY object_name,object_type
/
SELECT workspace,workspace_id FROM apex_workspaces WHERE workspace='KCV_KNOWLEDGE'
/
