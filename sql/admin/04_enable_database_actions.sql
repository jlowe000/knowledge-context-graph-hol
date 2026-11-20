-- ADMIN: enable a dedicated authenticated Database Actions route for the lab user.
BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(p_enabled=>TRUE,p_schema=>'KCV_LAB',
    p_url_mapping_type=>'BASE_PATH',p_url_mapping_pattern=>'kcv_lab',p_auto_rest_auth=>TRUE);
END;
/
