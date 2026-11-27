SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_DEPLOY_RUNS_RECENT'
 AND table_name='KCV_DEPLOY_RUNS' AND uniqueness='NONUNIQUE' AND index_type='NORMAL' AND status='VALID';
 require(l_n=1,'Deployment request index differs');
 DECLARE cols VARCHAR2(4000);BEGIN
  SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY column_position) INTO cols FROM user_ind_columns
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
  require(cols='STARTED_AT,RUN_ID','Deployment request index columns differ');
 END;
