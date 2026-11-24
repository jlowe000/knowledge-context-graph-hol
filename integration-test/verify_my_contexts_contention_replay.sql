-- Run only after session A displays HOLD_RELEASED.
DECLARE
 token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;first_result CLOB;replay CLOB;j JSON_OBJECT_T;cid VARCHAR2(32);n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 IF token IS NULL OR NOT REGEXP_LIKE(token,'^v2_cross_[A-Fa-f0-9]{32}$','c') THEN
   RAISE_APPLICATION_ERROR(-20999,'Supply the fresh session A request token');END IF;
 first_result:=kcv_personal_context_api.save_draft(NULL,token,TO_CLOB('{}'),NULL,token);
 replay:=kcv_personal_context_api.save_draft(NULL,token,TO_CLOB('{}'),NULL,token);
 IF DBMS_LOB.COMPARE(first_result,replay)<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Replay changed the original response');END IF;
 j:=JSON_OBJECT_T.parse(first_result);cid:=j.get_string('context_id');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE owner_scope=kcv_access.owner_scope
   AND owner_subject=kcv_access.owner_subject AND title=token;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20990,'Replay did not retain exactly one draft');END IF;
 DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token=token;
 DELETE FROM kcv_personal_contexts WHERE context_id=cid AND owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject;COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: released request succeeded and replayed one draft; synthetic fixture removed');
END;
/
