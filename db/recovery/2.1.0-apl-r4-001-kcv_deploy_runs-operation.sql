-- Reconcile only physically complete work, after investigating the failure.
-- Acquires the same migration lock. Does not rerun DDL, clear a live lock or skip postconditions.
DECLARE
 l_lock VARCHAR2(128);l_result PLS_INTEGER;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN (' ',CHR(9),CHR(10),CHR(13),'"') THEN r:=r||UPPER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status='VALID';
  require(n=1,'Missing or invalid program: '||p_name||' '||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute='ERROR';
  require(n=0,'Compilation errors: '||p_name||' '||p_type);
  FOR r IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>'--' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||' ')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,'Installed source differs: '||p_name||' '||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_column VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string('name');cols:=t.get_array('columns');cs:=t.get_array('constraints');
  wanted_temp:=t.get_string('temporary');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,'Missing or incompatible table: '||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,'Column count differs: '||name);
  FOR i IN 0..cols.get_size-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string('name');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identity_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,'Missing column: '||name||'.'||c.get_string('name')); END;
   require(actual_type=c.get_string('type'),'Column type differs: '||name||'.'||c.get_string('name'));
   require(actual_nullable=c.get_string('nullable'),'Column nullability differs: '||name||'.'||c.get_string('name'));
   IF c.has('length') THEN
    require(len=c.get_number('length'),'Column length differs: '||name||'.'||c.get_string('name'));
    require(char_semantics=c.get_string('char_used'),'Column character semantics differ: '||name||'.'||c.get_string('name'));
   END IF;
   IF c.get_string('type')='NUMBER' THEN
    require(NVL(prec,-1)=NVL(c.get_number('precision'),-1) AND NVL(sc,-99)=NVL(c.get_number('scale'),-99),'Number precision differs: '||name||'.'||c.get_string('name'));
   END IF;
   require(ident=c.get_string('identity'),'Column identity differs: '||name||'.'||c.get_string('name'));
   IF ident='NO' THEN d:=def;require(NVL(compact(d),'#NULL#')=NVL(compact(c.get_string('default')),'#NULL#'),'Column default differs: '||name||'.'||c.get_string('name'));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;wanted_constraint:=c.get_string('type');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status='ENABLED' AND validated='VALIDATED'
      AND deferrable='NOT DEFERRABLE' AND (constraint_type<>'R' OR (delete_rule='NO ACTION' AND r_owner=SYS_CONTEXT('USERENV','CURRENT_USER')))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_columns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type='C' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string('expression')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_string('columns') THEN
     IF r.constraint_type='R' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,',') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string('reference_table') AND refcols=c.get_string('reference_columns') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
   require(found,'Missing or incompatible constraint: '||name||' '||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r.constraint_type<>'C' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),'^[A-Z][A-Z0-9_$]*ISNOTNULL$') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,'Unexpected constraints: '||name);
 END;

BEGIN
 require(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')=SYS_CONTEXT('USERENV','SESSION_USER')
  AND SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','SYS','SYSTEM'),'Connect as the intended project schema owner');
 DBMS_LOCK.ALLOCATE_UNIQUE('KCV_SCHEMA_'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),l_lock);
 l_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_result=0,'Another migration is active');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-r4-001-kcv_deploy_runs-operation'
  AND payload_sha256='15c5ce883fb3338d08acfe08e6d100c8b8e4121cd24409638f180121d3494697' AND phase IN ('FAILED','RUNNING');
 require(l_n=1,'Expected exactly one matching incomplete migration');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa');
 l_expected:=l_expected||TO_CLOB('ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default');
 l_expected:=l_expected||TO_CLOB('":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''CONFIGURE_PROFILE'',''TEST_MODEL'',''ENSURE_NETWORK'',''REGISTER_RUNTIME'',''LOAD_DATASET'',''ENABLE_LEARNING'',''CREATE_OCI_CREDENTIAL'')"},{"type":"C","expression":"status IN (''RUNNING'',''SUCCEEDED'',''FAILED'',''INTERRUPTED'')"},{"type":"C","expression":"account_id>=0"}]}');
 check_table(l_expected);
 UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL
  WHERE migration_id='2.1.0-apl-r4-001-kcv_deploy_runs-operation' AND payload_sha256='15c5ce883fb3338d08acfe08e6d100c8b8e4121cd24409638f180121d3494697';
 COMMIT;l_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN ROLLBACK;IF l_lock IS NOT NULL AND l_result=0 THEN l_result:=DBMS_LOCK.RELEASE(l_lock);END IF;RAISE;
END;
/
