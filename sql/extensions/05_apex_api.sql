-- Parsing schema must be KCV_LAB (same owner as the scenario API).
CREATE OR REPLACE PACKAGE kcv_apex AUTHID DEFINER AS
 PROCEDURE dispatch;
END;
/
CREATE OR REPLACE PACKAGE BODY kcv_apex AS
 PROCEDURE dispatch IS
   action VARCHAR2(32):=apex_application.g_x01;sid VARCHAR2(40):=apex_application.g_x02;
   result JSON_OBJECT_T:=JSON_OBJECT_T();status_json CLOB;request JSON_OBJECT_T:=JSON_OBJECT_T();
   arr JSON_ARRAY_T:=JSON_ARRAY_T();row_json JSON_OBJECT_T;body CLOB;off_set PLS_INTEGER:=1;
   plan JSON_OBJECT_T;operation VARCHAR2(32);vocabulary JSON_ARRAY_T:=JSON_ARRAY_T();source_rows JSON_ARRAY_T:=JSON_ARRAY_T();
 PROCEDURE emit(p_body CLOB) IS payload CLOB;pos PLS_INTEGER:=1;BEGIN
   SELECT JSON_SERIALIZE(p_body RETURNING CLOB PRETTY ASCII) INTO payload FROM dual;
   WHILE pos<=DBMS_LOB.GETLENGTH(payload) LOOP htp.prn(DBMS_LOB.SUBSTR(payload,1000,pos));pos:=pos+1000;END LOOP;
 END;
 BEGIN
   IF SYS_CONTEXT('APEX$SESSION','APP_USER') IS NULL OR UPPER(SYS_CONTEXT('APEX$SESSION','APP_USER')) IN ('NOBODY','APEX_PUBLIC_USER') THEN
     RAISE_APPLICATION_ERROR(-20130,'Sign in to use the knowledge explorer');END IF;
   IF action='start' THEN sid:=kcv_scenario.open_session(apex_application.g_x03);
   ELSE status_json:=kcv_scenario.state(sid);END IF; -- validates signed-in owner and APEX session before every action
   IF action='trace' THEN
     result.put('trace',JSON_OBJECT_T.parse(kcv_trace.response_trace(sid,TO_NUMBER(apex_application.g_x03))));
     result.put('ok',TRUE);emit(result.to_clob());RETURN;
   END IF;
   CASE action
     WHEN 'start' THEN NULL;
     WHEN 'state' THEN NULL;
     WHEN 'ask' THEN result.put('reply',kcv_scenario.ask(sid,apex_application.g_x03,apex_application.g_x04));
     WHEN 'stage' THEN
       -- Only structured user controls reach this path. No agent tool exposes apply.
       plan:=JSON_OBJECT_T();operation:=apex_application.g_x04;plan.put('operation',operation);
       IF operation='SET_OBJECTIVE' THEN plan.put('objective',apex_application.g_x03);
       ELSE plan.put('topic',apex_application.g_x03);END IF;
       result.put('change',JSON_OBJECT_T.parse(kcv_scenario.stage_change(sid,plan.to_clob())));
     WHEN 'apply' THEN result.put('change',JSON_OBJECT_T.parse(kcv_scenario.apply_change(sid,apex_application.g_x03)));
     WHEN 'observe' THEN kcv_scenario.observe(sid,apex_application.g_x04,apex_application.g_x03,apex_application.g_x05);
     WHEN 'evidence' THEN NULL;
     ELSE RAISE_APPLICATION_ERROR(-20131,'Unknown explorer action');
   END CASE;
   status_json:=kcv_scenario.state(sid);result.put('state',JSON_OBJECT_T.parse(status_json));
   request.put('scenario_session',sid);result.put('packet',JSON_OBJECT_T.parse(kcv_scenario.evidence_packet(request.to_clob())));
   FOR t IN (SELECT DISTINCT jt.label FROM kcv_graph_sources gs,
     JSON_TABLE(gs.metadata_json,'$.topics[*]' COLUMNS(label VARCHAR2(200) PATH '$')) jt
     WHERE gs.graph_name=JSON_VALUE(status_json,'$.base_graph') ORDER BY jt.label) LOOP vocabulary.append(t.label);END LOOP;
   result.put('topics',vocabulary);
   FOR src IN (SELECT metadata_json FROM kcv_graph_sources WHERE graph_name=JSON_VALUE(status_json,'$.base_graph') ORDER BY version_id) LOOP
     source_rows.append(JSON_OBJECT_T.parse(src.metadata_json));
   END LOOP;
   result.put('sources',source_rows);
   FOR r IN (SELECT * FROM (SELECT role,body,turn_id,revision_id FROM kcv_chat_turns WHERE session_id=sid ORDER BY turn_id DESC FETCH FIRST 20 ROWS ONLY) ORDER BY turn_id) LOOP
     row_json:=JSON_OBJECT_T();row_json.put('role',r.role);row_json.put('body',r.body);row_json.put('turn_id',r.turn_id);row_json.put('revision_id',r.revision_id);arr.append(row_json);
   END LOOP;
   result.put('turns',arr);result.put('ok',TRUE);body:=result.to_clob();
   emit(body);
 EXCEPTION WHEN OTHERS THEN
   ROLLBACK;result:=JSON_OBJECT_T();result.put('ok',FALSE);result.put('error',SQLERRM);result.put('diagnostic',DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);htp.prn(result.to_string());
 END;
END;
/
