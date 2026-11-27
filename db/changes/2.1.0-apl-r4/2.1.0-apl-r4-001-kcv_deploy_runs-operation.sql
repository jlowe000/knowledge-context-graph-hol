DECLARE
 old_expression CONSTANT VARCHAR2(1000):=
   q'~OPERATION IN ('CONFIGURE_PROFILE','TEST_MODEL','ENSURE_NETWORK','REGISTER_RUNTIME','LOAD_DATASET','ENABLE_LEARNING')~';
 new_expression CONSTANT VARCHAR2(1000):=
   q'~OPERATION IN ('CONFIGURE_PROFILE','TEST_MODEL','ENSURE_NETWORK','REGISTER_RUNTIME','LOAD_DATASET','ENABLE_LEARNING','CREATE_OCI_CREDENTIAL')~';
 new_name CONSTANT VARCHAR2(128):='KCV_DEPLOY_RUNS_OPERATION_V2';
 old_name VARCHAR2(128);old_count PLS_INTEGER:=0;new_count PLS_INTEGER:=0;n NUMBER;
 FUNCTION compact(p_text VARCHAR2) RETURN VARCHAR2 IS BEGIN
  RETURN REGEXP_REPLACE(UPPER(p_text),'[[:space:]"]','');
 END;
 PROCEDURE require(p_ok BOOLEAN) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN
   RAISE_APPLICATION_ERROR(-20301,'Deployment operation constraint requires administrator review');
  END IF;
 END;
BEGIN
 FOR c IN (SELECT constraint_name,search_condition_vc,status,validated,deferrable
   FROM user_constraints WHERE table_name='KCV_DEPLOY_RUNS' AND constraint_type='C') LOOP
  IF compact(c.search_condition_vc)=compact(old_expression) THEN
   require(c.status='ENABLED' AND c.validated='VALIDATED' AND c.deferrable='NOT DEFERRABLE');
   old_name:=c.constraint_name;old_count:=old_count+1;
  ELSIF c.constraint_name=new_name THEN
   require(compact(c.search_condition_vc)=compact(new_expression)
     AND c.status='ENABLED' AND c.validated='VALIDATED' AND c.deferrable='NOT DEFERRABLE');
   new_count:=new_count+1;
  END IF;
 END LOOP;
 require(old_count<=1 AND new_count<=1 AND old_count+new_count>=1);
 IF new_count=0 THEN
  SELECT COUNT(*) INTO n FROM user_constraints WHERE constraint_name=new_name;
  require(n=0);
  EXECUTE IMMEDIATE 'ALTER TABLE KCV_DEPLOY_RUNS ADD CONSTRAINT '
    ||DBMS_ASSERT.ENQUOTE_NAME(new_name,FALSE)||' CHECK ('||new_expression||') ENABLE VALIDATE';
 END IF;
 IF old_count=1 THEN
  EXECUTE IMMEDIATE 'ALTER TABLE KCV_DEPLOY_RUNS DROP CONSTRAINT '
    ||DBMS_ASSERT.ENQUOTE_NAME(old_name,FALSE);
 END IF;
END;
