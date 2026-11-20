-- ADMIN, read-only. This does not request Java enablement or restart anything.
SELECT status, version FROM dba_registry WHERE comp_id='JAVAVM'
/
SELECT o.owner, o.object_name, o.object_type, o.status FROM dba_objects o
 WHERE o.object_type IN ('PACKAGE','FUNCTION') AND
 (o.object_name IN ('SEM_APIS','SDO_SEM_APIS','RDF_APIS','RDF_MATCH','DBMS_CLOUD_AI','DBMS_CLOUD_AI_AGENT')
 OR (o.owner,o.object_name) IN (SELECT table_owner,table_name FROM all_synonyms
   WHERE owner='PUBLIC' AND synonym_name IN ('SEM_APIS','SEM_MATCH')))
/
SELECT owner,synonym_name,table_owner,table_name FROM all_synonyms
 WHERE synonym_name IN ('SEM_APIS','SEM_MATCH','SEM_MODELS','SEM_RULEBASES','DBMS_CLOUD_AI','DBMS_CLOUD_AI_AGENT') AND owner='PUBLIC'
/
