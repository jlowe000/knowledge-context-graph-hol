-- KCV_LAB: verify prerequisites before additive extension installation.
SELECT USER AS signed_in_as,version_no AS apex_version FROM apex_release
/
SELECT setting_key,setting_value FROM kcv_settings WHERE setting_key IN ('ACTIVE_GRAPH','AI_PROFILE')
/
SELECT object_name,object_type,status FROM user_objects
WHERE object_name IN ('KCV_SOURCE_PACKET','KCV_CONTEXT_PACKET','KCV_EVIDENCE_PACKET') ORDER BY object_name
/
