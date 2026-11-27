-- ADMIN Worksheet: Run Statement on the complete block without the final slash.
-- Bind KCV_SCHEMA to the prepared new owner; enter the four OCI values privately.
-- A temporary definer-rights procedure creates OCI_USER_CRED in that owner.
-- No key is placed in procedure source, application exports or printed output.
-- Existing credentials are never replaced. No EXECUTE privilege is granted.
DECLARE
 s VARCHAR2(128):=UPPER(TRIM(:KCV_SCHEMA));q VARCHAR2(261);n NUMBER;
 u VARCHAR2(4000):=:OCI_USER_OCID;t VARCHAR2(4000):=:OCI_TENANCY_OCID;
 f VARCHAR2(4000):=:OCI_FINGERPRINT;k VARCHAR2(32767):=:OCI_PRIVATE_KEY;
 made BOOLEAN:=FALSE;err NUMBER;
 PROCEDURE forget_inputs IS BEGIN u:=NULL;t:=NULL;f:=NULL;k:=NULL;END;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
  RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
 IF s IS NULL OR NOT REGEXP_LIKE(s,'^KCV_V[0-9]+_[0-9]{3}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use the prepared KCV_V<major>_<build> owner');END IF;
 SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=s AND schema=s;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Verify the exact workspace/schema mapping first');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username=s AND authentication_type='NONE';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'This helper is for the prepared schema-only owner');END IF;
 SELECT COUNT(*) INTO n FROM dba_credentials WHERE owner=s AND credential_name='OCI_USER_CRED';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Owner credential already exists; it was not changed');END IF;
 SELECT COUNT(*) INTO n FROM dba_objects WHERE owner=s AND object_name='KCV_APL_CREATE_CREDENTIAL';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Temporary credential helper already exists; inspect it before retrying');END IF;
 IF u IS NULL OR t IS NULL OR f IS NULL OR k IS NULL THEN
  RAISE_APPLICATION_ERROR(-20982,'Supply all four OCI credential fields privately');END IF;
 q:=DBMS_ASSERT.ENQUOTE_NAME(s,FALSE)||'.KCV_APL_CREATE_CREDENTIAL';
 EXECUTE IMMEDIATE 'CREATE PROCEDURE '||q||q'~(p_user VARCHAR2,p_tenancy VARCHAR2,p_fingerprint VARCHAR2,p_key VARCHAR2) AUTHID DEFINER AS
 BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN RAISE_APPLICATION_ERROR(-20981,'ADMIN credential preparation only');END IF;
  DBMS_CLOUD.CREATE_CREDENTIAL(credential_name=>'OCI_USER_CRED',user_ocid=>p_user,
   tenancy_ocid=>p_tenancy,fingerprint=>p_fingerprint,private_key=>p_key);
 END;~';
 made:=TRUE;
 SELECT COUNT(*) INTO n FROM dba_objects WHERE owner=s AND object_name='KCV_APL_CREATE_CREDENTIAL'
  AND object_type='PROCEDURE' AND status='VALID';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20986,'Credential helper compilation requires administrator review');END IF;
 EXECUTE IMMEDIATE 'BEGIN '||q||'(:u,:t,:f,:k);END;' USING u,t,f,k;
 forget_inputs;
 SELECT COUNT(*) INTO n FROM dba_credentials WHERE owner=s AND credential_name='OCI_USER_CRED';
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20986,'Credential was not found in the intended owner');END IF;
 EXECUTE IMMEDIATE 'DROP PROCEDURE '||q;made:=FALSE;
 DBMS_OUTPUT.PUT_LINE('Owner-local OCI_USER_CRED created; temporary helper removed. Test inference separately.');
EXCEPTION WHEN OTHERS THEN
 err:=SQLCODE;forget_inputs;
 IF made THEN
  BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE '||q;
  EXCEPTION WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(-20986,'Credential preparation needs administrator review, including temporary helper cleanup. Original error code: '||TO_CHAR(err));
  END;
 END IF;
 RAISE_APPLICATION_ERROR(-20986,'Credential preparation stopped. Review prerequisites and private inputs. Error code: '||TO_CHAR(err));
END;
/
