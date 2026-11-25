-- ADMIN: Run Statement. KCV_SCHEMA is the chosen existing owner; blank means KCV_LAB.
-- Additive grants only: no password reset, DBA/ANY privilege or owner replacement.
-- Check every required package before the first GRANT; DDL grants commit independently.
DECLARE
  l_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');
  l_target VARCHAR2(132);
  l_owner VARCHAR2(128);
  l_name VARCHAR2(128);
  l_count PLS_INTEGER;
  l_index PLS_INTEGER:=0;
  TYPE names_t IS TABLE OF VARCHAR2(128) INDEX BY PLS_INTEGER;
  l_owners names_t;l_names names_t;
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')<>'ADMIN' THEN
    RAISE_APPLICATION_ERROR(-20981,'Use a direct ADMIN session');END IF;
  IF NOT REGEXP_LIKE(l_schema,'^KCV_[A-Z0-9_]{1,26}$','c') THEN
    RAISE_APPLICATION_ERROR(-20982,'Use a KCV_ owner name of 5 to 30 letters, digits or underscores');END IF;
  SELECT COUNT(*) INTO l_count FROM dba_users WHERE username=l_schema;
  IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20983,'Create or identify the intended project owner first');END IF;
  l_target:=DBMS_ASSERT.ENQUOTE_NAME(l_schema,FALSE);
  FOR item IN (SELECT 'SEM_APIS' name FROM dual UNION ALL
               SELECT 'DBMS_CLOUD' FROM dual UNION ALL
               SELECT 'DBMS_CRYPTO' FROM dual UNION ALL
               SELECT 'DBMS_LOCK' FROM dual UNION ALL
               SELECT 'DBMS_CLOUD_AI' FROM dual UNION ALL
               SELECT 'DBMS_CLOUD_AI_AGENT' FROM dual) LOOP
    BEGIN
      SELECT table_owner,table_name INTO l_owner,l_name FROM all_synonyms
       WHERE owner='PUBLIC' AND synonym_name=item.name AND db_link IS NULL;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      SELECT owner,object_name INTO l_owner,l_name FROM dba_objects
       WHERE object_name=item.name AND object_type='PACKAGE';
    END;
    SELECT COUNT(*) INTO l_count FROM dba_objects WHERE owner=l_owner AND object_name=l_name AND object_type='PACKAGE' AND status='VALID';
    IF l_count<>1 THEN RAISE_APPLICATION_ERROR(-20986,'Required package is unavailable: '||item.name);END IF;
    l_index:=l_index+1;l_owners(l_index):=l_owner;l_names(l_index):=l_name;
  END LOOP;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE, CREATE TYPE, CREATE TRIGGER TO '||l_target;
  FOR i IN 1..l_index LOOP
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON '||DBMS_ASSERT.ENQUOTE_NAME(l_owners(i),FALSE)||'.'||
      DBMS_ASSERT.ENQUOTE_NAME(l_names(i),FALSE)||' TO '||l_target;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('KCV_OWNER_GRANTS_READY='||l_schema);
END;
/
