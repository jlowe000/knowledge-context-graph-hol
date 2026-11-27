-- Two-connection native test, connection B, same isolated owner as holder.
-- Start immediately after ADMISSION_HOLDER_READY, within its 30-second window.
-- Requires a valid trusted binding and final canonical installation checkpoint.
-- Tests the actual setup API; the published writer lease is not needed yet.
-- Removes only this test's request receipt. No network/model/data action can run
-- if the admission protocol works. A missed window fails the test explicitly.
SET SERVEROUTPUT ON
DECLARE
 token VARCHAR2(80):='ADMISSION_'||RAWTOHEX(SYS_GUID());n NUMBER;code NUMBER;
 before_setup VARCHAR2(3);after_setup VARCHAR2(3);
 before_legacy VARCHAR2(4000);after_legacy VARCHAR2(4000);before_count NUMBER;after_count NUMBER;
 PROCEDURE require(ok BOOLEAN,message VARCHAR2) IS BEGIN
  IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,message);END IF;
 END;
BEGIN
 require(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_002','KCV_V2_003')
  AND SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('APEX$SESSION','APP_ID') IS NULL AND SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL,
  'Use the second authenticated isolated owner connection');
 SELECT maintenance INTO before_setup FROM kcv_deploy_state WHERE singleton_id=1;
 SELECT COUNT(*),MAX(setting_value) INTO before_count,before_legacy FROM kcv_settings WHERE setting_key='APP_MAINTENANCE';
 require(before_setup='OFF' AND NVL(UPPER(before_legacy),'OFF')<>'ON','Begin with learning maintenance OFF');
 BEGIN
  kcv_deploy.ensure_network(token);
  RAISE_APPLICATION_ERROR(-20991,'Setup was admitted while the holder should own shared admission; the test window may have elapsed');
 EXCEPTION WHEN OTHERS THEN code:=SQLCODE;IF code<>-20304 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE request_token=token AND operation='ENSURE_NETWORK'
  AND account_id=0 AND status='FAILED' AND error_code=-20302;
 require(n=1,'Expected the owner setup action to fail on admission contention, before runtime work');
 SELECT maintenance INTO after_setup FROM kcv_deploy_state WHERE singleton_id=1;
 SELECT COUNT(*),MAX(setting_value) INTO after_count,after_legacy FROM kcv_settings WHERE setting_key='APP_MAINTENANCE';
 require(before_setup=after_setup AND before_count=after_count
  AND NVL(before_legacy,CHR(1))=NVL(after_legacy,CHR(1)),'Contending setup changed the prior maintenance tuple');
 BEGIN kcv_deploy.ensure_network(token);
  RAISE_APPLICATION_ERROR(-20991,'A failed request was unexpectedly replayed');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20304 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE request_token=token;
 require(n=1,'Same-token replay created another setup request');
 DELETE FROM kcv_deploy_runs WHERE request_token=token AND account_id=0;COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: an admitted write blocks setup before a durable writer lease exists');
 DBMS_OUTPUT.PUT_LINE('PASS: maintenance tuple preserved; failed-token replay made no additional request');
EXCEPTION WHEN OTHERS THEN
 ROLLBACK;
 -- Retain the bounded receipt for diagnosis on a failed assertion. Do not reset
 -- maintenance after an unexpected successful runtime operation.
 RAISE;
END;
/
