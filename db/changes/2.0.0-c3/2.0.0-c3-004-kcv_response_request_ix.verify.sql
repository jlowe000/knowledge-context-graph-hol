SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_RESPONSE_REQUEST_IX' AND table_name='KCV_RESPONSE_RUNS' AND uniqueness='UNIQUE' AND status='VALID';
 require(l_n=1,'Missing or incompatible index: KCV_RESPONSE_REQUEST_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_RESPONSE_REQUEST_IX';
 require(l_n=2,'Index column count differs: KCV_RESPONSE_REQUEST_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_RESPONSE_REQUEST_IX' AND column_position=1 AND descend='ASC';
 require(l_n=1,'Index direction differs: KCV_RESPONSE_REQUEST_IX');
 DECLARE expression_text LONG; BEGIN
 SELECT column_expression INTO expression_text FROM user_ind_expressions WHERE index_name='KCV_RESPONSE_REQUEST_IX' AND column_position=1;
 require(compact(expression_text) IN ('CASEWHENREQUEST_TOKENISNOTNULLTHENSESSION_IDEND','CASEWHENREQUEST_TOKENISNOTNULLTHENSESSION_IDELSENULLEND'),'Request-token index expression differs: KCV_RESPONSE_REQUEST_IX');
 END;
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_RESPONSE_REQUEST_IX' AND column_position=2 AND descend='ASC';
 require(l_n=1,'Index direction differs: KCV_RESPONSE_REQUEST_IX');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns WHERE index_name='KCV_RESPONSE_REQUEST_IX' AND column_position=2 AND column_name='REQUEST_TOKEN';
 require(l_n=1,'Index column/order differs: KCV_RESPONSE_REQUEST_IX');
