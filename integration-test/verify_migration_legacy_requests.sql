-- Native migration regression: legacy NULL request tokens must remain usable.
-- Run only as an isolated test schema owner. No project runtime rows are changed.
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
DECLARE
 created BOOLEAN:=FALSE; n NUMBER; rejected BOOLEAN:=FALSE;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20991,p_message);END IF;
 END;
BEGIN
 require(SYS_CONTEXT('USERENV','SESSION_USER') IN ('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_MIGTEST','KCV_V2_FRESH')
  AND SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER'),
  'Run only as an isolated project test schema owner');
 SELECT COUNT(*) INTO n FROM user_objects WHERE object_name IN ('KCV_MIG_IDX_PROBE','KCV_MIG_IDX_PROBE_UX');
 require(n=0,'Probe names already exist; inspect them instead of deleting them');
 EXECUTE IMMEDIATE 'CREATE TABLE kcv_mig_idx_probe (session_id VARCHAR2(40) NOT NULL, request_token VARCHAR2(40))';
 created:=TRUE;
 EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''legacy-session'',NULL)';
 EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''legacy-session'',NULL)';
 COMMIT;
 EXECUTE IMMEDIATE q'~CREATE UNIQUE INDEX kcv_mig_idx_probe_ux ON kcv_mig_idx_probe (
   CASE WHEN request_token IS NOT NULL THEN session_id END,request_token)~';
 EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''legacy-session'',NULL)';
 EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''personal-session'',''request-1'')';
 BEGIN
  EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''personal-session'',''request-1'')';
 EXCEPTION WHEN DUP_VAL_ON_INDEX THEN rejected:=TRUE;END;
 require(rejected,'A repeated non-NULL request token was not rejected');
 EXECUTE IMMEDIATE 'INSERT INTO kcv_mig_idx_probe VALUES (''another-session'',''request-1'')';
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_mig_idx_probe WHERE request_token IS NULL' INTO n;
 require(n=3,'Legacy NULL-token rows were not preserved');
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM kcv_mig_idx_probe WHERE request_token IS NOT NULL' INTO n;
 require(n=2,'Per-session token uniqueness did not preserve distinct conversations');
 ROLLBACK;
 EXECUTE IMMEDIATE 'DROP TABLE kcv_mig_idx_probe PURGE';created:=FALSE;
 DBMS_OUTPUT.PUT_LINE('PASS: legacy request rows preserved; duplicate personal requests rejected; probe removed');
EXCEPTION WHEN OTHERS THEN
 ROLLBACK;
 IF created THEN EXECUTE IMMEDIATE 'DROP TABLE kcv_mig_idx_probe PURGE';END IF;
 RAISE;
END;
/
