-- ADMIN, after 01_create_user_worksheet.sql creates the dedicated user.
-- Explicit creation privileges support own objects and the RDF network APIs.
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE SEQUENCE, CREATE TYPE, CREATE TRIGGER TO KCV_LAB
/
-- Resolve public synonyms; package owners differ between Oracle distributions.
DECLARE
  l_owner VARCHAR2(128);
  l_name VARCHAR2(128);
BEGIN
  FOR item IN (SELECT 'SEM_APIS' name FROM dual UNION ALL
               SELECT 'DBMS_CLOUD' FROM dual UNION ALL
               SELECT 'DBMS_CRYPTO' FROM dual UNION ALL
               SELECT 'DBMS_LOCK' FROM dual UNION ALL
               SELECT 'DBMS_CLOUD_AI' FROM dual UNION ALL
               SELECT 'DBMS_CLOUD_AI_AGENT' FROM dual) LOOP
    BEGIN
      SELECT table_owner,table_name INTO l_owner,l_name FROM all_synonyms
       WHERE owner='PUBLIC' AND synonym_name=item.name;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      SELECT owner,object_name INTO l_owner,l_name FROM dba_objects
       WHERE object_name=item.name AND object_type='PACKAGE';
    END;
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON '||DBMS_ASSERT.ENQUOTE_NAME(l_owner,FALSE)||'.'||
      DBMS_ASSERT.ENQUOTE_NAME(l_name,FALSE)||' TO KCV_LAB';
  END LOOP;
END;
/
