-- KCV_LAB: after 01_objects.sql and successful creation of KCV_GENAI.
-- Registers the profile name for extraction/agents; makes no model call.
MERGE INTO kcv_settings t USING (SELECT 'AI_PROFILE' setting_key FROM dual) s
 ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value='KCV_GENAI'
 WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('AI_PROFILE','KCV_GENAI')
/
COMMIT
/
