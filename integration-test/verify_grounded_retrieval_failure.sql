-- Native negative-path test. Run as KCV_V2_TEST or KCV_HOL_TEST after the
-- deterministic-retrieval migrations, with a ready public collection loaded.
-- Creates only an isolated synthetic context. No model request is expected.
-- The invalid graph reference belongs solely to that fixture and is restored.
-- This script neither reads credentials nor changes any profile or source data.
SET SERVEROUTPUT ON
DECLARE
 prefix VARCHAR2(24):='GF'||SUBSTR(RAWTOHEX(SYS_GUID()),1,22);
 cid VARCHAR2(32);sid VARCHAR2(40);rev VARCHAR2(40);conv VARCHAR2(128);
 overlay_before VARCHAR2(128);profile_before VARCHAR2(128);profile_after VARCHAR2(128);
 body JSON_OBJECT_T:=JSON_OBJECT_T();prefs JSON_OBJECT_T:=JSON_OBJECT_T();j JSON_OBJECT_T;
 reply CLOB;public_before VARCHAR2(64);n NUMBER;provider_before NUMBER;eid VARCHAR2(40);
 failed_graph VARCHAR2(128):='KCV_O_MISSING_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,20);
 PROCEDURE require(ok BOOLEAN,message VARCHAR2) IS BEGIN
  IF ok IS NULL OR NOT ok THEN RAISE_APPLICATION_ERROR(-20990,message);END IF;
 END;
 FUNCTION public_digest RETURN VARCHAR2 IS material CLOB;line VARCHAR2(4000);digest VARCHAR2(64);BEGIN
  DBMS_LOB.CREATETEMPORARY(material,TRUE);
  FOR r IN(SELECT version_id,source_id,sha256,metadata_json FROM kcv_sources ORDER BY version_id) LOOP
   line:='S|'||r.version_id||'|'||r.source_id||'|'||r.sha256||'|'||RAWTOHEX(DBMS_CRYPTO.HASH(r.metadata_json,4))||CHR(10);
   DBMS_LOB.WRITEAPPEND(material,LENGTH(line),line);
  END LOOP;
  FOR r IN(SELECT passage_id,version_id,pdf_page,chunk_index,text_sha256,passage_text,metadata_json FROM kcv_passages ORDER BY passage_id) LOOP
   line:='P|'||r.passage_id||'|'||r.version_id||'|'||TO_CHAR(r.pdf_page,'TM9')||'|'||TO_CHAR(r.chunk_index,'TM9')||'|'||r.text_sha256||'|'||RAWTOHEX(DBMS_CRYPTO.HASH(r.passage_text,4))||'|'||RAWTOHEX(DBMS_CRYPTO.HASH(r.metadata_json,4))||CHR(10);
   DBMS_LOB.WRITEAPPEND(material,LENGTH(line),line);
  END LOOP;
  FOR r IN(SELECT graph_name,version_id,metadata_json FROM kcv_graph_sources ORDER BY graph_name,version_id) LOOP
   line:='G|'||r.graph_name||'|'||r.version_id||'|'||RAWTOHEX(DBMS_CRYPTO.HASH(r.metadata_json,4))||CHR(10);
   DBMS_LOB.WRITEAPPEND(material,LENGTH(line),line);
  END LOOP;
  digest:=RAWTOHEX(DBMS_CRYPTO.HASH(material,4));DBMS_LOB.FREETEMPORARY(material);RETURN digest;
 EXCEPTION WHEN OTHERS THEN
  IF DBMS_LOB.ISTEMPORARY(material)=1 THEN DBMS_LOB.FREETEMPORARY(material);END IF;RAISE;
 END;
 PROCEDURE restore_overlay IS BEGIN
  IF rev IS NOT NULL AND overlay_before IS NOT NULL THEN
   UPDATE kcv_scenario_revisions SET overlay_graph=overlay_before WHERE revision_id=rev AND context_id=cid;
   COMMIT;
  END IF;
 END;
 PROCEDURE cleanup IS
  TYPE names_t IS TABLE OF VARCHAR2(128);graphs names_t;models names_t;
 BEGIN
  IF cid IS NULL THEN RETURN;END IF;
  restore_overlay;
  SELECT DISTINCT overlay_graph BULK COLLECT INTO graphs FROM kcv_personal_operations WHERE context_id=cid AND overlay_graph IS NOT NULL;
  SELECT model_id BULK COLLECT INTO models FROM (
   SELECT model_conversation_id model_id FROM kcv_personal_operations WHERE context_id=cid AND model_conversation_id IS NOT NULL
   UNION SELECT conversation_id FROM kcv_chat_sessions WHERE personal_context_id=cid
   UNION SELECT b.old_conversation FROM kcv_model_boundaries b JOIN kcv_chat_sessions s ON s.session_id=b.session_id WHERE s.personal_context_id=cid AND b.old_conversation IS NOT NULL);
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
  DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token=prefix||'_create';
  DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
  FOR i IN 1..models.COUNT LOOP DBMS_CLOUD_AI.DROP_CONVERSATION(models(i),force=>TRUE);END LOOP;
  FOR i IN 1..graphs.COUNT LOOP SEM_APIS.DROP_RDF_GRAPH(graphs(i),network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END LOOP;
 END;
BEGIN
 require(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH'),'Use an isolated test schema owner');
 public_before:=public_digest;
 SELECT setting_value INTO profile_before FROM kcv_settings WHERE setting_key='AI_PROFILE';
 body.put('question','Which public concepts help a synthetic learner explore project information?');
 body.put('objective_clarity','emerging');body.put('known_situation','Synthetic retrieval failure acceptance; no live project data.');
 prefs.put('Semantic retrieval',1);body.put('topic_preferences',prefs);
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(NULL,'Synthetic grounded retrieval failure',body.to_clob(),NULL,prefix||'_create'));cid:=j.get_string('context_id');
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,1));j:=JSON_OBJECT_T.parse(kcv_personal_journey.apply_preview(cid,j.get_string('token')));rev:=j.get_string('revision');
 sid:=kcv_personal_journey.start_conversation(cid,prefix||'_start');
 SELECT conversation_id INTO conv FROM kcv_chat_sessions WHERE session_id=sid;
 SELECT overlay_graph INTO overlay_before FROM kcv_scenario_revisions WHERE revision_id=rev AND context_id=cid;
 SELECT COUNT(*) INTO provider_before FROM user_ai_agent_team_history WHERE conversation_id=conv;
 require(provider_before=0,'New fixture unexpectedly has provider executions');
 UPDATE kcv_scenario_revisions SET overlay_graph=failed_graph WHERE revision_id=rev AND context_id=cid;
 require(SQL%ROWCOUNT=1,'Fixture revision missing');COMMIT;
 BEGIN
  reply:=kcv_scenario.ask(sid,'Which evidence should I explore?','question',prefix||'_ask');
  RAISE_APPLICATION_ERROR(-20991,'Retrieval failure incorrectly returned an answer');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20174 THEN RAISE;END IF;END;
 restore_overlay;
 SELECT execution_id INTO eid FROM kcv_response_runs WHERE session_id=sid AND request_token=prefix||'_ask';
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE execution_id=eid AND status='FAILED' AND error_code IS NOT NULL AND assistant_turn_id IS NULL AND model_started_at IS NULL;
 require(n=1,'Retrieval failure lacks a definitive pre-model failed run');
 SELECT COUNT(*) INTO n FROM kcv_response_tool_calls WHERE execution_id=eid AND tool_name='EVIDENCE' AND call_origin='APPLICATION' AND status='FAILED' AND error_code IS NOT NULL;
 require(n=1,'Failed application retrieval event missing');
 SELECT COUNT(*) INTO n FROM kcv_response_tool_calls WHERE execution_id=eid;require(n=1,'Retrieval failure produced duplicate events');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE session_id=sid AND mutation_token IS NULL;require(n=1,'Retrieval failure retained the lease');
 SELECT COUNT(*) INTO n FROM user_ai_agent_team_history WHERE conversation_id=conv;require(n=provider_before,'A model request ran despite retrieval failure');
 -- Restore the graph before replay: the failed token must remain failed even
 -- though a new request could now retrieve evidence. This is not an auto-retry.
 BEGIN
  reply:=kcv_scenario.ask(sid,'Which evidence should I explore?','question',prefix||'_ask');
  RAISE_APPLICATION_ERROR(-20991,'Failed-token replay incorrectly returned an answer');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20174 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE session_id=sid;require(n=1,'Failed-token replay created another run');
 SELECT COUNT(*) INTO n FROM kcv_response_tool_calls WHERE execution_id=eid;require(n=1,'Failed-token replay retrieved again');
 SELECT COUNT(*) INTO n FROM kcv_chat_turns WHERE session_id=sid;require(n=1,'Failed-token replay added a turn');
 SELECT COUNT(*) INTO n FROM user_ai_agent_team_history WHERE conversation_id=conv;require(n=provider_before,'Failed-token replay submitted a model request');
 SELECT setting_value INTO profile_after FROM kcv_settings WHERE setting_key='AI_PROFILE';require(profile_after=profile_before,'Original profile setting changed');
 require(public_digest=public_before,'Source text or catalogue metadata changed');
 DBMS_OUTPUT.PUT_LINE('GROUNDED_RETRIEVAL_FAILURE=PASS; application_failure=1; model_requests=0; same_token_no_retry=PASS; lease_cleared=PASS');
 cleanup;
 require(public_digest=public_before,'Fixture cleanup changed source content');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=cid;require(n=0,'Synthetic context remains after cleanup');
 DBMS_OUTPUT.PUT_LINE('GROUNDED_FAILURE_FIXTURE_CLEANUP=PASS');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;DBMS_OUTPUT.PUT_LINE('GROUNDED_FAILURE_CLEANUP_AFTER_ERROR=PASS');EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GROUNDED_FAILURE_CLEANUP_ERROR='||SQLCODE);END;
 RAISE;
END;
/
