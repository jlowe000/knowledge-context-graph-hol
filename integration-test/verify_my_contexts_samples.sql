-- Native sample-copy acceptance after the public sample dataset is loaded.
-- Uses no model calls. This is separate from the empty-schema draft test.
DECLARE
 g VARCHAR2(128);token_prefix VARCHAR2(32):=RAWTOHEX(SYS_GUID());token VARCHAR2(80);
 result CLOB;again CLOB;j JSON_OBJECT_T;draft JSON_OBJECT_T;
 source_before VARCHAR2(64);source_after VARCHAR2(64);n NUMBER:=0;
 ids SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST();
 PROCEDURE check_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 BEGIN SELECT setting_value INTO g FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20992,'Load the public sample dataset before this test');END;
 FOR s IN (SELECT c.context_id,c.snapshot_id,c.context_json FROM kcv_contexts c
   JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id WHERE gc.graph_name=g
   AND c.context_id IN ('CTX01','CTX02','CTX03')) LOOP
   source_before:=RAWTOHEX(DBMS_CRYPTO.HASH(s.context_json,DBMS_CRYPTO.HASH_SH256));
   token:=token_prefix||'_'||s.context_id;
   result:=kcv_personal_context_api.copy_sample(s.context_id,'C2 sample copy '||s.context_id,token);
   j:=JSON_OBJECT_T.parse(result);draft:=j.get_object('draft');ids.EXTEND;ids(ids.COUNT):=j.get_string('context_id');
   check_true(j.get_string('lifecycle')='DRAFT','Sample copy was activated');
   check_true(j.get_string('base_graph')=g,'Sample copy used the wrong collection');
   check_true(draft.get_string('objective_clarity')='unknown','Sample objective clarity was silently inherited');
   check_true(NOT draft.has('person') AND NOT draft.has('role') AND NOT draft.has('organisation')
     AND NOT draft.has('known_situation') AND NOT draft.has('objective'),'Sample identity/background/objective was retained');
   check_true(draft.get_array('constraints').get_size=0 AND draft.get_array('unknowns').get_size=0,'Sample constraints or unknowns were inherited');
   check_true(j.get_array('selected_topics').get_size>0,'Copied topic suggestions are not inspectable');
   check_true(j.get_object('provenance').get_string('sample_id')=s.context_id,'Sample provenance missing');
   again:=kcv_personal_context_api.copy_sample(s.context_id,'C2 sample copy '||s.context_id,token);
   check_true(DBMS_LOB.COMPARE(result,again)=0,'Sample retry did not return original receipt');
   SELECT RAWTOHEX(DBMS_CRYPTO.HASH(context_json,DBMS_CRYPTO.HASH_SH256)) INTO source_after FROM kcv_contexts WHERE snapshot_id=s.snapshot_id;
   check_true(source_after=source_before,'Public sample was modified');n:=n+1;
 END LOOP;
 check_true(n=3,'Expected all three loaded public sample contexts');
 DELETE FROM kcv_context_requests WHERE request_token LIKE token_prefix||'%';
 FOR i IN 1..ids.COUNT LOOP DELETE FROM kcv_personal_contexts WHERE context_id=ids(i);END LOOP;COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: native sample copy clears fictional facts, preserves visible suggestions/provenance, is idempotent and leaves the public samples unchanged');
END;
/
