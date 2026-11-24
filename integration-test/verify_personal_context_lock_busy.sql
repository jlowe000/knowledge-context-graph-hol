-- Session B. Execute only while session A reports HOLD_READY.
DECLARE token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;cid VARCHAR2(32);result CLOB;n NUMBER;started NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN('KCV_V2_TEST','KCV_HOL_TEST') OR NOT REGEXP_LIKE(token,'^v3_context_[A-Fa-f0-9]{32}$','c') THEN RAISE_APPLICATION_ERROR(-20999,'Use the isolated owner and the session A token');END IF;
 SELECT context_id INTO cid FROM kcv_personal_contexts WHERE title=token AND owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject;
 started:=DBMS_UTILITY.GET_TIME;
 BEGIN result:=kcv_personal_context_api.save_draft(cid,token,TO_CLOB('{}'),1,token||'_edit');RAISE_APPLICATION_ERROR(-20991,'Edit bypassed context publication lock');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.archive_context(cid,1,token||'_archive');RAISE_APPLICATION_ERROR(-20991,'Archive bypassed context publication lock');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 IF (DBMS_UTILITY.GET_TIME-started)/100>2 THEN RAISE_APPLICATION_ERROR(-20990,'Busy writes did not fail promptly');END IF;
 SELECT COUNT(*) INTO n FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token IN(token||'_edit',token||'_archive');
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Blocked writes committed request receipts');END IF;
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=cid AND draft_version=1 AND lifecycle='DRAFT';IF n<>1 THEN RAISE_APPLICATION_ERROR(-20990,'Blocked writes changed context');END IF;
 DBMS_OUTPUT.PUT_LINE('PASS: independent edit/archive writes reject the publication lock without writes');
END;
/
