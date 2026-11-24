-- ADMIN: isolated dev schema only. Bind KCV_DEV_SCHEMA to a new upper-case KCV_ name.
-- No password is created. Connect as the owner through the explicitly granted ADMIN proxy.
-- All prerequisites are checked before CREATE USER. DDL commits; stop and inspect any failure.
DECLARE
  l_schema VARCHAR2(128):=:KCV_DEV_SCHEMA;
  l_target VARCHAR2(132);
  l_count PLS_INTEGER;
  TYPE names_t IS TABLE OF VARCHAR2(128) INDEX BY PLS_INTEGER;
  l_owners names_t;
  l_packages names_t;
  l_index PLS_INTEGER:=0;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');
  END IF;
  IF l_schema IS NULL OR NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use an upper-case KCV_ identifier of 5 to 30 characters');
  END IF;
  l_target:=DBMS_ASSERT.ENQUOTE_NAME(l_schema,FALSE);
  SELECT COUNT(*) INTO l_count FROM dba_users WHERE username=l_schema;
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20983,'Target schema already exists; nothing was changed');END IF;
  SELECT COUNT(*) INTO l_count FROM dba_registry WHERE comp_id='JAVAVM' AND status='VALID';
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20984,'JAVAVM must already be VALID; this script does not enable or restart it');END IF;
  SELECT COUNT(*) INTO l_count FROM dba_tablespaces WHERE tablespace_name='DATA' AND contents='PERMANENT' AND status='ONLINE';
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20985,'The online DATA tablespace is required');END IF;
  FOR item IN (SELECT 'SEM_APIS' name FROM dual UNION ALL SELECT 'DBMS_CLOUD' FROM dual
    UNION ALL SELECT 'DBMS_CRYPTO' FROM dual UNION ALL SELECT 'DBMS_LOCK' FROM dual
    UNION ALL SELECT 'DBMS_CLOUD_AI' FROM dual UNION ALL SELECT 'DBMS_CLOUD_AI_AGENT' FROM dual) LOOP
    l_index:=l_index+1;
    BEGIN
      SELECT table_owner,table_name INTO l_owners(l_index),l_packages(l_index)
        FROM all_synonyms WHERE owner='PUBLIC' AND synonym_name=item.name AND db_link IS NULL;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      SELECT owner,object_name INTO l_owners(l_index),l_packages(l_index)
        FROM dba_objects WHERE object_name=item.name AND object_type='PACKAGE';
    END;
    SELECT COUNT(*) INTO l_count FROM dba_objects
      WHERE owner=l_owners(l_index) AND object_name=l_packages(l_index) AND object_type='PACKAGE' AND status='VALID';
    IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20986,'Required package is unavailable: '||item.name);END IF;
  END LOOP;
  EXECUTE IMMEDIATE 'CREATE USER '||l_target||' NO AUTHENTICATION QUOTA 1G ON DATA';
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE TYPE, CREATE TRIGGER TO '||l_target;
  FOR i IN 1..l_index LOOP
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON '||DBMS_ASSERT.ENQUOTE_NAME(l_owners(i),FALSE)||'.'||
      DBMS_ASSERT.ENQUOTE_NAME(l_packages(i),FALSE)||' TO '||l_target;
  END LOOP;
  EXECUTE IMMEDIATE 'ALTER USER '||l_target||' GRANT CONNECT THROUGH ADMIN';
  DBMS_OUTPUT.PUT_LINE('KCV_DEV_SCHEMA_CREATED='||l_schema);
END;
/
