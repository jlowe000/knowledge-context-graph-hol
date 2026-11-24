-- Session A. Supply the same synthetic :KCV_TEST_REQUEST_TOKEN in both sessions.
DECLARE token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;j JSON_OBJECT_T;cid VARCHAR2(32);lk PLS_INTEGER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH') OR NOT REGEXP_LIKE(token,'^v3_context_[A-Fa-f0-9]{32}$','c') THEN RAISE_APPLICATION_ERROR(-20999,'Use the isolated owner and a fresh v3_context_ token');END IF;
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(NULL,token,TO_CLOB('{}'),NULL,token));cid:=j.get_string('context_id');
 lk:=kcv_personal_journey.lock_context(cid);COMMIT;
 DBMS_OUTPUT.PUT_LINE('HOLD_READY: context lock survives commit in independent session A');
END;
/
DECLARE token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;cid VARCHAR2(32);lk PLS_INTEGER;
BEGIN
 DBMS_SESSION.SLEEP(30);
 SELECT context_id INTO cid FROM kcv_personal_contexts WHERE title=token AND owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject;
 lk:=DBMS_UTILITY.GET_HASH_VALUE('KCV_PERSONAL:'||cid,1,1073741823);kcv_personal_journey.unlock_context(lk);
 DBMS_OUTPUT.PUT_LINE('HOLD_RELEASED: context lock released');
END;
/
