-- Live native acceptance for application-controlled evidence retrieval.
-- Requires an isolated KCV_V2_TEST/KCV_HOL_TEST owner, a working AI_PROFILE,
-- the public sample collection and the deterministic-retrieval migrations.
-- Makes exactly three model requests; same-token replay makes no extra request.
-- Expires only its own provider conversation after four saved turns. All fixture
-- rows, private overlay graphs and model conversations are removed on completion.
-- Logs only acceptance counts, never profile attributes, prompts or responses.
SET SERVEROUTPUT ON
DECLARE
 prefix VARCHAR2(24):='GC'||SUBSTR(RAWTOHEX(SYS_GUID()),1,22);cid VARCHAR2(32);sid VARCHAR2(40);
 body JSON_OBJECT_T:=JSON_OBJECT_T();prefs JSON_OBJECT_T:=JSON_OBJECT_T();j JSON_OBJECT_T;t JSON_OBJECT_T;
 reply CLOB;replay CLOB;trace1 CLOB;trace2 CLOB;answer1 VARCHAR2(64);answer2 VARCHAR2(64);
 rev1 VARCHAR2(40);rev2 VARCHAR2(40);conv VARCHAR2(128);new_conv VARCHAR2(128);
 profile_before VARCHAR2(128);profile_after VARCHAR2(128);profile_hash VARCHAR2(64);public_before VARCHAR2(64);
 first_turn NUMBER;second_turn NUMBER;third_turn NUMBER;n NUMBER;before_runs NUMBER;before_provider NUMBER;
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
 FUNCTION profile_digest RETURN VARCHAR2 IS material CLOB:=TO_CLOB('');BEGIN
  -- Deliberately excludes credential attributes and private credential contents.
  FOR r IN(SELECT attribute_name,attribute_value FROM user_cloud_ai_profile_attributes
   WHERE profile_name=profile_before AND attribute_name IN('provider','region','model','oci_apiformat') ORDER BY attribute_name) LOOP
   material:=material||r.attribute_name||'|'||r.attribute_value||CHR(10);
  END LOOP;
  RETURN RAWTOHEX(DBMS_CRYPTO.HASH(material,4));
 END;
 FUNCTION answer_digest(p_turn NUMBER) RETURN VARCHAR2 IS result VARCHAR2(64);BEGIN
  SELECT RAWTOHEX(DBMS_CRYPTO.HASH(body,4)) INTO result FROM kcv_chat_turns WHERE session_id=sid AND turn_id=p_turn;RETURN result;
 END;
 PROCEDURE check_trace(p_turn NUMBER,p_revision VARCHAR2,p_label VARCHAR2) IS
  trace JSON_OBJECT_T;events JSON_ARRAY_T;cites JSON_ARRAY_T;event JSON_OBJECT_T;cite JSON_OBJECT_T;
  paths NUMBER:=0;matched NUMBER:=0;counted NUMBER;run_id VARCHAR2(40);team_id VARCHAR2(128);
  packet CLOB;supplied CLOB;task_input CLOB;
 BEGIN
  trace:=JSON_OBJECT_T.parse(kcv_trace.response_trace(sid,p_turn));
  require(trace.get_string('status')='COMPLETED',p_label||' lacks a completed saved response');
  require(trace.get_string('revision_id')=p_revision,p_label||' is pinned to the wrong revision');
  events:=trace.get_array('tool_calls');require(events.get_size=1,p_label||' did not record exactly one retrieval');
  event:=TREAT(events.get(0) AS JSON_OBJECT_T);
  require(event.get_string('tool')='EVIDENCE' AND event.get_string('origin')='APPLICATION' AND event.get_string('status')='SUCCEEDED',p_label||' retrieval origin/status invalid');
  require(event.get_object('output').get_string('context_revision')=p_revision,p_label||' packet revision differs');
  paths:=event.get_object('output').get_array('graph_paths').get_size;require(paths>0,p_label||' lacks native graph paths');
  cites:=trace.get_array('citations');require(trace.get_string('citation_parse_status')='PARSED' AND cites.get_size>0,p_label||' lacks explicit parsed citations');
  FOR i IN 0..cites.get_size-1 LOOP cite:=TREAT(cites.get(i) AS JSON_OBJECT_T);require(cite.get_boolean('matched'),p_label||' contains unmatched citations');matched:=matched+1;END LOOP;
  SELECT execution_id INTO run_id FROM kcv_response_runs WHERE session_id=sid AND assistant_turn_id=p_turn;
  SELECT COUNT(*) INTO counted FROM kcv_response_runs r JOIN kcv_response_tool_calls c ON c.execution_id=r.execution_id
   WHERE r.execution_id=run_id AND r.model_started_at IS NOT NULL AND c.call_origin='APPLICATION' AND c.finished_at<=r.model_started_at AND r.profile_name=profile_before;
  require(counted=1,p_label||' model began before recorded evidence retrieval or changed profile');
  SELECT COUNT(*) INTO counted FROM user_ai_agent_team_history h JOIN kcv_response_runs r ON h.conversation_id=r.conversation_id
   AND h.start_date>=r.model_started_at-INTERVAL '1' SECOND AND h.start_date<=r.finished_at+INTERVAL '1' SECOND
   WHERE r.execution_id=run_id AND h.team_name='KCV_GROUNDED_TEAM' AND h.state='SUCCEEDED';
  require(counted=1,p_label||' grounded team execution missing or duplicated');
  SELECT h.team_exec_id INTO team_id FROM user_ai_agent_team_history h JOIN kcv_response_runs r ON h.conversation_id=r.conversation_id
   AND h.start_date>=r.model_started_at-INTERVAL '1' SECOND AND h.start_date<=r.finished_at+INTERVAL '1' SECOND
   WHERE r.execution_id=run_id AND h.team_name='KCV_GROUNDED_TEAM' AND h.state='SUCCEEDED';
  SELECT COUNT(*) INTO counted FROM user_ai_agent_tool_history WHERE team_exec_id=team_id;require(counted=0,p_label||' unexpectedly depended on a provider tool call');
  -- The task input is provider orchestration metadata, not hidden reasoning.
  -- Inspect only the explicit evidence_packet field; never print the input.
  SELECT input INTO task_input FROM user_ai_agent_task_history WHERE team_exec_id=team_id AND task_name='KCV_GROUNDED_QA_TASK';
  SELECT JSON_QUERY(task_input,'$.evidence_packet' RETURNING CLOB NULL ON ERROR) INTO supplied FROM dual;
  IF supplied IS NULL THEN
   -- Some engine versions wrap the submitted user JSON in a query property.
   SELECT JSON_QUERY(JSON_VALUE(task_input,'$.query' RETURNING CLOB NULL ON ERROR),'$.evidence_packet' RETURNING CLOB NULL ON ERROR) INTO supplied FROM dual;
  END IF;
  IF supplied IS NOT NULL THEN
   SELECT output_json INTO packet FROM kcv_response_tool_calls WHERE execution_id=run_id AND call_origin='APPLICATION' AND tool_name='EVIDENCE';
   SELECT CASE WHEN JSON_EQUAL(supplied,packet) THEN 1 ELSE 0 END INTO counted FROM dual;
   require(counted=1,p_label||' provider evidence differs from captured packet');
   DBMS_OUTPUT.PUT_LINE(p_label||'_PROVIDER_PACKET_EQUAL=PASS');
  ELSE
   DBMS_OUTPUT.PUT_LINE(p_label||'_PROVIDER_PACKET_EQUAL=NOT_INSPECTABLE; task input is not a plain JSON envelope');
  END IF;
  DBMS_OUTPUT.PUT_LINE(p_label||'=PASS; application_retrievals=1; agent_tools=0; matched_citations='||matched||'; native_paths='||paths);
 END;
 PROCEDURE cleanup IS
  TYPE names_t IS TABLE OF VARCHAR2(128);graphs names_t;models names_t;
 BEGIN
  IF cid IS NULL THEN RETURN;END IF;
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
  DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token IN(prefix||'_create',prefix||'_focus');
  DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
  FOR i IN 1..models.COUNT LOOP DBMS_CLOUD_AI.DROP_CONVERSATION(models(i),force=>TRUE);END LOOP;
  FOR i IN 1..graphs.COUNT LOOP SEM_APIS.DROP_RDF_GRAPH(graphs(i),network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END LOOP;
 END;
BEGIN
 require(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST'),'Use an isolated test schema owner');
 SELECT setting_value INTO profile_before FROM kcv_settings WHERE setting_key='AI_PROFILE';profile_hash:=profile_digest;public_before:=public_digest;
 body.put('question','Which approaches could help a synthetic learner find relevant project information?');
 body.put('objective_clarity','emerging');body.put('learning_purpose','Orient and connect');
 body.put('known_situation','Synthetic engineering-information learner exploring discovery versus document approval.');
 body.put('constraints',JSON_ARRAY_T.parse('["Exploration only; no production deployment assumed"]'));
 prefs.put('Semantic retrieval',2);prefs.put('Ontology',1);body.put('topic_preferences',prefs);
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(NULL,'Synthetic grounded continuation acceptance',body.to_clob(),NULL,prefix||'_create'));cid:=j.get_string('context_id');
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,1));j:=JSON_OBJECT_T.parse(kcv_personal_journey.apply_preview(cid,j.get_string('token')));rev1:=j.get_string('revision');
 sid:=kcv_personal_journey.start_conversation(cid,prefix||'_start');
 reply:=kcv_scenario.ask(sid,'What should I explore first? Cite the provided public evidence supporting the suggestion.','question',prefix||'_ask1');
 SELECT assistant_turn_id INTO first_turn FROM kcv_response_runs WHERE session_id=sid AND request_token=prefix||'_ask1';check_trace(first_turn,rev1,'GROUNDED_INITIAL');
 trace1:=kcv_trace.response_trace(sid,first_turn);answer1:=answer_digest(first_turn);
 SELECT COUNT(*) INTO before_runs FROM kcv_response_runs WHERE session_id=sid;
 SELECT COUNT(*) INTO before_provider FROM user_ai_agent_team_history WHERE conversation_id=(SELECT conversation_id FROM kcv_chat_sessions WHERE session_id=sid);
 replay:=kcv_scenario.ask(sid,'What should I explore first? Cite the provided public evidence supporting the suggestion.','question',prefix||'_ask1');
 require(DBMS_LOB.COMPARE(reply,replay)=0,'Same-token replay changed answer');
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE session_id=sid;require(n=before_runs,'Replay added a run');
 SELECT COUNT(*) INTO n FROM user_ai_agent_team_history WHERE conversation_id=(SELECT conversation_id FROM kcv_chat_sessions WHERE session_id=sid);require(n=before_provider,'Replay submitted another model request');
 prefs.remove('Ontology');body.put('topic_preferences',prefs);
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(cid,'Synthetic grounded continuation acceptance',body.to_clob(),1,prefix||'_focus'));
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,2));j:=JSON_OBJECT_T.parse(kcv_personal_journey.apply_preview(cid,j.get_string('token')));rev2:=j.get_string('revision');
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));require(j.get_string('context_revision')=rev1 AND j.get_string('latest_revision')=rev2,'Publication silently adopted revision');
 kcv_personal_journey.adopt_head(sid,rev1,prefix||'_adopt',rev2);
 reply:=kcv_scenario.ask(sid,'I removed Ontology from my learning topics. Explain my current learning focus separately from technical constraints and cite the provided public evidence for a useful next step.','question',prefix||'_ask2');
 SELECT assistant_turn_id INTO second_turn FROM kcv_response_runs WHERE session_id=sid AND request_token=prefix||'_ask2';check_trace(second_turn,rev2,'GROUNDED_ADOPTED');
 trace2:=kcv_trace.response_trace(sid,second_turn);answer2:=answer_digest(second_turn);t:=JSON_OBJECT_T.parse(trace2);
 require(NOT t.get_object('selection_context').get_object('topics').has('Ontology'),'Removed topic remained selected');
 require(t.get_object('interpretation_context').get_array('constraints').get_size=1,'Topic removal introduced a technical constraint');
 require(DBMS_LOB.COMPARE(trace1,kcv_trace.response_trace(sid,first_turn))=0 AND answer_digest(first_turn)=answer1,'Historical answer/trace changed after adoption');
 SELECT COUNT(*) INTO n FROM kcv_chat_turns WHERE session_id=sid;require(n=4,'Need exactly four saved turns before expiry');
 SELECT conversation_id INTO conv FROM kcv_chat_sessions WHERE session_id=sid;DBMS_CLOUD_AI.DROP_CONVERSATION(conv);
 SELECT COUNT(*) INTO n FROM user_cloud_ai_conversations WHERE conversation_id=conv;require(n=0,'Synthetic provider conversation was not expired');
 reply:=kcv_scenario.ask(sid,'Continue from our discussion: what is my present learning focus and the next question to clarify? Distinguish my context from evidence and cite the provided public passages for the suggested next step.','question',prefix||'_ask3');
 SELECT conversation_id INTO new_conv FROM kcv_chat_sessions WHERE session_id=sid;require(new_conv<>conv,'Expired model conversation was not replaced');
 SELECT assistant_turn_id INTO third_turn FROM kcv_response_runs WHERE session_id=sid AND request_token=prefix||'_ask3';check_trace(third_turn,rev2,'GROUNDED_AFTER_EXPIRY');
 t:=JSON_OBJECT_T.parse(kcv_trace.response_trace(sid,third_turn));
 require(t.get_object('supplied_continuation').get_array('turns_newest_first').get_size=4,'Continuation did not include four saved turns');
 require(t.get_object('supplied_continuation').get_string('selected_revision')=rev2,'Continuation selected the wrong revision');
 require(t.get_object('supplied_continuation').get_number('included_characters')<=8000,'Continuation exceeded its character bound');
 SELECT COUNT(*) INTO n FROM kcv_model_boundaries WHERE session_id=sid AND reason='MISSING_MODEL' AND old_conversation=conv AND new_conversation=new_conv;require(n=1,'Missing-model boundary absent or duplicated');
 require(DBMS_LOB.COMPARE(trace1,kcv_trace.response_trace(sid,first_turn))=0 AND DBMS_LOB.COMPARE(trace2,kcv_trace.response_trace(sid,second_turn))=0,'Historical response traces changed after expiry');
 require(answer_digest(first_turn)=answer1 AND answer_digest(second_turn)=answer2,'Historical answer bytes changed after expiry');
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE session_id=sid;require(n=3,'Unexpected number of model runs');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE session_id=sid AND mutation_token IS NULL;require(n=1,'Completed model run retained a lease');
 SELECT setting_value INTO profile_after FROM kcv_settings WHERE setting_key='AI_PROFILE';require(profile_after=profile_before AND profile_digest=profile_hash,'Original model profile changed');
 require(public_digest=public_before,'Public source text or metadata changed');
 DBMS_OUTPUT.PUT_LINE('GROUNDED_EXPIRY_CONTINUATION=PASS; model_requests=3; prior_turns=4; history_immutable=PASS; profile_preserved=PASS');
 cleanup;require(public_digest=public_before,'Cleanup changed public source content');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=cid;require(n=0,'Synthetic fixture remains');
 DBMS_OUTPUT.PUT_LINE('GROUNDED_CONTINUATION_FIXTURE_CLEANUP=PASS');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;DBMS_OUTPUT.PUT_LINE('GROUNDED_CONTINUATION_CLEANUP_AFTER_ERROR=PASS');EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('GROUNDED_CONTINUATION_CLEANUP_ERROR='||SQLCODE);END;
 RAISE;
END;
/
