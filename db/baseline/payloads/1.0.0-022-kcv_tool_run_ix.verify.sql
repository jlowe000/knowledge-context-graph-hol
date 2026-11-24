 SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_TOOL_RUN_IX' AND table_name='KCV_RESPONSE_TOOL_CALLS' AND uniqueness='NONUNIQUE' AND status='VALID';
 require(l_n=1,'Missing baseline index');
