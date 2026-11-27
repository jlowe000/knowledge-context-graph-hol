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
 SELECT COUNT(*) INTO l_n FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-r1-003-kcv_deploy-package' AND payload_sha256='9022398decdf966f4c66867ce4c6b1d3a86d5a08dcd9c76b65fe8aa8b0680924' AND phase='COMPLETE';
 require(l_n=1,'Required prior migration is incomplete: 2.1.0-apl-r1-003-kcv_deploy-package');

 BEGIN SELECT payload_sha256,phase INTO l_hash,l_phase FROM kcv_schema_migrations WHERE migration_id='2.1.0-apl-r1-004-kcv_deploy-package-body';
 EXCEPTION WHEN NO_DATA_FOUND THEN l_phase:=NULL; END;
 IF l_phase IS NOT NULL THEN
  require(l_hash='61b74bb2d3243be86e7d6ecb246067d485aaaf798fb82c90b893e60def1994fe','Migration payload/verification changed: 2.1.0-apl-r1-004-kcv_deploy-package-body');
  require(l_phase='COMPLETE','Incomplete migration requires verified recovery: 2.1.0-apl-r1-004-kcv_deploy-package-body');
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_deploy AS
 c_profile CONSTANT VARCHAR2(128):=''KCV_GENAI'';
 c_network CONSTANT VARCHAR2(128):=''KCV_NET'';
 c_forbidden CONSTANT PLS_INTEGER:=-20300;
 c_invalid CONSTANT PLS_INTEGER:=-20301;
 c_busy CONSTANT PLS_INTEGER:=-20302;
 c_conflict CONSTANT PLS_INTEGER:=-20303;
 c_failed CONSTANT PLS_INTEGER:=-20304;
 c_not_ready CONSTANT PLS_INTEGER:=-20305;
 TYPE identity_t IS RECORD(workspace_id NUMBER,application_id NUMBER,account_id NUMBER);
 PROCEDURE require(p_ok BOOLEAN,p_code NUMBER,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION digest(p_text CLOB) RETURN VARCHAR2 IS BEGIN
  RETURN LOWER(RAWTOHE');
 l_expected:=l_expected||TO_CLOB('X(DBMS_CRYPTO.HASH(p_text,DBMS_CRYPTO.HASH_SH256)));
 END;
 FUNCTION own_table(p_name VARCHAR2) RETURN BOOLEAN IS n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=p_name;RETURN n=1;
 END;
 FUNCTION own_name(p_name VARCHAR2) RETURN VARCHAR2 IS BEGIN
  RETURN DBMS_ASSERT.ENQUOTE_NAME($$PLSQL_UNIT_OWNER,FALSE)||''.''||DBMS_ASSERT.ENQUOTE_NAME(p_name,FALSE);
 END;
 PROCEDURE verify_application(p_identity identity_t) IS w VARCHAR2(255);n NUMBER;BEGIN
  SELECT COUNT(*),MAX(workspace) INTO n,w FROM apex_applications
   WHERE application_id=p_identity.application_id AND owner=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Application parsing schema does not ma');
 l_expected:=l_expected||TO_CLOB('tch'');
  require(apex_util.find_security_group_id(p_workspace=>w)=p_identity.workspace_id,
    c_forbidden,''SETUP_FORBIDDEN: Workspace does not match'');
  SELECT COUNT(*) INTO n FROM apex_workspace_schemas
   WHERE workspace_name=w AND schema=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Workspace schema mapping does not match'');
 END;
 PROCEDURE native_identity(p_identity OUT identity_t) IS
  u VARCHAR2(255):=SYS_CONTEXT(''APEX$SESSION'',''APP_USER'');
  a VARCHAR2(64):=SYS_CONTEXT(''APEX$SESSION'',''APP_ID'');authenticated BOOLEAN;
 BEGIN
  require(a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'') AND u IS NOT NULL
    AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_USER''),c_forbidden,
 ');
 l_expected:=l_expected||TO_CLOB('   ''SETUP_FORBIDDEN: Sign in to the installed application'');
  authenticated:=apex_authentication.is_authenticated;
  require(authenticated AND a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'')
    AND u IS NOT NULL AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_USER''),
    c_forbidden,''SETUP_FORBIDDEN: Sign in to the installed application'');
  p_identity.application_id:=TO_NUMBER(a);
  p_identity.workspace_id:=apex_custom_auth.get_security_group_id;
  p_identity.account_id:=apex_util.get_user_id(p_username=>u);
  require(p_identity.workspace_id>0 AND p_identity.account_id>0,c_forbidden,
    ''SETUP_FORBIDDEN: A native workspace account is required'');
  verify_application(p_identity);
 END;
 PROCEDU');
 l_expected:=l_expected||TO_CLOB('RE capture_identity IS ident identity_t;pinned VARCHAR2(128);BEGIN
  native_identity(ident);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
  require(pinned IS NULL OR pinned=TO_CHAR(ident.account_id,''TM9''),c_forbidden,
    ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  IF pinned IS NULL THEN
   apex_util.set_session_state(p_name=>''KCV_AUTH_ACCOUNT_ID'',
     p_value=>TO_CHAR(ident.account_id,''TM9''),p_commit=>FALSE);
  END IF;
 END;
 PROCEDURE authorize(p_installer BOOLEAN,p_identity OUT identity_t) IS
  state kcv_deploy_state%ROWTYPE;roles VARCHAR2(4000);pinned VARCHAR2(128);owner_session BOOLEAN;
 BEGIN
  owner_session:=SYS_CONTEXT(''APEX$SESSIO');
 l_expected:=l_expected||TO_CLOB('N'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL;
  IF owner_session THEN
   require(SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER
     AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,c_forbidden,
     ''SETUP_FORBIDDEN: Use an authenticated project owner session'');
  ELSE
   native_identity(p_identity);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
   require(pinned=TO_CHAR(p_identity.account_id,''TM9''),c_forbidden,
     ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  END IF;
  BEGIN SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATIO');
 l_expected:=l_expected||TO_CLOB('N_ERROR(c_forbidden,
    ''SETUP_FORBIDDEN: Trusted application installation has not bound this setup'');END;
  IF owner_session THEN
   p_identity.workspace_id:=state.workspace_id;p_identity.application_id:=state.application_id;p_identity.account_id:=0;
   verify_application(p_identity);
  END IF;
  require(state.schema_owner=$$PLSQL_UNIT_OWNER AND state.workspace_id=p_identity.workspace_id
    AND state.application_id=p_identity.application_id,c_forbidden,
    ''SETUP_FORBIDDEN: This application is not the bound installation'');
  IF p_installer AND NOT owner_session THEN
   roles:=apex_util.get_user_roles(p_username=>SYS_CONTEXT(''APEX$SESSION'',''APP_USER''));
   require(INSTR('':''||UPPER(roles)|');
 l_expected:=l_expected||TO_CLOB('|'':'','':ADMIN:'')>0,c_forbidden,
     ''SETUP_FORBIDDEN: A workspace administrator must complete setup'');
  END IF;
 END;
 FUNCTION is_installer RETURN BOOLEAN IS ident identity_t;BEGIN
  authorize(TRUE,ident);RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;
 FUNCTION attribute_text(p_value CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T;s VARCHAR2(4000);BEGIN
  require(p_value IS NOT NULL AND DBMS_LOB.GETLENGTH(p_value)<=4000,c_not_ready,
    ''SETUP_NOT_READY: Profile metadata is unavailable'');
  s:=TRIM(DBMS_LOB.SUBSTR(p_value,4000,1));
  IF SUBSTR(s,1,1)=''"'' THEN j:=JSON_OBJECT_T.parse(''{"v":''||s||''}'');RETURN j.get_string(''v'');END IF;
  RETURN s;
 END;
 FUNCTION profile_attribute(p_name V');
 l_expected:=l_expected||TO_CLOB('ARCHAR2) RETURN VARCHAR2 IS value CLOB;BEGIN
  EXECUTE IMMEDIATE ''SELECT attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p AND attribute_name=:a'' INTO value USING c_profile,p_name;
  RETURN attribute_text(value);
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;END;
 PROCEDURE local_credential(p_name VARCHAR2) IS n NUMBER;BEGIN
  require(p_name IS NOT NULL AND REGEXP_LIKE(p_name,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),
    c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_credentials WHERE credential_name=:c'' INTO n USING p_name;
  require(n=1,c_invalid,''INVALID_SETUP_INPUT: The selected credential is ');
 l_expected:=l_expected||TO_CLOB('not local to this schema'');
 END;
 FUNCTION profile_fingerprint RETURN VARCHAR2 IS
  material CLOB:=TO_CLOB('''');v CLOB;name VARCHAR2(128);cursor_id SYS_REFCURSOR;n NUMBER;
 BEGIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name=:p AND status=''''ENABLED''''''
    INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Configure an enabled model profile'');
  require(profile_attribute(''provider'')=''oci'',c_not_ready,''SETUP_NOT_READY: The profile must use the prepared OCI provider'');
  local_credential(profile_attribute(''credential_name''));
  require(profile_attribute(''region'') IS NOT NULL AND profile_attribute(''model'') IS NOT NULL
    AND profile_attribu');
 l_expected:=l_expected||TO_CLOB('te(''oci_compartment_id'') IS NOT NULL,c_not_ready,''SETUP_NOT_READY: Model profile configuration is incomplete'');
  OPEN cursor_id FOR ''SELECT attribute_name,attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p ORDER BY attribute_name'' USING c_profile;
  LOOP FETCH cursor_id INTO name,v;EXIT WHEN cursor_id%NOTFOUND;
   material:=material||LENGTH(name)||'':''||name||'':''||DBMS_LOB.GETLENGTH(v)||'':''||v||CHR(10);
  END LOOP;CLOSE cursor_id;
  RETURN digest(material);
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;
 FUNCTION credential_options RETURN CLOB IS
  ident identity_t;items JSON_ARRAY_T:=JSON_ARRAY_T();name VARCHAR2(128);');
 l_expected:=l_expected||TO_CLOB('cursor_id SYS_REFCURSOR;
 BEGIN
  authorize(TRUE,ident);
  OPEN cursor_id FOR ''SELECT credential_name FROM user_credentials ORDER BY credential_name'';
  LOOP FETCH cursor_id INTO name;EXIT WHEN cursor_id%NOTFOUND;items.append(name);END LOOP;
  CLOSE cursor_id;RETURN items.to_clob();
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;
 PROCEDURE verify_network IS n NUMBER;BEGIN
  require(own_table(c_network||''#SEM_MODEL$''),c_not_ready,''SETUP_NOT_READY: Create the owner RDF network'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||own_name(c_network||''#SEM_MODEL$'')||'' WHERE owner<>:o''
    INTO n USING $$PLSQL_UNIT_OWNER;
  require(n=0,c_not_ready,''SETUP_NOT_REA');
 l_expected:=l_expected||TO_CLOB('DY: RDF network ownership requires administrator review'');
 END;
 FUNCTION runtime_instruction(p_grounded BOOLEAN) RETURN CLOB IS result CLOB;BEGIN
  IF p_grounded THEN EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.grounded_instruction;END;'' USING OUT result;
  ELSE EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.qa_instruction;END;'' USING OUT result;END IF;
  RETURN result;
 END;
 PROCEDURE expected_runtime(p_create BOOLEAN) IS
  task JSON_OBJECT_T;instruction CLOB;n NUMBER;
  PROCEDURE object_ready(p_type VARCHAR2,p_name VARCHAR2,p_attributes CLOB,p_description VARCHAR2 DEFAULT NULL) IS
   base_view VARCHAR2(128);attr_view VARCHAR2(128);name_column VARCHAR2(128);attr_name_column VARCHAR2(128);
   ex');
 l_expected:=l_expected||TO_CLOB('pected JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_attributes);keys JSON_KEY_LIST:=expected.get_keys;
   wanted JSON_ELEMENT_T;actual CLOB;wanted_json CLOB;n NUMBER;equal_value NUMBER;s VARCHAR2(32767);
  BEGIN
   CASE p_type
    WHEN ''tool'' THEN base_view:=''USER_AI_AGENT_TOOLS'';attr_view:=''USER_AI_AGENT_TOOL_ATTRIBUTES'';name_column:=''TOOL_NAME'';attr_name_column:=''TOOL_NAME'';
    WHEN ''task'' THEN base_view:=''USER_AI_AGENT_TASKS'';attr_view:=''USER_AI_AGENT_TASK_ATTRIBUTES'';name_column:=''TASK_NAME'';attr_name_column:=''TASK_NAME'';
    WHEN ''agent'' THEN base_view:=''USER_AI_AGENTS'';attr_view:=''USER_AI_AGENT_ATTRIBUTES'';name_column:=''AGENT_NAME'';attr_name_column:=''AGENT_NAME'';
    WHEN ''team'' THEN base_vie');
 l_expected:=l_expected||TO_CLOB('w:=''USER_AI_AGENT_TEAMS'';attr_view:=''USER_AI_AGENT_TEAM_ATTRIBUTES'';name_column:=''AGENT_TEAM_NAME'';attr_name_column:=''TEAM_NAME'';
    ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported runtime object'');
   END CASE;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n'' INTO n USING p_name;
   IF n=0 AND p_create THEN
    CASE p_type
     WHEN ''tool'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name=>:n,description=>:d,attributes=>:a);END;'' USING p_name,p_description,p_attributes;
     WHEN ''task'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>:n,attributes=>:a);END;'' USING p_name,p_attribut');
 l_expected:=l_expected||TO_CLOB('es;
     WHEN ''agent'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
     WHEN ''team'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
    END CASE;
   END IF;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n AND status=''''ENABLED'''''' INTO n USING p_name;
   require(n=1,c_not_ready,''SETUP_NOT_READY: A required runtime object is missing or disabled'');
   FOR i IN 1..keys.COUNT LOOP
    BEGIN EXECUTE IMMEDIATE ''SELECT attribute_value FROM ''||attr_view||'' WHERE ''||attr_name_column
      ||''=:n AND attribute');
 l_expected:=l_expected||TO_CLOB('_name=:a'' INTO actual USING p_name,keys(i);
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(c_conflict,''SETUP_CONFLICT: Existing runtime attributes require administrator review'');END;
    wanted:=expected.get(keys(i));
    IF wanted.is_string THEN
     s:=expected.get_string(keys(i));
     require(DBMS_LOB.GETLENGTH(actual)<=32767,c_conflict,''SETUP_CONFLICT: Unexpected runtime attribute size'');
     IF SUBSTR(TRIM(DBMS_LOB.SUBSTR(actual,32767,1)),1,1)=''"'' THEN
      wanted_json:=wanted.to_clob();
      EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
        INTO equal_value USING actual,wanted_json;
     ELSE equal_value:=CASE WHEN DBMS_');
 l_expected:=l_expected||TO_CLOB('LOB.COMPARE(actual,TO_CLOB(s))=0 THEN 1 ELSE 0 END;END IF;
    ELSE
     wanted_json:=wanted.to_clob();
     EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
       INTO equal_value USING actual,wanted_json;
    END IF;
    require(equal_value=1,c_conflict,''SETUP_CONFLICT: Existing runtime attributes differ; no object was replaced'');
   END LOOP;
  END;
  FUNCTION agent_attributes(p_role VARCHAR2,p_supervisor BOOLEAN DEFAULT FALSE) RETURN CLOB IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''profile_name'',c_profile);j.put(''role'',p_role);j.put(''enable_human_tool'',FALSE);
   IF p_supervisor THEN j.put(''supervisor'',TRUE);END IF;RETURN j.to_clob();
  END;
 BE');
 l_expected:=l_expected||TO_CLOB('GIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''' AND setting_value=:p'' INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_objects WHERE object_name IN ''
    ||''(''''KCV_SCENARIO_EVIDENCE'''',''''KCV_SCENARIO_PROPOSE'''') AND object_type=''''FUNCTION'''' AND status=''''VALID'''''' INTO n;
  require(n=2,c_not_ready,''SETUP_NOT_READY: Verify schema runtime functions first'');
  object_ready(''tool'',''KCV_SCENARIO_EVIDENCE'',
    ''{"function":"KCV_SCENARIO_EVIDENCE","instruction":"Pass the original request JSON unchanged.","tool_inputs":[{"name":"p_request","mandatory":true,');
 l_expected:=l_expected||TO_CLOB('"description":"Full request JSON including scenario_session and question"}]}'',
    ''Read public evidence and actual topic graph paths for the current scenario'');
  object_ready(''tool'',''KCV_SCENARIO_PROPOSE'',
    ''{"function":"KCV_SCENARIO_PROPOSE","instruction":"Pass the original request JSON unchanged. This tool cannot apply changes.","tool_inputs":[{"name":"p_request","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}'',
    ''Propose one context edit; never applies a change'');
  task:=JSON_OBJECT_T.parse(''{"tools":["KCV_SCENARIO_EVIDENCE"],"enable_human_tool":false}'');
  instruction:=runtime_instruction(FALSE);task.put(''instruction'',instruction);
 ');
 l_expected:=l_expected||TO_CLOB(' object_ready(''task'',''KCV_SCENARIO_QA_TASK'',task.to_clob());
  task:=JSON_OBJECT_T.parse(''{"tools":[],"enable_human_tool":false}'');
  instruction:=runtime_instruction(TRUE);task.put(''instruction'',instruction);
  object_ready(''task'',''KCV_GROUNDED_QA_TASK'',task.to_clob());
  object_ready(''task'',''KCV_SCENARIO_CHANGE_TASK'',q''~{"instruction":"For {query}, call KCV_SCENARIO_PROPOSE once with the original JSON. Return its proposed_plan JSON unchanged, including any clarification message. State that no change has been applied. The user must inspect and submit a structured refinement outside the agent. Never call another tool, invent a confirmation or claim success.","tools":["KCV_SCENARIO_PROPOSE"],');
 l_expected:=l_expected||TO_CLOB('"enable_human_tool":false}~'');
  object_ready(''agent'',''KCV_SCENARIO_QA'',agent_attributes(''Explain contextual relevance from public evidence and actual graph paths. Read only.''));
  object_ready(''agent'',''KCV_SCENARIO_PLANNER'',agent_attributes(''Propose one allowed context change. Never apply or confirm changes.''));
  object_ready(''agent'',''KCV_SCENARIO_ROUTER'',agent_attributes(''Route task question to KCV_SCENARIO_QA and task propose_change to KCV_SCENARIO_PLANNER. Pass the full request unchanged to exactly one worker and return its result.'',TRUE));
  object_ready(''team'',''KCV_EXPLORER_TEAM'',''{"supervisor_agent":"KCV_SCENARIO_ROUTER","process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","tas');
 l_expected:=l_expected||TO_CLOB('k":"KCV_SCENARIO_QA_TASK"},{"name":"KCV_SCENARIO_PLANNER","task":"KCV_SCENARIO_CHANGE_TASK"}]}'');
  object_ready(''team'',''KCV_EVIDENCE_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"}]}'');
  object_ready(''team'',''KCV_GROUNDED_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_GROUNDED_QA_TASK"}]}'');
 END;
 PROCEDURE dataset_state(p_sources OUT NUMBER,p_passages OUT NUMBER,p_contexts OUT NUMBER) IS g VARCHAR2(128);n NUMBER;BEGIN
  verify_network;
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''''' INTO g;
  require(REGEXP_LIKE(g,''^KCV_G_[A-F0-9]+$'',''c''),c_not_ready,''SETUP_NOT');
 l_expected:=l_expected||TO_CLOB('_READY: Collection graph is unavailable'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_runs g WHERE g.graph_name=:g AND g.state=''''READY'''' ''
    ||''AND EXISTS(SELECT 1 FROM kcv_dataset_runs d WHERE d.graph_name=g.graph_name AND d.status=''''SUCCEEDED'''')'' INTO n USING g;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Collection needs a completed verified import'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_sources WHERE graph_name=:g'' INTO p_sources USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_passages p JOIN kcv_graph_sources s ON p.version_id=s.version_id WHERE s.graph_name=:g'' INTO p_passages USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_contexts WHERE g');
 l_expected:=l_expected||TO_CLOB('raph_name=:g'' INTO p_contexts USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM TABLE(SEM_MATCH(''''SELECT ?s ?p ?o WHERE { ?s ?p ?o }'''',SEM_MODELS(''
    ||DBMS_ASSERT.ENQUOTE_LITERAL(g)||''),NULL,NULL,NULL,NULL,NULL,NULL,NULL,''
    ||DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||'',''''KCV_NET''''))'' INTO n;
  require(p_sources>0 AND p_passages>0 AND p_contexts>0 AND n>0,c_not_ready,''SETUP_NOT_READY: Collection evidence or graph is empty'');
 END;
 PROCEDURE verify_schema_ready IS n NUMBER;checkpoint VARCHAR2(128);version VARCHAR2(20);BEGIN
  kcv_deploy_contract.verify_schema;
  checkpoint:=kcv_deploy_contract.target_checkpoint;version:=kcv_deploy_contract.target_version;
  EXECUTE IMMEDIATE ''SE');
 l_expected:=l_expected||TO_CLOB('LECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND product_version=:v AND phase=''''COMPLETE'''''' INTO n USING checkpoint,version;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Complete the final ordered installation checkpoint'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND phase IN(''''FAILED'''',''''RUNNING'''')'' INTO n USING checkpoint;
  require(n=0,c_not_ready,''SETUP_NOT_READY: Recover the incomplete installation checkpoint'');
 END;
 PROCEDURE required_ready IS state kcv_deploy_state%ROWTYPE;hash_value VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;registered VARCHAR2(128);BEGIN
  verify_schema_ready;verify_network;hash_value:=p');
 l_expected:=l_expected||TO_CLOB('rofile_fingerprint;
  SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  require(state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=hash_value,c_not_ready,
    ''SETUP_NOT_READY: Explicitly test the current model configuration'');
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''''' INTO registered;
  require(registered=c_profile,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  expected_runtime(FALSE);dataset_state(a,b,c);
 END;
 FUNCTION learner_ready RETURN BOOLEAN IS ident identity_t;m VARCHAR2(3);n NUMBER;BEGIN
  authorize(FALSE,ident);SELECT maintenance INTO m FROM kcv_deploy_state WHERE singleton_id=1');
 l_expected:=l_expected||TO_CLOB(';
  IF m<>''OFF'' THEN RETURN FALSE;END IF;
  SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE status=''RUNNING'';IF n<>0 THEN RETURN FALSE;END IF;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
  IF n<>0 THEN RETURN FALSE;END IF;required_ready;RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;
 FUNCTION status_json RETURN CLOB IS
  ident identity_t;result JSON_OBJECT_T:=JSON_OBJECT_T();steps JSON_ARRAY_T:=JSON_ARRAY_T();
  item JSON_OBJECT_T;state kcv_deploy_state%ROWTYPE;h VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;n NUMBER;
  rows_json JSON_ARRAY_T:=JSON_ARRAY_T();search JSON_OBJECT_T:=JSON_OBJECT_T()');
 l_expected:=l_expected||TO_CLOB(';counts JSON_OBJECT_T:=JSON_OBJECT_T();
  all_ready BOOLEAN:=TRUE;code NUMBER;phase VARCHAR2(128);run_state VARCHAR2(16);
  PROCEDURE append_step(p_id VARCHAR2,p_ok BOOLEAN,p_error NUMBER,p_action VARCHAR2) IS BEGIN
   item:=JSON_OBJECT_T();item.put(''id'',p_id);item.put(''status'',CASE WHEN p_ok THEN ''READY'' ELSE ''PENDING'' END);
   IF p_error IS NOT NULL THEN item.put(''error_code'',p_error);END IF;
   IF NOT p_ok THEN item.put(''next_action'',p_action);all_ready:=FALSE;END IF;steps.append(item);
  END;
 BEGIN
  authorize(TRUE,ident);SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  result.put(''target_version'',kcv_deploy_contract.target_version);result.put(''target_checkpoint'',kcv_de');
 l_expected:=l_expected||TO_CLOB('ploy_contract.target_checkpoint);
  result.put(''maintenance'',state.maintenance=''ON'');
  BEGIN verify_schema_ready;append_step(''schema'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''schema'',FALSE,SQLCODE,''Finish or recover the matching Supporting Objects installation'');END;
  BEGIN verify_network;append_step(''network'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''network'',FALSE,SQLCODE,''Create or verify the owner RDF network'');END;
  BEGIN h:=profile_fingerprint;append_step(''profile'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN h:=NULL;append_step(''profile'',FALSE,SQLCODE,''Select an administrator-prepared local credential and configure model access'');END;
  append_st');
 l_expected:=l_expected||TO_CLOB('ep(''model_test'',h IS NOT NULL AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
    NULL,''Explicitly test the current model configuration'');
  BEGIN expected_runtime(FALSE);append_step(''runtime'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''runtime'',FALSE,SQLCODE,''Register the current scenario and grounded-answer runtime'');END;
  BEGIN dataset_state(a,b,c);append_step(''dataset'',TRUE,NULL,NULL);counts.put(''sources'',a);counts.put(''passages'',b);counts.put(''contexts'',c);result.put(''collection_counts'',counts);
  EXCEPTION WHEN OTHERS THEN append_step(''dataset'',FALSE,SQLCODE,''Load the approved pinned public collection or recover its failed import'');END;
  BEGIN
   E');
 l_expected:=l_expected||TO_CLOB('XECUTE IMMEDIATE ''SELECT status,phase FROM kcv_dataset_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 1 ROW ONLY'' INTO run_state,phase;
   item:=JSON_OBJECT_T();item.put(''status'',run_state);item.put(''phase'',phase);result.put(''dataset_progress'',item);
  EXCEPTION WHEN NO_DATA_FOUND THEN NULL;WHEN OTHERS THEN NULL;END;
  search.put(''optional'',TRUE);search.put(''mode'',''KEYWORD'');
  BEGIN EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_mining_models WHERE model_name=''''KCV_CONTEXT_MINILM'''''' INTO n;
   IF n=1 THEN search.put(''mode'',''MODEL_INSTALLED'');END IF;
  EXCEPTION WHEN OTHERS THEN NULL;END;
  search.put(''notice'',''Without the optional local embedding model, My Contexts uses keyword search.');
 l_expected:=l_expected||TO_CLOB(' The facilitator installs and verifies semantic search separately.'');
  result.put(''context_search'',search);result.put(''steps'',steps);
  FOR r IN(SELECT run_id,operation,status,phase,error_code FROM kcv_deploy_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 20 ROWS ONLY) LOOP
   item:=JSON_OBJECT_T();item.put(''run_id'',r.run_id);item.put(''operation'',r.operation);item.put(''status'',r.status);item.put(''phase'',r.phase);
   IF r.error_code IS NOT NULL THEN item.put(''error_code'',r.error_code);END IF;
   IF r.status IN(''FAILED'',''INTERRUPTED'') THEN item.put(''next_action'',''Review this step, then explicitly retry with a new request token'');END IF;
   rows_json.append(item);
  END LOOP;
  result.p');
 l_expected:=l_expected||TO_CLOB('ut(''runs'',rows_json);result.put(''required_checks_ready'',all_ready);
  result.put(''ready_for_learners'',learner_ready);RETURN result.to_clob();
 END;
 PROCEDURE lock_handle(p_handle OUT VARCHAR2) IS PRAGMA AUTONOMOUS_TRANSACTION;BEGIN
  DBMS_LOCK.ALLOCATE_UNIQUE(''KCV_DEPLOY_''||$$PLSQL_UNIT_OWNER,p_handle);COMMIT;
 END;
 PROCEDURE progress(p_run VARCHAR2,p_status VARCHAR2,p_phase VARCHAR2,p_error NUMBER DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
  UPDATE kcv_deploy_runs SET status=p_status,phase=p_phase,error_code=p_error,updated_at=SYSTIMESTAMP,
   completed_at=CASE WHEN p_status IN(''SUCCEEDED'',''FAILED'',''INTERRUPTED'') THEN SYSTIMESTAMP ELSE NULL END WHERE run_id=p_run;
  COMMIT;
');
 l_expected:=l_expected||TO_CLOB(' END;
 PROCEDURE maintenance_on IS BEGIN
  UPDATE kcv_deploy_state SET maintenance=''ON'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  IF own_table(''KCV_SETTINGS'') THEN
   EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
    WHEN MATCHED THEN UPDATE SET setting_value=''ON'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''ON'')~'';COMMIT;
  END IF;
 END;
 PROCEDURE no_active_work IS n NUMBER;BEGIN
  IF own_table(''KCV_CHAT_SESSIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the active a');
 l_expected:=l_expected||TO_CLOB('nswer or refinement'');
  END IF;
  IF own_table(''KCV_RESPONSE_RUNS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_response_runs WHERE status IN(''''RUNNING'''',''''UNCERTAIN'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Wait for the active answer or complete its supported recovery'');
  END IF;
  IF own_table(''KCV_PERSONAL_OPERATIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_personal_operations WHERE phase IN(''''BUILDING'''',''''READY'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the active personal-context operation'');
  END IF;
  IF own_table(''KCV_CONTEXT_DELETIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_context_deletions WHERE status=''''PENDING''''''');
 l_expected:=l_expected||TO_CLOB(' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the pending context deletion'');
  END IF;
 END;
 PROCEDURE register_profile IS BEGIN
  EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''AI_PROFILE'' k FROM dual)s ON(t.setting_key=s.k)
   WHEN MATCHED THEN UPDATE SET setting_value=''KCV_GENAI'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''KCV_GENAI'')~'';COMMIT;
 END;
 PROCEDURE verify_action(p_operation VARCHAR2,p_inputs JSON_OBJECT_T) IS h VARCHAR2(64);n NUMBER;a NUMBER;b NUMBER;c NUMBER;state kcv_deploy_state%ROWTYPE;BEGIN
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    h:=profile_fingerprint;
    require(profile_attribute(''credential_nam');
 l_expected:=l_expected||TO_CLOB('e'')=p_inputs.get_string(''credential_name'') AND profile_attribute(''region'')=p_inputs.get_string(''region'')
      AND profile_attribute(''model'')=p_inputs.get_string(''model'') AND profile_attribute(''oci_compartment_id'')=p_inputs.get_string(''oci_compartment_id''),
      c_conflict,''SETUP_CONFLICT: Profile changed after this request; use a new request token'');
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(h=p_inputs.get_string(''profile_hash'') AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
      c_not_ready,''SETUP_NOT_READY: This model test no longer matches the current configuration'');
   WHEN ''E');
 l_expected:=l_expected||TO_CLOB('NSURE_NETWORK'' THEN verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    require(profile_fingerprint=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed after this request'');
    expected_runtime(FALSE);
   WHEN ''LOAD_DATASET'' THEN
    dataset_state(a,b,c);
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_dataset_runs r JOIN kcv_settings s ON s.setting_key=''''ACTIVE_GRAPH'''' AND s.setting_value=r.graph_name ''
      ||''WHERE r.status=''''SUCCEEDED'''' AND r.source_ref=:ref AND r.manifest_sha256=:hash'' INTO n
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
    require(n>0,c_not_ready,''SETUP_NOT_READY: The active colle');
 l_expected:=l_expected||TO_CLOB('ction differs from this load request'');
   WHEN ''ENABLE_LEARNING'' THEN
    required_ready;
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(state.maintenance=''OFF'',c_not_ready,''SETUP_NOT_READY: Setup maintenance is still active'');
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
    require(n=0,c_not_ready,''SETUP_NOT_READY: Application maintenance is still active'');
   ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported setup operation'');
  END CASE;
 END;
 PROCEDURE run_action(p_operation VARCHAR2,p_token VARCHAR2,p_inputs JSON_OBJECT_T) IS
  ident ident');
 l_expected:=l_expected||TO_CLOB('ity_t;handle VARCHAR2(128);lock_result PLS_INTEGER;locked BOOLEAN:=FALSE;run VARCHAR2(32);
  input_hash VARCHAR2(64);old kcv_deploy_runs%ROWTYPE;state kcv_deploy_state%ROWTYPE;
  attrs CLOB;h VARCHAR2(64);existing_h VARCHAR2(64);n NUMBER;err NUMBER;response CLOB;ts VARCHAR2(128);found BOOLEAN:=TRUE;
  maintenance_changed BOOLEAN:=FALSE;runtime_started BOOLEAN:=FALSE;
  admission PLS_INTEGER;admission_locked BOOLEAN:=FALSE;
  prior_maintenance VARCHAR2(3);prior_updated TIMESTAMP WITH TIME ZONE;
  prior_legacy_exists BOOLEAN:=FALSE;prior_legacy_value VARCHAR2(4000);
  PROCEDURE snapshot_maintenance IS BEGIN
   SELECT maintenance,updated_at INTO prior_maintenance,prior_updated FROM kcv_deploy_s');
 l_expected:=l_expected||TO_CLOB('tate WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    BEGIN EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE''''''
      INTO prior_legacy_value;prior_legacy_exists:=TRUE;
    EXCEPTION WHEN NO_DATA_FOUND THEN prior_legacy_exists:=FALSE;END;
   END IF;
  END;
  PROCEDURE restore_maintenance IS BEGIN
   UPDATE kcv_deploy_state SET maintenance=prior_maintenance,updated_at=prior_updated WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    IF prior_legacy_exists THEN
     EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k,:v v FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED THEN UPDATE SET setting');
 l_expected:=l_expected||TO_CLOB('_value=s.v WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,s.v)~''
      USING prior_legacy_value;
    ELSE EXECUTE IMMEDIATE ''DELETE FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''''';END IF;
   END IF;COMMIT;
  END;
 BEGIN
  authorize(TRUE,ident);
  require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),c_invalid,
    ''INVALID_SETUP_INPUT: Use a new bounded request token for an explicit action'');
  input_hash:=digest(TO_CLOB(p_operation)||'':''||p_inputs.to_clob());
  lock_handle(handle);lock_result:=DBMS_LOCK.REQUEST(handle,DBMS_LOCK.X_MODE,0,FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: Another setup operation is active'');locked:=TRU');
 l_expected:=l_expected||TO_CLOB('E;
  authorize(TRUE,ident);
  BEGIN
   SELECT * INTO old FROM kcv_deploy_runs WHERE request_token=p_token;
  EXCEPTION WHEN NO_DATA_FOUND THEN found:=FALSE;END;
  IF found THEN
   require(old.input_hash=input_hash AND old.operation=p_operation AND old.account_id=ident.account_id
     AND old.application_id=ident.application_id AND old.workspace_id=ident.workspace_id,c_conflict,
     ''SETUP_CONFLICT: Request token belongs to different inputs or an account'');
   IF old.status=''SUCCEEDED'' THEN
    verify_action(p_operation,p_inputs);lock_result:=DBMS_LOCK.RELEASE(handle);RETURN;
   END IF;
   IF old.status=''RUNNING'' THEN progress(old.run_id,''INTERRUPTED'',''REVIEW_BEFORE_RETRY'',old.error_code);EN');
 l_expected:=l_expected||TO_CLOB('D IF;
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_PREVIOUS_FAILURE: Review the recorded step and explicitly retry with a new token'');
  END IF;
  UPDATE kcv_deploy_runs SET status=''INTERRUPTED'',phase=''REVIEW_BEFORE_RETRY'',updated_at=SYSTIMESTAMP,
    completed_at=SYSTIMESTAMP WHERE status=''RUNNING'';COMMIT;
  run:=RAWTOHEX(SYS_GUID());
  INSERT INTO kcv_deploy_runs(run_id,request_token,operation,input_hash,workspace_id,application_id,account_id,status,phase)
    VALUES(run,p_token,p_operation,input_hash,ident.workspace_id,ident.application_id,ident.account_id,''RUNNING'',''CHECKING_PREREQUISITES'');COMMIT;
  verify_schema_ready;
  admission:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_WRITE_ADMISSION:''||$$PL');
 l_expected:=l_expected||TO_CLOB('SQL_UNIT_OWNER,1,1073741823);
  lock_result:=DBMS_LOCK.REQUEST(id=>admission,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: A write is being admitted; retry after its transaction completes'');admission_locked:=TRUE;
  no_active_work;snapshot_maintenance;
  IF p_operation<>''ENABLE_LEARNING'' THEN maintenance_changed:=TRUE;maintenance_on;END IF;
  no_active_work;
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    progress(run,''RUNNING'',''CONFIGURING_PROFILE'');
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name=:p'' INTO n USING c_');
 l_expected:=l_expected||TO_CLOB('profile;
    attrs:=p_inputs.to_clob();
    IF n=0 THEN runtime_started:=TRUE;EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.CREATE_PROFILE(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
    ELSE
     existing_h:=profile_fingerprint;
     IF profile_attribute(''credential_name'')<>p_inputs.get_string(''credential_name'') OR profile_attribute(''region'')<>p_inputs.get_string(''region'')
       OR profile_attribute(''model'')<>p_inputs.get_string(''model'') OR profile_attribute(''oci_compartment_id'')<>p_inputs.get_string(''oci_compartment_id'') THEN
      require(state.config_hash=existing_h,c_conflict,''SETUP_CONFLICT: Existing profile was not configured here or has changed; ask the owner to review it');
 l_expected:=l_expected||TO_CLOB(''');
      runtime_started:=TRUE;
      EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.SET_ATTRIBUTES(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
     END IF;
    END IF;
    h:=profile_fingerprint;runtime_started:=TRUE;register_profile;
    UPDATE kcv_deploy_state SET config_hash=h,model_test_status=CASE WHEN model_test_hash=h THEN model_test_status ELSE ''NOT_TESTED'' END,
      updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;progress(run,''RUNNING'',''TESTING_MODEL'');
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before its test'');
    runtime_started:=TRUE;
    UP');
 l_expected:=l_expected||TO_CLOB('DATE kcv_deploy_state SET config_hash=h,model_test_status=''NOT_TESTED'',model_test_hash=NULL,model_test_at=NULL,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    EXECUTE IMMEDIATE ''BEGIN :r:=DBMS_CLOUD_AI.GENERATE(prompt=>''''Reply with the word Ready.'''',profile_name=>:p,action=>''''chat'''');END;'' USING OUT response,c_profile;
    require(response IS NOT NULL AND DBMS_LOB.GETLENGTH(response)>0,c_not_ready,''SETUP_NOT_READY: The model returned an empty test response'');
    require(profile_fingerprint=h,c_conflict,''SETUP_CONFLICT: Model configuration changed during its test'');
    register_profile;
    UPDATE kcv_deploy_state SET model_test_hash=h,model_test_status=''SUCCEEDED'',model_test_at=SY');
 l_expected:=l_expected||TO_CLOB('STIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
   WHEN ''ENSURE_NETWORK'' THEN
    progress(run,''RUNNING'',''ENSURING_RDF_NETWORK'');
    IF NOT own_table(c_network||''#SEM_MODEL$'') THEN
     SELECT network_tablespace INTO ts FROM kcv_deploy_state WHERE singleton_id=1;
     require(REGEXP_LIKE(ts,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),c_not_ready,''SETUP_NOT_READY: Administrator must verify the prepared tablespace'');
     EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_tablespaces WHERE tablespace_name=:t'' INTO n USING ts;
     require(n=1,c_not_ready,''SETUP_NOT_READY: Prepared RDF tablespace is unavailabl');
 l_expected:=l_expected||TO_CLOB('e'');
     runtime_started:=TRUE;
     EXECUTE IMMEDIATE ''BEGIN SEM_APIS.CREATE_RDF_NETWORK(:t,network_owner=>:o,network_name=>:n);END;'' USING ts,$$PLSQL_UNIT_OWNER,c_network;
    END IF;verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    h:=profile_fingerprint;
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before registration'');
    progress(run,''RUNNING'',''REGISTERING_RUNTIME'');runtime_started:=TRUE;register_profile;expected_runtime(TRUE);
   WHEN ''LOAD_DATASET'' THEN
    verify_network;progress(run,''RUNNING'',''LOADING_PUBLIC_COLLECTION'');
    require(REGEXP_LIKE(kcv_deploy_contract.dataset_ref,''^[0-9a-f]{40}$'',''c'')
      AND REGE');
 l_expected:=l_expected||TO_CLOB('XP_LIKE(kcv_deploy_contract.dataset_manifest_sha256,''^[0-9a-f]{64}$'',''c''),c_not_ready,''SETUP_NOT_READY: The packaged dataset pin is invalid'');
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE ''BEGIN KCV_DATASET.LOAD_GITHUB(p_ref=>:r,p_expected_manifest_sha256=>:h);END;''
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
   WHEN ''ENABLE_LEARNING'' THEN
    progress(run,''RUNNING'',''VERIFYING_READINESS'');required_ready;
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED THEN UPDATE SET setting_value=''OFF'' WHEN NOT MATCHED THEN INSERT(setting_key,se');
 l_expected:=l_expected||TO_CLOB('tting_value) VALUES(s.k,''OFF'')~'';
    UPDATE kcv_deploy_state SET maintenance=''OFF'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  END CASE;
  verify_action(p_operation,p_inputs);progress(run,''SUCCEEDED'',''COMPLETE'');
  lock_result:=DBMS_LOCK.RELEASE(admission);admission_locked:=FALSE;
  lock_result:=DBMS_LOCK.RELEASE(handle);locked:=FALSE;
 EXCEPTION WHEN OTHERS THEN
  err:=SQLCODE;
  IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
  ROLLBACK;
  IF run IS NOT NULL THEN
   IF runtime_started THEN maintenance_on;
   ELSIF maintenance_changed THEN restore_maintenance;END IF;
   IF p_operation=''TEST_MODEL'' AND runtime_started THEN
    UPDATE kcv_deploy_s');
 l_expected:=l_expected||TO_CLOB('tate SET model_test_status=''FAILED'',model_test_at=SYSTIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   END IF;
   progress(run,''FAILED'',''REVIEW_BEFORE_RETRY'',err);
  END IF;
  IF admission_locked THEN lock_result:=DBMS_LOCK.RELEASE(admission);END IF;
  IF locked THEN lock_result:=DBMS_LOCK.RELEASE(handle);END IF;
  IF run IS NOT NULL THEN
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_FAILED: Review the recorded error code and explicitly retry the step'');
  ELSE RAISE;END IF;
 END;
 PROCEDURE configure_profile(p_credential VARCHAR2,p_region VARCHAR2,p_compartment VARCHAR2,p_model VARCHAR2,p_request_token VARCHAR2) IS
  ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();cred VARCHA');
 l_expected:=l_expected||TO_CLOB('R2(128);
 BEGIN
  authorize(TRUE,ident);
  require(LENGTH(TRIM(p_credential)) BETWEEN 1 AND 128,c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  cred:=UPPER(TRIM(p_credential));local_credential(cred);
  require(p_region IS NOT NULL AND LENGTH(p_region)<=128 AND REGEXP_LIKE(p_region,''^[a-z][a-z0-9-]+-[0-9]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter an OCI region name'');
  require(p_compartment IS NOT NULL AND LENGTH(p_compartment)<=256 AND REGEXP_LIKE(p_compartment,''^ocid1\.compartment\.[A-Za-z0-9.-]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter a compartment OCID'');
  require(p_model IS NOT NULL AND LENGTH(p_model)<=256 AND REGEXP_LIKE(p_model,''^[A-Za-z0-9][A-Za-z0-9.');
 l_expected:=l_expected||TO_CLOB('_-]+$'',''c'')
    AND SUBSTR(p_model,1,6)<>''ocid1.'',c_invalid,''INVALID_SETUP_INPUT: Enter the supported model name, not an endpoint or URL'');
  j.put(''provider'',''oci'');j.put(''credential_name'',cred);j.put(''region'',p_region);j.put(''oci_compartment_id'',p_compartment);j.put(''model'',p_model);
  run_action(''CONFIGURE_PROFILE'',p_request_token,j);
 END;
 PROCEDURE test_model(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);run_action(''TEST_MODEL'',p_request_token,j);
 END;
 PROCEDURE ensure_network(p_request_token VARCHAR2) IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  j.put(''network'',c_network);run_acti');
 l_expected:=l_expected||TO_CLOB('on(''ENSURE_NETWORK'',p_request_token,j);
 END;
 PROCEDURE register_runtime(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);
  run_action(''REGISTER_RUNTIME'',p_request_token,j);
 END;
 PROCEDURE load_dataset(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''dataset_ref'',kcv_deploy_contract.dataset_ref);j.put(''manifest_sha256'',kcv_deploy_contract.dataset_manifest_sha256);
  run_action(''LOAD_DATASET'',p_request_token,j);
 END;
 PROCEDURE enable_learning(p_request_token VA');
 l_expected:=l_expected||TO_CLOB('RCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);run_action(''ENABLE_LEARNING'',p_request_token,j);
 END;
END;
');
 check_program('KCV_DEPLOY','PACKAGE BODY',l_expected);
 ELSE
  INSERT INTO kcv_schema_migrations(migration_id,payload_sha256,product_version,phase)
   VALUES('2.1.0-apl-r1-004-kcv_deploy-package-body','61b74bb2d3243be86e7d6ecb246067d485aaaf798fb82c90b893e60def1994fe','2.1.0','RUNNING');
  COMMIT;l_started:=TRUE;
 l_sql:=TO_CLOB('');
 l_sql:=l_sql||TO_CLOB('CREATE OR REPLACE PACKAGE BODY kcv_deploy AS
 c_profile CONSTANT VARCHAR2(128):=''KCV_GENAI'';
 c_network CONSTANT VARCHAR2(128):=''KCV_NET'';
 c_forbidden CONSTANT PLS_INTEGER:=-20300;
 c_invalid CONSTANT PLS_INTEGER:=-20301;
 c_busy CONSTANT PLS_INTEGER:=-20302;
 c_conflict CONSTANT PLS_INTEGER:=-20303;
 c_failed CONSTANT PLS_INTEGER:=-20304;
 c_not_ready CONSTANT PLS_INTEGER:=-20305;
 TYPE identity_t IS RECORD(workspace_id NUMBER,application_id NUMBER,account_id NUMBER);

 PROCEDURE require(p_ok BOOLEAN,p_code NUMBER,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION digest(p_text CLOB) RETURN VARCHAR2 IS BEGIN
  R');
 l_sql:=l_sql||TO_CLOB('ETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(p_text,DBMS_CRYPTO.HASH_SH256)));
 END;
 FUNCTION own_table(p_name VARCHAR2) RETURN BOOLEAN IS n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=p_name;RETURN n=1;
 END;
 FUNCTION own_name(p_name VARCHAR2) RETURN VARCHAR2 IS BEGIN
  RETURN DBMS_ASSERT.ENQUOTE_NAME($$PLSQL_UNIT_OWNER,FALSE)||''.''||DBMS_ASSERT.ENQUOTE_NAME(p_name,FALSE);
 END;

 PROCEDURE verify_application(p_identity identity_t) IS w VARCHAR2(255);n NUMBER;BEGIN
  SELECT COUNT(*),MAX(workspace) INTO n,w FROM apex_applications
   WHERE application_id=p_identity.application_id AND owner=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Application parsin');
 l_sql:=l_sql||TO_CLOB('g schema does not match'');
  require(apex_util.find_security_group_id(p_workspace=>w)=p_identity.workspace_id,
    c_forbidden,''SETUP_FORBIDDEN: Workspace does not match'');
  SELECT COUNT(*) INTO n FROM apex_workspace_schemas
   WHERE workspace_name=w AND schema=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Workspace schema mapping does not match'');
 END;
 PROCEDURE native_identity(p_identity OUT identity_t) IS
  u VARCHAR2(255):=SYS_CONTEXT(''APEX$SESSION'',''APP_USER'');
  a VARCHAR2(64):=SYS_CONTEXT(''APEX$SESSION'',''APP_ID'');authenticated BOOLEAN;
 BEGIN
  require(a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'') AND u IS NOT NULL
    AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_U');
 l_sql:=l_sql||TO_CLOB('SER''),c_forbidden,
    ''SETUP_FORBIDDEN: Sign in to the installed application'');
  authenticated:=apex_authentication.is_authenticated;
  require(authenticated AND a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'')
    AND u IS NOT NULL AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_USER''),
    c_forbidden,''SETUP_FORBIDDEN: Sign in to the installed application'');
  p_identity.application_id:=TO_NUMBER(a);
  p_identity.workspace_id:=apex_custom_auth.get_security_group_id;
  p_identity.account_id:=apex_util.get_user_id(p_username=>u);
  require(p_identity.workspace_id>0 AND p_identity.account_id>0,c_forbidden,
    ''SETUP_FORBIDDEN: A native workspace account is required'');
  verify_application(p_ident');
 l_sql:=l_sql||TO_CLOB('ity);
 END;
 PROCEDURE capture_identity IS ident identity_t;pinned VARCHAR2(128);BEGIN
  native_identity(ident);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
  require(pinned IS NULL OR pinned=TO_CHAR(ident.account_id,''TM9''),c_forbidden,
    ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  IF pinned IS NULL THEN
   apex_util.set_session_state(p_name=>''KCV_AUTH_ACCOUNT_ID'',
     p_value=>TO_CHAR(ident.account_id,''TM9''),p_commit=>FALSE);
  END IF;
 END;
 PROCEDURE authorize(p_installer BOOLEAN,p_identity OUT identity_t) IS
  state kcv_deploy_state%ROWTYPE;roles VARCHAR2(4000);pinned VARCHAR2(128);owner_session BOOLEAN;
 BEGIN
  owner_session:=SYS_');
 l_sql:=l_sql||TO_CLOB('CONTEXT(''APEX$SESSION'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL;
  IF owner_session THEN
   require(SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER
     AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,c_forbidden,
     ''SETUP_FORBIDDEN: Use an authenticated project owner session'');
  ELSE
   native_identity(p_identity);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
   require(pinned=TO_CHAR(p_identity.account_id,''TM9''),c_forbidden,
     ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  END IF;
  BEGIN SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  EXCEPTION WHEN NO_DATA_FOUND T');
 l_sql:=l_sql||TO_CLOB('HEN RAISE_APPLICATION_ERROR(c_forbidden,
    ''SETUP_FORBIDDEN: Trusted application installation has not bound this setup'');END;
  IF owner_session THEN
   p_identity.workspace_id:=state.workspace_id;p_identity.application_id:=state.application_id;p_identity.account_id:=0;
   verify_application(p_identity);
  END IF;
  require(state.schema_owner=$$PLSQL_UNIT_OWNER AND state.workspace_id=p_identity.workspace_id
    AND state.application_id=p_identity.application_id,c_forbidden,
    ''SETUP_FORBIDDEN: This application is not the bound installation'');
  IF p_installer AND NOT owner_session THEN
   roles:=apex_util.get_user_roles(p_username=>SYS_CONTEXT(''APEX$SESSION'',''APP_USER''));
   require(INST');
 l_sql:=l_sql||TO_CLOB('R('':''||UPPER(roles)||'':'','':ADMIN:'')>0,c_forbidden,
     ''SETUP_FORBIDDEN: A workspace administrator must complete setup'');
  END IF;
 END;
 FUNCTION is_installer RETURN BOOLEAN IS ident identity_t;BEGIN
  authorize(TRUE,ident);RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;

 FUNCTION attribute_text(p_value CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T;s VARCHAR2(4000);BEGIN
  require(p_value IS NOT NULL AND DBMS_LOB.GETLENGTH(p_value)<=4000,c_not_ready,
    ''SETUP_NOT_READY: Profile metadata is unavailable'');
  s:=TRIM(DBMS_LOB.SUBSTR(p_value,4000,1));
  IF SUBSTR(s,1,1)=''"'' THEN j:=JSON_OBJECT_T.parse(''{"v":''||s||''}'');RETURN j.get_string(''v'');END IF;
  RETURN s;
 END;
 FUNCTION profi');
 l_sql:=l_sql||TO_CLOB('le_attribute(p_name VARCHAR2) RETURN VARCHAR2 IS value CLOB;BEGIN
  EXECUTE IMMEDIATE ''SELECT attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p AND attribute_name=:a'' INTO value USING c_profile,p_name;
  RETURN attribute_text(value);
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;END;
 PROCEDURE local_credential(p_name VARCHAR2) IS n NUMBER;BEGIN
  require(p_name IS NOT NULL AND REGEXP_LIKE(p_name,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),
    c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_credentials WHERE credential_name=:c'' INTO n USING p_name;
  require(n=1,c_invalid,''INVALID_SETUP_INPUT: The se');
 l_sql:=l_sql||TO_CLOB('lected credential is not local to this schema'');
 END;
 FUNCTION profile_fingerprint RETURN VARCHAR2 IS
  material CLOB:=TO_CLOB('''');v CLOB;name VARCHAR2(128);cursor_id SYS_REFCURSOR;n NUMBER;
 BEGIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name=:p AND status=''''ENABLED''''''
    INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Configure an enabled model profile'');
  require(profile_attribute(''provider'')=''oci'',c_not_ready,''SETUP_NOT_READY: The profile must use the prepared OCI provider'');
  local_credential(profile_attribute(''credential_name''));
  require(profile_attribute(''region'') IS NOT NULL AND profile_attribute(''model'') IS NOT NULL
  ');
 l_sql:=l_sql||TO_CLOB('  AND profile_attribute(''oci_compartment_id'') IS NOT NULL,c_not_ready,''SETUP_NOT_READY: Model profile configuration is incomplete'');
  OPEN cursor_id FOR ''SELECT attribute_name,attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p ORDER BY attribute_name'' USING c_profile;
  LOOP FETCH cursor_id INTO name,v;EXIT WHEN cursor_id%NOTFOUND;
   material:=material||LENGTH(name)||'':''||name||'':''||DBMS_LOB.GETLENGTH(v)||'':''||v||CHR(10);
  END LOOP;CLOSE cursor_id;
  RETURN digest(material);
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;
 FUNCTION credential_options RETURN CLOB IS
  ident identity_t;items JSON_ARRAY_T:=JSON_ARRAY_T(');
 l_sql:=l_sql||TO_CLOB(');name VARCHAR2(128);cursor_id SYS_REFCURSOR;
 BEGIN
  authorize(TRUE,ident);
  OPEN cursor_id FOR ''SELECT credential_name FROM user_credentials ORDER BY credential_name'';
  LOOP FETCH cursor_id INTO name;EXIT WHEN cursor_id%NOTFOUND;items.append(name);END LOOP;
  CLOSE cursor_id;RETURN items.to_clob();
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;

 PROCEDURE verify_network IS n NUMBER;BEGIN
  require(own_table(c_network||''#SEM_MODEL$''),c_not_ready,''SETUP_NOT_READY: Create the owner RDF network'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||own_name(c_network||''#SEM_MODEL$'')||'' WHERE owner<>:o''
    INTO n USING $$PLSQL_UNIT_OWNER;
  require(n=0,c_no');
 l_sql:=l_sql||TO_CLOB('t_ready,''SETUP_NOT_READY: RDF network ownership requires administrator review'');
 END;
 FUNCTION runtime_instruction(p_grounded BOOLEAN) RETURN CLOB IS result CLOB;BEGIN
  IF p_grounded THEN EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.grounded_instruction;END;'' USING OUT result;
  ELSE EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.qa_instruction;END;'' USING OUT result;END IF;
  RETURN result;
 END;
 PROCEDURE expected_runtime(p_create BOOLEAN) IS
  task JSON_OBJECT_T;instruction CLOB;n NUMBER;
  PROCEDURE object_ready(p_type VARCHAR2,p_name VARCHAR2,p_attributes CLOB,p_description VARCHAR2 DEFAULT NULL) IS
   base_view VARCHAR2(128);attr_view VARCHAR2(128);name_column VARCHAR2(128);attr_name_colum');
 l_sql:=l_sql||TO_CLOB('n VARCHAR2(128);
   expected JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_attributes);keys JSON_KEY_LIST:=expected.get_keys;
   wanted JSON_ELEMENT_T;actual CLOB;wanted_json CLOB;n NUMBER;equal_value NUMBER;s VARCHAR2(32767);
  BEGIN
   CASE p_type
    WHEN ''tool'' THEN base_view:=''USER_AI_AGENT_TOOLS'';attr_view:=''USER_AI_AGENT_TOOL_ATTRIBUTES'';name_column:=''TOOL_NAME'';attr_name_column:=''TOOL_NAME'';
    WHEN ''task'' THEN base_view:=''USER_AI_AGENT_TASKS'';attr_view:=''USER_AI_AGENT_TASK_ATTRIBUTES'';name_column:=''TASK_NAME'';attr_name_column:=''TASK_NAME'';
    WHEN ''agent'' THEN base_view:=''USER_AI_AGENTS'';attr_view:=''USER_AI_AGENT_ATTRIBUTES'';name_column:=''AGENT_NAME'';attr_name_column:=''AGENT_NAME'';
    WHE');
 l_sql:=l_sql||TO_CLOB('N ''team'' THEN base_view:=''USER_AI_AGENT_TEAMS'';attr_view:=''USER_AI_AGENT_TEAM_ATTRIBUTES'';name_column:=''AGENT_TEAM_NAME'';attr_name_column:=''TEAM_NAME'';
    ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported runtime object'');
   END CASE;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n'' INTO n USING p_name;
   IF n=0 AND p_create THEN
    CASE p_type
     WHEN ''tool'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name=>:n,description=>:d,attributes=>:a);END;'' USING p_name,p_description,p_attributes;
     WHEN ''task'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>:n,attributes=>:a);END;'' U');
 l_sql:=l_sql||TO_CLOB('SING p_name,p_attributes;
     WHEN ''agent'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
     WHEN ''team'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
    END CASE;
   END IF;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n AND status=''''ENABLED'''''' INTO n USING p_name;
   require(n=1,c_not_ready,''SETUP_NOT_READY: A required runtime object is missing or disabled'');
   FOR i IN 1..keys.COUNT LOOP
    BEGIN EXECUTE IMMEDIATE ''SELECT attribute_value FROM ''||attr_view||'' WHERE ''||attr_name_column
    ');
 l_sql:=l_sql||TO_CLOB('  ||''=:n AND attribute_name=:a'' INTO actual USING p_name,keys(i);
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(c_conflict,''SETUP_CONFLICT: Existing runtime attributes require administrator review'');END;
    wanted:=expected.get(keys(i));
    IF wanted.is_string THEN
     s:=expected.get_string(keys(i));
     require(DBMS_LOB.GETLENGTH(actual)<=32767,c_conflict,''SETUP_CONFLICT: Unexpected runtime attribute size'');
     IF SUBSTR(TRIM(DBMS_LOB.SUBSTR(actual,32767,1)),1,1)=''"'' THEN
      wanted_json:=wanted.to_clob();
      EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
        INTO equal_value USING actual,wanted_json;
     ELSE equal_');
 l_sql:=l_sql||TO_CLOB('value:=CASE WHEN DBMS_LOB.COMPARE(actual,TO_CLOB(s))=0 THEN 1 ELSE 0 END;END IF;
    ELSE
     wanted_json:=wanted.to_clob();
     EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
       INTO equal_value USING actual,wanted_json;
    END IF;
    require(equal_value=1,c_conflict,''SETUP_CONFLICT: Existing runtime attributes differ; no object was replaced'');
   END LOOP;
  END;
  FUNCTION agent_attributes(p_role VARCHAR2,p_supervisor BOOLEAN DEFAULT FALSE) RETURN CLOB IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''profile_name'',c_profile);j.put(''role'',p_role);j.put(''enable_human_tool'',FALSE);
   IF p_supervisor THEN j.put(''supervisor'',TRUE);END IF;RETURN j');
 l_sql:=l_sql||TO_CLOB('.to_clob();
  END;
 BEGIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''' AND setting_value=:p'' INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_objects WHERE object_name IN ''
    ||''(''''KCV_SCENARIO_EVIDENCE'''',''''KCV_SCENARIO_PROPOSE'''') AND object_type=''''FUNCTION'''' AND status=''''VALID'''''' INTO n;
  require(n=2,c_not_ready,''SETUP_NOT_READY: Verify schema runtime functions first'');
  object_ready(''tool'',''KCV_SCENARIO_EVIDENCE'',
    ''{"function":"KCV_SCENARIO_EVIDENCE","instruction":"Pass the original request JSON unchanged.","tool_inputs":[{"name":"p_requ');
 l_sql:=l_sql||TO_CLOB('est","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}'',
    ''Read public evidence and actual topic graph paths for the current scenario'');
  object_ready(''tool'',''KCV_SCENARIO_PROPOSE'',
    ''{"function":"KCV_SCENARIO_PROPOSE","instruction":"Pass the original request JSON unchanged. This tool cannot apply changes.","tool_inputs":[{"name":"p_request","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}'',
    ''Propose one context edit; never applies a change'');
  task:=JSON_OBJECT_T.parse(''{"tools":["KCV_SCENARIO_EVIDENCE"],"enable_human_tool":false}'');
  instruction:=runtime_instruction(FALSE);task.put(''instru');
 l_sql:=l_sql||TO_CLOB('ction'',instruction);
  object_ready(''task'',''KCV_SCENARIO_QA_TASK'',task.to_clob());
  task:=JSON_OBJECT_T.parse(''{"tools":[],"enable_human_tool":false}'');
  instruction:=runtime_instruction(TRUE);task.put(''instruction'',instruction);
  object_ready(''task'',''KCV_GROUNDED_QA_TASK'',task.to_clob());
  object_ready(''task'',''KCV_SCENARIO_CHANGE_TASK'',q''~{"instruction":"For {query}, call KCV_SCENARIO_PROPOSE once with the original JSON. Return its proposed_plan JSON unchanged, including any clarification message. State that no change has been applied. The user must inspect and submit a structured refinement outside the agent. Never call another tool, invent a confirmation or claim success.","tools":["K');
 l_sql:=l_sql||TO_CLOB('CV_SCENARIO_PROPOSE"],"enable_human_tool":false}~'');
  object_ready(''agent'',''KCV_SCENARIO_QA'',agent_attributes(''Explain contextual relevance from public evidence and actual graph paths. Read only.''));
  object_ready(''agent'',''KCV_SCENARIO_PLANNER'',agent_attributes(''Propose one allowed context change. Never apply or confirm changes.''));
  object_ready(''agent'',''KCV_SCENARIO_ROUTER'',agent_attributes(''Route task question to KCV_SCENARIO_QA and task propose_change to KCV_SCENARIO_PLANNER. Pass the full request unchanged to exactly one worker and return its result.'',TRUE));
  object_ready(''team'',''KCV_EXPLORER_TEAM'',''{"supervisor_agent":"KCV_SCENARIO_ROUTER","process":"sequential","agents":[{"name":');
 l_sql:=l_sql||TO_CLOB('"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"},{"name":"KCV_SCENARIO_PLANNER","task":"KCV_SCENARIO_CHANGE_TASK"}]}'');
  object_ready(''team'',''KCV_EVIDENCE_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"}]}'');
  object_ready(''team'',''KCV_GROUNDED_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_GROUNDED_QA_TASK"}]}'');
 END;

 PROCEDURE dataset_state(p_sources OUT NUMBER,p_passages OUT NUMBER,p_contexts OUT NUMBER) IS g VARCHAR2(128);n NUMBER;BEGIN
  verify_network;
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''''' INTO g;
  require(REGEXP_LIKE(g,''^KCV_G_[A-F0-9]+$'',''c'')');
 l_sql:=l_sql||TO_CLOB(',c_not_ready,''SETUP_NOT_READY: Collection graph is unavailable'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_runs g WHERE g.graph_name=:g AND g.state=''''READY'''' ''
    ||''AND EXISTS(SELECT 1 FROM kcv_dataset_runs d WHERE d.graph_name=g.graph_name AND d.status=''''SUCCEEDED'''')'' INTO n USING g;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Collection needs a completed verified import'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_sources WHERE graph_name=:g'' INTO p_sources USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_passages p JOIN kcv_graph_sources s ON p.version_id=s.version_id WHERE s.graph_name=:g'' INTO p_passages USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv');
 l_sql:=l_sql||TO_CLOB('_graph_contexts WHERE graph_name=:g'' INTO p_contexts USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM TABLE(SEM_MATCH(''''SELECT ?s ?p ?o WHERE { ?s ?p ?o }'''',SEM_MODELS(''
    ||DBMS_ASSERT.ENQUOTE_LITERAL(g)||''),NULL,NULL,NULL,NULL,NULL,NULL,NULL,''
    ||DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||'',''''KCV_NET''''))'' INTO n;
  require(p_sources>0 AND p_passages>0 AND p_contexts>0 AND n>0,c_not_ready,''SETUP_NOT_READY: Collection evidence or graph is empty'');
 END;
 PROCEDURE verify_schema_ready IS n NUMBER;checkpoint VARCHAR2(128);version VARCHAR2(20);BEGIN
  kcv_deploy_contract.verify_schema;
  checkpoint:=kcv_deploy_contract.target_checkpoint;version:=kcv_deploy_contract.target_version;
');
 l_sql:=l_sql||TO_CLOB('  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND product_version=:v AND phase=''''COMPLETE'''''' INTO n USING checkpoint,version;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Complete the final ordered installation checkpoint'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND phase IN(''''FAILED'''',''''RUNNING'''')'' INTO n USING checkpoint;
  require(n=0,c_not_ready,''SETUP_NOT_READY: Recover the incomplete installation checkpoint'');
 END;
 PROCEDURE required_ready IS state kcv_deploy_state%ROWTYPE;hash_value VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;registered VARCHAR2(128);BEGIN
  verify_schema_ready;verif');
 l_sql:=l_sql||TO_CLOB('y_network;hash_value:=profile_fingerprint;
  SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  require(state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=hash_value,c_not_ready,
    ''SETUP_NOT_READY: Explicitly test the current model configuration'');
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''''' INTO registered;
  require(registered=c_profile,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  expected_runtime(FALSE);dataset_state(a,b,c);
 END;
 FUNCTION learner_ready RETURN BOOLEAN IS ident identity_t;m VARCHAR2(3);n NUMBER;BEGIN
  authorize(FALSE,ident);SELECT maintenance INTO m FROM kcv_deploy_sta');
 l_sql:=l_sql||TO_CLOB('te WHERE singleton_id=1;
  IF m<>''OFF'' THEN RETURN FALSE;END IF;
  SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE status=''RUNNING'';IF n<>0 THEN RETURN FALSE;END IF;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
  IF n<>0 THEN RETURN FALSE;END IF;required_ready;RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;
 FUNCTION status_json RETURN CLOB IS
  ident identity_t;result JSON_OBJECT_T:=JSON_OBJECT_T();steps JSON_ARRAY_T:=JSON_ARRAY_T();
  item JSON_OBJECT_T;state kcv_deploy_state%ROWTYPE;h VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;n NUMBER;
  rows_json JSON_ARRAY_T:=JSON_ARRAY_T();search JSON_OB');
 l_sql:=l_sql||TO_CLOB('JECT_T:=JSON_OBJECT_T();counts JSON_OBJECT_T:=JSON_OBJECT_T();
  all_ready BOOLEAN:=TRUE;code NUMBER;phase VARCHAR2(128);run_state VARCHAR2(16);
  PROCEDURE append_step(p_id VARCHAR2,p_ok BOOLEAN,p_error NUMBER,p_action VARCHAR2) IS BEGIN
   item:=JSON_OBJECT_T();item.put(''id'',p_id);item.put(''status'',CASE WHEN p_ok THEN ''READY'' ELSE ''PENDING'' END);
   IF p_error IS NOT NULL THEN item.put(''error_code'',p_error);END IF;
   IF NOT p_ok THEN item.put(''next_action'',p_action);all_ready:=FALSE;END IF;steps.append(item);
  END;
 BEGIN
  authorize(TRUE,ident);SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  result.put(''target_version'',kcv_deploy_contract.target_version);result.put(''ta');
 l_sql:=l_sql||TO_CLOB('rget_checkpoint'',kcv_deploy_contract.target_checkpoint);
  result.put(''maintenance'',state.maintenance=''ON'');
  BEGIN verify_schema_ready;append_step(''schema'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''schema'',FALSE,SQLCODE,''Finish or recover the matching Supporting Objects installation'');END;
  BEGIN verify_network;append_step(''network'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''network'',FALSE,SQLCODE,''Create or verify the owner RDF network'');END;
  BEGIN h:=profile_fingerprint;append_step(''profile'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN h:=NULL;append_step(''profile'',FALSE,SQLCODE,''Select an administrator-prepared local credential and configure model ac');
 l_sql:=l_sql||TO_CLOB('cess'');END;
  append_step(''model_test'',h IS NOT NULL AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
    NULL,''Explicitly test the current model configuration'');
  BEGIN expected_runtime(FALSE);append_step(''runtime'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''runtime'',FALSE,SQLCODE,''Register the current scenario and grounded-answer runtime'');END;
  BEGIN dataset_state(a,b,c);append_step(''dataset'',TRUE,NULL,NULL);counts.put(''sources'',a);counts.put(''passages'',b);counts.put(''contexts'',c);result.put(''collection_counts'',counts);
  EXCEPTION WHEN OTHERS THEN append_step(''dataset'',FALSE,SQLCODE,''Load the approved pinned public collection or recover its failed imp');
 l_sql:=l_sql||TO_CLOB('ort'');END;
  BEGIN
   EXECUTE IMMEDIATE ''SELECT status,phase FROM kcv_dataset_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 1 ROW ONLY'' INTO run_state,phase;
   item:=JSON_OBJECT_T();item.put(''status'',run_state);item.put(''phase'',phase);result.put(''dataset_progress'',item);
  EXCEPTION WHEN NO_DATA_FOUND THEN NULL;WHEN OTHERS THEN NULL;END;
  search.put(''optional'',TRUE);search.put(''mode'',''KEYWORD'');
  BEGIN EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_mining_models WHERE model_name=''''KCV_CONTEXT_MINILM'''''' INTO n;
   IF n=1 THEN search.put(''mode'',''MODEL_INSTALLED'');END IF;
  EXCEPTION WHEN OTHERS THEN NULL;END;
  search.put(''notice'',''Without the optional local embedding model, My Contex');
 l_sql:=l_sql||TO_CLOB('ts uses keyword search. The facilitator installs and verifies semantic search separately.'');
  result.put(''context_search'',search);result.put(''steps'',steps);
  FOR r IN(SELECT run_id,operation,status,phase,error_code FROM kcv_deploy_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 20 ROWS ONLY) LOOP
   item:=JSON_OBJECT_T();item.put(''run_id'',r.run_id);item.put(''operation'',r.operation);item.put(''status'',r.status);item.put(''phase'',r.phase);
   IF r.error_code IS NOT NULL THEN item.put(''error_code'',r.error_code);END IF;
   IF r.status IN(''FAILED'',''INTERRUPTED'') THEN item.put(''next_action'',''Review this step, then explicitly retry with a new request token'');END IF;
   rows_json.append(item);');
 l_sql:=l_sql||TO_CLOB('
  END LOOP;
  result.put(''runs'',rows_json);result.put(''required_checks_ready'',all_ready);
  result.put(''ready_for_learners'',learner_ready);RETURN result.to_clob();
 END;

 PROCEDURE lock_handle(p_handle OUT VARCHAR2) IS PRAGMA AUTONOMOUS_TRANSACTION;BEGIN
  DBMS_LOCK.ALLOCATE_UNIQUE(''KCV_DEPLOY_''||$$PLSQL_UNIT_OWNER,p_handle);COMMIT;
 END;
 PROCEDURE progress(p_run VARCHAR2,p_status VARCHAR2,p_phase VARCHAR2,p_error NUMBER DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
  UPDATE kcv_deploy_runs SET status=p_status,phase=p_phase,error_code=p_error,updated_at=SYSTIMESTAMP,
   completed_at=CASE WHEN p_status IN(''SUCCEEDED'',''FAILED'',''INTERRUPTED'') THEN SYSTIMESTAMP ELSE NULL END WHERE ');
 l_sql:=l_sql||TO_CLOB('run_id=p_run;
  COMMIT;
 END;
 PROCEDURE maintenance_on IS BEGIN
  UPDATE kcv_deploy_state SET maintenance=''ON'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  IF own_table(''KCV_SETTINGS'') THEN
   EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
    WHEN MATCHED THEN UPDATE SET setting_value=''ON'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''ON'')~'';COMMIT;
  END IF;
 END;
 PROCEDURE no_active_work IS n NUMBER;BEGIN
  IF own_table(''KCV_CHAT_SESSIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete');
 l_sql:=l_sql||TO_CLOB(' or recover the active answer or refinement'');
  END IF;
  IF own_table(''KCV_RESPONSE_RUNS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_response_runs WHERE status IN(''''RUNNING'''',''''UNCERTAIN'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Wait for the active answer or complete its supported recovery'');
  END IF;
  IF own_table(''KCV_PERSONAL_OPERATIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_personal_operations WHERE phase IN(''''BUILDING'''',''''READY'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the active personal-context operation'');
  END IF;
  IF own_table(''KCV_CONTEXT_DELETIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_context_deletions W');
 l_sql:=l_sql||TO_CLOB('HERE status=''''PENDING'''''' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the pending context deletion'');
  END IF;
 END;
 PROCEDURE register_profile IS BEGIN
  EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''AI_PROFILE'' k FROM dual)s ON(t.setting_key=s.k)
   WHEN MATCHED THEN UPDATE SET setting_value=''KCV_GENAI'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''KCV_GENAI'')~'';COMMIT;
 END;
 PROCEDURE verify_action(p_operation VARCHAR2,p_inputs JSON_OBJECT_T) IS h VARCHAR2(64);n NUMBER;a NUMBER;b NUMBER;c NUMBER;state kcv_deploy_state%ROWTYPE;BEGIN
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    h:=profile_fingerprint;
    require(profile_a');
 l_sql:=l_sql||TO_CLOB('ttribute(''credential_name'')=p_inputs.get_string(''credential_name'') AND profile_attribute(''region'')=p_inputs.get_string(''region'')
      AND profile_attribute(''model'')=p_inputs.get_string(''model'') AND profile_attribute(''oci_compartment_id'')=p_inputs.get_string(''oci_compartment_id''),
      c_conflict,''SETUP_CONFLICT: Profile changed after this request; use a new request token'');
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(h=p_inputs.get_string(''profile_hash'') AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
      c_not_ready,''SETUP_NOT_READY: This model test no longer matches the current con');
 l_sql:=l_sql||TO_CLOB('figuration'');
   WHEN ''ENSURE_NETWORK'' THEN verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    require(profile_fingerprint=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed after this request'');
    expected_runtime(FALSE);
   WHEN ''LOAD_DATASET'' THEN
    dataset_state(a,b,c);
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_dataset_runs r JOIN kcv_settings s ON s.setting_key=''''ACTIVE_GRAPH'''' AND s.setting_value=r.graph_name ''
      ||''WHERE r.status=''''SUCCEEDED'''' AND r.source_ref=:ref AND r.manifest_sha256=:hash'' INTO n
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
    require(n>0,c_not_ready,''SETUP_NOT');
 l_sql:=l_sql||TO_CLOB('_READY: The active collection differs from this load request'');
   WHEN ''ENABLE_LEARNING'' THEN
    required_ready;
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(state.maintenance=''OFF'',c_not_ready,''SETUP_NOT_READY: Setup maintenance is still active'');
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
    require(n=0,c_not_ready,''SETUP_NOT_READY: Application maintenance is still active'');
   ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported setup operation'');
  END CASE;
 END;
 PROCEDURE run_action(p_operation VARCHAR2,p_token VARCHAR2,p_inputs JSON_OB');
 l_sql:=l_sql||TO_CLOB('JECT_T) IS
  ident identity_t;handle VARCHAR2(128);lock_result PLS_INTEGER;locked BOOLEAN:=FALSE;run VARCHAR2(32);
  input_hash VARCHAR2(64);old kcv_deploy_runs%ROWTYPE;state kcv_deploy_state%ROWTYPE;
  attrs CLOB;h VARCHAR2(64);existing_h VARCHAR2(64);n NUMBER;err NUMBER;response CLOB;ts VARCHAR2(128);found BOOLEAN:=TRUE;
  maintenance_changed BOOLEAN:=FALSE;runtime_started BOOLEAN:=FALSE;
  admission PLS_INTEGER;admission_locked BOOLEAN:=FALSE;
  prior_maintenance VARCHAR2(3);prior_updated TIMESTAMP WITH TIME ZONE;
  prior_legacy_exists BOOLEAN:=FALSE;prior_legacy_value VARCHAR2(4000);
  PROCEDURE snapshot_maintenance IS BEGIN
   SELECT maintenance,updated_at INTO prior_maintenance,prior_u');
 l_sql:=l_sql||TO_CLOB('pdated FROM kcv_deploy_state WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    BEGIN EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE''''''
      INTO prior_legacy_value;prior_legacy_exists:=TRUE;
    EXCEPTION WHEN NO_DATA_FOUND THEN prior_legacy_exists:=FALSE;END;
   END IF;
  END;
  PROCEDURE restore_maintenance IS BEGIN
   UPDATE kcv_deploy_state SET maintenance=prior_maintenance,updated_at=prior_updated WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    IF prior_legacy_exists THEN
     EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k,:v v FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED');
 l_sql:=l_sql||TO_CLOB(' THEN UPDATE SET setting_value=s.v WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,s.v)~''
      USING prior_legacy_value;
    ELSE EXECUTE IMMEDIATE ''DELETE FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''''';END IF;
   END IF;COMMIT;
  END;
 BEGIN
  authorize(TRUE,ident);
  require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),c_invalid,
    ''INVALID_SETUP_INPUT: Use a new bounded request token for an explicit action'');
  input_hash:=digest(TO_CLOB(p_operation)||'':''||p_inputs.to_clob());
  lock_handle(handle);lock_result:=DBMS_LOCK.REQUEST(handle,DBMS_LOCK.X_MODE,0,FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: Another setup operation');
 l_sql:=l_sql||TO_CLOB(' is active'');locked:=TRUE;
  authorize(TRUE,ident);
  BEGIN
   SELECT * INTO old FROM kcv_deploy_runs WHERE request_token=p_token;
  EXCEPTION WHEN NO_DATA_FOUND THEN found:=FALSE;END;
  IF found THEN
   require(old.input_hash=input_hash AND old.operation=p_operation AND old.account_id=ident.account_id
     AND old.application_id=ident.application_id AND old.workspace_id=ident.workspace_id,c_conflict,
     ''SETUP_CONFLICT: Request token belongs to different inputs or an account'');
   IF old.status=''SUCCEEDED'' THEN
    verify_action(p_operation,p_inputs);lock_result:=DBMS_LOCK.RELEASE(handle);RETURN;
   END IF;
   IF old.status=''RUNNING'' THEN progress(old.run_id,''INTERRUPTED'',''REVIEW_BEFORE_R');
 l_sql:=l_sql||TO_CLOB('ETRY'',old.error_code);END IF;
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_PREVIOUS_FAILURE: Review the recorded step and explicitly retry with a new token'');
  END IF;
  UPDATE kcv_deploy_runs SET status=''INTERRUPTED'',phase=''REVIEW_BEFORE_RETRY'',updated_at=SYSTIMESTAMP,
    completed_at=SYSTIMESTAMP WHERE status=''RUNNING'';COMMIT;
  run:=RAWTOHEX(SYS_GUID());
  INSERT INTO kcv_deploy_runs(run_id,request_token,operation,input_hash,workspace_id,application_id,account_id,status,phase)
    VALUES(run,p_token,p_operation,input_hash,ident.workspace_id,ident.application_id,ident.account_id,''RUNNING'',''CHECKING_PREREQUISITES'');COMMIT;
  verify_schema_ready;
  admission:=DBMS_UTILITY.GET_HASH_VALUE(''KCV');
 l_sql:=l_sql||TO_CLOB('_WRITE_ADMISSION:''||$$PLSQL_UNIT_OWNER,1,1073741823);
  lock_result:=DBMS_LOCK.REQUEST(id=>admission,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: A write is being admitted; retry after its transaction completes'');admission_locked:=TRUE;
  no_active_work;snapshot_maintenance;
  IF p_operation<>''ENABLE_LEARNING'' THEN maintenance_changed:=TRUE;maintenance_on;END IF;
  no_active_work;
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    progress(run,''RUNNING'',''CONFIGURING_PROFILE'');
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_');
 l_sql:=l_sql||TO_CLOB('name=:p'' INTO n USING c_profile;
    attrs:=p_inputs.to_clob();
    IF n=0 THEN runtime_started:=TRUE;EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.CREATE_PROFILE(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
    ELSE
     existing_h:=profile_fingerprint;
     IF profile_attribute(''credential_name'')<>p_inputs.get_string(''credential_name'') OR profile_attribute(''region'')<>p_inputs.get_string(''region'')
       OR profile_attribute(''model'')<>p_inputs.get_string(''model'') OR profile_attribute(''oci_compartment_id'')<>p_inputs.get_string(''oci_compartment_id'') THEN
      require(state.config_hash=existing_h,c_conflict,''SETUP_CONFLICT: Existing profile was not configured here or has changed; as');
 l_sql:=l_sql||TO_CLOB('k the owner to review it'');
      runtime_started:=TRUE;
      EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.SET_ATTRIBUTES(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
     END IF;
    END IF;
    h:=profile_fingerprint;runtime_started:=TRUE;register_profile;
    UPDATE kcv_deploy_state SET config_hash=h,model_test_status=CASE WHEN model_test_hash=h THEN model_test_status ELSE ''NOT_TESTED'' END,
      updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;progress(run,''RUNNING'',''TESTING_MODEL'');
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before its test'');
    runti');
 l_sql:=l_sql||TO_CLOB('me_started:=TRUE;
    UPDATE kcv_deploy_state SET config_hash=h,model_test_status=''NOT_TESTED'',model_test_hash=NULL,model_test_at=NULL,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    EXECUTE IMMEDIATE ''BEGIN :r:=DBMS_CLOUD_AI.GENERATE(prompt=>''''Reply with the word Ready.'''',profile_name=>:p,action=>''''chat'''');END;'' USING OUT response,c_profile;
    require(response IS NOT NULL AND DBMS_LOB.GETLENGTH(response)>0,c_not_ready,''SETUP_NOT_READY: The model returned an empty test response'');
    require(profile_fingerprint=h,c_conflict,''SETUP_CONFLICT: Model configuration changed during its test'');
    register_profile;
    UPDATE kcv_deploy_state SET model_test_hash=h,model_test_status=''SUC');
 l_sql:=l_sql||TO_CLOB('CEEDED'',model_test_at=SYSTIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
   WHEN ''ENSURE_NETWORK'' THEN
    progress(run,''RUNNING'',''ENSURING_RDF_NETWORK'');
    IF NOT own_table(c_network||''#SEM_MODEL$'') THEN
     SELECT network_tablespace INTO ts FROM kcv_deploy_state WHERE singleton_id=1;
     require(REGEXP_LIKE(ts,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),c_not_ready,''SETUP_NOT_READY: Administrator must verify the prepared tablespace'');
     EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_tablespaces WHERE tablespace_name=:t'' INTO n USING ts;
     require(n=1,c_not_ready,''SETUP_NOT_READY: Prepared RDF ');
 l_sql:=l_sql||TO_CLOB('tablespace is unavailable'');
     runtime_started:=TRUE;
     EXECUTE IMMEDIATE ''BEGIN SEM_APIS.CREATE_RDF_NETWORK(:t,network_owner=>:o,network_name=>:n);END;'' USING ts,$$PLSQL_UNIT_OWNER,c_network;
    END IF;verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    h:=profile_fingerprint;
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before registration'');
    progress(run,''RUNNING'',''REGISTERING_RUNTIME'');runtime_started:=TRUE;register_profile;expected_runtime(TRUE);
   WHEN ''LOAD_DATASET'' THEN
    verify_network;progress(run,''RUNNING'',''LOADING_PUBLIC_COLLECTION'');
    require(REGEXP_LIKE(kcv_deploy_contract.dataset_ref,''^[0-9a-f]{4');
 l_sql:=l_sql||TO_CLOB('0}$'',''c'')
      AND REGEXP_LIKE(kcv_deploy_contract.dataset_manifest_sha256,''^[0-9a-f]{64}$'',''c''),c_not_ready,''SETUP_NOT_READY: The packaged dataset pin is invalid'');
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE ''BEGIN KCV_DATASET.LOAD_GITHUB(p_ref=>:r,p_expected_manifest_sha256=>:h);END;''
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
   WHEN ''ENABLE_LEARNING'' THEN
    progress(run,''RUNNING'',''VERIFYING_READINESS'');required_ready;
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED THEN UPDATE SET setting_value=''OFF'' WHEN NOT MATCHED TH');
 l_sql:=l_sql||TO_CLOB('EN INSERT(setting_key,setting_value) VALUES(s.k,''OFF'')~'';
    UPDATE kcv_deploy_state SET maintenance=''OFF'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  END CASE;
  verify_action(p_operation,p_inputs);progress(run,''SUCCEEDED'',''COMPLETE'');
  lock_result:=DBMS_LOCK.RELEASE(admission);admission_locked:=FALSE;
  lock_result:=DBMS_LOCK.RELEASE(handle);locked:=FALSE;
 EXCEPTION WHEN OTHERS THEN
  err:=SQLCODE;
  IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
  ROLLBACK;
  IF run IS NOT NULL THEN
   IF runtime_started THEN maintenance_on;
   ELSIF maintenance_changed THEN restore_maintenance;END IF;
   IF p_operation=''TEST_MODEL'' AND runtime_started THEN');
 l_sql:=l_sql||TO_CLOB('
    UPDATE kcv_deploy_state SET model_test_status=''FAILED'',model_test_at=SYSTIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   END IF;
   progress(run,''FAILED'',''REVIEW_BEFORE_RETRY'',err);
  END IF;
  IF admission_locked THEN lock_result:=DBMS_LOCK.RELEASE(admission);END IF;
  IF locked THEN lock_result:=DBMS_LOCK.RELEASE(handle);END IF;
  IF run IS NOT NULL THEN
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_FAILED: Review the recorded error code and explicitly retry the step'');
  ELSE RAISE;END IF;
 END;
 PROCEDURE configure_profile(p_credential VARCHAR2,p_region VARCHAR2,p_compartment VARCHAR2,p_model VARCHAR2,p_request_token VARCHAR2) IS
  ident identity_t;j JSON_OBJECT_T:=JSO');
 l_sql:=l_sql||TO_CLOB('N_OBJECT_T();cred VARCHAR2(128);
 BEGIN
  authorize(TRUE,ident);
  require(LENGTH(TRIM(p_credential)) BETWEEN 1 AND 128,c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  cred:=UPPER(TRIM(p_credential));local_credential(cred);
  require(p_region IS NOT NULL AND LENGTH(p_region)<=128 AND REGEXP_LIKE(p_region,''^[a-z][a-z0-9-]+-[0-9]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter an OCI region name'');
  require(p_compartment IS NOT NULL AND LENGTH(p_compartment)<=256 AND REGEXP_LIKE(p_compartment,''^ocid1\.compartment\.[A-Za-z0-9.-]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter a compartment OCID'');
  require(p_model IS NOT NULL AND LENGTH(p_model)<=256 AND REGEXP_LIKE(p_model,');
 l_sql:=l_sql||TO_CLOB('''^[A-Za-z0-9][A-Za-z0-9._-]+$'',''c'')
    AND SUBSTR(p_model,1,6)<>''ocid1.'',c_invalid,''INVALID_SETUP_INPUT: Enter the supported model name, not an endpoint or URL'');
  j.put(''provider'',''oci'');j.put(''credential_name'',cred);j.put(''region'',p_region);j.put(''oci_compartment_id'',p_compartment);j.put(''model'',p_model);
  run_action(''CONFIGURE_PROFILE'',p_request_token,j);
 END;
 PROCEDURE test_model(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);run_action(''TEST_MODEL'',p_request_token,j);
 END;
 PROCEDURE ensure_network(p_request_token VARCHAR2) IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  j.put(''netw');
 l_sql:=l_sql||TO_CLOB('ork'',c_network);run_action(''ENSURE_NETWORK'',p_request_token,j);
 END;
 PROCEDURE register_runtime(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);
  run_action(''REGISTER_RUNTIME'',p_request_token,j);
 END;
 PROCEDURE load_dataset(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''dataset_ref'',kcv_deploy_contract.dataset_ref);j.put(''manifest_sha256'',kcv_deploy_contract.dataset_manifest_sha256);
  run_action(''LOAD_DATASET'',p_request_token,j);
 END;
 PROCEDURE enable_lea');
 l_sql:=l_sql||TO_CLOB('rning(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);run_action(''ENABLE_LEARNING'',p_request_token,j);
 END;
END;');
  EXECUTE IMMEDIATE l_sql;
l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE BODY kcv_deploy AS
 c_profile CONSTANT VARCHAR2(128):=''KCV_GENAI'';
 c_network CONSTANT VARCHAR2(128):=''KCV_NET'';
 c_forbidden CONSTANT PLS_INTEGER:=-20300;
 c_invalid CONSTANT PLS_INTEGER:=-20301;
 c_busy CONSTANT PLS_INTEGER:=-20302;
 c_conflict CONSTANT PLS_INTEGER:=-20303;
 c_failed CONSTANT PLS_INTEGER:=-20304;
 c_not_ready CONSTANT PLS_INTEGER:=-20305;
 TYPE identity_t IS RECORD(workspace_id NUMBER,application_id NUMBER,account_id NUMBER);
 PROCEDURE require(p_ok BOOLEAN,p_code NUMBER,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(p_code,p_message);END IF;
 END;
 FUNCTION digest(p_text CLOB) RETURN VARCHAR2 IS BEGIN
  RETURN LOWER(RAWTOHE');
 l_expected:=l_expected||TO_CLOB('X(DBMS_CRYPTO.HASH(p_text,DBMS_CRYPTO.HASH_SH256)));
 END;
 FUNCTION own_table(p_name VARCHAR2) RETURN BOOLEAN IS n NUMBER;BEGIN
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name=p_name;RETURN n=1;
 END;
 FUNCTION own_name(p_name VARCHAR2) RETURN VARCHAR2 IS BEGIN
  RETURN DBMS_ASSERT.ENQUOTE_NAME($$PLSQL_UNIT_OWNER,FALSE)||''.''||DBMS_ASSERT.ENQUOTE_NAME(p_name,FALSE);
 END;
 PROCEDURE verify_application(p_identity identity_t) IS w VARCHAR2(255);n NUMBER;BEGIN
  SELECT COUNT(*),MAX(workspace) INTO n,w FROM apex_applications
   WHERE application_id=p_identity.application_id AND owner=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Application parsing schema does not ma');
 l_expected:=l_expected||TO_CLOB('tch'');
  require(apex_util.find_security_group_id(p_workspace=>w)=p_identity.workspace_id,
    c_forbidden,''SETUP_FORBIDDEN: Workspace does not match'');
  SELECT COUNT(*) INTO n FROM apex_workspace_schemas
   WHERE workspace_name=w AND schema=$$PLSQL_UNIT_OWNER;
  require(n=1,c_forbidden,''SETUP_FORBIDDEN: Workspace schema mapping does not match'');
 END;
 PROCEDURE native_identity(p_identity OUT identity_t) IS
  u VARCHAR2(255):=SYS_CONTEXT(''APEX$SESSION'',''APP_USER'');
  a VARCHAR2(64):=SYS_CONTEXT(''APEX$SESSION'',''APP_ID'');authenticated BOOLEAN;
 BEGIN
  require(a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'') AND u IS NOT NULL
    AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_USER''),c_forbidden,
 ');
 l_expected:=l_expected||TO_CLOB('   ''SETUP_FORBIDDEN: Sign in to the installed application'');
  authenticated:=apex_authentication.is_authenticated;
  require(authenticated AND a IS NOT NULL AND REGEXP_LIKE(a,''^[0-9]+$'',''c'')
    AND u IS NOT NULL AND UPPER(u) NOT IN(''NOBODY'',''APEX_PUBLIC_USER''),
    c_forbidden,''SETUP_FORBIDDEN: Sign in to the installed application'');
  p_identity.application_id:=TO_NUMBER(a);
  p_identity.workspace_id:=apex_custom_auth.get_security_group_id;
  p_identity.account_id:=apex_util.get_user_id(p_username=>u);
  require(p_identity.workspace_id>0 AND p_identity.account_id>0,c_forbidden,
    ''SETUP_FORBIDDEN: A native workspace account is required'');
  verify_application(p_identity);
 END;
 PROCEDU');
 l_expected:=l_expected||TO_CLOB('RE capture_identity IS ident identity_t;pinned VARCHAR2(128);BEGIN
  native_identity(ident);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
  require(pinned IS NULL OR pinned=TO_CHAR(ident.account_id,''TM9''),c_forbidden,
    ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  IF pinned IS NULL THEN
   apex_util.set_session_state(p_name=>''KCV_AUTH_ACCOUNT_ID'',
     p_value=>TO_CHAR(ident.account_id,''TM9''),p_commit=>FALSE);
  END IF;
 END;
 PROCEDURE authorize(p_installer BOOLEAN,p_identity OUT identity_t) IS
  state kcv_deploy_state%ROWTYPE;roles VARCHAR2(4000);pinned VARCHAR2(128);owner_session BOOLEAN;
 BEGIN
  owner_session:=SYS_CONTEXT(''APEX$SESSIO');
 l_expected:=l_expected||TO_CLOB('N'',''APP_ID'') IS NULL AND SYS_CONTEXT(''APEX$SESSION'',''APP_USER'') IS NULL;
  IF owner_session THEN
   require(SYS_CONTEXT(''USERENV'',''SESSION_USER'')=$$PLSQL_UNIT_OWNER
     AND SYS_CONTEXT(''USERENV'',''CURRENT_SCHEMA'')=$$PLSQL_UNIT_OWNER,c_forbidden,
     ''SETUP_FORBIDDEN: Use an authenticated project owner session'');
  ELSE
   native_identity(p_identity);pinned:=apex_util.get_session_state(''KCV_AUTH_ACCOUNT_ID'');
   require(pinned=TO_CHAR(p_identity.account_id,''TM9''),c_forbidden,
     ''SETUP_FORBIDDEN: Sign out and sign in again to refresh the account identity'');
  END IF;
  BEGIN SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATIO');
 l_expected:=l_expected||TO_CLOB('N_ERROR(c_forbidden,
    ''SETUP_FORBIDDEN: Trusted application installation has not bound this setup'');END;
  IF owner_session THEN
   p_identity.workspace_id:=state.workspace_id;p_identity.application_id:=state.application_id;p_identity.account_id:=0;
   verify_application(p_identity);
  END IF;
  require(state.schema_owner=$$PLSQL_UNIT_OWNER AND state.workspace_id=p_identity.workspace_id
    AND state.application_id=p_identity.application_id,c_forbidden,
    ''SETUP_FORBIDDEN: This application is not the bound installation'');
  IF p_installer AND NOT owner_session THEN
   roles:=apex_util.get_user_roles(p_username=>SYS_CONTEXT(''APEX$SESSION'',''APP_USER''));
   require(INSTR('':''||UPPER(roles)|');
 l_expected:=l_expected||TO_CLOB('|'':'','':ADMIN:'')>0,c_forbidden,
     ''SETUP_FORBIDDEN: A workspace administrator must complete setup'');
  END IF;
 END;
 FUNCTION is_installer RETURN BOOLEAN IS ident identity_t;BEGIN
  authorize(TRUE,ident);RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;
 FUNCTION attribute_text(p_value CLOB) RETURN VARCHAR2 IS j JSON_OBJECT_T;s VARCHAR2(4000);BEGIN
  require(p_value IS NOT NULL AND DBMS_LOB.GETLENGTH(p_value)<=4000,c_not_ready,
    ''SETUP_NOT_READY: Profile metadata is unavailable'');
  s:=TRIM(DBMS_LOB.SUBSTR(p_value,4000,1));
  IF SUBSTR(s,1,1)=''"'' THEN j:=JSON_OBJECT_T.parse(''{"v":''||s||''}'');RETURN j.get_string(''v'');END IF;
  RETURN s;
 END;
 FUNCTION profile_attribute(p_name V');
 l_expected:=l_expected||TO_CLOB('ARCHAR2) RETURN VARCHAR2 IS value CLOB;BEGIN
  EXECUTE IMMEDIATE ''SELECT attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p AND attribute_name=:a'' INTO value USING c_profile,p_name;
  RETURN attribute_text(value);
 EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;END;
 PROCEDURE local_credential(p_name VARCHAR2) IS n NUMBER;BEGIN
  require(p_name IS NOT NULL AND REGEXP_LIKE(p_name,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),
    c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_credentials WHERE credential_name=:c'' INTO n USING p_name;
  require(n=1,c_invalid,''INVALID_SETUP_INPUT: The selected credential is ');
 l_expected:=l_expected||TO_CLOB('not local to this schema'');
 END;
 FUNCTION profile_fingerprint RETURN VARCHAR2 IS
  material CLOB:=TO_CLOB('''');v CLOB;name VARCHAR2(128);cursor_id SYS_REFCURSOR;n NUMBER;
 BEGIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name=:p AND status=''''ENABLED''''''
    INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Configure an enabled model profile'');
  require(profile_attribute(''provider'')=''oci'',c_not_ready,''SETUP_NOT_READY: The profile must use the prepared OCI provider'');
  local_credential(profile_attribute(''credential_name''));
  require(profile_attribute(''region'') IS NOT NULL AND profile_attribute(''model'') IS NOT NULL
    AND profile_attribu');
 l_expected:=l_expected||TO_CLOB('te(''oci_compartment_id'') IS NOT NULL,c_not_ready,''SETUP_NOT_READY: Model profile configuration is incomplete'');
  OPEN cursor_id FOR ''SELECT attribute_name,attribute_value FROM user_cloud_ai_profile_attributes ''
    ||''WHERE profile_name=:p ORDER BY attribute_name'' USING c_profile;
  LOOP FETCH cursor_id INTO name,v;EXIT WHEN cursor_id%NOTFOUND;
   material:=material||LENGTH(name)||'':''||name||'':''||DBMS_LOB.GETLENGTH(v)||'':''||v||CHR(10);
  END LOOP;CLOSE cursor_id;
  RETURN digest(material);
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;
 FUNCTION credential_options RETURN CLOB IS
  ident identity_t;items JSON_ARRAY_T:=JSON_ARRAY_T();name VARCHAR2(128);');
 l_expected:=l_expected||TO_CLOB('cursor_id SYS_REFCURSOR;
 BEGIN
  authorize(TRUE,ident);
  OPEN cursor_id FOR ''SELECT credential_name FROM user_credentials ORDER BY credential_name'';
  LOOP FETCH cursor_id INTO name;EXIT WHEN cursor_id%NOTFOUND;items.append(name);END LOOP;
  CLOSE cursor_id;RETURN items.to_clob();
 EXCEPTION WHEN OTHERS THEN IF cursor_id%ISOPEN THEN CLOSE cursor_id;END IF;RAISE;END;
 PROCEDURE verify_network IS n NUMBER;BEGIN
  require(own_table(c_network||''#SEM_MODEL$''),c_not_ready,''SETUP_NOT_READY: Create the owner RDF network'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||own_name(c_network||''#SEM_MODEL$'')||'' WHERE owner<>:o''
    INTO n USING $$PLSQL_UNIT_OWNER;
  require(n=0,c_not_ready,''SETUP_NOT_REA');
 l_expected:=l_expected||TO_CLOB('DY: RDF network ownership requires administrator review'');
 END;
 FUNCTION runtime_instruction(p_grounded BOOLEAN) RETURN CLOB IS result CLOB;BEGIN
  IF p_grounded THEN EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.grounded_instruction;END;'' USING OUT result;
  ELSE EXECUTE IMMEDIATE ''BEGIN :v:=kcv_scenario.qa_instruction;END;'' USING OUT result;END IF;
  RETURN result;
 END;
 PROCEDURE expected_runtime(p_create BOOLEAN) IS
  task JSON_OBJECT_T;instruction CLOB;n NUMBER;
  PROCEDURE object_ready(p_type VARCHAR2,p_name VARCHAR2,p_attributes CLOB,p_description VARCHAR2 DEFAULT NULL) IS
   base_view VARCHAR2(128);attr_view VARCHAR2(128);name_column VARCHAR2(128);attr_name_column VARCHAR2(128);
   ex');
 l_expected:=l_expected||TO_CLOB('pected JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_attributes);keys JSON_KEY_LIST:=expected.get_keys;
   wanted JSON_ELEMENT_T;actual CLOB;wanted_json CLOB;n NUMBER;equal_value NUMBER;s VARCHAR2(32767);
  BEGIN
   CASE p_type
    WHEN ''tool'' THEN base_view:=''USER_AI_AGENT_TOOLS'';attr_view:=''USER_AI_AGENT_TOOL_ATTRIBUTES'';name_column:=''TOOL_NAME'';attr_name_column:=''TOOL_NAME'';
    WHEN ''task'' THEN base_view:=''USER_AI_AGENT_TASKS'';attr_view:=''USER_AI_AGENT_TASK_ATTRIBUTES'';name_column:=''TASK_NAME'';attr_name_column:=''TASK_NAME'';
    WHEN ''agent'' THEN base_view:=''USER_AI_AGENTS'';attr_view:=''USER_AI_AGENT_ATTRIBUTES'';name_column:=''AGENT_NAME'';attr_name_column:=''AGENT_NAME'';
    WHEN ''team'' THEN base_vie');
 l_expected:=l_expected||TO_CLOB('w:=''USER_AI_AGENT_TEAMS'';attr_view:=''USER_AI_AGENT_TEAM_ATTRIBUTES'';name_column:=''AGENT_TEAM_NAME'';attr_name_column:=''TEAM_NAME'';
    ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported runtime object'');
   END CASE;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n'' INTO n USING p_name;
   IF n=0 AND p_create THEN
    CASE p_type
     WHEN ''tool'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TOOL(tool_name=>:n,description=>:d,attributes=>:a);END;'' USING p_name,p_description,p_attributes;
     WHEN ''task'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TASK(task_name=>:n,attributes=>:a);END;'' USING p_name,p_attribut');
 l_expected:=l_expected||TO_CLOB('es;
     WHEN ''agent'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_AGENT(agent_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
     WHEN ''team'' THEN EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI_AGENT.CREATE_TEAM(team_name=>:n,attributes=>:a);END;'' USING p_name,p_attributes;
    END CASE;
   END IF;
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM ''||base_view||'' WHERE ''||name_column||''=:n AND status=''''ENABLED'''''' INTO n USING p_name;
   require(n=1,c_not_ready,''SETUP_NOT_READY: A required runtime object is missing or disabled'');
   FOR i IN 1..keys.COUNT LOOP
    BEGIN EXECUTE IMMEDIATE ''SELECT attribute_value FROM ''||attr_view||'' WHERE ''||attr_name_column
      ||''=:n AND attribute');
 l_expected:=l_expected||TO_CLOB('_name=:a'' INTO actual USING p_name,keys(i);
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(c_conflict,''SETUP_CONFLICT: Existing runtime attributes require administrator review'');END;
    wanted:=expected.get(keys(i));
    IF wanted.is_string THEN
     s:=expected.get_string(keys(i));
     require(DBMS_LOB.GETLENGTH(actual)<=32767,c_conflict,''SETUP_CONFLICT: Unexpected runtime attribute size'');
     IF SUBSTR(TRIM(DBMS_LOB.SUBSTR(actual,32767,1)),1,1)=''"'' THEN
      wanted_json:=wanted.to_clob();
      EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
        INTO equal_value USING actual,wanted_json;
     ELSE equal_value:=CASE WHEN DBMS_');
 l_expected:=l_expected||TO_CLOB('LOB.COMPARE(actual,TO_CLOB(s))=0 THEN 1 ELSE 0 END;END IF;
    ELSE
     wanted_json:=wanted.to_clob();
     EXECUTE IMMEDIATE ''SELECT CASE WHEN JSON_EQUAL(:a,:b) THEN 1 ELSE 0 END FROM dual''
       INTO equal_value USING actual,wanted_json;
    END IF;
    require(equal_value=1,c_conflict,''SETUP_CONFLICT: Existing runtime attributes differ; no object was replaced'');
   END LOOP;
  END;
  FUNCTION agent_attributes(p_role VARCHAR2,p_supervisor BOOLEAN DEFAULT FALSE) RETURN CLOB IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
   j.put(''profile_name'',c_profile);j.put(''role'',p_role);j.put(''enable_human_tool'',FALSE);
   IF p_supervisor THEN j.put(''supervisor'',TRUE);END IF;RETURN j.to_clob();
  END;
 BE');
 l_expected:=l_expected||TO_CLOB('GIN
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''' AND setting_value=:p'' INTO n USING c_profile;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_objects WHERE object_name IN ''
    ||''(''''KCV_SCENARIO_EVIDENCE'''',''''KCV_SCENARIO_PROPOSE'''') AND object_type=''''FUNCTION'''' AND status=''''VALID'''''' INTO n;
  require(n=2,c_not_ready,''SETUP_NOT_READY: Verify schema runtime functions first'');
  object_ready(''tool'',''KCV_SCENARIO_EVIDENCE'',
    ''{"function":"KCV_SCENARIO_EVIDENCE","instruction":"Pass the original request JSON unchanged.","tool_inputs":[{"name":"p_request","mandatory":true,');
 l_expected:=l_expected||TO_CLOB('"description":"Full request JSON including scenario_session and question"}]}'',
    ''Read public evidence and actual topic graph paths for the current scenario'');
  object_ready(''tool'',''KCV_SCENARIO_PROPOSE'',
    ''{"function":"KCV_SCENARIO_PROPOSE","instruction":"Pass the original request JSON unchanged. This tool cannot apply changes.","tool_inputs":[{"name":"p_request","mandatory":true,"description":"Full request JSON including scenario_session and question"}]}'',
    ''Propose one context edit; never applies a change'');
  task:=JSON_OBJECT_T.parse(''{"tools":["KCV_SCENARIO_EVIDENCE"],"enable_human_tool":false}'');
  instruction:=runtime_instruction(FALSE);task.put(''instruction'',instruction);
 ');
 l_expected:=l_expected||TO_CLOB(' object_ready(''task'',''KCV_SCENARIO_QA_TASK'',task.to_clob());
  task:=JSON_OBJECT_T.parse(''{"tools":[],"enable_human_tool":false}'');
  instruction:=runtime_instruction(TRUE);task.put(''instruction'',instruction);
  object_ready(''task'',''KCV_GROUNDED_QA_TASK'',task.to_clob());
  object_ready(''task'',''KCV_SCENARIO_CHANGE_TASK'',q''~{"instruction":"For {query}, call KCV_SCENARIO_PROPOSE once with the original JSON. Return its proposed_plan JSON unchanged, including any clarification message. State that no change has been applied. The user must inspect and submit a structured refinement outside the agent. Never call another tool, invent a confirmation or claim success.","tools":["KCV_SCENARIO_PROPOSE"],');
 l_expected:=l_expected||TO_CLOB('"enable_human_tool":false}~'');
  object_ready(''agent'',''KCV_SCENARIO_QA'',agent_attributes(''Explain contextual relevance from public evidence and actual graph paths. Read only.''));
  object_ready(''agent'',''KCV_SCENARIO_PLANNER'',agent_attributes(''Propose one allowed context change. Never apply or confirm changes.''));
  object_ready(''agent'',''KCV_SCENARIO_ROUTER'',agent_attributes(''Route task question to KCV_SCENARIO_QA and task propose_change to KCV_SCENARIO_PLANNER. Pass the full request unchanged to exactly one worker and return its result.'',TRUE));
  object_ready(''team'',''KCV_EXPLORER_TEAM'',''{"supervisor_agent":"KCV_SCENARIO_ROUTER","process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","tas');
 l_expected:=l_expected||TO_CLOB('k":"KCV_SCENARIO_QA_TASK"},{"name":"KCV_SCENARIO_PLANNER","task":"KCV_SCENARIO_CHANGE_TASK"}]}'');
  object_ready(''team'',''KCV_EVIDENCE_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_SCENARIO_QA_TASK"}]}'');
  object_ready(''team'',''KCV_GROUNDED_TEAM'',''{"process":"sequential","agents":[{"name":"KCV_SCENARIO_QA","task":"KCV_GROUNDED_QA_TASK"}]}'');
 END;
 PROCEDURE dataset_state(p_sources OUT NUMBER,p_passages OUT NUMBER,p_contexts OUT NUMBER) IS g VARCHAR2(128);n NUMBER;BEGIN
  verify_network;
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''ACTIVE_GRAPH'''''' INTO g;
  require(REGEXP_LIKE(g,''^KCV_G_[A-F0-9]+$'',''c''),c_not_ready,''SETUP_NOT');
 l_expected:=l_expected||TO_CLOB('_READY: Collection graph is unavailable'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_runs g WHERE g.graph_name=:g AND g.state=''''READY'''' ''
    ||''AND EXISTS(SELECT 1 FROM kcv_dataset_runs d WHERE d.graph_name=g.graph_name AND d.status=''''SUCCEEDED'''')'' INTO n USING g;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Collection needs a completed verified import'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_sources WHERE graph_name=:g'' INTO p_sources USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_passages p JOIN kcv_graph_sources s ON p.version_id=s.version_id WHERE s.graph_name=:g'' INTO p_passages USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_graph_contexts WHERE g');
 l_expected:=l_expected||TO_CLOB('raph_name=:g'' INTO p_contexts USING g;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM TABLE(SEM_MATCH(''''SELECT ?s ?p ?o WHERE { ?s ?p ?o }'''',SEM_MODELS(''
    ||DBMS_ASSERT.ENQUOTE_LITERAL(g)||''),NULL,NULL,NULL,NULL,NULL,NULL,NULL,''
    ||DBMS_ASSERT.ENQUOTE_LITERAL($$PLSQL_UNIT_OWNER)||'',''''KCV_NET''''))'' INTO n;
  require(p_sources>0 AND p_passages>0 AND p_contexts>0 AND n>0,c_not_ready,''SETUP_NOT_READY: Collection evidence or graph is empty'');
 END;
 PROCEDURE verify_schema_ready IS n NUMBER;checkpoint VARCHAR2(128);version VARCHAR2(20);BEGIN
  kcv_deploy_contract.verify_schema;
  checkpoint:=kcv_deploy_contract.target_checkpoint;version:=kcv_deploy_contract.target_version;
  EXECUTE IMMEDIATE ''SE');
 l_expected:=l_expected||TO_CLOB('LECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND product_version=:v AND phase=''''COMPLETE'''''' INTO n USING checkpoint,version;
  require(n=1,c_not_ready,''SETUP_NOT_READY: Complete the final ordered installation checkpoint'');
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_schema_migrations WHERE migration_id=:m ''
    ||''AND phase IN(''''FAILED'''',''''RUNNING'''')'' INTO n USING checkpoint;
  require(n=0,c_not_ready,''SETUP_NOT_READY: Recover the incomplete installation checkpoint'');
 END;
 PROCEDURE required_ready IS state kcv_deploy_state%ROWTYPE;hash_value VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;registered VARCHAR2(128);BEGIN
  verify_schema_ready;verify_network;hash_value:=p');
 l_expected:=l_expected||TO_CLOB('rofile_fingerprint;
  SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  require(state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=hash_value,c_not_ready,
    ''SETUP_NOT_READY: Explicitly test the current model configuration'');
  EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''AI_PROFILE'''''' INTO registered;
  require(registered=c_profile,c_not_ready,''SETUP_NOT_READY: Register the current model profile'');
  expected_runtime(FALSE);dataset_state(a,b,c);
 END;
 FUNCTION learner_ready RETURN BOOLEAN IS ident identity_t;m VARCHAR2(3);n NUMBER;BEGIN
  authorize(FALSE,ident);SELECT maintenance INTO m FROM kcv_deploy_state WHERE singleton_id=1');
 l_expected:=l_expected||TO_CLOB(';
  IF m<>''OFF'' THEN RETURN FALSE;END IF;
  SELECT COUNT(*) INTO n FROM kcv_deploy_runs WHERE status=''RUNNING'';IF n<>0 THEN RETURN FALSE;END IF;
  EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
  IF n<>0 THEN RETURN FALSE;END IF;required_ready;RETURN TRUE;
 EXCEPTION WHEN OTHERS THEN RETURN FALSE;END;
 FUNCTION status_json RETURN CLOB IS
  ident identity_t;result JSON_OBJECT_T:=JSON_OBJECT_T();steps JSON_ARRAY_T:=JSON_ARRAY_T();
  item JSON_OBJECT_T;state kcv_deploy_state%ROWTYPE;h VARCHAR2(64);a NUMBER;b NUMBER;c NUMBER;n NUMBER;
  rows_json JSON_ARRAY_T:=JSON_ARRAY_T();search JSON_OBJECT_T:=JSON_OBJECT_T()');
 l_expected:=l_expected||TO_CLOB(';counts JSON_OBJECT_T:=JSON_OBJECT_T();
  all_ready BOOLEAN:=TRUE;code NUMBER;phase VARCHAR2(128);run_state VARCHAR2(16);
  PROCEDURE append_step(p_id VARCHAR2,p_ok BOOLEAN,p_error NUMBER,p_action VARCHAR2) IS BEGIN
   item:=JSON_OBJECT_T();item.put(''id'',p_id);item.put(''status'',CASE WHEN p_ok THEN ''READY'' ELSE ''PENDING'' END);
   IF p_error IS NOT NULL THEN item.put(''error_code'',p_error);END IF;
   IF NOT p_ok THEN item.put(''next_action'',p_action);all_ready:=FALSE;END IF;steps.append(item);
  END;
 BEGIN
  authorize(TRUE,ident);SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
  result.put(''target_version'',kcv_deploy_contract.target_version);result.put(''target_checkpoint'',kcv_de');
 l_expected:=l_expected||TO_CLOB('ploy_contract.target_checkpoint);
  result.put(''maintenance'',state.maintenance=''ON'');
  BEGIN verify_schema_ready;append_step(''schema'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''schema'',FALSE,SQLCODE,''Finish or recover the matching Supporting Objects installation'');END;
  BEGIN verify_network;append_step(''network'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''network'',FALSE,SQLCODE,''Create or verify the owner RDF network'');END;
  BEGIN h:=profile_fingerprint;append_step(''profile'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN h:=NULL;append_step(''profile'',FALSE,SQLCODE,''Select an administrator-prepared local credential and configure model access'');END;
  append_st');
 l_expected:=l_expected||TO_CLOB('ep(''model_test'',h IS NOT NULL AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
    NULL,''Explicitly test the current model configuration'');
  BEGIN expected_runtime(FALSE);append_step(''runtime'',TRUE,NULL,NULL);
  EXCEPTION WHEN OTHERS THEN append_step(''runtime'',FALSE,SQLCODE,''Register the current scenario and grounded-answer runtime'');END;
  BEGIN dataset_state(a,b,c);append_step(''dataset'',TRUE,NULL,NULL);counts.put(''sources'',a);counts.put(''passages'',b);counts.put(''contexts'',c);result.put(''collection_counts'',counts);
  EXCEPTION WHEN OTHERS THEN append_step(''dataset'',FALSE,SQLCODE,''Load the approved pinned public collection or recover its failed import'');END;
  BEGIN
   E');
 l_expected:=l_expected||TO_CLOB('XECUTE IMMEDIATE ''SELECT status,phase FROM kcv_dataset_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 1 ROW ONLY'' INTO run_state,phase;
   item:=JSON_OBJECT_T();item.put(''status'',run_state);item.put(''phase'',phase);result.put(''dataset_progress'',item);
  EXCEPTION WHEN NO_DATA_FOUND THEN NULL;WHEN OTHERS THEN NULL;END;
  search.put(''optional'',TRUE);search.put(''mode'',''KEYWORD'');
  BEGIN EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_mining_models WHERE model_name=''''KCV_CONTEXT_MINILM'''''' INTO n;
   IF n=1 THEN search.put(''mode'',''MODEL_INSTALLED'');END IF;
  EXCEPTION WHEN OTHERS THEN NULL;END;
  search.put(''notice'',''Without the optional local embedding model, My Contexts uses keyword search.');
 l_expected:=l_expected||TO_CLOB(' The facilitator installs and verifies semantic search separately.'');
  result.put(''context_search'',search);result.put(''steps'',steps);
  FOR r IN(SELECT run_id,operation,status,phase,error_code FROM kcv_deploy_runs ORDER BY started_at DESC,run_id DESC FETCH FIRST 20 ROWS ONLY) LOOP
   item:=JSON_OBJECT_T();item.put(''run_id'',r.run_id);item.put(''operation'',r.operation);item.put(''status'',r.status);item.put(''phase'',r.phase);
   IF r.error_code IS NOT NULL THEN item.put(''error_code'',r.error_code);END IF;
   IF r.status IN(''FAILED'',''INTERRUPTED'') THEN item.put(''next_action'',''Review this step, then explicitly retry with a new request token'');END IF;
   rows_json.append(item);
  END LOOP;
  result.p');
 l_expected:=l_expected||TO_CLOB('ut(''runs'',rows_json);result.put(''required_checks_ready'',all_ready);
  result.put(''ready_for_learners'',learner_ready);RETURN result.to_clob();
 END;
 PROCEDURE lock_handle(p_handle OUT VARCHAR2) IS PRAGMA AUTONOMOUS_TRANSACTION;BEGIN
  DBMS_LOCK.ALLOCATE_UNIQUE(''KCV_DEPLOY_''||$$PLSQL_UNIT_OWNER,p_handle);COMMIT;
 END;
 PROCEDURE progress(p_run VARCHAR2,p_status VARCHAR2,p_phase VARCHAR2,p_error NUMBER DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
  UPDATE kcv_deploy_runs SET status=p_status,phase=p_phase,error_code=p_error,updated_at=SYSTIMESTAMP,
   completed_at=CASE WHEN p_status IN(''SUCCEEDED'',''FAILED'',''INTERRUPTED'') THEN SYSTIMESTAMP ELSE NULL END WHERE run_id=p_run;
  COMMIT;
');
 l_expected:=l_expected||TO_CLOB(' END;
 PROCEDURE maintenance_on IS BEGIN
  UPDATE kcv_deploy_state SET maintenance=''ON'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  IF own_table(''KCV_SETTINGS'') THEN
   EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
    WHEN MATCHED THEN UPDATE SET setting_value=''ON'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''ON'')~'';COMMIT;
  END IF;
 END;
 PROCEDURE no_active_work IS n NUMBER;BEGIN
  IF own_table(''KCV_CHAT_SESSIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_chat_sessions WHERE mutation_token IS NOT NULL'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the active a');
 l_expected:=l_expected||TO_CLOB('nswer or refinement'');
  END IF;
  IF own_table(''KCV_RESPONSE_RUNS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_response_runs WHERE status IN(''''RUNNING'''',''''UNCERTAIN'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Wait for the active answer or complete its supported recovery'');
  END IF;
  IF own_table(''KCV_PERSONAL_OPERATIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_personal_operations WHERE phase IN(''''BUILDING'''',''''READY'''')'' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the active personal-context operation'');
  END IF;
  IF own_table(''KCV_CONTEXT_DELETIONS'') THEN
   EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_context_deletions WHERE status=''''PENDING''''''');
 l_expected:=l_expected||TO_CLOB(' INTO n;
   require(n=0,c_busy,''SETUP_BUSY: Complete or recover the pending context deletion'');
  END IF;
 END;
 PROCEDURE register_profile IS BEGIN
  EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''AI_PROFILE'' k FROM dual)s ON(t.setting_key=s.k)
   WHEN MATCHED THEN UPDATE SET setting_value=''KCV_GENAI'' WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,''KCV_GENAI'')~'';COMMIT;
 END;
 PROCEDURE verify_action(p_operation VARCHAR2,p_inputs JSON_OBJECT_T) IS h VARCHAR2(64);n NUMBER;a NUMBER;b NUMBER;c NUMBER;state kcv_deploy_state%ROWTYPE;BEGIN
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    h:=profile_fingerprint;
    require(profile_attribute(''credential_nam');
 l_expected:=l_expected||TO_CLOB('e'')=p_inputs.get_string(''credential_name'') AND profile_attribute(''region'')=p_inputs.get_string(''region'')
      AND profile_attribute(''model'')=p_inputs.get_string(''model'') AND profile_attribute(''oci_compartment_id'')=p_inputs.get_string(''oci_compartment_id''),
      c_conflict,''SETUP_CONFLICT: Profile changed after this request; use a new request token'');
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(h=p_inputs.get_string(''profile_hash'') AND state.model_test_status=''SUCCEEDED'' AND state.model_test_hash=h,
      c_not_ready,''SETUP_NOT_READY: This model test no longer matches the current configuration'');
   WHEN ''E');
 l_expected:=l_expected||TO_CLOB('NSURE_NETWORK'' THEN verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    require(profile_fingerprint=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed after this request'');
    expected_runtime(FALSE);
   WHEN ''LOAD_DATASET'' THEN
    dataset_state(a,b,c);
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_dataset_runs r JOIN kcv_settings s ON s.setting_key=''''ACTIVE_GRAPH'''' AND s.setting_value=r.graph_name ''
      ||''WHERE r.status=''''SUCCEEDED'''' AND r.source_ref=:ref AND r.manifest_sha256=:hash'' INTO n
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
    require(n>0,c_not_ready,''SETUP_NOT_READY: The active colle');
 l_expected:=l_expected||TO_CLOB('ction differs from this load request'');
   WHEN ''ENABLE_LEARNING'' THEN
    required_ready;
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    require(state.maintenance=''OFF'',c_not_ready,''SETUP_NOT_READY: Setup maintenance is still active'');
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''' AND UPPER(setting_value)=''''ON'''''' INTO n;
    require(n=0,c_not_ready,''SETUP_NOT_READY: Application maintenance is still active'');
   ELSE RAISE_APPLICATION_ERROR(c_invalid,''INVALID_SETUP_INPUT: Unsupported setup operation'');
  END CASE;
 END;
 PROCEDURE run_action(p_operation VARCHAR2,p_token VARCHAR2,p_inputs JSON_OBJECT_T) IS
  ident ident');
 l_expected:=l_expected||TO_CLOB('ity_t;handle VARCHAR2(128);lock_result PLS_INTEGER;locked BOOLEAN:=FALSE;run VARCHAR2(32);
  input_hash VARCHAR2(64);old kcv_deploy_runs%ROWTYPE;state kcv_deploy_state%ROWTYPE;
  attrs CLOB;h VARCHAR2(64);existing_h VARCHAR2(64);n NUMBER;err NUMBER;response CLOB;ts VARCHAR2(128);found BOOLEAN:=TRUE;
  maintenance_changed BOOLEAN:=FALSE;runtime_started BOOLEAN:=FALSE;
  admission PLS_INTEGER;admission_locked BOOLEAN:=FALSE;
  prior_maintenance VARCHAR2(3);prior_updated TIMESTAMP WITH TIME ZONE;
  prior_legacy_exists BOOLEAN:=FALSE;prior_legacy_value VARCHAR2(4000);
  PROCEDURE snapshot_maintenance IS BEGIN
   SELECT maintenance,updated_at INTO prior_maintenance,prior_updated FROM kcv_deploy_s');
 l_expected:=l_expected||TO_CLOB('tate WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    BEGIN EXECUTE IMMEDIATE ''SELECT setting_value FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE''''''
      INTO prior_legacy_value;prior_legacy_exists:=TRUE;
    EXCEPTION WHEN NO_DATA_FOUND THEN prior_legacy_exists:=FALSE;END;
   END IF;
  END;
  PROCEDURE restore_maintenance IS BEGIN
   UPDATE kcv_deploy_state SET maintenance=prior_maintenance,updated_at=prior_updated WHERE singleton_id=1;
   IF own_table(''KCV_SETTINGS'') THEN
    IF prior_legacy_exists THEN
     EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k,:v v FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED THEN UPDATE SET setting');
 l_expected:=l_expected||TO_CLOB('_value=s.v WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,s.v)~''
      USING prior_legacy_value;
    ELSE EXECUTE IMMEDIATE ''DELETE FROM kcv_settings WHERE setting_key=''''APP_MAINTENANCE'''''';END IF;
   END IF;COMMIT;
  END;
 BEGIN
  authorize(TRUE,ident);
  require(p_token IS NOT NULL AND REGEXP_LIKE(p_token,''^[A-Za-z0-9_-]{16,80}$'',''c''),c_invalid,
    ''INVALID_SETUP_INPUT: Use a new bounded request token for an explicit action'');
  input_hash:=digest(TO_CLOB(p_operation)||'':''||p_inputs.to_clob());
  lock_handle(handle);lock_result:=DBMS_LOCK.REQUEST(handle,DBMS_LOCK.X_MODE,0,FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: Another setup operation is active'');locked:=TRU');
 l_expected:=l_expected||TO_CLOB('E;
  authorize(TRUE,ident);
  BEGIN
   SELECT * INTO old FROM kcv_deploy_runs WHERE request_token=p_token;
  EXCEPTION WHEN NO_DATA_FOUND THEN found:=FALSE;END;
  IF found THEN
   require(old.input_hash=input_hash AND old.operation=p_operation AND old.account_id=ident.account_id
     AND old.application_id=ident.application_id AND old.workspace_id=ident.workspace_id,c_conflict,
     ''SETUP_CONFLICT: Request token belongs to different inputs or an account'');
   IF old.status=''SUCCEEDED'' THEN
    verify_action(p_operation,p_inputs);lock_result:=DBMS_LOCK.RELEASE(handle);RETURN;
   END IF;
   IF old.status=''RUNNING'' THEN progress(old.run_id,''INTERRUPTED'',''REVIEW_BEFORE_RETRY'',old.error_code);EN');
 l_expected:=l_expected||TO_CLOB('D IF;
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_PREVIOUS_FAILURE: Review the recorded step and explicitly retry with a new token'');
  END IF;
  UPDATE kcv_deploy_runs SET status=''INTERRUPTED'',phase=''REVIEW_BEFORE_RETRY'',updated_at=SYSTIMESTAMP,
    completed_at=SYSTIMESTAMP WHERE status=''RUNNING'';COMMIT;
  run:=RAWTOHEX(SYS_GUID());
  INSERT INTO kcv_deploy_runs(run_id,request_token,operation,input_hash,workspace_id,application_id,account_id,status,phase)
    VALUES(run,p_token,p_operation,input_hash,ident.workspace_id,ident.application_id,ident.account_id,''RUNNING'',''CHECKING_PREREQUISITES'');COMMIT;
  verify_schema_ready;
  admission:=DBMS_UTILITY.GET_HASH_VALUE(''KCV_WRITE_ADMISSION:''||$$PL');
 l_expected:=l_expected||TO_CLOB('SQL_UNIT_OWNER,1,1073741823);
  lock_result:=DBMS_LOCK.REQUEST(id=>admission,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>FALSE);
  require(lock_result=0,c_busy,''SETUP_BUSY: A write is being admitted; retry after its transaction completes'');admission_locked:=TRUE;
  no_active_work;snapshot_maintenance;
  IF p_operation<>''ENABLE_LEARNING'' THEN maintenance_changed:=TRUE;maintenance_on;END IF;
  no_active_work;
  CASE p_operation
   WHEN ''CONFIGURE_PROFILE'' THEN
    progress(run,''RUNNING'',''CONFIGURING_PROFILE'');
    SELECT * INTO state FROM kcv_deploy_state WHERE singleton_id=1;
    EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_cloud_ai_profiles WHERE profile_name=:p'' INTO n USING c_');
 l_expected:=l_expected||TO_CLOB('profile;
    attrs:=p_inputs.to_clob();
    IF n=0 THEN runtime_started:=TRUE;EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.CREATE_PROFILE(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
    ELSE
     existing_h:=profile_fingerprint;
     IF profile_attribute(''credential_name'')<>p_inputs.get_string(''credential_name'') OR profile_attribute(''region'')<>p_inputs.get_string(''region'')
       OR profile_attribute(''model'')<>p_inputs.get_string(''model'') OR profile_attribute(''oci_compartment_id'')<>p_inputs.get_string(''oci_compartment_id'') THEN
      require(state.config_hash=existing_h,c_conflict,''SETUP_CONFLICT: Existing profile was not configured here or has changed; ask the owner to review it');
 l_expected:=l_expected||TO_CLOB(''');
      runtime_started:=TRUE;
      EXECUTE IMMEDIATE ''BEGIN DBMS_CLOUD_AI.SET_ATTRIBUTES(profile_name=>:p,attributes=>:a);END;'' USING c_profile,attrs;
     END IF;
    END IF;
    h:=profile_fingerprint;runtime_started:=TRUE;register_profile;
    UPDATE kcv_deploy_state SET config_hash=h,model_test_status=CASE WHEN model_test_hash=h THEN model_test_status ELSE ''NOT_TESTED'' END,
      updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   WHEN ''TEST_MODEL'' THEN
    h:=profile_fingerprint;progress(run,''RUNNING'',''TESTING_MODEL'');
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before its test'');
    runtime_started:=TRUE;
    UP');
 l_expected:=l_expected||TO_CLOB('DATE kcv_deploy_state SET config_hash=h,model_test_status=''NOT_TESTED'',model_test_hash=NULL,model_test_at=NULL,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    EXECUTE IMMEDIATE ''BEGIN :r:=DBMS_CLOUD_AI.GENERATE(prompt=>''''Reply with the word Ready.'''',profile_name=>:p,action=>''''chat'''');END;'' USING OUT response,c_profile;
    require(response IS NOT NULL AND DBMS_LOB.GETLENGTH(response)>0,c_not_ready,''SETUP_NOT_READY: The model returned an empty test response'');
    require(profile_fingerprint=h,c_conflict,''SETUP_CONFLICT: Model configuration changed during its test'');
    register_profile;
    UPDATE kcv_deploy_state SET model_test_hash=h,model_test_status=''SUCCEEDED'',model_test_at=SY');
 l_expected:=l_expected||TO_CLOB('STIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
    IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
   WHEN ''ENSURE_NETWORK'' THEN
    progress(run,''RUNNING'',''ENSURING_RDF_NETWORK'');
    IF NOT own_table(c_network||''#SEM_MODEL$'') THEN
     SELECT network_tablespace INTO ts FROM kcv_deploy_state WHERE singleton_id=1;
     require(REGEXP_LIKE(ts,''^[A-Z][A-Z0-9_$#]{0,127}$'',''c''),c_not_ready,''SETUP_NOT_READY: Administrator must verify the prepared tablespace'');
     EXECUTE IMMEDIATE ''SELECT COUNT(*) FROM user_tablespaces WHERE tablespace_name=:t'' INTO n USING ts;
     require(n=1,c_not_ready,''SETUP_NOT_READY: Prepared RDF tablespace is unavailabl');
 l_expected:=l_expected||TO_CLOB('e'');
     runtime_started:=TRUE;
     EXECUTE IMMEDIATE ''BEGIN SEM_APIS.CREATE_RDF_NETWORK(:t,network_owner=>:o,network_name=>:n);END;'' USING ts,$$PLSQL_UNIT_OWNER,c_network;
    END IF;verify_network;
   WHEN ''REGISTER_RUNTIME'' THEN
    h:=profile_fingerprint;
    require(h=p_inputs.get_string(''profile_hash''),c_conflict,''SETUP_CONFLICT: The model configuration changed before registration'');
    progress(run,''RUNNING'',''REGISTERING_RUNTIME'');runtime_started:=TRUE;register_profile;expected_runtime(TRUE);
   WHEN ''LOAD_DATASET'' THEN
    verify_network;progress(run,''RUNNING'',''LOADING_PUBLIC_COLLECTION'');
    require(REGEXP_LIKE(kcv_deploy_contract.dataset_ref,''^[0-9a-f]{40}$'',''c'')
      AND REGE');
 l_expected:=l_expected||TO_CLOB('XP_LIKE(kcv_deploy_contract.dataset_manifest_sha256,''^[0-9a-f]{64}$'',''c''),c_not_ready,''SETUP_NOT_READY: The packaged dataset pin is invalid'');
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE ''BEGIN KCV_DATASET.LOAD_GITHUB(p_ref=>:r,p_expected_manifest_sha256=>:h);END;''
      USING kcv_deploy_contract.dataset_ref,kcv_deploy_contract.dataset_manifest_sha256;
   WHEN ''ENABLE_LEARNING'' THEN
    progress(run,''RUNNING'',''VERIFYING_READINESS'');required_ready;
    runtime_started:=TRUE;
    EXECUTE IMMEDIATE q''~MERGE INTO kcv_settings t USING(SELECT ''APP_MAINTENANCE'' k FROM dual)s ON(t.setting_key=s.k)
      WHEN MATCHED THEN UPDATE SET setting_value=''OFF'' WHEN NOT MATCHED THEN INSERT(setting_key,se');
 l_expected:=l_expected||TO_CLOB('tting_value) VALUES(s.k,''OFF'')~'';
    UPDATE kcv_deploy_state SET maintenance=''OFF'',updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
  END CASE;
  verify_action(p_operation,p_inputs);progress(run,''SUCCEEDED'',''COMPLETE'');
  lock_result:=DBMS_LOCK.RELEASE(admission);admission_locked:=FALSE;
  lock_result:=DBMS_LOCK.RELEASE(handle);locked:=FALSE;
 EXCEPTION WHEN OTHERS THEN
  err:=SQLCODE;
  IF DBMS_LOB.ISTEMPORARY(response)=1 THEN DBMS_LOB.FREETEMPORARY(response);END IF;
  ROLLBACK;
  IF run IS NOT NULL THEN
   IF runtime_started THEN maintenance_on;
   ELSIF maintenance_changed THEN restore_maintenance;END IF;
   IF p_operation=''TEST_MODEL'' AND runtime_started THEN
    UPDATE kcv_deploy_s');
 l_expected:=l_expected||TO_CLOB('tate SET model_test_status=''FAILED'',model_test_at=SYSTIMESTAMP,updated_at=SYSTIMESTAMP WHERE singleton_id=1;COMMIT;
   END IF;
   progress(run,''FAILED'',''REVIEW_BEFORE_RETRY'',err);
  END IF;
  IF admission_locked THEN lock_result:=DBMS_LOCK.RELEASE(admission);END IF;
  IF locked THEN lock_result:=DBMS_LOCK.RELEASE(handle);END IF;
  IF run IS NOT NULL THEN
   RAISE_APPLICATION_ERROR(c_failed,''SETUP_FAILED: Review the recorded error code and explicitly retry the step'');
  ELSE RAISE;END IF;
 END;
 PROCEDURE configure_profile(p_credential VARCHAR2,p_region VARCHAR2,p_compartment VARCHAR2,p_model VARCHAR2,p_request_token VARCHAR2) IS
  ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();cred VARCHA');
 l_expected:=l_expected||TO_CLOB('R2(128);
 BEGIN
  authorize(TRUE,ident);
  require(LENGTH(TRIM(p_credential)) BETWEEN 1 AND 128,c_invalid,''INVALID_SETUP_INPUT: Select a schema-local credential'');
  cred:=UPPER(TRIM(p_credential));local_credential(cred);
  require(p_region IS NOT NULL AND LENGTH(p_region)<=128 AND REGEXP_LIKE(p_region,''^[a-z][a-z0-9-]+-[0-9]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter an OCI region name'');
  require(p_compartment IS NOT NULL AND LENGTH(p_compartment)<=256 AND REGEXP_LIKE(p_compartment,''^ocid1\.compartment\.[A-Za-z0-9.-]+$'',''c''),c_invalid,''INVALID_SETUP_INPUT: Enter a compartment OCID'');
  require(p_model IS NOT NULL AND LENGTH(p_model)<=256 AND REGEXP_LIKE(p_model,''^[A-Za-z0-9][A-Za-z0-9.');
 l_expected:=l_expected||TO_CLOB('_-]+$'',''c'')
    AND SUBSTR(p_model,1,6)<>''ocid1.'',c_invalid,''INVALID_SETUP_INPUT: Enter the supported model name, not an endpoint or URL'');
  j.put(''provider'',''oci'');j.put(''credential_name'',cred);j.put(''region'',p_region);j.put(''oci_compartment_id'',p_compartment);j.put(''model'',p_model);
  run_action(''CONFIGURE_PROFILE'',p_request_token,j);
 END;
 PROCEDURE test_model(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);run_action(''TEST_MODEL'',p_request_token,j);
 END;
 PROCEDURE ensure_network(p_request_token VARCHAR2) IS j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  j.put(''network'',c_network);run_acti');
 l_expected:=l_expected||TO_CLOB('on(''ENSURE_NETWORK'',p_request_token,j);
 END;
 PROCEDURE register_runtime(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);j.put(''profile_hash'',profile_fingerprint);j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);
  run_action(''REGISTER_RUNTIME'',p_request_token,j);
 END;
 PROCEDURE load_dataset(p_request_token VARCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''dataset_ref'',kcv_deploy_contract.dataset_ref);j.put(''manifest_sha256'',kcv_deploy_contract.dataset_manifest_sha256);
  run_action(''LOAD_DATASET'',p_request_token,j);
 END;
 PROCEDURE enable_learning(p_request_token VA');
 l_expected:=l_expected||TO_CLOB('RCHAR2) IS ident identity_t;j JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN
  authorize(TRUE,ident);
  j.put(''checkpoint'',kcv_deploy_contract.target_checkpoint);run_action(''ENABLE_LEARNING'',p_request_token,j);
 END;
END;
');
 check_program('KCV_DEPLOY','PACKAGE BODY',l_expected);
  UPDATE kcv_schema_migrations SET phase='COMPLETE',completed_at=SYSTIMESTAMP,error_code=NULL WHERE migration_id='2.1.0-apl-r1-004-kcv_deploy-package-body';
  COMMIT;
 END IF;
 l_lock_result:=DBMS_LOCK.RELEASE(l_lock);
EXCEPTION WHEN OTHERS THEN
 l_error:=SQLCODE;ROLLBACK;
 IF l_started THEN UPDATE kcv_schema_migrations SET phase='FAILED',error_code=l_error WHERE migration_id='2.1.0-apl-r1-004-kcv_deploy-package-body';COMMIT;END IF;
 IF l_lock IS NOT NULL AND l_lock_result=0 THEN l_lock_result:=DBMS_LOCK.RELEASE(l_lock);END IF;
 RAISE;
END;
