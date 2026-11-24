-- Run after session A has released its lock; removes only the shared test fixture.
DECLARE token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;cid VARCHAR2(32);result CLOB;lk PLS_INTEGER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN('KCV_V2_TEST','KCV_HOL_TEST') OR NOT REGEXP_LIKE(token,'^v3_context_[A-Fa-f0-9]{32}$','c') THEN RAISE_APPLICATION_ERROR(-20999,'Use the isolated owner and the session A token');END IF;
 SELECT context_id INTO cid FROM kcv_personal_contexts WHERE title=token AND owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject;
 result:=kcv_personal_context_api.save_draft(cid,token,TO_CLOB('{}'),1,token||'_after');
 DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token IN(token,token||'_after');
 DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: writes resume after lock release; synthetic fixture removed');
END;
/
