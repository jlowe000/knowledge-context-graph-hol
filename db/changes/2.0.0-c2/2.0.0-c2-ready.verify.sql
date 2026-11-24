 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name IN ('KCV_ACCESS','KCV_PERSONAL_CONTEXT_API') AND object_type IN ('PACKAGE','PACKAGE BODY') AND status='VALID';
 require(l_n=4,'C2 API compilation is incomplete');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name IN ('KCV_ACCESS','KCV_PERSONAL_CONTEXT_API') AND attribute='ERROR';
 require(l_n=0,'C2 API compilation errors remain');
