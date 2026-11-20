-- KCV_LAB: retain the returned database-created ID for subsequent agent calls.
SELECT DBMS_CLOUD_AI.CREATE_CONVERSATION(
  attributes=>'{"title":"Knowledge context lab","retention_days":7}') AS conversation_id
FROM dual
/
