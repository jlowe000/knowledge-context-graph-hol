-- Session B: run concurrently while session A displays HOLD_READY.
DECLARE
 token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;started NUMBER;elapsed NUMBER;n NUMBER;result CLOB;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 IF token IS NULL OR NOT REGEXP_LIKE(token,'^v2_cross_[A-Fa-f0-9]{32}$','c') THEN
   RAISE_APPLICATION_ERROR(-20999,'Supply the fresh session A request token');END IF;
 started:=DBMS_UTILITY.GET_TIME;
 BEGIN
   result:=kcv_personal_context_api.save_draft(NULL,token,TO_CLOB('{}'),NULL,token);
   RAISE_APPLICATION_ERROR(-20991,'Concurrent request unexpectedly acquired the held lock');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 elapsed:=(DBMS_UTILITY.GET_TIME-started)/100;
 IF elapsed>2 THEN RAISE_APPLICATION_ERROR(-20990,'Busy request did not return within two seconds');END IF;
 SELECT COUNT(*) INTO n FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope
   AND owner_subject=kcv_access.owner_subject AND request_token=token;
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Busy request left a receipt');END IF;
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE owner_scope=kcv_access.owner_scope
   AND owner_subject=kcv_access.owner_subject AND title=token;
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Busy request left a draft');END IF;
 DBMS_OUTPUT.PUT_LINE('PASS: independent session B returned busy in '||TO_CHAR(elapsed,'FM0D00')||' seconds without writes');
END;
/
