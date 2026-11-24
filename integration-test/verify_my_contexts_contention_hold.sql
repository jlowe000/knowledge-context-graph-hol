-- Session A: run as the isolated test schema, with a fresh shared request token.
-- Start session B only after HOLD_READY is visible. This releases after 30 seconds.
DECLARE
 token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;lock_id PLS_INTEGER;rc PLS_INTEGER;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 IF token IS NULL OR NOT REGEXP_LIKE(token,'^v2_cross_[A-Fa-f0-9]{32}$','c') THEN
   RAISE_APPLICATION_ERROR(-20999,'Supply a fresh v2_cross_ request token');END IF;
 lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_CONTEXT_REQUEST:'||kcv_access.owner_scope||':'||kcv_access.owner_subject||':'||token,1,1073741823);
 rc:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
 IF rc<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Session A could not acquire request lock');END IF;
 DBMS_OUTPUT.PUT_LINE('HOLD_READY: request lock acquired by independent session A');
END;
/
DECLARE
 token VARCHAR2(80):=:KCV_TEST_REQUEST_TOKEN;lock_id PLS_INTEGER;rc PLS_INTEGER;
BEGIN
 DBMS_SESSION.SLEEP(30);
 lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_CONTEXT_REQUEST:'||kcv_access.owner_scope||':'||kcv_access.owner_subject||':'||token,1,1073741823);
 rc:=DBMS_LOCK.RELEASE(lock_id);
 IF rc<>0 THEN RAISE_APPLICATION_ERROR(-20990,'Session A could not release request lock');END IF;
 DBMS_OUTPUT.PUT_LINE('HOLD_RELEASED: request lock released');
END;
/
