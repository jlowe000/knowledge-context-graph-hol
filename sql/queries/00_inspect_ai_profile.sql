-- KCV_LAB: read-only, no model call; excludes credential contents and OCIDs.
SELECT attribute_name, attribute_value
FROM user_cloud_ai_profile_attributes
WHERE profile_name='KCV_GENAI'
  AND attribute_name IN ('provider','region','model','oci_apiformat','credential_name')
ORDER BY attribute_name
/
