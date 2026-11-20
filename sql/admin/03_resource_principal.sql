-- Optional ADMIN path for OCI Generative AI authentication on ADB Serverless.
-- First configure the ADB dynamic group and compartment-scoped inference policy.
-- This is not supported as a local-container authentication assumption.
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_RESOURCE_PRINCIPAL(username=>'KCV_LAB');
END;
/
