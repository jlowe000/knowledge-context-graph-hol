 SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_PERSONAL_OWNER_IX' AND table_name='KCV_PERSONAL_CONTEXTS' AND status='VALID' AND uniqueness='NONUNIQUE';
 require(l_n=1,'Missing personal-context index');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_PERSONAL_OWNER_IX';
 require(l_n=4,'Personal-context index column count differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_PERSONAL_OWNER_IX' AND descend='ASC';
 require(l_n=4,'Personal-context index direction differs');
 SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY column_position) INTO l_actual FROM user_ind_columns WHERE index_name='KCV_PERSONAL_OWNER_IX' AND column_position<=3;
 require(l_actual='OWNER_SCOPE,OWNER_SUBJECT,LIFECYCLE','Personal-context index prefix/order differs');
 DECLARE expression_text LONG; last_column VARCHAR2(128);
 BEGIN
  SELECT column_name INTO last_column FROM user_ind_columns WHERE index_name='KCV_PERSONAL_OWNER_IX' AND column_position=4;
  IF last_column<>'UPDATED_AT' THEN
   SELECT column_expression INTO expression_text FROM user_ind_expressions WHERE index_name='KCV_PERSONAL_OWNER_IX' AND column_position=4;
   require(compact(expression_text)='SYS_EXTRACT_UTC(UPDATED_AT)','Personal-context timestamp index expression differs');
  END IF;
 END;
