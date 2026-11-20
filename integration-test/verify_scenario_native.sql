-- KCV_LAB on Serverless ONLY. Creates scenario overlays/conversations; no inference calls.
-- Do not describe a mock-service run of this script as native validation.
DECLARE
 sid VARCHAR2(40);req JSON_OBJECT_T:=JSON_OBJECT_T();packet JSON_OBJECT_T;ev JSON_ARRAY_T;row_json JSON_OBJECT_T;
 p3 BOOLEAN:=FALSE;p10 BOOLEAN:=FALSE;change_json JSON_OBJECT_T;reply CLOB;token VARCHAR2(40);oldbase VARCHAR2(128);newbase VARCHAR2(128);
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER')<>'KCV_LAB' THEN RAISE_APPLICATION_ERROR(-20150,'Run native acceptance as KCV_LAB on the target, not the isolated mock schema');END IF;
 sid:=kcv_scenario.open_session('CTX03');req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));
 ev:=packet.get_array('evidence');IF packet.get_array('graph_paths').get_size=0 THEN RAISE_APPLICATION_ERROR(-20151,'No native graph paths returned');END IF;
 FOR i IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(i) AS JSON_OBJECT_T);
   IF row_json.get_string('source_id')<>'S10' THEN RAISE_APPLICATION_ERROR(-20152,'Unexpected healthcare source');END IF;
   IF row_json.get_number('pdf_page')=3 THEN p3:=TRUE;END IF;IF row_json.get_number('pdf_page')=10 THEN p10:=TRUE;END IF;
 END LOOP;
 IF NOT p3 OR NOT p10 THEN RAISE_APPLICATION_ERROR(-20153,'Missing overview or disclaimer');END IF;
 sid:=kcv_scenario.open_session('CTX01');req.put('scenario_session',sid);packet:=JSON_OBJECT_T.parse(kcv_scenario.state(sid));oldbase:=packet.get_string('base_graph');
 reply:=kcv_scenario.stage_change(sid,'{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}');change_json:=JSON_OBJECT_T.parse(reply);token:=change_json.get_string('pending_change');
 reply:=kcv_scenario.apply_change(sid,token);packet:=JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(req.to_clob()));newbase:=packet.get_string('base_graph');
 IF oldbase<>newbase THEN RAISE_APPLICATION_ERROR(-20154,'Context refinement changed the pinned base');END IF;
 ev:=packet.get_array('evidence');FOR i IN 0..ev.get_size-1 LOOP row_json:=TREAT(ev.get(i) AS JSON_OBJECT_T);
   IF row_json.get_string('source_id')='S06' THEN RAISE_APPLICATION_ERROR(-20155,'Removed topic still selected the multicloud source');END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('PASS: native graph paths, healthcare qualifications and changed topic retrieval; base graph preserved');
END;
/
