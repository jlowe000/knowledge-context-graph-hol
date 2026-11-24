-- Native Serverless regression for the original Alex/Sam/Casey HOL journeys.
-- Dedicated isolated schema only. No GENERATE/RUN_TEAM calls. Unlike the legacy
-- verify_scenario_native.sql, this removes only the sessions/overlays it creates.
DECLARE
 ids SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST('CTX01','CTX02','CTX03');
 names SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST('Alex','Sam','Casey');
 sessions SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST();roots SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST();models SYS.ODCIVARCHAR2LIST:=SYS.ODCIVARCHAR2LIST();
 sid VARCHAR2(40);req JSON_OBJECT_T:=JSON_OBJECT_T();packet JSON_OBJECT_T;ev JSON_ARRAY_T;row_json JSON_OBJECT_T;plan JSON_OBJECT_T;
 before_context JSON_OBJECT_T;after_context JSON_OBJECT_T;prefs JSON_OBJECT_T;reply CLOB;token VARCHAR2(40);base VARCHAR2(128);active_before VARCHAR2(128);r VARCHAR2(40);c VARCHAR2(128);
 p3 BOOLEAN:=FALSE;p10 BOOLEAN:=FALSE;n NUMBER;sources_before NUMBER;passages_before NUMBER;samples_before VARCHAR2(64);samples_after VARCHAR2(64);
 PROCEDURE check_true(ok BOOLEAN,msg VARCHAR2) IS BEGIN IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,msg);END IF;END;
 PROCEDURE remember_model(p_sid VARCHAR2) IS v VARCHAR2(128);BEGIN
  SELECT conversation_id INTO v FROM kcv_chat_sessions WHERE session_id=p_sid;models.EXTEND;models(models.COUNT):=v;
 END;
 PROCEDURE cleanup IS
  revisions SYS.ODCIVARCHAR2LIST;graphs SYS.ODCIVARCHAR2LIST;v VARCHAR2(128);
 BEGIN
  FOR i IN 1..sessions.COUNT LOOP
   SELECT revision_id,overlay_graph BULK COLLECT INTO revisions,graphs FROM kcv_scenario_revisions
    START WITH revision_id=roots(i) CONNECT BY PRIOR revision_id=parent_revision;
   SELECT conversation_id INTO v FROM kcv_chat_sessions WHERE session_id=sessions(i);models.EXTEND;models(models.COUNT):=v;
   DELETE FROM kcv_response_tool_calls WHERE execution_id IN(SELECT execution_id FROM kcv_response_runs WHERE session_id=sessions(i));
   DELETE FROM kcv_response_runs WHERE session_id=sessions(i);
   DELETE FROM kcv_chat_turns WHERE session_id=sessions(i);
   DELETE FROM kcv_scenario_observations WHERE session_id=sessions(i);
   DELETE FROM kcv_scenario_changes WHERE session_id=sessions(i);
   DELETE FROM kcv_scenario_audit WHERE session_id=sessions(i);
   DELETE FROM kcv_chat_sessions WHERE session_id=sessions(i);
   FOR j IN 1..revisions.COUNT LOOP DELETE FROM kcv_scenario_revisions WHERE revision_id=revisions(j);END LOOP;COMMIT;
   FOR j IN 1..graphs.COUNT LOOP SEM_APIS.DROP_RDF_GRAPH(graphs(j),network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END LOOP;
  END LOOP;
  FOR i IN 1..models.COUNT LOOP DBMS_CLOUD_AI.DROP_CONVERSATION(models(i),force=>TRUE);END LOOP;
 END;
 FUNCTION sample_hash RETURN VARCHAR2 IS v CLOB;BEGIN
  SELECT JSON_ARRAYAGG(JSON_QUERY(context_json,'$' RETURNING CLOB) FORMAT JSON ORDER BY snapshot_id RETURNING CLOB) INTO v FROM kcv_contexts;
  RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(v,DBMS_CRYPTO.HASH_SH256)));
 END;
BEGIN
 check_true(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH'),'Use the isolated Serverless schema owner');
 SELECT setting_value INTO active_before FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
 SELECT COUNT(*) INTO sources_before FROM kcv_sources;SELECT COUNT(*) INTO passages_before FROM kcv_passages;samples_before:=sample_hash;
 FOR i IN 1..ids.COUNT LOOP
  sid:=kcv_scenario.open_session(ids(i));sessions.EXTEND;sessions(sessions.COUNT):=sid;
  SELECT revision_id INTO r FROM kcv_chat_sessions WHERE session_id=sid;roots.EXTEND;roots(roots.COUNT):=r;remember_model(sid);
  req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));ev:=packet.get_array('evidence');
  check_true(packet.get_object('context').get_string('person')=names(i),'Sample identity changed');
  check_true(packet.get_array('graph_paths').get_size>0 AND ev.get_size>0 AND ev.get_size<=6,'Sample lacks bounded native graph evidence');
  check_true(packet.get_string('base_graph')=active_before,'Sample did not pin the active collection');
  IF ids(i)='CTX03' THEN
   FOR k IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(k) AS JSON_OBJECT_T);
    IF row_json.get_string('source_id')='S10' THEN IF row_json.get_number('pdf_page')=3 THEN p3:=TRUE;END IF;IF row_json.get_number('pdf_page')=10 THEN p10:=TRUE;END IF;END IF;
   END LOOP;
   check_true(p3 AND p10,'Casey lost the healthcare overview or scope qualification');
  END IF;
  kcv_scenario.observe(sid,'source_check','Synthetic native HOL regression: inspect cited sources','Choose a relevant next step');
  SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id=sid;check_true(n=1,'Sample observation was not recorded');
 END LOOP;
 -- Alex's topic removal must only change learning focus, retaining the pinned
 -- collection and every explicit constraint/background field.
 sid:=sessions(1);req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));before_context:=packet.get_object('context');base:=packet.get_string('base_graph');
 plan:=JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,'{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}'));token:=plan.get_string('pending_change');
 packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(packet.get_string('context_revision')=roots(1),'Staging published a refinement');
 reply:=kcv_scenario.apply_change(sid,token);remember_model(sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));after_context:=packet.get_object('context');
 check_true(packet.get_string('base_graph')=base,'Refinement changed the pinned source collection');
 prefs:=before_context.get_object('topic_preferences');prefs.remove('Graph capabilities');before_context.put('topic_preferences',prefs);
 check_true(DBMS_LOB.COMPARE(before_context.to_clob(),after_context.to_clob())=0,'Topic removal changed facts beyond learning focus');
 check_true(packet.get_string('context_semantics') IS NOT NULL,'Learning-focus semantics are missing');
 ev:=packet.get_array('evidence');FOR i IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(i) AS JSON_OBJECT_T);check_true(row_json.get_string('source_id')<>'S06','Removed topic still selected the multicloud source');END LOOP;
 BEGIN reply:=kcv_scenario.apply_change(sid,token);RAISE_APPLICATION_ERROR(-20991,'Applied legacy token replay accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20108 THEN RAISE;END IF;END;
 -- Sam can explicitly refine the objective through the original staged flow.
 sid:=sessions(2);plan:=JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,'{"operation":"SET_OBJECTIVE","objective":"Inspect source and version relationships before choosing a practical next step"}'));
 reply:=kcv_scenario.apply_change(sid,plan.get_string('pending_change'));remember_model(sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));
 check_true(packet.get_object('context').get_string('objective_clarity')='defined','Sam objective did not become defined');
 check_true(packet.get_object('context').get_string('objective')='Inspect source and version relationships before choosing a practical next step','Sam objective was not persisted');
 cleanup;
 SELECT setting_value INTO base FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';check_true(base=active_before,'Active collection changed');
 SELECT COUNT(*) INTO n FROM kcv_sources;check_true(n=sources_before,'Public source count changed');SELECT COUNT(*) INTO n FROM kcv_passages;check_true(n=passages_before,'Public passage count changed');
 samples_after:=sample_hash;check_true(samples_before=samples_after,'Immutable sample context content changed');
 DBMS_OUTPUT.PUT_LINE('PASS: native Alex/Sam/Casey evidence, graph paths, healthcare qualifications, staged refinements, topic-removal semantics, replay rejection and observations; exact fixtures removed');
 DBMS_OUTPUT.PUT_LINE('NOT COVERED: LLM generation, agent invocation, proposal generation or real browser interaction');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Sample regression fixture cleanup needs review: '||SQLCODE);END;
 RAISE;
END;
/
