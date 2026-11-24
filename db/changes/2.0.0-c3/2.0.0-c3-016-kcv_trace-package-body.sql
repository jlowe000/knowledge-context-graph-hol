CREATE OR REPLACE PACKAGE BODY kcv_trace AS
 PROCEDURE own_session(p_session VARCHAR2) IS BEGIN kcv_access.assert_session(p_session);END;
 PROCEDURE assert_run(p_request CLOB) IS sid VARCHAR2(40);eid VARCHAR2(40);n NUMBER;BEGIN
  sid:=JSON_VALUE(p_request,'$.scenario_session');eid:=JSON_VALUE(p_request,'$.execution_id');own_session(sid);
  SELECT COUNT(*) INTO n FROM kcv_response_runs r JOIN kcv_chat_sessions s ON s.session_id=r.session_id
   WHERE r.execution_id=eid AND r.session_id=sid AND r.status='RUNNING'
   AND s.mutation_token=eid AND s.revision_id=r.revision_id
   AND r.request_mode=JSON_VALUE(p_request,'$.task')
   AND DBMS_LOB.COMPARE(r.question,TO_CLOB(JSON_VALUE(p_request,'$.question' RETURNING VARCHAR2(8000))))=0;
  IF n<>1 THEN RAISE_APPLICATION_ERROR(-20170,'Invalid or inactive response execution');END IF;
 END;
 PROCEDURE record_tool(p_request CLOB,p_tool VARCHAR2,p_output CLOB,p_started TIMESTAMP WITH TIME ZONE,p_error NUMBER DEFAULT NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;eid VARCHAR2(40);j JSON_ELEMENT_T;
 BEGIN
  assert_run(p_request);eid:=JSON_VALUE(p_request,'$.execution_id');
  IF p_tool NOT IN ('EVIDENCE','PROPOSAL') THEN RAISE_APPLICATION_ERROR(-20171,'Unknown trace tool');END IF;
  IF p_output IS NOT NULL THEN
   IF DBMS_LOB.GETLENGTH(p_output)>1000000 THEN RAISE_APPLICATION_ERROR(-20172,'Evidence trace exceeds capture limit');END IF;
   j:=JSON_ELEMENT_T.parse(p_output);
  END IF;
  INSERT INTO kcv_response_tool_calls(execution_id,tool_name,input_json,output_json,status,error_code,started_at)
   VALUES(eid,p_tool,p_request,p_output,CASE WHEN p_error IS NULL THEN 'SUCCEEDED' ELSE 'FAILED' END,p_error,p_started);
  COMMIT;
 EXCEPTION WHEN OTHERS THEN ROLLBACK;RAISE;
 END;
 FUNCTION response_trace(p_session VARCHAR2,p_turn NUMBER) RETURN CLOB IS
  r kcv_response_runs%ROWTYPE;result JSON_OBJECT_T:=JSON_OBJECT_T();obj JSON_OBJECT_T;
  calls JSON_ARRAY_T:=JSON_ARRAY_T();cites JSON_ARRAY_T:=JSON_ARRAY_T();j JSON_OBJECT_T;
  ev JSON_ARRAY_T;cit JSON_ARRAY_T;packet JSON_OBJECT_T;row_j JSON_OBJECT_T;
  TYPE seen_t IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(4000);supplied seen_t;seen seen_t;
  answer CLOB;clean CLOB;cid VARCHAR2(4000);rev VARCHAR2(40);last_pos NUMBER;parse_state VARCHAR2(32):='UNAVAILABLE';
  PROCEDURE visit(p_node JSON_ELEMENT_T,p_depth PLS_INTEGER DEFAULT 0) IS
   o JSON_OBJECT_T;a JSON_ARRAY_T;ks JSON_KEY_LIST;v JSON_ELEMENT_T;id_text VARCHAR2(4000);entry JSON_OBJECT_T;citation_obj JSON_OBJECT_T;
   id_keys JSON_KEY_LIST:=JSON_KEY_LIST('id','passage_id','evidence_id');candidate VARCHAR2(4000);invalid_id BOOLEAN;
  BEGIN
   IF p_depth>32 THEN parse_state:='PARTIAL';RETURN;END IF;
   IF p_node.is_object THEN
    o:=TREAT(p_node AS JSON_OBJECT_T);ks:=o.get_keys;
    FOR k IN 1..ks.COUNT LOOP
     v:=o.get(ks(k));
     IF LOWER(ks(k))='citations' THEN
      IF v.is_array THEN
       a:=TREAT(v AS JSON_ARRAY_T);IF parse_state<>'PARTIAL' THEN parse_state:='PARSED';END IF;
       FOR x IN 0..a.get_size-1 LOOP
        id_text:=NULL;v:=a.get(x);
        IF v.is_string THEN id_text:=a.get_string(x);
        ELSIF v.is_object THEN
         citation_obj:=TREAT(v AS JSON_OBJECT_T);invalid_id:=FALSE;
         FOR key_i IN 1..id_keys.COUNT LOOP
          IF citation_obj.has(id_keys(key_i)) THEN
           IF citation_obj.get(id_keys(key_i)).is_string THEN
            candidate:=citation_obj.get_string(id_keys(key_i));
            IF candidate IS NULL OR (id_text IS NOT NULL AND candidate<>id_text) THEN invalid_id:=TRUE;
            ELSE id_text:=candidate;END IF;
           ELSE invalid_id:=TRUE;END IF;
          END IF;
         END LOOP;
         IF invalid_id THEN id_text:=NULL;END IF;
        END IF;
        IF id_text IS NULL THEN parse_state:='PARTIAL';
        ELSIF NOT seen.EXISTS(id_text) THEN
          entry:=JSON_OBJECT_T();entry.put('id',id_text);entry.put('matched',supplied.EXISTS(id_text));cites.append(entry);seen(id_text):=1;
        END IF;
       END LOOP;
      ELSE parse_state:='PARTIAL';END IF;
     ELSE visit(v,p_depth+1);END IF;
    END LOOP;
   ELSIF p_node.is_array THEN
    a:=TREAT(p_node AS JSON_ARRAY_T);FOR x IN 0..a.get_size-1 LOOP visit(a.get(x),p_depth+1);END LOOP;
   END IF;
  END;
 BEGIN
  own_session(p_session);
  SELECT body,revision_id INTO answer,rev FROM kcv_chat_turns WHERE turn_id=p_turn AND session_id=p_session AND role='assistant';
  BEGIN SELECT * INTO r FROM kcv_response_runs WHERE session_id=p_session AND assistant_turn_id=p_turn;
  EXCEPTION WHEN NO_DATA_FOUND THEN
   result.put('availability','LEGACY');result.put('revision_id',rev);
   result.put('message','Saved process details are unavailable for this earlier response. Current evidence is not a historical trace.');RETURN result.to_clob();END;
  result.put('availability','RECORDED');result.put('execution_id',r.execution_id);result.put('revision_id',r.revision_id);
  result.put('question',r.question);result.put('mode',r.request_mode);result.put('status',r.status);result.put('conversation_id',r.conversation_id);
  result.put('context',JSON_OBJECT_T.parse(r.context_json));result.put('sources',JSON_ARRAY_T.parse(r.sources_json));
  result.put('history_turn_ids',JSON_ARRAY_T.parse(r.history_json));result.put('profile_name',r.profile_name);
  IF r.continuation_json IS NOT NULL THEN result.put('supplied_continuation',JSON_OBJECT_T.parse(r.continuation_json));END IF;
  DECLARE selection JSON_OBJECT_T:=JSON_OBJECT_T();framing JSON_OBJECT_T:=JSON_OBJECT_T.parse(r.context_json);g VARCHAR2(128);BEGIN
   SELECT base_graph INTO g FROM kcv_scenario_revisions WHERE revision_id=r.revision_id;
   selection.put('collection',g);selection.put('topics',framing.get_object('topic_preferences'));selection.put('match','any selected topic');selection.put('weights_used_for_ranking',FALSE);
   framing.remove('topic_preferences');result.put('selection_context',selection);result.put('interpretation_context',framing);
  END;
  result.put('started_at',TO_CHAR(r.started_at,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM'));
  IF r.finished_at IS NOT NULL THEN result.put('finished_at',TO_CHAR(r.finished_at,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM'));END IF;
  result.put('trace_version',r.trace_version);result.put('retrieval_policy',r.retrieval_policy);
  FOR t IN (SELECT * FROM kcv_response_tool_calls WHERE execution_id=r.execution_id ORDER BY call_id) LOOP
   obj:=JSON_OBJECT_T();obj.put('call_id',t.call_id);obj.put('tool',t.tool_name);obj.put('status',t.status);
   obj.put('started_at',TO_CHAR(t.started_at,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM'));
   obj.put('finished_at',TO_CHAR(t.finished_at,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM'));
   IF t.output_json IS NOT NULL THEN
    packet:=JSON_OBJECT_T.parse(t.output_json);obj.put('output',packet);
    IF t.tool_name='EVIDENCE' AND t.status='SUCCEEDED' THEN
     ev:=packet.get_array('evidence');FOR i IN 0..ev.get_size-1 LOOP j:=TREAT(ev.get(i) AS JSON_OBJECT_T);supplied(j.get_string('id')):=1;END LOOP;
    END IF;
   END IF;
   IF t.error_code IS NOT NULL THEN obj.put('error_code',t.error_code);END IF;calls.append(obj);
  END LOOP;
  BEGIN
   clean:=REGEXP_REPLACE(answer,'^[[:space:]]+|[[:space:]]+$','');
   clean:=REGEXP_REPLACE(clean,'^```(json)?[[:space:]]*','',1,1,'i');
   clean:=REGEXP_REPLACE(clean,'[[:space:]]*```[[:space:]]*$','');
   j:=JSON_OBJECT_T.parse(clean);
   visit(j);
  EXCEPTION WHEN OTHERS THEN parse_state:='UNAVAILABLE';END;
  result.put('tool_calls',calls);result.put('citations',cites);result.put('citation_parse_status',parse_state);result.put('citation_parser_version','4-explicit-citation-ids');
  result.put('notice','Recorded application inputs and tool returns, not private reasoning. Citation matches establish traceability, not claim correctness. Prior conversation may influence the answer; this is not a provider prompt archive.');
  RETURN result.to_clob();
 END;
END;
