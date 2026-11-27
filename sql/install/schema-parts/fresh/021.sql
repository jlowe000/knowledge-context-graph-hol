-- FRESH part 021 of 025. Run Script as the project owner.
-- Run in manifest order. Stop after any error; do not skip ahead.
-- An oversized atomic step is retained intact to preserve its checks.
DECLARE l_step CLOB;
BEGIN
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('DECLARE
 l_sql CLOB;l_replaced BOOLEAN:=FALSE;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,i+1,1)=CHR(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN ('' '',CHR(9),CHR(10),CHR(13),''"'') THEN r:=r||UPP');
 l_step:=l_step||TO_CLOB('ER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>');
 l_step:=l_step||TO_CLOB('''--'' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,''Installed source differs: ''||p_name||'' ''||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; ident VARCHAR2(3); char_semantics VARCHAR2(1); def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_col');
 l_step:=l_step||TO_CLOB('umn VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string(''name'');cols:=t.get_array(''columns'');cs:=t.get_array(''constraints'');
  wanted_temp:=t.get_string(''temporary'');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,''Missing or incompatible table: ''||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
  require(n=cols.get_size,''Column count differs: ''||name);
  FOR i IN 0..cols.get_size-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string(''name'');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identit');
 l_step:=l_step||TO_CLOB('y_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,''Missing column: ''||name||''.''||c.get_string(''name'')); END;
   require(actual_type=c.get_string(''type''),''Column type differs: ''||name||''.''||c.get_string(''name''));
   require(actual_nullable=c.get_string(''nullable''),''Column nullability differs: ''||name||''.''||c.get_string(''name''));
   IF c.has(''length'') THEN
    require(len=c.get_number(''length''),''Column length differs: ''||name||''.''||c.get_string(''name''));
    require(char_semantics=c.get_string(');
 l_step:=l_step||TO_CLOB('''char_used''),''Column character semantics differ: ''||name||''.''||c.get_string(''name''));
   END IF;
   IF c.get_string(''type'')=''NUMBER'' THEN
    require(NVL(prec,-1)=NVL(c.get_number(''precision''),-1) AND NVL(sc,-99)=NVL(c.get_number(''scale''),-99),''Number precision differs: ''||name||''.''||c.get_string(''name''));
   END IF;
   require(ident=c.get_string(''identity''),''Column identity differs: ''||name||''.''||c.get_string(''name''));
   IF ident=''NO'' THEN d:=def;require(NVL(compact(d),''#NULL#'')=NVL(compact(c.get_string(''default'')),''#NULL#''),''Column default differs: ''||name||''.''||c.get_string(''name''));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;');
 l_step:=l_step||TO_CLOB('wanted_constraint:=c.get_string(''type'');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status=''ENABLED'' AND validated=''VALIDATED''
      AND deferrable=''NOT DEFERRABLE'' AND (constraint_type<>''R'' OR (delete_rule=''NO ACTION'' AND r_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'')))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,'','') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_columns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type=''C'' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string(''expression'')) THEN found:=TRUE;E');
 l_step:=l_step||TO_CLOB('ND IF;
    ELSIF colnames=c.get_string(''columns'') THEN
     IF r.constraint_type=''R'' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name,'','') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string(''reference_table'') AND refcols=c.get_string(''reference_columns'') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
   require(found,''Missing or incompatible constraint: ''||name||'' ''||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WH');
 l_step:=l_step||TO_CLOB('ERE table_name=name) LOOP
   IF r.constraint_type<>''C'' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),''^[A-Z][A-Z0-9_$]*ISNOTNULL$'') THEN
    meaningful_constraints:=meaningful_constraints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,''Unexpected constraints: ''||name);
 END;

BEGIN
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r4-ready'' AND payload_sha256=''bfd965ec8cf6165dc982e8ef5bcfaadf7ed8efecf319de21937503ad65f7d1ee'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(6');
 l_step:=l_step||TO_CLOB('4);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBM');
 l_step:=l_step||TO_CLOB('S_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY''');
 l_step:=l_step||TO_CLOB(',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066e');
 l_step:=l_step||TO_CLOB('dc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''10fb99163cabc1638c3f6ac8b63d4153e906df26330c572d658cf37d452e28f9'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''1710117af168258bf3d5fd716946c5985f12de4b15360e93a3adb4422904c429'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE BODY'',''2f35936163285eb42bc3e3479df8cb2bc3359853b2a14df6f91fc50e5d6b55b7'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468');
 l_step:=l_step||TO_CLOB('c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b');
 l_step:=l_step||TO_CLOB('5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70');
 l_step:=l_step||TO_CLOB('153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"');
 l_step:=l_step||TO_CLOB('length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6');
 l_step:=l_step||TO_CLOB(') WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","co');
 l_step:=l_step||TO_CLOB('lumns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":nu');
 l_step:=l_step||TO_CLOB('ll,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_');
 l_step:=l_step||TO_CLOB('expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''',''''CREATE_OCI_CREDENTIAL'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CO');
 l_step:=l_step||TO_CLOB('NTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SE');
 l_step:=l_step||TO_CLOB('LECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(ex');
 l_step:=l_step||TO_CLOB('pression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains ');
 l_step:=l_step||TO_CLOB('invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r4-004-backend-ready'' AND payload_sha256=''4547ce832086a3a7a03169451150e24dfa8');
 l_step:=l_step||TO_CLOB('e5e851229fc31552bac5c5d4c741a'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10)');
 l_step:=l_step||TO_CLOB(')) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE B');
 l_step:=l_step||TO_CLOB('ODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8');
 l_step:=l_step||TO_CLOB('704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''10fb99163cabc1638c3f6ac8b63d4153e906df26330c572d658cf37d452e28f9'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''1710117af168258bf3d5fd716946c5985f12de4b15360e93a3adb4422904c429'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008b');
 l_step:=l_step||TO_CLOB('deba44b3becd1af'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e');
 l_step:=l_step||TO_CLOB('965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5');
 l_step:=l_step||TO_CLOB('662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":nul');
 l_step:=l_step||TO_CLOB('l},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH T');
 l_step:=l_step||TO_CLOB('IME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expec');
 l_step:=l_step||TO_CLOB('ted:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID",');
 l_step:=l_step||TO_CLOB('"type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name"');
 l_step:=l_step||TO_CLOB(':"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''',''''CREATE_OCI_CREDENTIAL'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUN');
 l_step:=l_step||TO_CLOB('T(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_');
 l_step:=l_step||TO_CLOB('DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY');
 l_step:=l_step||TO_CLOB('_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects W');
 l_step:=l_step||TO_CLOB('HERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migr');
 l_step:=l_step||TO_CLOB('ation_id=''2.1.0-apl-r3-ready'' AND payload_sha256=''3e7760dd6fe6094b32b39ab95ad2df64f4ad8385f5ea810479ae26adbaa74a3d'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE nam');
 l_step:=l_step||TO_CLOB('e=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f3888468');
 l_step:=l_step||TO_CLOB('8f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac');
 l_step:=l_step||TO_CLOB('0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''c058846d139b9f507e07f4b71090bd87869ec4cd6ff444ae6cfdcd52cc1445c0'');
 check_dige');
 l_step:=l_step||TO_CLOB('st(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE BODY'',''8c1c5181656ae6d42e4fc49bc1c2346017d4ab95c04fa1a9b056781e10ed16a8'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
');
 l_step:=l_step||TO_CLOB(' check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_');
 l_step:=l_step||TO_CLOB('digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","ty');
 l_step:=l_step||TO_CLOB('pe":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length"');
 l_step:=l_step||TO_CLOB(':64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"appl');
 l_step:=l_step||TO_CLOB('ication_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":');
 l_step:=l_step||TO_CLOB('"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NU');
 l_step:=l_step||TO_CLOB('MBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''')"');
 l_step:=l_step||TO_CLOB('},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RU');
 l_step:=l_step||TO_CLOB('NS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count ');
 l_step:=l_step||TO_CLOB('differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' A');
 l_step:=l_step||TO_CLOB('ND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompat');
 l_step:=l_step||TO_CLOB('ible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r3-002-backend-ready'' AND payload_sha256=''99dcaeee8d88f9136007661748a37baadefe9605e97322d1b82e3466968875ef'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*)');
 l_step:=l_step||TO_CLOB(' INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EX');
 l_step:=l_step||TO_CLOB('CEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONT');
 l_step:=l_step||TO_CLOB('EXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',');
 l_step:=l_step||TO_CLOB('''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''c058846d139b9f507e07f4b71090bd87869ec4cd6ff444ae6cfdcd52cc1445c0'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY');
 l_step:=l_step||TO_CLOB(''',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe');
 l_step:=l_step||TO_CLOB('34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO",');
 l_step:=l_step||TO_CLOB('"default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","');
 l_step:=l_step||TO_CLOB('type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"');
 l_step:=l_step||TO_CLOB('type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length"');
 l_step:=l_step||TO_CLOB(':24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","def');
 l_step:=l_step||TO_CLOB('ault":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSUR');
 l_step:=l_step||TO_CLOB('E_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  ');
 l_step:=l_step||TO_CLOB('WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_D');
 l_step:=l_step||TO_CLOB('EPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_');
 l_step:=l_step||TO_CLOB('DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64e');
 l_step:=l_step||TO_CLOB('b320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r2-ready'' AND payload_sha256=''a3d936703d3957f41f286a39f3139889e0ccda6e89f1ef593770273681589603'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or ');
 l_step:=l_step||TO_CLOB('invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''In');
 l_step:=l_step||TO_CLOB('stalled source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db');
 l_step:=l_step||TO_CLOB('4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2');
 l_step:=l_step||TO_CLOB('ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''18e1acaf5b56cb4aa25a40486fd5737dbfc42f2b4856c3cf61559caf05535e41'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE BODY'',''0c233cd449b39deda752a6f7bcf50e0552c323f31e1fb1703da7524e3178adcc'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b8');
 l_step:=l_step||TO_CLOB('2'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d');
 l_step:=l_step||TO_CLOB('676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"');
 l_step:=l_step||TO_CLOB('SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":');
 l_step:=l_step||TO_CLOB('"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_ex');
 l_step:=l_step||TO_CLOB('pected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type"');
 l_step:=l_step||TO_CLOB(':"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},');
 l_step:=l_step||TO_CLOB('{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default');
 l_step:=l_step||TO_CLOB('":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID''');
 l_step:=l_step||TO_CLOB(' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 ');
 l_step:=l_step||TO_CLOB('require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_c');
 l_step:=l_step||TO_CLOB('olumns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'')');
 l_step:=l_step||TO_CLOB(';
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r2-002-backend-ready'' AND payload_sha256=''40438d2a7556a1dbe9b036064d6771aa9e10620d0287d32aa883d0fe36373383'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=');
 l_step:=l_step||TO_CLOB('TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWE');
 l_step:=l_step||TO_CLOB('R(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92');
 l_step:=l_step||TO_CLOB(''');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check');
 l_step:=l_step||TO_CLOB('_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''18e1acaf5b56cb4aa25a40486fd5737dbfc42f2b4856c3cf61559caf05535e41'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUN');
 l_step:=l_step||TO_CLOB('CTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACK');
 l_step:=l_step||TO_CLOB('AGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||T');
 l_step:=l_step||TO_CLOB('O_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullabl');
 l_step:=l_step||TO_CLOB('e":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"');
 l_step:=l_step||TO_CLOB('name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","de');
 l_step:=l_step||TO_CLOB('fault":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nulla');
 l_step:=l_step||TO_CLOB('ble":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type');
 l_step:=l_step||TO_CLOB('":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness');
 l_step:=l_step||TO_CLOB('=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND descend=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name');
 l_step:=l_step||TO_CLOB('=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expre');
 l_step:=l_step||TO_CLOB('ssion differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND a');
 l_step:=l_step||TO_CLOB('ttribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-ready'' AND payload_sha256=''1b15435b3a3a9aedf222f36cefc8be42692d2275c593e253ad779cedc91897c7'' AND phase=''COMPLETE'';
 IF l_n=1 THEN
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2');
 l_step:=l_step||TO_CLOB(',p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''VALID'';
  require(n=1,''Missing or invalid program: ''||p_name||'' ''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''ERROR'';
  require(n=0,''Compilation errors: ''||p_name||'' ''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''--'' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)');
 l_step:=l_step||TO_CLOB('||'' '')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''Installed source digest differs: ''||p_name||'' ''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''KCV_ACCESS'',''PACKAGE'',''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'');
 check_digest(''KCV_ACCESS'',''PACKAGE BODY'',''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'');
 check_digest(''KCV_APEX'',''PACKAGE'',''557f9');
 l_step:=l_step||TO_CLOB('dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'');
 check_digest(''KCV_APEX'',''PACKAGE BODY'',''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE'',''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'');
 check_digest(''KCV_CONTEXT_DELETE'',''PACKAGE BODY'',''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'');
 check_digest(''KCV_CONTEXT_PACKET'',''FUNCTION'',''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE'',''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'');
 check_digest(''KCV_CONTEXT_SEARCH'',''PACKAGE BODY'',''e00d5e9ba152bf6');
 l_step:=l_step||TO_CLOB('9d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'');
 check_digest(''KCV_DATASET'',''PACKAGE'',''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'');
 check_digest(''KCV_DATASET'',''PACKAGE BODY'',''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'');
 check_digest(''KCV_DEPLOY'',''PACKAGE'',''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'');
 check_digest(''KCV_DEPLOY'',''PACKAGE BODY'',''65635147e716682a28512b4b3cbce5ba2d75c630834de5c49b1c31f6f0b09e38'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE'',''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'');
 check_digest(''KCV_DEPLOY_CONTRACT'',''PACKAGE BODY'',''f2ff5243d5f6ad83188b53dc949814b4ccf6d4b4e8ce');
 l_step:=l_step||TO_CLOB('05473b08d7ff17f55157'');
 check_digest(''KCV_EVIDENCE_PACKET'',''FUNCTION'',''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'');
 check_digest(''KCV_EXTRACT_DOMAIN'',''FUNCTION'',''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE'',''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'');
 check_digest(''KCV_PERSONAL_CONTEXT_API'',''PACKAGE BODY'',''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE'',''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'');
 check_digest(''KCV_PERSONAL_JOURNEY'',''PACKAGE BODY'',''dc62706c70bc5ced67702606fe87de8');
 l_step:=l_step||TO_CLOB('b294e965ace389c46c0259c72a51ce77c'');
 check_digest(''KCV_SCENARIO'',''PACKAGE'',''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'');
 check_digest(''KCV_SCENARIO'',''PACKAGE BODY'',''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'');
 check_digest(''KCV_SCENARIO_EVIDENCE'',''FUNCTION'',''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'');
 check_digest(''KCV_SCENARIO_PROPOSE'',''FUNCTION'',''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'');
 check_digest(''KCV_SOURCE_PACKET'',''FUNCTION'',''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'');
 check_digest(''KCV_TRACE'',''PACKAGE'',''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276');
 l_step:=l_step||TO_CLOB('919a5662'');
 check_digest(''KCV_TRACE'',''PACKAGE BODY'',''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'');
END;
 l_expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale');
 l_step:=l_step||TO_CLOB('":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'');
 l_expected:=l_expected||TO_CLOB(''identity":"NO","default":"''''ON''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''NOT_TESTED''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) W');
 l_step:=l_step||TO_CLOB('ITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '');
 l_expected:=l_expected||TO_CLOB(''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''ON'''',''''OFF'''')"},{"type":"C","expression":"model_test_status IN (''''NOT_TESTED'''',''''SUCCEEDED'''',''''FAILED'''')"}]}'');
 check_table(l_expected);
 l_');
 l_step:=l_step||TO_CLOB('expected:=TO_CLOB('''');
 l_expected:=l_expected||TO_CLOB(''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION');
 l_step:=l_step||TO_CLOB('_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'');
 l_expected:=l_expected||TO_CLOB(''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"');
 l_step:=l_step||TO_CLOB('name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'');
 l_expected:=l_expected||TO_CLOB(''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''CONFIGURE_PROFILE'''',''''TEST_MODEL'''',''''ENSURE_NETWORK'''',''''REGISTER_RUNTIME'''',''''LOAD_DATASET'''',''''ENABLE_LEARNING'''')"},{"type":"C","expression":"status IN (''''RUNNING'''',''''SUCCEEDED'''',''''FAILED'''',''''INTERRUPTED'''')"},{"type":"C","expression":"account_id>=0"}]}'');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM us');
 l_step:=l_step||TO_CLOB('er_indexes WHERE index_name=''KCV_DEPLOY_RUNS_RECENT''
 AND table_owner=SYS_CONTEXT(''USERENV'',''CURRENT_USER'') AND table_name=''KCV_DEPLOY_RUNS''
 AND table_type=''TABLE'' AND uniqueness=''NONUNIQUE'' AND index_type=''FUNCTION-BASED NORMAL''
 AND status=''VALID'' AND funcidx_status=''ENABLED'' AND partitioned=''NO'' AND visibility=''VISIBLE'';
 require(l_n=1,''Deployment request index differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=2,''Deployment request index key count differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND desc');
 l_step:=l_step||TO_CLOB('end=''ASC'';
 require(l_n=2,''Deployment request index direction differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS''
   AND column_position=2 AND column_name=''RUN_ID'';
 require(l_n=1,''Deployment request index second key differs'');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'';
 require(l_n=1,''Deployment request index expression count differs'');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND tab');
 l_step:=l_step||TO_CLOB('le_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''[[:space:]]'','''')=''SYS_EXTRACT_UTC("STARTED_AT")'',
   ''Deployment request index UTC expression differs'');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''KCV_DEPLOY_RUNS_RECENT'' AND table_name=''KCV_DEPLOY_RUNS'' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''KCV_DEPLOY_RUNS'' AND column_name=first_column
    AND hidden_column=''YES'' AND virtual_column=''YES'' AND data_type=''TIMESTAMP(6)'';
  require(l_n=1,''Deployment request index generated UTC column differs'');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE');
 l_step:=l_step||TO_CLOB(' ''KCV\_%'' ESCAPE ''\'' AND status=''INVALID'';
 require(l_n=0,''Project contains invalid objects'');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''KCV\_%'' ESCAPE ''\'' AND attribute=''ERROR'';
 require(l_n=0,''Project contains compilation errors'');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''2.1.0-apl-r1-005-backend-ready'' AND payload_sha256=''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'' AND phase=''COMPLETE'';
 require(l_n=1,''Missing or incompatible completion receipt: 2.1.0-apl-r1-005-backend-ready'');
 l_replaced:=TRUE;END IF;END IF;
 IF NOT l_replaced THEN
 l_sql:=TO_CLOB('''');
 l_sql:=l_sql||TO_CLOB(''-- Generated from immutable local SQL; ');
 l_step:=l_step||TO_CLOB('do not edit this wrapper.
DECLARE
 l_sql CLOB; l_hash VARCHAR2(64); l_phase VARCHAR2(16); l_started BOOLEAN:=FALSE;
 l_lock VARCHAR2(128); l_lock_result PLS_INTEGER; l_error NUMBER;

 l_n NUMBER; l_source CLOB; l_expected CLOB; l_actual CLOB;
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20301,p_message); END IF;
 END;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS
  r VARCHAR2(32767):=''''''''; c VARCHAR2(1); quoted BOOLEAN:=FALSE; i PLS_INTEGER:=1;
 BEGIN
  WHILE i<=LENGTH(p_text) LOOP
   c:=SUBSTR(p_text,i,1);
   IF c=CHR(39) THEN
    r:=r||c;
    IF quoted AND SUBSTR(p_text,'');
 l_sql:=l_sql||TO_CLOB(''i+1,1)=CH');
 l_step:=l_step||TO_CLOB('R(39) THEN r:=r||CHR(39);i:=i+1;
    ELSE quoted:=NOT quoted; END IF;
   ELSIF quoted THEN r:=r||c;
   ELSIF c NOT IN ('''' '''',CHR(9),CHR(10),CHR(13),''''"'''') THEN r:=r||UPPER(c);
   END IF;
   i:=i+1;
  END LOOP;
  RETURN r;
 END;
 PROCEDURE check_program(p_name VARCHAR2,p_type VARCHAR2,p_expected CLOB) IS
  actual CLOB:=TO_CLOB(''''''''); n NUMBER;
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''''VALID'''';
  require(n=1,''''Missing or invalid program: ''''||p_name||'''' ''''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''''ERROR'''';
  require(n=0,''''Compilation errors: ''''||p_name||'''' ''''||p_type)');
 l_step:=l_step||TO_CLOB(';
  FOR r'');
 l_sql:=l_sql||TO_CLOB('' IN (SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''''--'''' THEN
    actual:=actual||RTRIM(r.text,CHR(13)||CHR(10)||'''' '''')||CHR(10);
   END IF;
  END LOOP;
  require(DBMS_LOB.COMPARE(actual,p_expected)=0,''''Installed source differs: ''''||p_name||'''' ''''||p_type);
 END;
 PROCEDURE check_table(p_contract CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_contract); cols JSON_ARRAY_T; cs JSON_ARRAY_T;
  c JSON_OBJECT_T; name VARCHAR2(128); n NUMBER; actual_type VARCHAR2(128); actual_nullable VARCHAR2(1);
  len NUMBER; prec NUMBER; sc NUMBER; id');
 l_step:=l_step||TO_CLOB('ent VARCHAR2(3); char_semantics VARCHAR2(1); '');
 l_sql:=l_sql||TO_CLOB(''def LONG; d VARCHAR2(32767);
  found BOOLEAN; colnames VARCHAR2(4000); refcols VARCHAR2(4000); reftable VARCHAR2(128); cn VARCHAR2(128);
  wanted_temp VARCHAR2(1); wanted_column VARCHAR2(128); wanted_constraint VARCHAR2(1); meaningful_constraints NUMBER:=0;
 BEGIN
  name:=t.get_string(''''name'''');cols:=t.get_array(''''columns'''');cs:=t.get_array(''''constraints'''');
  wanted_temp:=t.get_string(''''temporary'''');
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=name
   AND temporary=wanted_temp;
  require(n=1,''''Missing or incompatible table: ''''||name);
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name=name;
');
 l_step:=l_step||TO_CLOB('  require(n=cols.get_size,''''Column count differs: ''''||name);
  FOR i IN 0..cols.get_s'');
 l_sql:=l_sql||TO_CLOB(''ize-1 LOOP
   c:=TREAT(cols.get(i) AS JSON_OBJECT_T);
   wanted_column:=c.get_string(''''name'''');
   BEGIN SELECT data_type,nullable,char_length,data_precision,data_scale,identity_column,char_used,data_default
    INTO actual_type,actual_nullable,len,prec,sc,ident,char_semantics,def FROM user_tab_columns
    WHERE table_name=name AND column_name=wanted_column;
   EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20301,''''Missing column: ''''||name||''''.''''||c.get_string(''''name'''')); END;
   require(actual_type=c.get_string(''''type''''),''''Column type differs: ''''||name||''''.''''||c.get_s');
 l_step:=l_step||TO_CLOB('tring(''''name''''));
   require(actual_nullable=c.get_string(''''nullable''''),''''Column nullability differs: ''''||name||''''.''''||c.get_string(''''na'');
 l_sql:=l_sql||TO_CLOB(''me''''));
   IF c.has(''''length'''') THEN
    require(len=c.get_number(''''length''''),''''Column length differs: ''''||name||''''.''''||c.get_string(''''name''''));
    require(char_semantics=c.get_string(''''char_used''''),''''Column character semantics differ: ''''||name||''''.''''||c.get_string(''''name''''));
   END IF;
   IF c.get_string(''''type'''')=''''NUMBER'''' THEN
    require(NVL(prec,-1)=NVL(c.get_number(''''precision''''),-1) AND NVL(sc,-99)=NVL(c.get_number(''''scale''''),-99),''''Number precision differs: ''''||name||''''.''''||c.get_string(''''name''''));
   END IF;
   require');
 l_step:=l_step||TO_CLOB('(ident=c.get_string(''''identity''''),''''Column identity differs: ''''||name||''''.''''||c.get_string(''''name''''));
   IF ident=''''NO'''' THEN d:=def;require(NVL(compact(d),''''#NULL#'''')=NVL(compact(c.get_string(''''default'''')),''''#N'');
 l_sql:=l_sql||TO_CLOB(''ULL#''''),''''Column default differs: ''''||name||''''.''''||c.get_string(''''name''''));END IF;
  END LOOP;
  FOR i IN 0..cs.get_size-1 LOOP
   c:=TREAT(cs.get(i) AS JSON_OBJECT_T);found:=FALSE;wanted_constraint:=c.get_string(''''type'''');
   FOR r IN (SELECT constraint_name,constraint_type,search_condition_vc,r_constraint_name
      FROM user_constraints WHERE table_name=name AND status=''''ENABLED'''' AND validated=''''VALIDATED''''
      AND deferrable=''''NOT DEFERRABLE'''' AND (');
 l_step:=l_step||TO_CLOB('constraint_type<>''''R'''' OR (delete_rule=''''NO ACTION'''' AND r_owner=SYS_CONTEXT(''''USERENV'''',''''CURRENT_USER'''')))
      AND constraint_type=wanted_constraint) LOOP
    SELECT LISTAGG(column_name,'''','''') WITHIN GROUP(ORDER BY position) INTO colnames
     FROM user_cons_co'');
 l_sql:=l_sql||TO_CLOB(''lumns WHERE constraint_name=r.constraint_name;
    IF r.constraint_type=''''C'''' THEN
     IF compact(r.search_condition_vc)=compact(c.get_string(''''expression'''')) THEN found:=TRUE;END IF;
    ELSIF colnames=c.get_string(''''columns'''') THEN
     IF r.constraint_type=''''R'''' THEN
      SELECT table_name INTO reftable FROM user_constraints WHERE constraint_name=r.r_constraint_name;
      SELECT LISTAGG(column_name');
 l_step:=l_step||TO_CLOB(','''','''') WITHIN GROUP(ORDER BY position) INTO refcols
       FROM user_cons_columns WHERE constraint_name=r.r_constraint_name;
      IF reftable=c.get_string(''''reference_table'''') AND refcols=c.get_string(''''reference_columns'''') THEN found:=TRUE;END IF;
     ELSE found:=TRUE;END IF;
    END IF;
   END LOOP;
 '');
 l_sql:=l_sql||TO_CLOB(''  require(found,''''Missing or incompatible constraint: ''''||name||'''' ''''||c.to_string());
  END LOOP;
  FOR r IN (SELECT constraint_type,search_condition_vc FROM user_constraints WHERE table_name=name) LOOP
   IF r.constraint_type<>''''C'''' OR NOT REGEXP_LIKE(compact(r.search_condition_vc),''''^[A-Z][A-Z0-9_$]*ISNOTNULL$'''') THEN
    meaningful_constraints:=meaningful_con');
 l_step:=l_step||TO_CLOB('straints+1;
   END IF;
  END LOOP;
  require(meaningful_constraints=cs.get_size,''''Unexpected constraints: ''''||name);
 END;

BEGIN
 require(SYS_CONTEXT(''''USERENV'''',''''CURRENT_SCHEMA'''')=SYS_CONTEXT(''''USERENV'''',''''SESSION_USER'''')
  AND SYS_CONTEXT(''''USERENV'''',''''SESSION_USER'''') NOT IN (''''ADMIN'''',''''SYS'''',''''SYSTEM''''),''''Connect as the intended project schema owner'''');
 DB'');
 l_sql:=l_sql||TO_CLOB(''MS_LOCK.ALLOCATE_UNIQUE(''''KCV_SCHEMA_''''||SYS_CONTEXT(''''USERENV'''',''''CURRENT_SCHEMA''''),l_lock);
 l_lock_result:=DBMS_LOCK.REQUEST(l_lock,DBMS_LOCK.X_MODE,0,FALSE);
 require(l_lock_result=0,''''Another schema migration is active'''');
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id=''''2.1.0');
 l_step:=l_step||TO_CLOB('-apl-r1-004-kcv_deploy-package-body'''' AND payload_sha256=''''61b74bb2d3243be86e7d6ecb246067d485aaaf798fb82c90b893e60def1994fe'''' AND phase=''''COMPLETE'''';
 require(l_n=1,''''Required prior migration is incomplete: 2.1.0-apl-r1-004-kcv_deploy-package-body'''');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id=''''2.1.0-apl-r1-005-backend-ready'''';
 EXCEPTION WHEN NO_DA'');
 l_sql:=l_sql||TO_CLOB(''TA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash=''''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c64eb320686b2e58'''',''''Migration payload/verification changed: 2.1.0-apl-r1-005-backend-ready'''');
  require(l_phase=''''COMPLETE'''',''''In');
 l_step:=l_step||TO_CLOB('complete migration requires verified recovery: 2.1.0-apl-r1-005-backend-ready'''');
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''''''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  SELECT COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''''VALID'''';
  require(n=1,''''Missing or invalid program: ''''||p_name||'''' ''''||p_type);
  SELECT COUNT(*) INTO n F'');
 l_sql:=l_sql||TO_CLOB(''ROM user_errors WHERE name=p_name AND type=p_type AND attribute=''''ERROR'''';
  require(n=0,''''Compilation errors: ''''||p_name||'''' ''''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDE');
 l_step:=l_step||TO_CLOB('R BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''''--'''' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'''' '''')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CRYPTO.HASH_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''''Installed source digest differs: ''''||p_name||'''' ''''||p_type);
 EXCEPTION W'');
 l_sql:=l_sql||TO_CLOB(''HEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''''KCV_ACCESS'''',''''PACKAGE'''',''''bd279799');
 l_step:=l_step||TO_CLOB('1d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'''');
 check_digest(''''KCV_ACCESS'''',''''PACKAGE BODY'''',''''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'''');
 check_digest(''''KCV_APEX'''',''''PACKAGE'''',''''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d92'''');
 check_digest(''''KCV_APEX'''',''''PACKAGE BODY'''',''''d059aa917536991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'''');
 check_digest(''''KCV_CONTEXT_DELETE'''',''''PACKAGE'''',''''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'''');
 check_digest(''''KCV_CONTEXT_DELET'');
 l_sql:=l_sql||TO_CLOB(''E'''',''''PACKAGE BODY'''',''''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'''');
 check_digest(''''KCV_CONT');
 l_step:=l_step||TO_CLOB('EXT_PACKET'''',''''FUNCTION'''',''''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'''');
 check_digest(''''KCV_CONTEXT_SEARCH'''',''''PACKAGE'''',''''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'''');
 check_digest(''''KCV_CONTEXT_SEARCH'''',''''PACKAGE BODY'''',''''e00d5e9ba152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'''');
 check_digest(''''KCV_DATASET'''',''''PACKAGE'''',''''381b6a066edc550aedbd03cd7c4eed58447ac39b7f1dc0dc25f872d453418dea'''');
 check_digest(''''KCV_DATASET'''',''''PACKAGE BODY'''',''''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'''');
 check_digest(''''KCV_DEPLOY'''',''''PACKAGE'''',''''f60c1471'');
 l_sql:=l_sql||TO_CLOB(''9eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a72');
 l_step:=l_step||TO_CLOB('99258c70'''');
 check_digest(''''KCV_DEPLOY'''',''''PACKAGE BODY'''',''''65635147e716682a28512b4b3cbce5ba2d75c630834de5c49b1c31f6f0b09e38'''');
 check_digest(''''KCV_DEPLOY_CONTRACT'''',''''PACKAGE'''',''''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'''');
 check_digest(''''KCV_EVIDENCE_PACKET'''',''''FUNCTION'''',''''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'''');
 check_digest(''''KCV_EXTRACT_DOMAIN'''',''''FUNCTION'''',''''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa416d5f05aaac5b82'''');
 check_digest(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE'''',''''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'''');
 check_digest(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE BODY'''',''''bfba9d'');
 l_sql:=');
 l_step:=l_step||TO_CLOB('l_sql||TO_CLOB(''2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'''');
 check_digest(''''KCV_PERSONAL_JOURNEY'''',''''PACKAGE'''',''''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'''');
 check_digest(''''KCV_PERSONAL_JOURNEY'''',''''PACKAGE BODY'''',''''dc62706c70bc5ced67702606fe87de8b294e965ace389c46c0259c72a51ce77c'''');
 check_digest(''''KCV_SCENARIO'''',''''PACKAGE'''',''''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'''');
 check_digest(''''KCV_SCENARIO'''',''''PACKAGE BODY'''',''''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c418485830ac7296d676a'''');
 check_digest(''''KCV_SCENARIO_EVIDENCE'''',''''FUNCTION'''',''''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'''');
 check_digest(''');
 l_step:=l_step||TO_CLOB('''KCV_SCENARIO_PROPOSE'''',''''FUNCTION'''',''''ecbe34a1b1aa3'');
 l_sql:=l_sql||TO_CLOB(''bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'''');
 check_digest(''''KCV_SOURCE_PACKET'''',''''FUNCTION'''',''''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'''');
 check_digest(''''KCV_TRACE'''',''''PACKAGE'''',''''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'''');
 check_digest(''''KCV_TRACE'''',''''PACKAGE BODY'''',''''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'''');
END;
 l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''{"name":"KCV_DEPLOY_STATE","temporary":"N","columns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision');
 l_step:=l_step||TO_CLOB('":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default"'');
 l_sql:=l_sql||TO_CLOB('':null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'''');
 l_expected:=l_expected||TO_CLOB(''''identity":"NO","default":"''''''''ON''''''''","length":3,"char_used":"B"},{"name":"CONFIG');
 l_step:=l_step||TO_CLOB('_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VA'');
 l_sql:=l_sql||TO_CLOB(''RCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":"''''''''NOT_TESTED''''''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '''');
 l_expected:=l_expected||TO_CLOB(''''Z');
 l_step:=l_step||TO_CLOB('ONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C"'');
 l_sql:=l_sql||TO_CLOB('',"expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type":"C","expression":"maintenance IN (''''''''ON'''''''',''''''''OFF'''''''')"},{"type":"C","expression":"model_test_status IN (''''''''NOT_TESTED'''''''',''''''''SUCCEEDED'''''''',''''''''FAILED'''''''')"}]}'''');
 check_table(l_expected);
 l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"');
 l_step:=l_step||TO_CLOB('B"},{"name":"REQUEST_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char'');
 l_sql:=l_sql||TO_CLOB(''_used":"B"},{"name":"INPUT_HASH","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'''');
 l_expected:=l_expected||TO_CLOB(''''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N');
 l_step:=l_step||TO_CLOB('","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":nul'');
 l_sql:=l_sql||TO_CLOB(''l,"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'''');
 l_expected:=l_expected||TO_CLOB(''''":"SYSTIMESTAMP"},{"nam');
 l_step:=l_step||TO_CLOB('e":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''''''CONFIGURE_PROFILE'''''''',''''''''TEST_MODEL'''''''',''''''''ENSURE_NETWORK'');
 l_sql:=l_sql||TO_CLOB('''''''''',''''''''REGISTER_RUNTIME'''''''',''''''''LOAD_DATASET'''''''',''''''''ENABLE_LEARNING'''''''')"},{"type":"C","expression":"status IN (''''''''RUNNING'''''''',''''''''SUCCEEDED'''''''',''''''''FAILED'''''''',''''''''INTERRUPTED'''''''')"},{"type":"C","expression":"account_id>=0"}]}'''');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT''''
 AND table_owner=SYS_CONTEXT(''''U');
 l_step:=l_step||TO_CLOB('SERENV'''',''''CURRENT_USER'''') AND table_name=''''KCV_DEPLOY_RUNS''''
 AND table_type=''''TABLE'''' AND uniqueness=''''NONUNIQUE'''' AND index_type=''''FUNCTION-BASED NORMAL''''
 AND status=''''VALID'''' AND funcidx_status=''''ENABLED'''' AND partitioned=''''NO'''' AND visibility=''''VISIBLE'''';
 require(l_n=1,''''Deployment request index differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE ind'');
 l_sql:=l_sql||TO_CLOB(''ex_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''';
 require(l_n=2,''''Deployment request index key count differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND descend=''''ASC'''';
 require(l_n');
 l_step:=l_step||TO_CLOB('=2,''''Deployment request index direction differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS''''
   AND column_position=2 AND column_name=''''RUN_ID'''';
 require(l_n=1,''''Deployment request index second key differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUN'');
 l_sql:=l_sql||TO_CLOB(''S'''';
 require(l_n=1,''''Deployment request index expression count differs'''');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''''KCV_DEPLO');
 l_step:=l_step||TO_CLOB('Y_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''''[[:space:]]'''','''''''')=''''SYS_EXTRACT_UTC("STARTED_AT")'''',
   ''''Deployment request index UTC expression differs'''');
  SELECT column_name INTO first_column FROM user_ind_columns
   WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''''KCV_DEPLOY_RU'');
 l_sql:=l_sql||TO_CLOB(''NS'''' AND column_name=first_column
    AND hidden_column=''''YES'''' AND virtual_column=''''YES'''' AND data_type=''''TIMESTAMP(6)'''';
  require(l_n=1,''''Deployment request index generated UTC column differs''''');
 l_step:=l_step||TO_CLOB(');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''''KCV\_%'''' ESCAPE ''''\'''' AND status=''''INVALID'''';
 require(l_n=0,''''Project contains invalid objects'''');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''''KCV\_%'''' ESCAPE ''''\'''' AND attribute=''''ERROR'''';
 require(l_n=0,''''Project contains compilation errors'''');
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES(''''2.1.0-apl-r1-005-backend-ready'''',''''5b72f774729c27c730ec3c7ce4d45c0a659b82cb6524b329c'');
 l_sql:=l_sql||TO_CLOB(''64eb320686b2e58'''',''''2.1.0'''',''''RUNNING'''');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('''''''');
 l_sql:=l_sql||TO_CLOB(''''BEGIN
 EXECUTE IMMEDIATE');
 l_step:=l_step||TO_CLOB(' ''''''''ALTER PACKAGE KCV_ACCESS COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_APEX COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_CONTEXT_DELETE COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_CONTEXT_PACKET COMPILE'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_CONTEXT_SEARCH COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_DATASET COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_DEPLOY COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_EVIDENCE_PACKET COMPILE'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_EXTRACT_DOMAIN COMPILE'''''''';
'');
 l_sql:=l_sql||TO_CLOB('' EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_PERSONAL_CONTEXT_API COMPIL');
 l_step:=l_step||TO_CLOB('E BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_PERSONAL_JOURN'''');
 l_sql:=l_sql||TO_CLOB(''''EY COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_SCENARIO COMPILE BODY'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_SCENARIO_EVIDENCE COMPILE'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_SCENARIO_PROPOSE COMPILE'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER FUNCTION KCV_SOURCE_PACKET COMPILE'''''''';
 EXECUTE IMMEDIATE ''''''''ALTER PACKAGE KCV_TRACE COMPILE BODY'''''''';
END;'''');
  EXECUTE IMMEDIATE l_sql;
DECLARE
 PROCEDURE check_digest(p_name VARCHAR2,p_type VARCHAR2,p_sha256 VARCHAR2) IS
  source_text CLOB:=TO_CLOB('''''''');n NUMBER;actual_hash VARCHAR2(64);
 BEGIN
  '');
 l_sql:=l_sql||TO_CLOB(''SELECT ');
 l_step:=l_step||TO_CLOB('COUNT(*) INTO n FROM user_objects WHERE object_name=p_name AND object_type=p_type AND status=''''VALID'''';
  require(n=1,''''Missing or invalid program: ''''||p_name||'''' ''''||p_type);
  SELECT COUNT(*) INTO n FROM user_errors WHERE name=p_name AND type=p_type AND attribute=''''ERROR'''';
  require(n=0,''''Compilation errors: ''''||p_name||'''' ''''||p_type);
  FOR r IN(SELECT text FROM user_source WHERE name=p_name AND type=p_type ORDER BY line) LOOP
   IF TRIM(RTRIM(r.text,CHR(13)||CHR(10))) IS NOT NULL AND SUBSTR(LTRIM(r.text),1,2)<>''''--'''' THEN
    source_text:=source_text||RTRIM(r.text,CHR(13)||CHR(10)||'''' '''')||CHR(10);
   END IF;
  END LOOP;
  actual_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(source_text,DBMS_CR');
 l_step:=l_step||TO_CLOB('YPTO.HASH'');
 l_sql:=l_sql||TO_CLOB(''_SH256)));
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;
  require(actual_hash=p_sha256,''''Installed source digest differs: ''''||p_name||'''' ''''||p_type);
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(source_text)=1 THEN DBMS_LOB.FREETEMPORARY(source_text);END IF;RAISE;
 END;
BEGIN
 check_digest(''''KCV_ACCESS'''',''''PACKAGE'''',''''bd2797991d92f38884688f33c519d3b0cabf7a8fd63eb504a38f66a88850929b'''');
 check_digest(''''KCV_ACCESS'''',''''PACKAGE BODY'''',''''83dd0ac6545cc7fdfbacc94f96cb475dc35fb9aebbf4f973660b1c56a010bcd5'''');
 check_digest(''''KCV_APEX'''',''''PACKAGE'''',''''557f9dd16b6c09f2a9673941eae7e2d8332176d76606c1d6aacc48be623d2d');
 l_step:=l_step||TO_CLOB('92'''');
 check_digest(''''KCV_APEX'''',''''PACKAGE BODY'''',''''d059aa91753'');
 l_sql:=l_sql||TO_CLOB(''6991afa8447668f78263147ed89ce8bc3ae69598013c42a35d061'''');
 check_digest(''''KCV_CONTEXT_DELETE'''',''''PACKAGE'''',''''022b5370f4035bd20d64f74c2ba764db4c140d9bf02dd900b1e91012d1ec5a70'''');
 check_digest(''''KCV_CONTEXT_DELETE'''',''''PACKAGE BODY'''',''''a8f98f56e75f4b2674b77ac4a94bd5120f661fc89e90e596e80414b8ecf0c951'''');
 check_digest(''''KCV_CONTEXT_PACKET'''',''''FUNCTION'''',''''f5c42312edd8835dcc165c60706a0996acf74de2a6ee6fac0bf744db802eb404'''');
 check_digest(''''KCV_CONTEXT_SEARCH'''',''''PACKAGE'''',''''80e65016c21e01dd7e8704303e0eb29bb22547c5b1d3185c0e07c81d486e94ba'''');
 check_digest(''''KCV_CONTEXT_SEARCH'''',''''PACKAGE BODY'''',''''e00d5e9b');
 l_step:=l_step||TO_CLOB('a152bf69d2cab4bc81f236b11d13919b8aef21945710bcf2db175480'''');
 check_digest(''''KCV_DATASET'''',''''PACKAGE'''',''''381b6a066edc550aedbd03c'');
 l_sql:=l_sql||TO_CLOB(''d7c4eed58447ac39b7f1dc0dc25f872d453418dea'''');
 check_digest(''''KCV_DATASET'''',''''PACKAGE BODY'''',''''2bdcb49fba69b3d36cf77fac6310c1a2e9c9dd78990ec2ec658aab4697dff007'''');
 check_digest(''''KCV_DEPLOY'''',''''PACKAGE'''',''''f60c14719eb25bb9c0b0fbd965d58ed1e8b5ba4924abdfd4b3810a7299258c70'''');
 check_digest(''''KCV_DEPLOY'''',''''PACKAGE BODY'''',''''65635147e716682a28512b4b3cbce5ba2d75c630834de5c49b1c31f6f0b09e38'''');
 check_digest(''''KCV_DEPLOY_CONTRACT'''',''''PACKAGE'''',''''1d0ddb31e4f049c7db6e60c24404f561c9aa32f3f0f39008bdeba44b3becd1af'''');
 check_digest(''''KCV_EVIDENCE_P');
 l_step:=l_step||TO_CLOB('ACKET'''',''''FUNCTION'''',''''7c840f5652444109aafe1c1dc03468c1a83aded6c58a0e31acf11bf71b2a4e13'''');
 check_digest(''''KCV_EXTRACT_DOMAIN'''',''''FUNCTION'''',''''b0e84b54567f3b26f2edfc54d4f920b070a8d0c910eee7aa'');
 l_sql:=l_sql||TO_CLOB(''416d5f05aaac5b82'''');
 check_digest(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE'''',''''f719f875767677db14c704f34032842f3314bd845d86636a6db835bc78705626'''');
 check_digest(''''KCV_PERSONAL_CONTEXT_API'''',''''PACKAGE BODY'''',''''bfba9d2c46b82c4ddb1b35bd518aeb82cd345a2449ce5b0b3bd1e6529fd79d00'''');
 check_digest(''''KCV_PERSONAL_JOURNEY'''',''''PACKAGE'''',''''3dd6f8ea8ec9d527551e5e56547a91077535b0cb33a17bb8c2ff3c1cf94ec623'''');
 check_digest(''''KCV_PERSONAL_JOURNEY'''',''''PACKAGE BODY'''',''''dc62706c70bc5ced677026');
 l_step:=l_step||TO_CLOB('06fe87de8b294e965ace389c46c0259c72a51ce77c'''');
 check_digest(''''KCV_SCENARIO'''',''''PACKAGE'''',''''6317be07ea6c4611366da257b5c92c131e7b151cab030c418548754104729e0a'''');
 check_digest(''''KCV_SCENARIO'''',''''PACKAGE BODY'''',''''f113bbfbd4fa0b8ba608b28c25b3441bb7f5b6d7756c4'');
 l_sql:=l_sql||TO_CLOB(''18485830ac7296d676a'''');
 check_digest(''''KCV_SCENARIO_EVIDENCE'''',''''FUNCTION'''',''''74403bf11cc031745e5f1b750bed07a43972cb41300b6fadd2acb25e55dba371'''');
 check_digest(''''KCV_SCENARIO_PROPOSE'''',''''FUNCTION'''',''''ecbe34a1b1aa3bb7be7940f9d9e68fa364b67bb89c84d1759274f5cdd4139939'''');
 check_digest(''''KCV_SOURCE_PACKET'''',''''FUNCTION'''',''''c0f7dd8265e2d432990727170ae5f996d774fc5ae0da61df0ff76af9d6433416'''');
 check_digest(''''KCV_TRACE');
 l_step:=l_step||TO_CLOB(''''',''''PACKAGE'''',''''86383b4ce586e09473ae04b4449e9b90bf6eb2edd46ddcde7ebef276919a5662'''');
 check_digest(''''KCV_TRACE'''',''''PACKAGE BODY'''',''''47e4332c2b8373bf249f94b39a4705de31c96904f4806f70153e6074acc31702'''');
END;
 l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''{"name":"KCV_DEPLOY_STATE","temporary":"N","colu'');
 l_sql:=l_sql||TO_CLOB(''mns":[{"name":"SINGLETON_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"SCHEMA_OWNER","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null}');
 l_step:=l_step||TO_CLOB(',{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"NETWORK_TABLESPACE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":128,"char_used":"B"},{"name":"MAINTENANCE","type":"VARCHAR2","nullable":"N","'''');
 l_expected:=l_expected||TO_CLOB(''''identity":'');
 l_sql:=l_sql||TO_CLOB(''"NO","default":"''''''''ON''''''''","length":3,"char_used":"B"},{"name":"CONFIG_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_HASH","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"MODEL_TEST_STATUS","type"');
 l_step:=l_step||TO_CLOB(':"VARCHAR2","nullable":"N","identity":"NO","default":"''''''''NOT_TESTED''''''''","length":16,"char_used":"B"},{"name":"MODEL_TEST_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity":"NO","default":null},{"name":"CREATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME '''');
 l'');
 l_sql:=l_sql||TO_CLOB(''_expected:=l_expected||TO_CLOB(''''ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"}],"constraints":[{"type":"P","columns":"SINGLETON_ID"},{"type":"C","expression":"singleton_id=1"},{"type":"C","expression":"workspace_id>0"},{"type":"C","expression":"application_id>0"},{"type');
 l_step:=l_step||TO_CLOB('":"C","expression":"maintenance IN (''''''''ON'''''''',''''''''OFF'''''''')"},{"type":"C","expression":"model_test_status IN (''''''''NOT_TESTED'''''''',''''''''SUCCEEDED'''''''',''''''''FAILED'''''''')"}]}'''');
 check_table(l_expected);
 l_expected:=TO_CLOB('''''''');
 l_expected:=l_expected||TO_CLOB(''''{"name":"KCV_DEPLOY_RUNS","temporary":"N","columns":[{"name":"RUN_ID","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":32,"char_used":"B"},{"name":"REQUES'');
 l_sql:=l_sql||TO_CLOB(''T_TOKEN","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":80,"char_used":"B"},{"name":"OPERATION","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":24,"char_used":"B"},{"name":"INPUT_HASH');
 l_step:=l_step||TO_CLOB('","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"WORKSPACE_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null,"scale":null},{"name":"APPLICATION_ID","type":"NUMBER","nullable":"N","identity":"NO","defa'''');
 l_expected:=l_expected||TO_CLOB(''''ult":null,"precision":null,"scale":null},{"name":"ACCOUNT_ID","type":"NUMBER","nullable":"N","identity":"NO","default":null,"precision":null'');
 l_sql:=l_sql||TO_CLOB('',"scale":null},{"name":"STATUS","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":16,"char_used":"B"},{"name":"PHASE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null');
 l_step:=l_step||TO_CLOB(',"length":64,"char_used":"B"},{"name":"ERROR_CODE","type":"NUMBER","nullable":"Y","identity":"NO","default":null,"precision":null,"scale":null},{"name":"STARTED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default":"SYSTIMESTAMP"},{"name":"UPDATED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"N","identity":"NO","default'''');
 l_expected:=l_expected||TO_CLOB(''''":"SYSTIMESTAMP"},{"name":"COMPLETED_AT","type":"TIMESTAMP(6) WITH TIME ZONE","nullable":"Y","identity'');
 l_sql:=l_sql||TO_CLOB(''":"NO","default":null}],"constraints":[{"type":"P","columns":"RUN_ID"},{"type":"U","columns":"REQUEST_TOKEN"},{"type":"C","expression":"operation IN (''''''''CONFIGURE_PROFILE''''''');
 l_step:=l_step||TO_CLOB(''',''''''''TEST_MODEL'''''''',''''''''ENSURE_NETWORK'''''''',''''''''REGISTER_RUNTIME'''''''',''''''''LOAD_DATASET'''''''',''''''''ENABLE_LEARNING'''''''')"},{"type":"C","expression":"status IN (''''''''RUNNING'''''''',''''''''SUCCEEDED'''''''',''''''''FAILED'''''''',''''''''INTERRUPTED'''''''')"},{"type":"C","expression":"account_id>=0"}]}'''');
 check_table(l_expected);
SELECT COUNT(*) INTO l_n FROM user_indexes WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT''''
 AND table_owner=SYS_CONTEXT(''''USERENV'''',''''CURRENT_USER'''') AND table_name=''''KCV_DEPLOY_RUNS''''
 AND table_type=''''TABLE'''' AND uniqueness=''''NONUNIQUE'''' AND index_type=''''FUNCTION-BASED NORMAL''''
 AND'');
 l_sql:=l_sql||TO_CLOB('' status=''''VALID'''' AND funcidx_status=''''ENABLED'''' AND partitioned=''''NO'''' AND visibility=''''VI');
 l_step:=l_step||TO_CLOB('SIBLE'''';
 require(l_n=1,''''Deployment request index differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''';
 require(l_n=2,''''Deployment request index key count differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND descend=''''ASC'''';
 require(l_n=2,''''Deployment request index direction differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_columns
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS''''
   AND column_position=2 AND column_n'');
 l_sql:=l_sql||TO_CLOB(''ame=''''RUN_ID'''';
 require(l_n=1,''''De');
 l_step:=l_step||TO_CLOB('ployment request index second key differs'''');
 SELECT COUNT(*) INTO l_n FROM user_ind_expressions
  WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''';
 require(l_n=1,''''Deployment request index expression count differs'''');
 DECLARE expression_text LONG;first_column VARCHAR2(128);BEGIN
  SELECT column_expression INTO expression_text FROM user_ind_expressions
   WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND column_position=1;
  require(REGEXP_REPLACE(expression_text,''''[[:space:]]'''','''''''')=''''SYS_EXTRACT_UTC("STARTED_AT")'''',
   ''''Deployment request index UTC expression differs'''');
  SELECT column_name INTO first_column '');
 l_sql:=l');
 l_step:=l_step||TO_CLOB('_sql||TO_CLOB(''FROM user_ind_columns
   WHERE index_name=''''KCV_DEPLOY_RUNS_RECENT'''' AND table_name=''''KCV_DEPLOY_RUNS'''' AND column_position=1;
  SELECT COUNT(*) INTO l_n FROM user_tab_cols
   WHERE table_name=''''KCV_DEPLOY_RUNS'''' AND column_name=first_column
    AND hidden_column=''''YES'''' AND virtual_column=''''YES'''' AND data_type=''''TIMESTAMP(6)'''';
  require(l_n=1,''''Deployment request index generated UTC column differs'''');
 END;
 SELECT COUNT(*) INTO l_n FROM user_objects WHERE object_name LIKE ''''KCV\_%'''' ESCAPE ''''\'''' AND status=''''INVALID'''';
 require(l_n=0,''''Project contains invalid objects'''');
 SELECT COUNT(*) INTO l_n FROM user_errors WHERE name LIKE ''''KCV\_%'''' ESCAPE ''''\'''' AND attribute=''''ERRO');
 l_step:=l_step||TO_CLOB('R'''';
 require(l_n=0,''''Project contains compi'');
 l_sql:=l_sql||TO_CLOB(''lation errors'''');
  UPDATE kcv_schema_migrations SET phase=''''COMPLETE'''',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id=''''2.1.0-apl-r1-005-backend-ready'''';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase=''''FAILED'''',error_code=l_error WHERE migration_id=''''2.1.0-apl-r1-005-backend-ready'''';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;'');
 EXECUTE IMMEDIATE l_sql;END IF;
END;');
 EXECUTE IMMEDIATE l_step;
 l_step:=TO_CLOB('');
 l_step:=l_step||TO_CLOB('BEGIN DBMS_OUTPUT.PUT_LINE(''KCV_SCHEMA_PART_COMPLETE=fresh:021/025'');END;');
 EXECUTE IMMEDIATE l_step;
END;
/
