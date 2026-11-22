-- ADMIN: read-only project inventory. No passwords or credential contents.
SELECT USER AS signed_in_as FROM dual
/
SELECT owner,object_type,COUNT(*) AS object_count FROM dba_objects
 WHERE owner='KCV_LAB' GROUP BY owner,object_type ORDER BY object_type
/
SELECT owner,object_type,object_name FROM dba_objects WHERE owner='KCV_LAB'
 AND object_type IN ('TABLE','VIEW','PACKAGE','FUNCTION','PROCEDURE','JOB')
 ORDER BY object_type,object_name
/
SELECT workspace,application_id,application_name,owner FROM apex_applications
 WHERE workspace='KCV_KNOWLEDGE' OR owner='KCV_LAB'
/
SELECT workspace_name,schema FROM apex_workspace_schemas WHERE workspace_name='KCV_KNOWLEDGE'
/
SELECT username,COUNT(*) AS sessions FROM v$session WHERE username='KCV_LAB' GROUP BY username
/
SELECT status,version FROM dba_registry WHERE comp_id='JAVAVM'
/
