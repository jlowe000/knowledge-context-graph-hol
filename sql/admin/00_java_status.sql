-- ADMIN: read-only status, safe even before Java is installed.
SELECT status, version FROM dba_registry WHERE comp_id='JAVAVM'
/
