-- OPTIONAL ADMIN action, only after readiness shows Java is absent.
-- Database-wide and irreversible enablement; NOT part of automatic setup.
-- Afterwards restart the Serverless instance through OCI and wait for VALID.
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_FEATURE(feature_name=>'JAVAVM');
END;
/
