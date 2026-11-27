-- FRESH part 001 of 025. Run Script as the project owner.
-- Run in manifest order. Stop after any error; do not skip ahead.
-- An oversized atomic step is retained intact to preserve its checks.
DECLARE l_step CLOB;
BEGIN
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('DECLARE n NUMBER;
BEGIN
 IF SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')<>SYS_CONTEXT(''USERENV'',''SESSION_USER'')
  OR SYS_CONTEXT(''USERENV'',''SESSION_USER'') IN (''ADMIN'',''SYS'',''SYSTEM'') THEN
  RAISE_APPLICATION_ERROR(-20300,''Connect as the intended project schema owner''); END IF;
 SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=''KCV_SCHEMA_MIGRATIONS'';
 IF n=0 THEN EXECUTE IMMEDIATE ''CREATE TABLE kcv_schema_migrations (
  migration_id VARCHAR2(128) PRIMARY KEY, payload_sha256 VARCHAR2(64) NOT NULL,
  product_version VARCHAR2(20) NOT NULL, phase VARCHAR2(16) NOT NULL,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE, error_code NUMB');
 l_step:=l_step||TO_CLOB('ER,
  CHECK(phase IN (''''RUNNING'''',''''COMPLETE'''',''''FAILED'''')))''; END IF;
 SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=''KCV_SCHEMA_MIGRATIONS'' AND
  ((column_name=''MIGRATION_ID'' AND data_type=''VARCHAR2'' AND char_length=128 AND nullable=''N'') OR
   (column_name=''PAYLOAD_SHA256'' AND data_type=''VARCHAR2'' AND char_length=64 AND nullable=''N'') OR
   (column_name=''PRODUCT_VERSION'' AND data_type=''VARCHAR2'' AND char_length=20 AND nullable=''N'') OR
   (column_name=''PHASE'' AND data_type=''VARCHAR2'' AND char_length=16 AND nullable=''N'') OR
   (column_name=''STARTED_AT'' AND data_type=''TIMESTAMP(6) WITH TIME ZONE'' AND nullable=''N'') OR
   (column_name=''COMPLETED_AT'' AND data_type=''TIMESTAMP(6) WI');
 l_step:=l_step||TO_CLOB('TH TIME ZONE'') OR
   (column_name=''ERROR_CODE'' AND data_type=''NUMBER''));
 IF n<>7 THEN RAISE_APPLICATION_ERROR(-20300,''Migration registry structure differs''); END IF;
 SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=''KCV_SCHEMA_MIGRATIONS'';
 IF n<>7 THEN RAISE_APPLICATION_ERROR(-20300,''Migration registry has unexpected columns''); END IF;
 SELECT COUNT(*) INTO n FROM user_constraints c JOIN user_cons_columns k ON k.constraint_name=c.constraint_name
  WHERE c.table_name=''KCV_SCHEMA_MIGRATIONS'' AND c.constraint_type=''P'' AND c.status=''ENABLED''
  AND c.validated=''VALIDATED'' AND k.column_name=''MIGRATION_ID'' AND k.position=1;
 IF n<>1 THEN RAISE_APPLICATION_ERROR(-20300,''Migration reg');
 l_step:=l_step||TO_CLOB('istry primary key differs''); END IF;
END;');
 EXECUTE IMMEDIATE l_step;
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('BEGIN DBMS_OUTPUT.PUT_LINE(''KCV_SCHEMA_PART_COMPLETE=fresh:001/025'');END;');
 EXECUTE IMMEDIATE l_step;
END;
/
