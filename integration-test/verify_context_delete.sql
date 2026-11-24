-- Run only in the isolated schema after the deletion migrations.
-- Creates synthetic private contexts and native RDF/conversation metadata only;
-- no model inference, no public collection mutation, no existing context deletion.
-- A fixture-only trigger interrupts the final relational deletion to verify
-- durable PENDING recovery after irreversible native resource cleanup.
DECLARE
 prefix VARCHAR2(24):=SUBSTR(RAWTOHEX(SYS_GUID()),1,24);
 cid VARCHAR2(32);control_id VARCHAR2(32);sid VARCHAR2(40);rev VARCHAR2(40);g VARCHAR2(128);old_model VARCHAR2(128);current_model VARCHAR2(128);
 trigger_name VARCHAR2(30):='KCV_DT_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,20);trigger_created BOOLEAN:=FALSE;
 body JSON_OBJECT_T:=JSON_OBJECT_T();prefs JSON_OBJECT_T:=JSON_OBJECT_T();j JSON_OBJECT_T;p JSON_OBJECT_T;orig JSON_OBJECT_T;
 result CLOB;create_body CLOB;token VARCHAR2(80);topic VARCHAR2(200);n NUMBER;lock_id PLS_INTEGER;lock_result PLS_INTEGER;held BOOLEAN:=FALSE;
 ut NUMBER;aturn NUMBER;eid VARCHAR2(40):='E'||RAWTOHEX(SYS_GUID());before_sources NUMBER;before_passages NUMBER;before_graphs NUMBER;
 owner_scope VARCHAR2(128):=kcv_access.owner_scope;owner_subject VARCHAR2(128):=kcv_access.owner_subject;
 PROCEDURE ok(v BOOLEAN,msg VARCHAR2) IS BEGIN IF v IS NULL OR NOT v THEN RAISE_APPLICATION_ERROR(-20990,msg);END IF;END;
 FUNCTION remove_confirmed(c VARCHAR2,pv JSON_OBJECT_T,t VARCHAR2) RETURN CLOB IS BEGIN
  RETURN kcv_context_delete.delete_context(c,pv.get_number('expected_version'),pv.get_string('expected_head'),pv.get_string('preview_digest'),t);
 END;
 PROCEDURE drop_test_trigger IS BEGIN
  IF trigger_created THEN EXECUTE IMMEDIATE 'DROP TRIGGER '||DBMS_ASSERT.SIMPLE_SQL_NAME(trigger_name);trigger_created:=FALSE;END IF;
 END;
 PROCEDURE clean_fixture(c VARCHAR2) IS pv JSON_OBJECT_T;res JSON_OBJECT_T;del_token VARCHAR2(80);BEGIN
  IF c IS NULL THEN RETURN;END IF;
  -- The only temporary identity change uses a distinct literal below; restore
  -- it explicitly so cleanup cannot accidentally adopt an existing account.
  UPDATE kcv_personal_contexts SET owner_scope=kcv_access.owner_scope,owner_subject=kcv_access.owner_subject WHERE context_id=c AND owner_subject='SYNTHETIC_DELETE_OTHER';
  UPDATE kcv_chat_sessions SET mutation_token=NULL WHERE personal_context_id=c;COMMIT;
  SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=c;
  IF n=1 THEN
   pv:=JSON_OBJECT_T.parse(kcv_context_delete.preview(c));del_token:=pv.get_string('request_token');IF del_token IS NULL THEN del_token:=prefix||'_cleanup_'||SUBSTR(c,2,8);END IF;
   res:=JSON_OBJECT_T.parse(remove_confirmed(c,pv,del_token));ok(res.get_string('status')='DELETED','Fixture cleanup remains pending');
  END IF;
  DELETE FROM kcv_context_delete_resources WHERE context_id=c;
  DELETE FROM kcv_context_deletions WHERE context_id=c AND owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject;
 END;
BEGIN
 ok(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH'),'Use an isolated test schema owner');
 SELECT COUNT(*) INTO before_sources FROM kcv_sources;SELECT COUNT(*) INTO before_passages FROM kcv_passages;SELECT COUNT(*) INTO before_graphs FROM kcv_graph_runs;
 j:=JSON_OBJECT_T.parse(kcv_personal_context_api.topic_options);topic:=j.get_array('topics').get_string(0);
 body.put('question','Synthetic deletion fixture: what should I learn?');body.put('objective_clarity','emerging');prefs.put(topic,2);body.put('topic_preferences',prefs);create_body:=body.to_clob();
 result:=kcv_personal_context_api.save_draft(NULL,'Synthetic deletion fixture',create_body,NULL,prefix||'_create');j:=JSON_OBJECT_T.parse(result);cid:=j.get_string('context_id');
 result:=kcv_personal_context_api.duplicate_context(cid,'Synthetic independent copy',prefix||'_copy');j:=JSON_OBJECT_T.parse(result);control_id:=j.get_string('context_id');
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));ok(p.get_string('status')='READY' AND p.get_object('counts').get_number('conversations')=0,'Draft preview invalid');
 result:=kcv_personal_context_api.save_draft(cid,'Synthetic revised title',create_body,1,prefix||'_edit');
 BEGIN result:=remove_confirmed(cid,p,prefix||'_stale');RAISE_APPLICATION_ERROR(-20990,'Stale version deleted context');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 UPDATE kcv_personal_contexts SET owner_subject='SYNTHETIC_DELETE_OTHER' WHERE context_id=cid;COMMIT;
 BEGIN result:=kcv_context_delete.preview(cid);RAISE_APPLICATION_ERROR(-20990,'Cross-owner preview succeeded');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 BEGIN result:=remove_confirmed(cid,p,prefix||'_other');RAISE_APPLICATION_ERROR(-20990,'Cross-owner deletion succeeded');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 UPDATE kcv_personal_contexts SET owner_subject=kcv_access.owner_subject WHERE context_id=cid;COMMIT;
 result:=kcv_personal_journey.preview(cid,2);j:=JSON_OBJECT_T.parse(result);result:=kcv_personal_journey.apply_preview(cid,j.get_string('token'));
 sid:=kcv_personal_journey.start_conversation(cid,prefix||'_start');SELECT revision_id,conversation_id INTO rev,current_model FROM kcv_chat_sessions WHERE session_id=sid;
 SELECT overlay_graph INTO g FROM kcv_scenario_revisions WHERE revision_id=rev;
 old_model:=DBMS_CLOUD_AI.CREATE_CONVERSATION(attributes=>'{"title":"Synthetic historical deletion fixture","retention_days":1}');
 INSERT INTO kcv_model_boundaries(session_id,old_conversation,new_conversation,reason,old_revision,new_revision,history_json)
  VALUES(sid,old_model,current_model,'MISSING_MODEL',rev,rev,'{}');
 INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev,'user','Synthetic private question') RETURNING turn_id INTO ut;
 INSERT INTO kcv_chat_turns(session_id,revision_id,role,body) VALUES(sid,rev,'assistant','Synthetic private answer') RETURNING turn_id INTO aturn;
 INSERT INTO kcv_response_runs(execution_id,session_id,revision_id,conversation_id,user_turn_id,assistant_turn_id,request_mode,question,context_json,sources_json,history_json,status)
  VALUES(eid,sid,rev,current_model,ut,aturn,'question','Synthetic private question','{}','[]','[]','COMPLETED');
 INSERT INTO kcv_response_tool_calls(execution_id,tool_name,input_json,output_json,status,started_at,call_origin)
  VALUES(eid,'EVIDENCE','{}','{"synthetic":true}','SUCCEEDED',SYSTIMESTAMP,'APPLICATION');COMMIT;
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));
 kcv_scenario.observe(sid,'source_check','Synthetic later observation','Review another source',prefix||'_observe');
 BEGIN result:=remove_confirmed(cid,p,prefix||'_late');RAISE_APPLICATION_ERROR(-20990,'New observation did not invalidate deletion preview');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 UPDATE kcv_chat_sessions SET mutation_token='SYNTHETIC_BUSY' WHERE session_id=sid;COMMIT;
 BEGIN result:=kcv_context_delete.preview(cid);RAISE_APPLICATION_ERROR(-20990,'Busy response accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 UPDATE kcv_chat_sessions SET mutation_token=NULL WHERE session_id=sid;COMMIT;
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_PERSONAL:'||cid,1,1073741823);
 lock_result:=DBMS_LOCK.REQUEST(lock_id,DBMS_LOCK.X_MODE,0,FALSE);ok(lock_result=0,'Fixture context lock unavailable');held:=TRUE;
 BEGIN result:=remove_confirmed(cid,p,prefix||'_locked');RAISE_APPLICATION_ERROR(-20990,'Nested held context was deleted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 lock_result:=DBMS_LOCK.RELEASE(lock_id);held:=FALSE;
 -- A corrupted/unsafe manifest must fail before any native resource is removed.
 UPDATE kcv_personal_contexts SET base_graph=g WHERE context_id=control_id;COMMIT;
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));
 BEGIN result:=remove_confirmed(cid,p,prefix||'_shared');RAISE_APPLICATION_ERROR(-20990,'Shared graph reference was deleted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20249 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_context_deletions WHERE context_id=cid;ok(n=0,'Scope failure left irreversible deletion journal');
 UPDATE kcv_personal_contexts SET base_graph=(SELECT base_graph FROM kcv_personal_contexts WHERE context_id=cid) WHERE context_id=control_id;COMMIT;
 -- Archived contexts can be deleted directly, without restoring their content.
 result:=kcv_personal_context_api.archive_context(cid,2,prefix||'_archive');
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));orig:=p;
 ok(p.get_object('counts').get_number('conversations')=1 AND p.get_object('counts').get_number('turns')=2 AND p.get_object('counts').get_number('observations')=1 AND p.get_object('counts').get_number('model_conversations')=2,'Confirmation inventory incomplete');
 EXECUTE IMMEDIATE 'CREATE TRIGGER '||DBMS_ASSERT.SIMPLE_SQL_NAME(trigger_name)||' BEFORE DELETE ON kcv_personal_contexts FOR EACH ROW BEGIN IF :OLD.context_id='||DBMS_ASSERT.ENQUOTE_LITERAL(cid)||' THEN RAISE_APPLICATION_ERROR(-20991,''Synthetic final-delete interruption''); END IF; END;';trigger_created:=TRUE;
 token:=prefix||'_delete';result:=remove_confirmed(cid,p,token);j:=JSON_OBJECT_T.parse(result);
 ok(j.get_string('status')='PENDING' AND j.get_number('error_code')=-20991,'Interrupted deletion falsely reported success');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=cid;ok(n=1,'Interrupted deletion lost recoverable context row');
 SELECT COUNT(*) INTO n FROM user_cloud_ai_conversations WHERE conversation_id IN(current_model,old_model);ok(n=0,'Associated model conversations remain');
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM KCV_NET#SEM_MODEL$ WHERE model_name=:g' INTO n USING g;ok(n=0,'Private RDF overlay remains');
 BEGIN result:=kcv_personal_context_api.get_context(cid);RAISE_APPLICATION_ERROR(-20990,'Pending deletion exposed context');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.topic_options(cid);RAISE_APPLICATION_ERROR(-20990,'Pending deletion exposed context topics');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_journey.history(sid);RAISE_APPLICATION_ERROR(-20990,'Pending deletion exposed history');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 BEGIN kcv_personal_journey.open_conversation(sid);RAISE_APPLICATION_ERROR(-20990,'Pending deletion reopened conversation');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.duplicate_context(cid,'Forbidden pending copy',prefix||'_badcopy');RAISE_APPLICATION_ERROR(-20990,'Pending deletion duplicated context');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.save_draft(NULL,'Synthetic deletion fixture',create_body,NULL,prefix||'_create');RAISE_APPLICATION_ERROR(-20990,'Pending deletion replay exposed private snapshot');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 p:=JSON_OBJECT_T.parse(kcv_context_delete.preview(cid));ok(p.get_string('status')='PENDING' AND p.get_string('request_token')=token AND p.get_string('preview_digest')=orig.get_string('preview_digest'),'Pending retry lost original confirmation');
 BEGIN result:=remove_confirmed(cid,p,prefix||'_wrongretry');RAISE_APPLICATION_ERROR(-20990,'Wrong deletion token accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 drop_test_trigger;
 result:=remove_confirmed(cid,p,token);j:=JSON_OBJECT_T.parse(result);ok(j.get_string('status')='DELETED','Confirmed retry did not finish');
 result:=remove_confirmed(cid,p,token);j:=JSON_OBJECT_T.parse(result);ok(j.get_string('status')='DELETED','Completed deletion not idempotent');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE context_id=cid;ok(n=0,'Context survived successful deletion');
 SELECT COUNT(*) INTO n FROM kcv_scenario_revisions WHERE context_id=cid;ok(n=0,'Revisions survived');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions WHERE personal_context_id=cid;ok(n=0,'Conversations survived');
 SELECT COUNT(*) INTO n FROM kcv_personal_operations WHERE context_id=cid;ok(n=0,'Publication journal survived');
 SELECT COUNT(*) INTO n FROM kcv_response_runs WHERE session_id=sid;ok(n=0,'Response survived');
 SELECT COUNT(*) INTO n FROM kcv_response_tool_calls WHERE execution_id=eid;ok(n=0,'Evidence survived');
 SELECT COUNT(*) INTO n FROM kcv_chat_turns WHERE session_id=sid;ok(n=0,'Turns survived');
 SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id=sid;ok(n=0,'Observations survived');
 SELECT COUNT(*) INTO n FROM kcv_context_attachments WHERE session_id=sid;ok(n=0,'Attachments survived');
 SELECT COUNT(*) INTO n FROM kcv_model_boundaries WHERE session_id=sid;ok(n=0,'Model boundaries survived');
 SELECT COUNT(*) INTO n FROM kcv_context_delete_resources WHERE context_id=cid;ok(n=0,'Completed resource manifest not scrubbed');
 SELECT COUNT(*) INTO n FROM kcv_context_deletions WHERE context_id=cid AND title IS NULL AND status='DELETED';ok(n=1,'Completed receipt retained title');
 SELECT COUNT(*) INTO n FROM kcv_context_requests WHERE request_token=prefix||'_create' AND JSON_VALUE(result_json,'$.status')='DELETED' AND DBMS_LOB.GETLENGTH(result_json)<100;ok(n=1,'Old replay snapshot not sanitized');
 BEGIN result:=kcv_personal_context_api.save_draft(NULL,'Synthetic deletion fixture',create_body,NULL,prefix||'_create');RAISE_APPLICATION_ERROR(-20990,'Completed stale creation recreated context');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 result:=kcv_personal_context_api.get_context(control_id);j:=JSON_OBJECT_T.parse(result);ok(j.get_string('title')='Synthetic independent copy','Independent copy was deleted');
 SELECT COUNT(*) INTO n FROM kcv_sources;ok(n=before_sources,'Public source count changed');SELECT COUNT(*) INTO n FROM kcv_passages;ok(n=before_passages,'Public passage count changed');SELECT COUNT(*) INTO n FROM kcv_graph_runs;ok(n=before_graphs,'Shared collection count changed');
 clean_fixture(control_id);clean_fixture(cid);
 DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token LIKE prefix||'%';COMMIT;
 DBMS_OUTPUT.PUT_LINE('CONTEXT_DELETE_PASS: ownership, stale history, locks, archived deletion, scope guard, pending recovery, replay privacy, native cleanup, independent copy preserved');
EXCEPTION WHEN OTHERS THEN
 IF held THEN lock_result:=DBMS_LOCK.RELEASE(lock_id);END IF;
 drop_test_trigger;
 -- Only the two IDs created above are eligible for failure cleanup.
 IF control_id IS NOT NULL THEN UPDATE kcv_personal_contexts SET base_graph=(SELECT setting_value FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH') WHERE context_id=control_id;COMMIT;END IF;
 clean_fixture(control_id);clean_fixture(cid);
 DELETE FROM kcv_context_requests WHERE owner_scope=kcv_access.owner_scope AND owner_subject=kcv_access.owner_subject AND request_token LIKE prefix||'%';COMMIT;
 RAISE;
END;
/
