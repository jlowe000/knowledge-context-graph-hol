-- Project owner on Serverless ONLY. KCV_SCHEMA bind: chosen owner, blank means KCV_LAB.
-- Run Statement without the final slash. Creates scenario overlays/conversations;
-- no inference calls. Existing scenario data is not deleted by this exercise.
-- Do not describe a mock-service run of this script as native validation.
DECLARE
 target_schema VARCHAR2(128):=NVL(UPPER(TRIM(:KCV_SCHEMA)),'KCV_LAB');mock_count PLS_INTEGER;
 sid VARCHAR2(40);req JSON_OBJECT_T:=JSON_OBJECT_T();packet JSON_OBJECT_T;ev JSON_ARRAY_T;row_json JSON_OBJECT_T;
 p3 BOOLEAN:=FALSE;p10 BOOLEAN:=FALSE;change_json JSON_OBJECT_T;reply CLOB;token VARCHAR2(40);oldbase VARCHAR2(128);newbase VARCHAR2(128);
 original_context JSON_OBJECT_T;refined_context JSON_OBJECT_T;original_preferences JSON_OBJECT_T;
BEGIN
 IF NOT REGEXP_LIKE(target_schema,'^KCV_[A-Z0-9_]{1,26}$','c')
   OR SYS_CONTEXT('USERENV','SESSION_USER')<>target_schema
   OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>target_schema THEN
   RAISE_APPLICATION_ERROR(-20150,'Sign in as the chosen project owner on Serverless; do not change CURRENT_SCHEMA to bypass this check');END IF;
 SELECT COUNT(*) INTO mock_count FROM user_objects WHERE object_name IN('SEM_APIS','DBMS_CLOUD_AI','DBMS_CLOUD_AI_AGENT');
 IF mock_count<>0 THEN RAISE_APPLICATION_ERROR(-20150,'Local service replacements cannot establish native Serverless acceptance');END IF;
 sid:=kcv_scenario.open_session('CTX03');req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));
 ev:=packet.get_array('evidence');IF packet.get_array('graph_paths').get_size=0 THEN RAISE_APPLICATION_ERROR(-20151,'No native graph paths returned');END IF;
 FOR i IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(i) AS JSON_OBJECT_T);
   -- Additional catalogue sources may fill the remaining slots. The original
   -- healthcare overview and qualification must still accompany this scenario.
   IF row_json.get_string('source_id')='S10' THEN
     IF row_json.get_number('pdf_page')=3 THEN p3:=TRUE;END IF;IF row_json.get_number('pdf_page')=10 THEN p10:=TRUE;END IF;
   END IF;
 END LOOP;
 IF NOT p3 OR NOT p10 THEN RAISE_APPLICATION_ERROR(-20153,'Missing overview or disclaimer');END IF;
 sid:=kcv_scenario.open_session('CTX01');req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));oldbase:=packet.get_string('base_graph');
 original_context:=packet.get_object('context');
 reply:=kcv_scenario.stage_change(sid,'{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}');change_json:=JSON_OBJECT_T.parse(reply);token:=change_json.get_string('pending_change');
 reply:=kcv_scenario.apply_change(sid,token);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));newbase:=packet.get_string('base_graph');
 IF oldbase<>newbase THEN RAISE_APPLICATION_ERROR(-20154,'Context refinement changed the pinned base');END IF;
 refined_context:=packet.get_object('context');
 IF refined_context.get_object('topic_preferences').has('Graph capabilities') THEN
   RAISE_APPLICATION_ERROR(-20156,'Removed topic remains in learning focus');END IF;
 original_preferences:=original_context.get_object('topic_preferences');original_preferences.remove('Graph capabilities');
 original_context.put('topic_preferences',original_preferences);
 IF DBMS_LOB.COMPARE(original_context.to_clob(),refined_context.to_clob())<>0 THEN
   RAISE_APPLICATION_ERROR(-20157,'Topic removal changed context beyond learning preferences');END IF;
 IF packet.get_string('context_semantics') IS NULL THEN
   RAISE_APPLICATION_ERROR(-20158,'Evidence packet does not explain learning-focus semantics');END IF;
 ev:=packet.get_array('evidence');FOR i IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(i) AS JSON_OBJECT_T);
   IF row_json.get_string('source_id')='S06' THEN RAISE_APPLICATION_ERROR(-20155,'Removed topic still selected the multicloud source');END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('PASS: native graph paths, healthcare qualifications and changed topic retrieval; base graph and explicit constraints preserved; learning-focus semantics supplied');
END;
/
