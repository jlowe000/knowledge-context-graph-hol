DECLARE
 l_n NUMBER;l_retired NUMBER;l_failed NUMBER;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message);END IF;
 END;
BEGIN
 SELECT COUNT(*) INTO l_retired FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-005-kcv_deploy_runs_recent';
 SELECT COUNT(*) INTO l_failed FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-005-kcv_deploy_runs_recent'
  AND payload_sha256='934d633fdd8e72ef6598aadf5e984c6759da44f404e776d5848f79fb9dd55870' AND product_version='2.1.0'
  AND phase='FAILED' AND error_code=-20301 AND completed_at IS NULL;
 require(l_retired=l_failed AND l_failed IN(0,1),'Retired deployment index audit differs');
 SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_DEPLOY_RUNS_RECENT';
 IF l_failed=1 THEN
  require(l_n=1,'Retired deployment index is missing; owner recovery review is required');
 ELSIF l_n=0 THEN
  EXECUTE IMMEDIATE 'CREATE INDEX kcv_deploy_runs_recent ON kcv_deploy_runs (started_at,run_id)';
 END IF;
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_DEPLOY_RUNS_RECENT'
 AND table_owner=SYS_CONTEXT('USERENV','CURRENT_USER') AND table_name='KCV_DEPLOY_RUNS'
 AND table_type='TABLE' AND uniqueness='NONUNIQUE' AND index_type='FUNCTION-BASED NORMAL'
 AND status='VALID' AND funcidx_status='ENABLED' AND partitioned='NO' AND visibility='VISIBLE';
 require(l_n=1,'Deployment request index differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=2,'Deployment request index key count differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND descend='ASC';
 require(l_n=2,'Deployment request index direction differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS'
   AND column_position=2 AND column_name='RUN_ID';
 require(l_n=1,'Deployment request index second key differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=1,'Deployment request index expression count differs');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,'[[:space:]]','')='SYS_EXTRACT_UTC("STARTED_AT")',
   'Deployment request index UTC expression differs');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name='KCV_DEPLOY_RUNS' AND column_name=first_column
    AND hidden_column='YES' AND virtual_column='YES' AND data_type='TIMESTAMP(6)';
  require(l_n=1,'Deployment request index generated UTC column differs');
 END;
END;
