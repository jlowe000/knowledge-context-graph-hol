l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE kcv_deploy_contract AUTHID DEFINER AS
 PROCEDURE verify_schema;
 FUNCTION target_version RETURN VARCHAR2;
 FUNCTION target_checkpoint RETURN VARCHAR2;
 FUNCTION dataset_ref RETURN VARCHAR2;
 FUNCTION dataset_manifest_sha256 RETURN VARCHAR2;
END kcv_deploy_contract;
');
 check_program('KCV_DEPLOY_CONTRACT','PACKAGE',l_expected);
