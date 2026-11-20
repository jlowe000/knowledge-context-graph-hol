-- KCV_LAB: select BEGIN through END; and use Run Statement, excluding the slash.
-- Enter OCI API signing-key values through the bind dialog, not SQL literals.
-- OCI_PRIVATE_KEY: unencrypted PEM key body only, without BEGIN/END lines.
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name=>'OCI_USER_CRED',
    user_ocid=>:OCI_USER_OCID, tenancy_ocid=>:OCI_TENANCY_OCID,
    private_key=>:OCI_PRIVATE_KEY,
    fingerprint=>:OCI_FINGERPRINT);
END;
/
