-- Generated from immutable local SQL; do not edit this wrapper.
DECLARE
 l_sql CLOB; l_hash VARCHAR2(64); l_phase VARCHAR2(16); l_started BOOLEAN:=FALSE;
 l_lock VARCHAR2(128); l_lock_result PLS_INTEGER; l_error NUMBER;

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
 l_lock_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_lock_result=0,'Another schema migration is active');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-r4-003-kcv_deploy-package-body' AND payload_sha256='f7613ad3ef4f1f1f992bd5615ffebe23aa91cdbde7d891666810cdae3efaff96' AND phase='COMPLETE';
 require(l_n=1,'Required prior migration is incomplete: 2.1.0-apl-r4-003-kcv_deploy-package-body');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-r4-004-backend-ready';
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash='4547ce832086a3a7a03169451150e24dfa8e5e851229fc31552bac5c5d4c741a','Migration payload/verification changed: 2.1.0-apl-r4-004-backend-ready');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: 2.1.0-apl-r4-004-backend-ready');
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status='VALID';
  require(n=1,'Missing or invalid program: '||p_name||' '||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute='ERROR';
  require(n=0,'Compilation errors: '||p_name||' '||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>'--' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||' ')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,'Installed source digest differs: '||p_name||' '||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest('KCV_ACCESS','PACKAGE','bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b');
 check_digest('KCV_ACCESS','PACKAGE BODY','83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5');
 check_digest('KCV_APEX','PACKAGE','557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92');
 check_digest('KCV_APEX','PACKAGE BODY','d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061');
 check_digest('KCV_CONTEXT_DELETE','PACKAGE','022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70');
 check_digest('KCV_CONTEXT_DELETE','PACKAGE BODY','a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951');
 check_digest('KCV_CONTEXT_PACKET','FUNCTION','f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404');
 check_digest('KCV_CONTEXT_SEARCH','PACKAGE','80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba');
 check_digest('KCV_CONTEXT_SEARCH','PACKAGE BODY','e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480');
 check_digest('KCV_DATASET','PACKAGE','381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea');
 check_digest('KCV_DATASET','PACKAGE BODY','2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007');
 check_digest('KCV_DEPLOY','PACKAGE','10fb99163cabc1638c3f6ac8b63d4153e906df26330c572d658cf37d452e28f9');
 check_digest('KCV_DEPLOY','PACKAGE BODY','1710117af168258bf3d5fd716946c5985f12de4b15360e93a3adb4422904c429');
 check_digest('KCV_DEPLOY_CONTRACT','PACKAGE','1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af');
 check_digest('KCV_EVIDENCE_PACKET','FUNCTION','7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13');
 check_digest('KCV_EXTRACT_DOMAIN','FUNCTION','b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82');
 check_digest('KCV_PERSONAL_CONTEXT_API','PACKAGE','f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626');
 check_digest('KCV_PERSONAL_CONTEXT_API','PACKAGE BODY','bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00');
 check_digest('KCV_PERSONAL_JOURNEY','PACKAGE','3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623');
 check_digest('KCV_PERSONAL_JOURNEY','PACKAGE BODY','dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c');
 check_digest('KCV_SCENARIO','PACKAGE','6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a');
 check_digest('KCV_SCENARIO','PACKAGE BODY','f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a');
 check_digest('KCV_SCENARIO_EVIDENCE','FUNCTION','74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371');
 check_digest('KCV_SCENARIO_PROPOSE','FUNCTION','ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939');
 check_digest('KCV_SOURCE_PACKET','FUNCTION','c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416');
 check_digest('KCV_TRACE','PACKAGE','86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662');
 check_digest('KCV_TRACE','PACKAGE BODY','47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702');
END;
 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","');
 l_expected:=l_expected||TO_CLOB('identity":"NO","default":"''ON''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''NOT_TESTED''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ');
 l_expected:=l_expected||TO_CLOB('ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''ON'',''OFF'')"},{"type":"C","expression":"model_test_status IN (''NOT_TESTED'',''SUCCEEDED'',''FAILED'')"}]}');
 check_table(l_expected);
 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa');
 l_expected:=l_expected||TO_CLOB('ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default');
 l_expected:=l_expected||TO_CLOB('":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''CONFIGURE_PROFILE'',''TEST_MODEL'',''ENSURE_NETWORK'',''REGISTER_RUNTIME'',''LOAD_DATASET'',''ENABLE_LEARNING'',''CREATE_OCI_CREDENTIAL'')"},{"type":"C","expression":"status IN (''RUNNING'',''SUCCEEDED'',''FAILED'',''INTERRUPTED'')"},{"type":"C","expression":"account_id>=0"}]}');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_DEPLOY_RUNS_RECENT'
 AND table_owner=SYS_CONTEXT('USERENV','CURRENT_USER') AND table_name='KCV_DEPLOY_RUNS'
 AND table_type='TABLE' AND uniqueness='NONUNIQUE' AND index_type='FUNCTION-BASED NORMAL'
 AND status='VALID' AND funcidx_status='ENABLED' AND partitioned='NO' AND visibility='VISIBLE';
 require(l_n=1,'Deployment request index differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=2,'Deployment request index key count differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND descend='ASC';
 require(l_n=2,'Deployment request index direction differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS'
   AND column_position=2 AND column_name='RUN_ID';
 require(l_n=1,'Deployment request index second key differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=1,'Deployment request index expression count differs');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,'[[:space:]]','')='SYS_EXTRACT_UTC("STARTED_AT")',
   'Deployment request index UTC expression differs');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name='KCV_DEPLOY_RUNS' AND column_name=first_column
    AND hidden_column='YES' AND virtual_column='YES' AND data_type='TIMESTAMP(6)';
  require(l_n=1,'Deployment request index generated UTC column differs');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE 'KCV\_%' ESCAPE '\' AND status='INVALID';
 require(l_n=0,'Project contains invalid objects');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE 'KCV\_%' ESCAPE '\' AND attribute='ERROR';
 require(l_n=0,'Project contains compilation errors');
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES('2.1.0-apl-r4-004-backend-ready','4547ce832086a3a7a03169451150e24dfa8e5e851229fc31552bac5c5d4c741a','2.1.0','RUNNING');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('');
 l_sql:=l_sql||TO_CLOB('BEGIN NULL; END;');
  EXECUTE IMMEDIATE l_sql;
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status='VALID';
  require(n=1,'Missing or invalid program: '||p_name||' '||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute='ERROR';
  require(n=0,'Compilation errors: '||p_name||' '||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>'--' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||' ')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,'Installed source digest differs: '||p_name||' '||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest('KCV_ACCESS','PACKAGE','bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b');
 check_digest('KCV_ACCESS','PACKAGE BODY','83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5');
 check_digest('KCV_APEX','PACKAGE','557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92');
 check_digest('KCV_APEX','PACKAGE BODY','d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061');
 check_digest('KCV_CONTEXT_DELETE','PACKAGE','022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70');
 check_digest('KCV_CONTEXT_DELETE','PACKAGE BODY','a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951');
 check_digest('KCV_CONTEXT_PACKET','FUNCTION','f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404');
 check_digest('KCV_CONTEXT_SEARCH','PACKAGE','80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba');
 check_digest('KCV_CONTEXT_SEARCH','PACKAGE BODY','e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480');
 check_digest('KCV_DATASET','PACKAGE','381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea');
 check_digest('KCV_DATASET','PACKAGE BODY','2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007');
 check_digest('KCV_DEPLOY','PACKAGE','10fb99163cabc1638c3f6ac8b63d4153e906df26330c572d658cf37d452e28f9');
 check_digest('KCV_DEPLOY','PACKAGE BODY','1710117af168258bf3d5fd716946c5985f12de4b15360e93a3adb4422904c429');
 check_digest('KCV_DEPLOY_CONTRACT','PACKAGE','1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af');
 check_digest('KCV_EVIDENCE_PACKET','FUNCTION','7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13');
 check_digest('KCV_EXTRACT_DOMAIN','FUNCTION','b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82');
 check_digest('KCV_PERSONAL_CONTEXT_API','PACKAGE','f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626');
 check_digest('KCV_PERSONAL_CONTEXT_API','PACKAGE BODY','bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00');
 check_digest('KCV_PERSONAL_JOURNEY','PACKAGE','3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623');
 check_digest('KCV_PERSONAL_JOURNEY','PACKAGE BODY','dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c');
 check_digest('KCV_SCENARIO','PACKAGE','6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a');
 check_digest('KCV_SCENARIO','PACKAGE BODY','f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a');
 check_digest('KCV_SCENARIO_EVIDENCE','FUNCTION','74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371');
 check_digest('KCV_SCENARIO_PROPOSE','FUNCTION','ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939');
 check_digest('KCV_SOURCE_PACKET','FUNCTION','c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416');
 check_digest('KCV_TRACE','PACKAGE','86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662');
 check_digest('KCV_TRACE','PACKAGE BODY','47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702');
END;
 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","');
 l_expected:=l_expected||TO_CLOB('identity":"NO","default":"''ON''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''NOT_TESTED''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ');
 l_expected:=l_expected||TO_CLOB('ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''ON'',''OFF'')"},{"type":"C","expression":"model_test_status IN (''NOT_TESTED'',''SUCCEEDED'',''FAILED'')"}]}');
 check_table(l_expected);
 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa');
 l_expected:=l_expected||TO_CLOB('ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default');
 l_expected:=l_expected||TO_CLOB('":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''CONFIGURE_PROFILE'',''TEST_MODEL'',''ENSURE_NETWORK'',''REGISTER_RUNTIME'',''LOAD_DATASET'',''ENABLE_LEARNING'',''CREATE_OCI_CREDENTIAL'')"},{"type":"C","expression":"status IN (''RUNNING'',''SUCCEEDED'',''FAILED'',''INTERRUPTED'')"},{"type":"C","expression":"account_id>=0"}]}');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name='KCV_DEPLOY_RUNS_RECENT'
 AND table_owner=SYS_CONTEXT('USERENV','CURRENT_USER') AND table_name='KCV_DEPLOY_RUNS'
 AND table_type='TABLE' AND uniqueness='NONUNIQUE' AND index_type='FUNCTION-BASED NORMAL'
 AND status='VALID' AND funcidx_status='ENABLED' AND partitioned='NO' AND visibility='VISIBLE';
 require(l_n=1,'Deployment request index differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=2,'Deployment request index key count differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND descend='ASC';
 require(l_n=2,'Deployment request index direction differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS'
   AND column_position=2 AND column_name='RUN_ID';
 require(l_n=1,'Deployment request index second key differs');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS';
 require(l_n=1,'Deployment request index expression count differs');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,'[[:space:]]','')='SYS_EXTRACT_UTC("STARTED_AT")',
   'Deployment request index UTC expression differs');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name='KCV_DEPLOY_RUNS_RECENT' AND table_name='KCV_DEPLOY_RUNS' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name='KCV_DEPLOY_RUNS' AND column_name=first_column
    AND hidden_column='YES' AND virtual_column='YES' AND data_type='TIMESTAMP(6)';
  require(l_n=1,'Deployment request index generated UTC column differs');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE 'KCV\_%' ESCAPE '\' AND status='INVALID';
 require(l_n=0,'Project contains invalid objects');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE 'KCV\_%' ESCAPE '\' AND attribute='ERROR';
 require(l_n=0,'Project contains compilation errors');
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id='2.1.0-apl-r4-004-backend-ready';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id='2.1.0-apl-r4-004-backend-ready';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;
