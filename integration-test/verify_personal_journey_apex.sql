-- Privileged native APEX_SESSION harness, NOT a real browser sign-in test.
-- Uses two existing synthetic accounts in isolated app 101; no passwords,
-- account changes, GENERATE or RUN_TEAM calls. Cleans only its own fixtures.
DECLARE
 app_id NUMBER:=:KCV_TEST_APP_ID;user_a VARCHAR2(255):=:KCV_TEST_USER_A;user_b VARCHAR2(255):=:KCV_TEST_USER_B;
 prefix VARCHAR2(24):=SUBSTR(RAWTOHEX(SYS_GUID()),1,24);cid VARCHAR2(32);sid VARCHAR2(40);rev VARCHAR2(40);conv VARCHAR2(128);
 scope_a VARCHAR2(128);subject_a VARCHAR2(128);sessions SYS.ODCINUMBERLIST:=SYS.ODCINUMBERLIST();
 result CLOB;request CLOB;ctx CLOB;j JSON_OBJECT_T;b JSON_OBJECT_T:=JSON_OBJECT_T();prefs JSON_OBJECT_T:=JSON_OBJECT_T();topics JSON_ARRAY_T;
 user_turn NUMBER;answer_turn NUMBER;n NUMBER;sources_before NUMBER;passages_before NUMBER;
 PROCEDURE check_true(ok BOOLEAN,msg VARCHAR2) IS BEGIN IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,msg);END IF;END;
 PROCEDURE login_as(account_name VARCHAR2,pin BOOLEAN DEFAULT TRUE) IS BEGIN
  apex_session.create_session(p_app_id=>app_id,p_page_id=>10,p_username=>account_name);
  sessions.EXTEND;sessions(sessions.COUNT):=TO_NUMBER(SYS_CONTEXT('APEX$SESSION','APP_SESSION'));
  IF pin THEN kcv_access.capture_identity;END IF;
 END;
 PROCEDURE denied(action_name VARCHAR2,expected_code NUMBER) IS BEGIN
  CASE action_name
   WHEN 'open' THEN kcv_personal_journey.open_conversation(sid);
   WHEN 'state' THEN result:=kcv_scenario.state(sid);
   WHEN 'evidence' THEN result:=kcv_scenario.evidence_packet(request);
   WHEN 'history' THEN result:=kcv_personal_journey.history(sid);
   WHEN 'trace' THEN result:=kcv_trace.response_trace(sid,answer_turn);
   WHEN 'observe' THEN kcv_scenario.observe(sid,'discussion','Synthetic rejected observation',NULL,prefix||'_rejected');
   WHEN 'adopt' THEN kcv_personal_journey.adopt_head(sid,rev,prefix||'_adopt',rev);
   ELSE RAISE_APPLICATION_ERROR(-20998,'Unknown test operation');
  END CASE;
  RAISE_APPLICATION_ERROR(-20991,'Authorization unexpectedly allowed '||action_name);
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>expected_code THEN RAISE;END IF;END;
 PROCEDURE cleanup IS
  TYPE names_t IS TABLE OF VARCHAR2(128);graphs names_t;models names_t;
 BEGIN
  apex_session.detach;
  IF cid IS NOT NULL THEN
   SELECT DISTINCT overlay_graph BULK COLLECT INTO graphs FROM kcv_personal_operations WHERE context_id=cid AND overlay_graph IS NOT NULL;
   SELECT model_id BULK COLLECT INTO models FROM (
    SELECT model_conversation_id model_id FROM kcv_personal_operations WHERE context_id=cid AND model_conversation_id IS NOT NULL
    UNION SELECT conversation_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_context_attachments WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_model_boundaries WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_response_tool_calls WHERE execution_id IN(SELECT x.execution_id FROM kcv_response_runs x JOIN kcv_chat_sessions s ON s.session_id=x.session_id WHERE s.personal_context_id=cid);
   DELETE FROM kcv_response_runs WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_scenario_observations WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_chat_turns WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_scenario_changes WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_scenario_audit WHERE session_id IN(SELECT session_id FROM kcv_chat_sessions WHERE personal_context_id=cid);
   DELETE FROM kcv_chat_sessions WHERE personal_context_id=cid;
   DELETE FROM kcv_personal_operations WHERE context_id=cid;
   UPDATE kcv_personal_contexts SET latest_revision=NULL,lifecycle='DRAFT',prior_lifecycle=NULL WHERE context_id=cid;
   DELETE FROM kcv_scenario_revisions WHERE context_id=cid;
   DELETE FROM kcv_context_requests WHERE owner_scope=scope_a AND owner_subject=subject_a AND request_token LIKE prefix||'%';
   DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
   FOR i IN 1..models.COUNT LOOP DBMS_CLOUD_AI.DROP_CONVERSATION(models(i),force=>TRUE);END LOOP;
   FOR i IN 1..graphs.COUNT LOOP SEM_APIS.DROP_RDF_GRAPH(graphs(i),network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END LOOP;
  END IF;
  FOR i IN 1..sessions.COUNT LOOP apex_session.delete_session(p_session_id=>sessions(i));END LOOP;
 END;
BEGIN
 check_true(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST'),'Use the isolated schema owner');
 SELECT COUNT(*) INTO n FROM apex_applications WHERE application_id=app_id AND owner=SYS_CONTEXT('USERENV','SESSION_USER');
 check_true(n=1 AND app_id<>100,'Use the isolated test application');
 check_true(user_a IS NOT NULL AND user_b IS NOT NULL AND UPPER(user_a)<>UPPER(user_b),'Two existing distinct test accounts are required');
 SELECT COUNT(*) INTO sources_before FROM kcv_sources;SELECT COUNT(*) INTO passages_before FROM kcv_passages;
 login_as(user_a);scope_a:=kcv_access.owner_scope;subject_a:=kcv_access.owner_subject;
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.topic_options);topics:=j.get_array('topics');check_true(topics.get_size>0,'Public topics are required');
 prefs.put(topics.get_string(0),2);b.put('topic_preferences',prefs);b.put('question','Which public information should this synthetic learner explore?');b.put('objective_clarity','emerging');
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(NULL,'APEX C3 synthetic authorization',b.to_clob(),NULL,prefix||'_create'));cid:=j.get_string('context_id');
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,1));j:=JSON_OBJECT_T.parse(kcv_personal_journey.apply_preview(cid,j.get_string('token')));rev:=j.get_string('revision');
 sid:=kcv_personal_journey.start_conversation(cid,prefix||'_start');j:=JSON_OBJECT_T();j.put('scenario_session',sid);request:=j.to_clob();
 result:=kcv_scenario.state(sid);result:=kcv_scenario.evidence_packet(request);
 -- Synthetic recorded answer tests trace authorization, not generation quality.
 SELECT conversation_id INTO conv FROM kcv_chat_sessions WHERE session_id=sid;SELECT context_json INTO ctx FROM kcv_scenario_revisions WHERE revision_id=rev;
 INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev,'user','Synthetic authorization fixture') RETURNING turn_id INTO user_turn;
 INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev,'assistant','{"citations":[],"limitations":["Synthetic authorization fixture; no model call"]}') RETURNING turn_id INTO answer_turn;
 INSERT INTO kcv_response_runs(execution_id,session_id,revision_id,conversation_id,user_turn_id,assistant_turn_id,request_mode,question,context_json,sources_json,history_json,status)
  VALUES('E'||RAWTOHEX(SYS_GUID()),sid,rev,conv,user_turn,answer_turn,'question','Synthetic authorization fixture',ctx,'[]','[]','INCOMPLETE');COMMIT;
 result:=kcv_trace.response_trace(sid,answer_turn);check_true(result IS NOT NULL,'Owner could not read its synthetic trace');
 login_as(user_b);check_true(kcv_access.owner_subject<>subject_a,'Test accounts share an identity');
 denied('open',-20241);denied('state',-20241);denied('evidence',-20241);denied('history',-20241);denied('trace',-20241);denied('observe',-20241);denied('adopt',-20241);
 SELECT COUNT(*) INTO n FROM kcv_context_attachments WHERE session_id=sid;check_true(n=1,'Foreign account gained an attachment');
 login_as(user_a,FALSE);apex_util.set_session_state(p_name=>'KCV_AUTH_ACCOUNT_ID',p_value=>NULL,p_commit=>FALSE);
 denied('state',-20240);kcv_access.capture_identity;
 check_true(kcv_access.owner_scope=scope_a AND kcv_access.owner_subject=subject_a,'Stable owner identity changed across sessions');
 denied('state',-20100);denied('evidence',-20100);denied('history',-20100);denied('trace',-20100);denied('observe',-20100);denied('adopt',-20100);
 kcv_personal_journey.open_conversation(sid);kcv_personal_journey.open_conversation(sid);
 SELECT COUNT(*) INTO n FROM kcv_context_attachments WHERE session_id=sid;check_true(n=2,'Reopen was not idempotent for the current authenticated session');
 result:=kcv_scenario.state(sid);result:=kcv_personal_journey.history(sid);result:=kcv_trace.response_trace(sid,answer_turn);result:=kcv_scenario.evidence_packet(request);
 kcv_scenario.observe(sid,'discussion','Synthetic owned observation',NULL,prefix||'_observe');
 result:=kcv_personal_context_api.archive_context(cid,1,prefix||'_archive');
 login_as(user_a);kcv_personal_journey.open_conversation(sid);
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(j.get_boolean('read_only'),'Archived conversation was not read-only after reopen');
 result:=kcv_personal_journey.history(sid);result:=kcv_trace.response_trace(sid,answer_turn);result:=kcv_scenario.evidence_packet(request);
 denied('observe',-20243);denied('adopt',-20243);
 SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id=sid;check_true(n=1,'Denied account/session/archive writes persisted');
 cleanup;
 SELECT COUNT(*) INTO n FROM kcv_sources;check_true(n=sources_before,'Public source count changed');SELECT COUNT(*) INTO n FROM kcv_passages;check_true(n=passages_before,'Public passage count changed');
 DBMS_OUTPUT.PUT_LINE('PASS: native APEX personal conversation ownership, cross-account denial, authenticated attachment, same-owner session reopening and archived read-only access');
 DBMS_OUTPUT.PUT_LINE('NOT COVERED: real browser authentication or model generation; this is a privileged APEX_SESSION authorization harness');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('APEX synthetic fixture cleanup needs review: '||SQLCODE);END;
 RAISE;
END;
/
