-- ADMIN: creates only an APEX workspace mapped to the existing lab schema.
-- Existing workspace names cause an error, never replacement. No password is stored.
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
    p_workspace=>'KCV_KNOWLEDGE',p_primary_schema=>'KCV_LAB');
END;
/
