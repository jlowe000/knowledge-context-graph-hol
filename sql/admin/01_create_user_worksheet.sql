-- ADMIN: Run Statement on this block; SQL Worksheet prompts for the bind value.
-- The password is not supplied in this file. Do not save credentials in Git.
DECLARE
  l_password VARCHAR2(128):=:KCV_LAB_PASSWORD;
  l_count NUMBER;
BEGIN
  IF l_password IS NULL OR NOT REGEXP_LIKE(l_password,'^[A-Za-z0-9_!#$%*+.-]{12,64}$') THEN
    RAISE_APPLICATION_ERROR(-20010,'Supply a 12-64 character lab password, without quotes or whitespace');
  END IF;
  SELECT COUNT(*) INTO l_count FROM dba_users WHERE username='KCV_LAB';
  IF l_count<>0 THEN RAISE_APPLICATION_ERROR(-20011,'KCV_LAB already exists; inspect rather than reset it'); END IF;
  EXECUTE IMMEDIATE 'CREATE USER KCV_LAB IDENTIFIED BY "'||l_password||'" QUOTA 500M ON DATA';
END;
/
