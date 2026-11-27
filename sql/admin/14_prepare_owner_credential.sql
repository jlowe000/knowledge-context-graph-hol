-- ADMIN Worksheet: Run Statement on the complete block without the final slash.
-- Bind KCV_SCHEMA/KCV_WORKSPACE to the prepared mapping; blanks use KCV_LAB/KCV_KNOWLEDGE.
-- Optional facilitator route for schema-only or password owners before model setup.
-- The installer can instead use the application's credential-creation form.
-- Enter the four OCI values privately. No ADMIN proxy grant to the owner is required.
-- A temporary definer-rights procedure creates OCI_USER_CRED in that owner.
-- No key is placed in procedure source, application exports or printed output.
-- Existing credentials are never replaced. No EXECUTE privilege is granted.
DECLARE
 s VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
 w VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_WORKSPACE)),'KCV_KNOWLEDGE');q VARCHAR2(261);n NUMBER;
 u VARCHAR2(4000):=:OCI_USER_OCID;t VARCHAR2(4000):=:OCI_TENANCY_OCID;
 f VARCHAR2(4000):=:OCI_FINGERPRINT;k VARCHAR2(32767):=:OCI_PRIVATE_KEY;
 made BOOLEAN:=FALSE;err NUMBER;
 PROCEDURE forget_inputs IS BEGIN u:=NULL;t:=NULL;f:=NULL;k:=NULL;END;
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_USER')<>'ADMIN'
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'ADMIN'
  OR NVL(SYS_CONTEXT('USERENV','PROXY_USER'),'ADMIN') NOT IN('ADMIN','ORDS_PUBLIC_USER') THEN
  RAISE_APPLICATION_ERROR(-20981,'Use the authenticated ADMIN session and ADMIN schema');END IF;
 IF NOT REGEXP_LIKE(s,'^KCV_[A-Z0-9_]{1,26}$','c')
  OR NOT REGEXP_LIKE(w,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
  RAISE_APPLICATION_ERROR(-20982,'Use the intended KCV_ schema and workspace names');END IF;
 SELECT COUNT(*) INTO n FROM apex_workspace_schemas WHERE workspace_name=w AND schema=s;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Verify the exact workspace/schema mapping first');END IF;
 SELECT COUNT(*) INTO n FROM dba_users WHERE username=s AND authentication_type IN('NONE','PASSWORD');
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20989,'Prepare the intended schema-only or password owner first');END IF;
 SELECT COUNT(*) INTO n FROM dba_credentials WHERE owner=s AND credential_name='OCI_USER_CRED';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Owner credential already exists; it was not changed');END IF;
 SELECT COUNT(*) INTO n FROM dba_objects WHERE owner=s AND object_name='KCV_APL_CREATE_CREDENTIAL';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Temporary credential helper already exists; inspect it before retrying');END IF;
 IF u IS NULL OR t IS NULL OR f IS NULL OR k IS NULL THEN
  RAISE_APPLICATION_ERROR(-20982,'Supply all four OCI credential fields privately');END IF;
 q:=DBMS_ASSERT.ENQUOTE_NAME(s,FALSE)||'.KCV_APL_CREATE_CREDENTIAL';
 EXECUTE IMMEDIATE 'CREATE PROCEDURE '||q||q'~(p_user VARCHAR2,p_tenancy VARCHAR2,p_fingerprint VARCHAR2,p_key VARCHAR2) AUTHID DEFINER AS
 BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN'
   OR NVL(SYS_CONTEXT('USERENV','PROXY_USER'),'ADMIN') NOT IN('ADMIN','ORDS_PUBLIC_USER')
   THEN RAISE_APPLICATION_ERROR(-20981,'ADMIN credential preparation only');END IF;
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
