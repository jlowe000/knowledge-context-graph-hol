CREATE OR REPLACE PACKAGE BODY kcv_apex AS
 PROCEDURE dispatch IS
   action VARCHAR2(32):=apex_application.g_x01;sid VARCHAR2(40):=apex_application.g_x02;
   result JSON_OBJECT_T:=JSON_OBJECT_T();status_json CLOB;request JSON_OBJECT_T:=JSON_OBJECT_T();
   arr JSON_ARRAY_T:=JSON_ARRAY_T();row_json JSON_OBJECT_T;body CLOB;off_set PLS_INTEGER:=1;
   plan JSON_OBJECT_T;operation VARCHAR2(32);vocabulary JSON_ARRAY_T:=JSON_ARRAY_T();source_rows JSON_ARRAY_T:=JSON_ARRAY_T();
   personal_id VARCHAR2(32);personal_doc JSON_OBJECT_T;personal_links JSON_OBJECT_T;err NUMBER;message VARCHAR2(4000);
 PROCEDURE emit(p_body CLOB) IS payload CLOB;pos PLS_INTEGER:=1;BEGIN
   SELECT JSON_SERIALIZE(p_body RETURNING CLOB PRETTY ASCII) INTO payload FROM dual;
   WHILE pos<=DBMS_LOB.GETLENGTH(payload) LOOP htp.prn(DBMS_LOB.SUBSTR(payload,1000,pos));pos:=pos+1000;END LOOP;
 END;
 BEGIN
   IF SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL OR UPPER(SYS_CONTEXT('APEX$SESSION','APP_USER')) IN ('NOBODY','APEX_PUBLIC_USER') THEN
     RAISE_APPLICATION_ERROR(-20130,'Sign in to use the knowledge explorer');END IF;
   IF action='start' THEN sid:=kcv_scenario.open_session(apex_application.g_x03);
   ELSIF action='open_personal' THEN kcv_personal_journey.open_conversation(sid);
   END IF;
   status_json:=kcv_scenario.state(sid); -- validates owner and authenticated attachment before every action
   personal_id:=JSON_VALUE(status_json,'$.personal_context_id');
   IF action='trace' THEN
     result.put('trace',JSON_OBJECT_T.parse(kcv_trace.response_trace(sid,TO_NUMBER(apex_application.g_x03))));
     result.put('ok',TRUE);emit(result.to_clob());RETURN;
   END IF;
   IF action IN ('history','observations') THEN
     IF personal_id IS NULL THEN RAISE_APPLICATION_ERROR(-20131,'Open a saved personal conversation first');END IF;
     IF action='history' THEN result.put('turns',JSON_ARRAY_T.parse(kcv_personal_journey.history(sid,TO_NUMBER(apex_application.g_x03))));
     ELSE result.put('observations',JSON_ARRAY_T.parse(kcv_personal_journey.observations(sid,TO_NUMBER(apex_application.g_x03))));END IF;
     result.put('ok',TRUE);emit(result.to_clob());RETURN;
   END IF;
   CASE action
     WHEN 'start' THEN NULL;
     WHEN 'state' THEN NULL;
     WHEN 'open_personal' THEN NULL;
     WHEN 'adopt_head' THEN kcv_personal_journey.adopt_head(sid,apex_application.g_x03,apex_application.g_x06,apex_application.g_x04);
     WHEN 'recover_response' THEN kcv_personal_journey.recover_response(sid,apex_application.g_x03);
     WHEN 'ask' THEN result.put('reply',kcv_scenario.ask(sid,apex_application.g_x03,apex_application.g_x04,apex_application.g_x06));
     WHEN 'stage' THEN
       plan:=JSON_OBJECT_T();operation:=apex_application.g_x04;plan.put('operation',operation);
       IF operation='SET_OBJECTIVE' THEN plan.put('objective',apex_application.g_x03);
       ELSE plan.put('topic',apex_application.g_x03);END IF;
       result.put('change',JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,plan.to_clob())));
     WHEN 'apply' THEN result.put('change',JSON_OBJECT_T.parse(kcv_scenario.apply_change(sid,apex_application.g_x03)));
     WHEN 'observe' THEN kcv_scenario.observe(sid,apex_application.g_x04,apex_application.g_x03,apex_application.g_x05,apex_application.g_x06);
     WHEN 'evidence' THEN NULL;
     ELSE RAISE_APPLICATION_ERROR(-20131,'Unknown explorer action');
   END CASE;
   status_json:=kcv_scenario.state(sid);result.put('state',JSON_OBJECT_T.parse(status_json));
   request.put('scenario_session',sid);result.put('packet',JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(request.to_clob())));
   vocabulary:=JSON_ARRAY_T.parse(kcv_access.topic_options(JSON_VALUE(status_json,'$.base_graph')));
   result.put('topics',vocabulary);
    FOR src IN (SELECT gs.metadata_json FROM kcv_graph_sources gs WHERE gs.graph_name=JSON_VALUE(status_json,'$.base_graph')
      AND (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER)>0
        OR (JSON_VALUE(gs.metadata_json,'$.retrieval_eligible_passage_count' RETURNING NUMBER) IS NULL
          AND REGEXP_LIKE(gs.version_id,'^S[0-9]+-v')
          AND EXISTS (SELECT 1 FROM kcv_passages ep WHERE ep.version_id=gs.version_id))) ORDER BY gs.version_id) LOOP
     source_rows.append(JSON_OBJECT_T.parse(src.metadata_json));
   END LOOP;
   result.put('sources',source_rows);
   IF personal_id IS NOT NULL THEN
     arr:=JSON_ARRAY_T.parse(kcv_personal_journey.history(sid));
     personal_doc:=JSON_OBJECT_T.parse(kcv_personal_context_api.get_context(personal_id));
     personal_links:=JSON_OBJECT_T();personal_links.put('title',personal_doc.get_string('title'));
     personal_links.put('overview_url',apex_page.get_url(p_page=>13,p_clear_cache=>'13',p_items=>'P13_CONTEXT_ID',p_values=>personal_id));
     personal_links.put('edit_url',apex_page.get_url(p_page=>11,p_clear_cache=>'11',p_items=>'P11_CONTEXT_ID',p_values=>personal_id));
     result.put('personal',personal_links);
     result.put('observations',JSON_ARRAY_T.parse(kcv_personal_journey.observations(sid)));
   ELSE
     FOR r IN (SELECT * FROM (SELECT role,body,turn_id,revision_id FROM kcv_chat_turns WHERE session_id=sid ORDER BY turn_id DESC FETCH FIRST 20 ROWS ONLY) ORDER BY turn_id) LOOP
       row_json:=JSON_OBJECT_T();row_json.put('role',r.role);row_json.put('body',r.body);row_json.put('turn_id',r.turn_id);row_json.put('revision_id',r.revision_id);arr.append(row_json);
     END LOOP;
   END IF;
   result.put('turns',arr);result.put('ok',TRUE);body:=result.to_clob();
   emit(body);
 EXCEPTION WHEN OTHERS THEN
   err:=SQLCODE;message:=SQLERRM;ROLLBACK;result:=JSON_OBJECT_T();result.put('ok',FALSE);
   IF err BETWEEN -20299 AND -20100 THEN result.put('error',REGEXP_REPLACE(message,'^ORA-[0-9]+: ',''));
   ELSE result.put('error','The request could not complete. Your saved work is retained. Check the operation status before retrying.');END IF;
   result.put('error_code',err);emit(result.to_clob());
 END;
END;
