-- GENERATED candidate. Freeze as a new immutable migration before use.
CREATE OR REPLACE PACKAGE kcv_deploy_contract AUTHID DEFINER AS
 PROCEDURE verify_schema;
 FUNCTION target_version RETURN VARCHAR2;
 FUNCTION target_checkpoint RETURN VARCHAR2;
 FUNCTION dataset_ref RETURN VARCHAR2;
 FUNCTION dataset_manifest_sha256 RETURN VARCHAR2;
END kcv_deploy_contract;
/
