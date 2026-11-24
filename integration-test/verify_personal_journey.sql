-- C3 native integration: synthetic owner data, actual RDF and registered model
-- conversation metadata. No GENERATE/RUN_TEAM call and no source graph mutation.
-- Run only as the dedicated isolated schema owner, after the C3 migrations.
DECLARE
 prefix VARCHAR2(24):=SUBSTR(RAWTOHEX(SYS_GUID()),1,24);cid VARCHAR2(32);sid VARCHAR2(40);sid2 VARCHAR2(40);
 body JSON_OBJECT_T:=JSON_OBJECT_T();prefs JSON_OBJECT_T:=JSON_OBJECT_T();j JSON_OBJECT_T;other JSON_OBJECT_T;a JSON_ARRAY_T;
 result CLOB;packet_before CLOB;packet_after CLOB;rev1 VARCHAR2(40);rev2 VARCHAR2(40);token VARCHAR2(40);stale_token VARCHAR2(40);conv VARCHAR2(128);new_conv VARCHAR2(128);
 topic1 VARCHAR2(200);topic2 VARCHAR2(200);n NUMBER;before_sources NUMBER;before_passages NUMBER;first_turn NUMBER;ut NUMBER;eid VARCHAR2(40);
 collection_graph VARCHAR2(128);collection_created BOOLEAN:=FALSE;old_graph VARCHAR2(128);old_version NUMBER;selected_version VARCHAR2(128);selected_metadata CLOB;
 PROCEDURE check_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;END;
 FUNCTION req(p_sid VARCHAR2) RETURN CLOB IS x JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN x.put('scenario_session',p_sid);RETURN x.to_clob();END;
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
  DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token LIKE prefix||'%';
  DELETE FROM kcv_personal_contexts WHERE context_id=cid;COMMIT;
  FOR i IN 1..models.COUNT LOOP DBMS_CLOUD_AI.DROP_CONVERSATION(models(i),force=>TRUE);END LOOP;
  FOR i IN 1..graphs.COUNT LOOP SEM_APIS.DROP_RDF_GRAPH(graphs(i),network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END LOOP;
  IF collection_graph IS NOT NULL THEN
   DELETE FROM kcv_graph_sources WHERE graph_name=collection_graph;DELETE FROM kcv_graph_runs WHERE graph_name=collection_graph;COMMIT;
   IF collection_created THEN SEM_APIS.DROP_RDF_GRAPH(collection_graph,network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');END IF;
  END IF;
 END;
BEGIN
 check_true(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH'),'Use the isolated schema owner');
 SELECT COUNT(*) INTO before_sources FROM kcv_sources;SELECT COUNT(*) INTO before_passages FROM kcv_passages;
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.topic_options);a:=j.get_array('topics');check_true(a.get_size>=2,'Need two eligible public topics');topic1:=a.get_string(0);topic2:=a.get_string(1);
 body.put('question','Which public information would help a synthetic learner decide what to explore?');body.put('objective_clarity','emerging');prefs.put(topic1,2);body.put('topic_preferences',prefs);
 result:=kcv_personal_context_api.save_draft(NULL,'Synthetic C3 acceptance',body.to_clob(),NULL,prefix||'_create');j:=JSON_OBJECT_T.parse(result);cid:=j.get_string('context_id');
 result:=kcv_personal_journey.preview(cid,1);j:=JSON_OBJECT_T.parse(result);token:=j.get_string('token');
 check_true(j.get_object('before').get_size=0 AND j.get_object('after').get_string('question') IS NOT NULL,'Preview before/after invalid');
 SELECT COUNT(*) INTO n FROM kcv_scenario_revisions WHERE context_id=cid;check_true(n=0,'Preview published a revision');
 result:=kcv_personal_journey.apply_preview(cid,token);j:=JSON_OBJECT_T.parse(result);rev1:=j.get_string('revision');check_true(j.get_string('status')='APPLIED','Activation failed');
 result:=kcv_personal_journey.apply_preview(cid,token);j:=JSON_OBJECT_T.parse(result);check_true(j.get_string('revision')=rev1,'Apply retry changed revision');
 SELECT COUNT(*) INTO n FROM kcv_scenario_revisions WHERE context_id=cid;check_true(n=1,'Apply retry duplicated RDF publication');
 result:=kcv_personal_context_api.get_context(cid);j:=JSON_OBJECT_T.parse(result);check_true(NOT j.get_boolean('has_unapplied_changes'),'Activated draft still reported dirty');
 check_true(j.get_number('draft_version')=1,'Unchanged activation needlessly changed the saved draft version');
 sid:=kcv_personal_journey.start_conversation(cid,prefix||'_start');
 check_true(kcv_personal_journey.start_conversation(cid,prefix||'_start')=sid,'Start retry duplicated conversation');
 sid2:=kcv_personal_journey.start_conversation(cid,prefix||'_start2');check_true(sid<>sid2,'Second conversation was not separate');
 packet_before:=kcv_scenario.evidence_packet(req(sid));j:=JSON_OBJECT_T.parse(packet_before);check_true(j.get_array('evidence').get_size>0,'Selected eligible topic returned no native evidence');
 result:=kcv_personal_journey.preview(cid,1);j:=JSON_OBJECT_T.parse(result);stale_token:=j.get_string('token');
 body.put('objective','Only the framing has changed');result:=kcv_personal_context_api.save_draft(cid,'Synthetic C3 acceptance',body.to_clob(),1,prefix||'_save');
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.get_context(cid));check_true(j.get_boolean('has_unapplied_changes'),'Saved draft was confused with ready context');
 BEGIN result:=kcv_personal_journey.apply_preview(cid,stale_token);RAISE_APPLICATION_ERROR(-20991,'Stale preview accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,2));result:=kcv_personal_journey.apply_preview(cid,j.get_string('token'));j:=JSON_OBJECT_T.parse(result);rev2:=j.get_string('revision');
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(j.get_string('context_revision')=rev1 AND j.get_string('latest_revision')=rev2,'Other conversation silently adopted head');
 BEGIN kcv_personal_journey.adopt_head(sid,rev1,prefix||'_staleadopt',rev1);RAISE_APPLICATION_ERROR(-20991,'Unreviewed current head adopted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 kcv_personal_journey.adopt_head(sid,rev1,prefix||'_adopt',rev2);kcv_personal_journey.adopt_head(sid,rev1,prefix||'_adopt',rev2);
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(j.get_string('context_revision')=rev2,'Explicit adoption failed');
 packet_after:=kcv_scenario.evidence_packet(req(sid));j:=JSON_OBJECT_T.parse(packet_before);other:=JSON_OBJECT_T.parse(packet_after);
 check_true(DBMS_LOB.COMPARE(j.get_array('evidence').to_clob(),other.get_array('evidence').to_clob())=0,'Objective-only change altered selected evidence');
 check_true(other.get_object('selection_context').get_object('topics').has(topic1),'Selection explanation missing');
 check_true(other.get_object('interpretation_context').get_string('objective')='Only the framing has changed','Interpretation explanation missing');
 -- A changed topic changes the explicit graph selection; an existing conversation
 -- stays pinned until it is deliberately adopted.
 prefs:=JSON_OBJECT_T();prefs.put(topic2,2);body.put('topic_preferences',prefs);
 result:=kcv_personal_context_api.save_draft(cid,'Synthetic C3 acceptance',body.to_clob(),2,prefix||'_topics');
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,3));result:=kcv_personal_journey.apply_preview(cid,j.get_string('token'));
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(j.get_string('context_revision')=rev2,'Topic publication moved an existing conversation');
 -- Durable history, exact continuation bounds, and cursor ownership.
 FOR i IN 1..25 LOOP INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev2,'user',TO_CLOB('Synthetic turn '||i));END LOOP;COMMIT;
 a:=JSON_ARRAY_T.parse(kcv_personal_journey.history(sid));check_true(a.get_size=20,'First history page size invalid');j:=TREAT(a.get(0) AS JSON_OBJECT_T);first_turn:=j.get_number('turn_id');
 a:=JSON_ARRAY_T.parse(kcv_personal_journey.history(sid,first_turn));check_true(a.get_size=5,'Second history page lost older work');
 BEGIN result:=kcv_personal_journey.history(sid2,first_turn);RAISE_APPLICATION_ERROR(-20991,'Foreign history cursor accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.continuation(sid));check_true(j.get_array('turns_newest_first').get_size=8 AND j.get_number('included_characters')<=8000,'Continuation bound failed');
 kcv_scenario.observe(sid,'discussion','Synthetic discussion note','Review sources',prefix||'_observe');
 kcv_scenario.observe(sid,'discussion','Synthetic discussion note','Review sources',prefix||'_observe');
 SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id=sid;check_true(n=1,'Observation retry duplicated data');
 SELECT conversation_id INTO conv FROM kcv_chat_sessions WHERE session_id=sid;DBMS_CLOUD_AI.DROP_CONVERSATION(conv);
 kcv_personal_journey.ensure_model(sid);SELECT conversation_id INTO new_conv FROM kcv_chat_sessions WHERE session_id=sid;
 check_true(new_conv<>conv,'Confirmed missing model conversation was not replaced');
 SELECT COUNT(*) INTO n FROM kcv_model_boundaries WHERE session_id=sid AND reason='MISSING_MODEL' AND old_conversation=conv AND new_conversation=new_conv;check_true(n=1,'Expiry boundary not recorded');
 -- Interrupted model submission cannot be replayed silently.
 eid:='E'||RAWTOHEX(SYS_GUID());INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev2,'user','Synthetic uncertain request') RETURNING turn_id INTO ut;
 INSERT INTO kcv_response_runs(execution_id,session_id,revision_id,conversation_id,user_turn_id,request_mode,question,context_json,sources_json,history_json,status)
  SELECT eid,sid,rev2,new_conv,ut,'question','Synthetic uncertain request',context_json,'[]','[]','UNCERTAIN' FROM kcv_scenario_revisions WHERE revision_id=rev2;
 UPDATE kcv_chat_sessions SET mutation_token=eid WHERE session_id=sid;COMMIT;
 BEGIN result:=kcv_personal_context_api.archive_context(cid,3,prefix||'_busyarchive');RAISE_APPLICATION_ERROR(-20991,'Archive ignored a pending answer');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 kcv_personal_journey.recover_response(sid,eid);kcv_personal_journey.recover_response(sid,eid);SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE execution_id=eid AND status='ABANDONED';check_true(n=1,'Explicit response recovery not recorded');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE session_id=sid AND mutation_token IS NULL;check_true(n=1,'Recovery did not release the finished worker lease');
 result:=kcv_personal_context_api.archive_context(cid,3,prefix||'_archive');
 DELETE FROM kcv_context_attachments WHERE session_id=sid;COMMIT;kcv_personal_journey.open_conversation(sid);
 j:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));check_true(j.get_boolean('read_only'),'Archived reopened conversation was not read-only');
 result:=kcv_personal_journey.history(sid);check_true(result IS NOT NULL,'Archived history not readable');
 BEGIN kcv_scenario.observe(sid,'other','Must fail',NULL,prefix||'_archivedobs');RAISE_APPLICATION_ERROR(-20991,'Archived observation accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20243 THEN RAISE;END IF;END;
 result:=kcv_personal_context_api.restore_context(cid,4,prefix||'_restore');
 -- A collection-only adoption is an editor-visible change even when its topics
 -- and draft body overlap exactly. Use a disposable RDF collection and reuse
 -- one immutable public metadata row; do not change any source/passage content.
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.get_context(cid));old_graph:=j.get_string('base_graph');old_version:=j.get_number('draft_version');
 SELECT gs.version_id,gs.metadata_json INTO selected_version,selected_metadata FROM kcv_graph_sources gs
  WHERE gs.graph_name=old_graph AND EXISTS(SELECT 1 FROM JSON_TABLE(gs.metadata_json,'$.topics[*]' COLUMNS(label VARCHAR2(200) PATH '$')) t WHERE t.label=topic2)
  AND (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER)>0 OR
   (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER) IS NULL AND REGEXP_LIKE(gs.version_id,'^S[0-9]+-v') AND EXISTS(SELECT 1 FROM kcv_passages p WHERE p.version_id=gs.version_id)))
  FETCH FIRST 1 ROW ONLY;
 collection_graph:='KCV_TC_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);
 SEM_APIS.CREATE_RDF_GRAPH(collection_graph,NULL,NULL,network_owner=>SYS_CONTEXT('USERENV','SESSION_USER'),network_name=>'KCV_NET');collection_created:=TRUE;
 INSERT INTO kcv_graph_runs(graph_name,graph_hash,state) VALUES(collection_graph,LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(TO_CLOB(collection_graph),DBMS_CRYPTO.HASH_SH256))),'READY');
 INSERT INTO kcv_graph_sources(graph_name,version_id,metadata_json) VALUES(collection_graph,selected_version,selected_metadata);COMMIT;
 j:=JSON_OBJECT_T.parse(kcv_personal_journey.preview(cid,old_version,p_collection=>collection_graph));result:=kcv_personal_journey.apply_preview(cid,j.get_string('token'));
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.get_context(cid));check_true(j.get_string('base_graph')=collection_graph AND j.get_number('draft_version')=old_version+1,'Collection-only adoption did not advance the editor version');
 BEGIN result:=kcv_personal_context_api.save_draft(cid,'Synthetic C3 acceptance',body.to_clob(),old_version,prefix||'_staleedit');RAISE_APPLICATION_ERROR(-20991,'Old editor overwrote an adopted collection');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 cleanup;
 SELECT COUNT(*) INTO n FROM kcv_sources;check_true(n=before_sources,'Public sources changed');SELECT COUNT(*) INTO n FROM kcv_passages;check_true(n=before_passages,'Public passages changed');
 DBMS_OUTPUT.PUT_LINE('PASS: C3 native activation, idempotent publication/start, stale preview, pinned adoption, unchanged objective-only evidence, topic publication, pagination, continuation, observations, expiry, uncertainty recovery, archive and collection-only editor fencing');
 DBMS_OUTPUT.PUT_LINE('NOT COVERED: real model generation, independent-session concurrency and authenticated browser acceptance');
EXCEPTION WHEN OTHERS THEN
 BEGIN cleanup;EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Synthetic fixture cleanup needs review: '||SQLCODE);END;
 RAISE;
END;
/
