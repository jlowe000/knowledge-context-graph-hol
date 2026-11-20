-- TEST ONLY: run after fixture/mocks in KCV_HOL_TEST, not the live lab schema.
DECLARE
 sid VARCHAR2(40);req JSON_OBJECT_T:=JSON_OBJECT_T();packet JSON_OBJECT_T;proposal JSON_OBJECT_T;
 result CLOB;token VARCHAR2(40);oldrev VARCHAR2(40);newrev VARCHAR2(40);n NUMBER;count_before NUMBER;
 PROCEDURE assert_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'KCV_HOL_TEST' THEN RAISE_APPLICATION_ERROR(-20999,'Isolated test schema required');END IF;
 sid:=kcv_scenario.open_session('CTX01');req.put('scenario_session',sid);
 packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));
 assert_true(packet.get_array('graph_paths').get_size>0,'Missing returned graph paths');
 assert_true(packet.get_array('evidence').get_size<=6,'Evidence cap violated');
 oldrev:=packet.get_string('context_revision');
 SELECT COUNT(*) INTO count_before FROM kcv_scenario_revisions;
 result:=kcv_scenario.stage_change(sid,'{"operation":"SET_OBJECTIVE","objective":"Find existing project information; approval and workflow are out of scope"}');
 proposal:=JSON_OBJECT_T.parse(result);token:=proposal.get_string('pending_change');
 SELECT COUNT(*) INTO n FROM kcv_scenario_revisions;assert_true(n=count_before,'Staging must not mutate context');
 result:=kcv_scenario.apply_change(sid,token);packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));newrev:=packet.get_string('context_revision');
 assert_true(oldrev<>newrev,'Refinement did not create a revision');
 assert_true(packet.get_object('context').get_string('objective_clarity')='defined','Objective not persisted');
 BEGIN result:=kcv_scenario.apply_change(sid,token);RAISE_APPLICATION_ERROR(-20991,'Applied token replay accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20108 THEN RAISE;END IF;ROLLBACK;END;
 BEGIN result:=kcv_scenario.stage_change(sid,'{"operation":"ADD_TOPIC","topic":"Invented topic"}');RAISE_APPLICATION_ERROR(-20991,'Unknown topic accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20102 THEN RAISE;END IF;END;
 result:=kcv_scenario.stage_change(sid,'{"operation":"REMOVE_TOPIC","topic":"Embeddings"}');proposal:=JSON_OBJECT_T.parse(result);
 result:=kcv_scenario.apply_change(sid,proposal.get_string('pending_change'));
 packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));assert_true(NOT packet.get_object('context').get_object('topic_preferences').has('Embeddings'),'Topic still present');
 kcv_scenario.observe(sid,'dot_vote','Component-test fixture: different preferences were recorded','Check the source before drawing a factual conclusion');
 SELECT COUNT(*) INTO n FROM kcv_scenario_observations WHERE session_id=sid;assert_true(n=1,'Observation not recorded');
 UPDATE kcv_chat_sessions SET owner_name='ANOTHER_TEST_USER' WHERE session_id=sid;COMMIT;
 BEGIN result:=kcv_scenario.state(sid);RAISE_APPLICATION_ERROR(-20991,'Cross-owner access accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20100 THEN RAISE;END IF;END;
 UPDATE kcv_chat_sessions SET owner_name=COALESCE(SYS_CONTEXT('APEX$SESSION','APP_USER'),SYS_CONTEXT('USERENV','SESSION_USER')) WHERE session_id=sid;COMMIT;
 SELECT COUNT(*) INTO n FROM kcv_scenario_audit WHERE session_id=sid AND operation IN ('SET_OBJECTIVE','REMOVE_TOPIC');assert_true(n=2,'Missing change audit');
 result:=kcv_extract_domain('S02');packet:=JSON_OBJECT_T.parse(result);assert_true(packet.get_number('fact_count')=0,'Empty extraction should remain empty');
 DBMS_OUTPUT.PUT_LINE('PASS: isolated scenario components: paths, bounds, staged changes, revisions, replay protection, topic allow-list, ownership, observations, audit, empty extraction');
END;
/
