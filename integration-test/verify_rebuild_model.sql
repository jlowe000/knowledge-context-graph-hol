-- KCV_LAB on real Serverless ONLY. Makes TWO billable model requests.
-- Creates its own fictional Alex session; never installs or uses local mocks.
DECLARE
 sid VARCHAR2(40); reply CLOB; old_trace CLOB; new_trace CLOB;
 first_turn NUMBER; second_turn NUMBER; old_revision VARCHAR2(40);
 j JSON_OBJECT_T; plan JSON_OBJECT_T; token VARCHAR2(40);
 PROCEDURE require(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
  IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20230,p_message); END IF;
 END;
 FUNCTION latest_turn RETURN NUMBER IS n NUMBER; BEGIN
  SELECT MAX(turn_id) INTO n FROM kcv_chat_turns WHERE session_id=sid AND role='assistant';RETURN n;
 END;
 FUNCTION has_source(p_trace CLOB,p_source VARCHAR2) RETURN BOOLEAN IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_trace);calls JSON_ARRAY_T:=t.get_array('tool_calls');
  c JSON_OBJECT_T;o JSON_OBJECT_T;e JSON_ARRAY_T;r JSON_OBJECT_T;
 BEGIN
  FOR i IN 0..calls.get_size-1 LOOP
   c:=TREAT(calls.get(i) AS JSON_OBJECT_T);
   IF c.get_string('tool')='EVIDENCE' AND c.get_string('status')='SUCCEEDED' THEN
    o:=c.get_object('output');e:=o.get_array('evidence');
    FOR k IN 0..e.get_size-1 LOOP
     r:=TREAT(e.get(k) AS JSON_OBJECT_T);
     IF r.get_string('source_id')=p_source THEN RETURN TRUE; END IF;
    END LOOP;
   END IF;
  END LOOP;
  RETURN FALSE;
 END;
 PROCEDURE check_trace(p_trace CLOB) IS
  t JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_trace);c JSON_ARRAY_T:=t.get_array('citations');r JSON_OBJECT_T;
 BEGIN
  require(t.get_string('availability')='RECORDED','Missing recorded trace');
  require(t.get_string('status')='COMPLETED','Model/tool run was not completed');
  require(t.get_array('tool_calls').get_size>0,'No actual tool calls captured');
  require(t.get_string('citation_parse_status')='PARSED','Structured citations could not be parsed');
  require(c.get_size>0,'Model returned no explicit citation IDs');
  FOR i IN 0..c.get_size-1 LOOP
   r:=TREAT(c.get(i) AS JSON_OBJECT_T);require(r.get_boolean('matched'),'Citation was not in actual returned evidence');
  END LOOP;
 END;
BEGIN
 require(SYS_CONTEXT('USERENV','SESSION_USER')='KCV_LAB','Run only as the real lab owner, not the mock schema');
 sid:=kcv_scenario.open_session('CTX01');
 reply:=kcv_scenario.ask(sid,'Which supplied sources could help Alex find existing project information? Distinguish source statements from proposed relevance, preserve availability limits, and cite exact returned evidence IDs.');
 first_turn:=latest_turn;old_trace:=kcv_trace.response_trace(sid,first_turn);check_trace(old_trace);
 j:=JSON_OBJECT_T.parse(old_trace);old_revision:=j.get_string('revision_id');
 require(has_source(old_trace,'S06'),'Expected original S06 evidence');
 plan:=JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,'{"operation":"REMOVE_TOPIC","topic":"Graph capabilities"}'));
 token:=plan.get_string('pending_change');reply:=kcv_scenario.apply_change(sid,token);
 reply:=kcv_scenario.ask(sid,'With Graph capabilities removed from the stored context, which returned sources should Alex explore first, and what remains unproven? Cite exact returned evidence IDs.');
 second_turn:=latest_turn;new_trace:=kcv_trace.response_trace(sid,second_turn);check_trace(new_trace);
 j:=JSON_OBJECT_T.parse(new_trace);require(j.get_string('revision_id')<>old_revision,'Follow-up used the old revision');
 require(NOT has_source(new_trace,'S06'),'Removed topic still returned S06');
 require(has_source(new_trace,'S08'),'Expected S08 in refined evidence');
 require(DBMS_LOB.COMPARE(old_trace,kcv_trace.response_trace(sid,first_turn))=0,'Historical trace changed after refinement');
 kcv_scenario.observe(sid,'practical_test',
  'Automated native verification checked two real model runs, captured tool evidence and citation matching; S06 left and S08 entered after topic removal, while the historical trace stayed unchanged.',
  'Inspect the original public pages and answer wording; traceability and changed selection do not establish business value.');
 DBMS_OUTPUT.PUT_LINE('Session: '||sid||'; assistant turns: '||first_turn||', '||second_turn);
 DBMS_OUTPUT.PUT_LINE('PASS: two real model answers, actual tool capture, matched citations, changed retrieval, historical immutability and saved observation');
END;
/
