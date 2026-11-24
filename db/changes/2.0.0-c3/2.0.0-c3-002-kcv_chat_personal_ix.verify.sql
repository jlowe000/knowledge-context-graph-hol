SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_CHAT_PERSONAL_IX' AND table_name='KCV_CHAT_SESSIONS' AND uniqueness='NONUNIQUE' AND status='VALID';
 require(l_n=1,'Missing or incompatible index: KCV_CHAT_PERSONAL_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_CHAT_PERSONAL_IX';
 require(l_n=2,'Index column count differs: KCV_CHAT_PERSONAL_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_CHAT_PERSONAL_IX' AND column_position=1 AND descend='ASC';
 require(l_n=1,'Index direction differs: KCV_CHAT_PERSONAL_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_CHAT_PERSONAL_IX' AND column_position=1 AND column_name='PERSONAL_CONTEXT_ID';
 require(l_n=1,'Index column/order differs: KCV_CHAT_PERSONAL_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_CHAT_PERSONAL_IX' AND column_position=2 AND descend='ASC';
 require(l_n=1,'Index direction differs: KCV_CHAT_PERSONAL_IX');
 DECLARE expression_text LONG; actual_column VARCHAR2(128); BEGIN
 SELECT column_name INTO actual_column FROM user_ind_columns WHERE index_name='KCV_CHAT_PERSONAL_IX' AND column_position=2;
 IF actual_column<>'CREATED_AT' THEN
 SELECT column_expression INTO expression_text FROM user_ind_expressions WHERE index_name='KCV_CHAT_PERSONAL_IX' AND column_position=2;
 require(compact(expression_text)='SYS_EXTRACT_UTC(CREATED_AT)','Timestamp index expression differs: KCV_CHAT_PERSONAL_IX');
 END IF; END;
