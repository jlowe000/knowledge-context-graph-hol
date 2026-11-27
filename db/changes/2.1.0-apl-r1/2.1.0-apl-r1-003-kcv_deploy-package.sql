CREATE OR REPLACE PACKAGE kcv_deploy AUTHID DEFINER AS
 PROCEDURE capture_identity;
 FUNCTION is_installer RETURN BOOLEAN;
 FUNCTION learner_ready RETURN BOOLEAN;
 FUNCTION status_json RETURN CLOB;
 FUNCTION credential_options RETURN CLOB;
 PROCEDURE configure_profile(p_credential VARCHAR2,p_region VARCHAR2,
   p_compartment VARCHAR2,p_model VARCHAR2,p_request_token VARCHAR2);
 PROCEDURE test_model(p_request_token VARCHAR2);
 PROCEDURE ensure_network(p_request_token VARCHAR2);
 PROCEDURE register_runtime(p_request_token VARCHAR2);
 PROCEDURE load_dataset(p_request_token VARCHAR2);
 PROCEDURE enable_learning(p_request_token VARCHAR2);
END;
