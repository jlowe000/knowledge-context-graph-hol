-- KCV_LAB: set non-secret environment choices below before Run Script.
-- The credential must already be accessible to this lab user.
-- User signing key: OCI_USER_CRED. Resource principal: OCI$RESOURCE_PRINCIPAL.
-- Independent of lab tables. Run 06_register_profile.sql after 01_objects.sql.
DECLARE
  l_region VARCHAR2(128):=NULL;
  l_compartment VARCHAR2(256):=NULL;
  l_model VARCHAR2(256):=NULL;
  l_credential VARCHAR2(128):='OCI_USER_CRED';
  l_attributes JSON_OBJECT_T:=JSON_OBJECT_T();
  l_attributes_clob CLOB;
BEGIN
  IF l_region IS NULL OR l_compartment IS NULL OR l_model IS NULL THEN
    RAISE_APPLICATION_ERROR(-20012,'Set the model, region and compartment for this environment');
  END IF;
  l_attributes.put('provider','oci');
  l_attributes.put('credential_name',l_credential);
  l_attributes.put('oci_compartment_id',l_compartment);
  l_attributes.put('region',l_region);
  l_attributes.put('model',l_model);
  l_attributes_clob:=l_attributes.to_clob();
  DBMS_CLOUD_AI.CREATE_PROFILE(profile_name=>'KCV_GENAI',attributes=>l_attributes_clob);
END;
/
