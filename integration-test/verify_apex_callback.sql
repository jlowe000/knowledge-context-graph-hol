-- Isolated local test only: KCV_HOL_TEST, imported test application 17001, mocked services.
DECLARE
 names owa.vc_arr;vals owa.vc_arr;sid VARCHAR2(40);token VARCHAR2(40);oldrev VARCHAR2(40);data JSON_OBJECT_T;tid NUMBER;
 PROCEDURE invoke(p_action VARCHAR2,p_text VARCHAR2 DEFAULT NULL,p_mode VARCHAR2 DEFAULT NULL,p_extra VARCHAR2 DEFAULT NULL) IS
   lines htp.htbuf_arr;n INTEGER:=10000;body CLOB;start_pos NUMBER;
 BEGIN
   htp.init;apex_application.g_x01:=p_action;apex_application.g_x02:=sid;apex_application.g_x03:=p_text;
   apex_application.g_x04:=p_mode;apex_application.g_x05:=p_extra;kcv_apex.dispatch;
   owa.get_page(lines,n);DBMS_LOB.CREATETEMPORARY(body,TRUE);
   FOR i IN 1..n LOOP IF lines(i) IS NOT NULL THEN DBMS_LOB.WRITEAPPEND(body,LENGTH(lines(i)),lines(i));END IF;END LOOP;
   start_pos:=DBMS_LOB.INSTR(body,'{');data:=JSON_OBJECT_T.parse(SUBSTR(body,start_pos));DBMS_LOB.FREETEMPORARY(body);
 END;
 PROCEDURE require_ok IS BEGIN IF NOT data.get_boolean('ok') THEN RAISE_APPLICATION_ERROR(-20990,data.get_string('error'));END IF;END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'KCV_HOL_TEST' THEN RAISE_APPLICATION_ERROR(-20999,'Isolated test schema required');END IF;
 names(1):='SERVER_PROTOCOL';vals(1):='HTTP/1.1';names(2):='REQUEST_METHOD';vals(2):='GET';
 names(3):='SERVER_NAME';vals(3):='localhost';names(4):='HTTP_HOST';vals(4):='localhost:8443';owa.init_cgi_env(4,names,vals);
 apex_session.create_session(p_app_id=>17001,p_page_id=>1,p_username=>'KCV_EDITOR');
 invoke('start','CTX01');require_ok;sid:=data.get_object('state').get_string('scenario_session');oldrev:=data.get_object('state').get_string('context_revision');
 IF data.get_object('packet').get_array('graph_paths').get_size=0 THEN RAISE_APPLICATION_ERROR(-20990,'Callback omitted graph paths');END IF;
 invoke('stage','Find project information; approval is out of scope','SET_OBJECTIVE');require_ok;
 token:=data.get_object('change').get_string('pending_change');
 invoke('apply',token);require_ok;
 IF data.get_object('state').get_string('context_revision')=oldrev THEN RAISE_APPLICATION_ERROR(-20990,'APEX change not applied');END IF;
 invoke('ask','Why do these sources connect?','question');require_ok;
 IF data.get_array('turns').get_size<>2 THEN RAISE_APPLICATION_ERROR(-20990,'Conversation turns not returned');END IF;
 tid:=TREAT(data.get_array('turns').get(1) AS JSON_OBJECT_T).get_number('turn_id');
 invoke('trace',TO_CHAR(tid));require_ok;
 IF data.has('packet') OR data.get_object('trace').get_string('availability')<>'RECORDED' THEN RAISE_APPLICATION_ERROR(-20990,'Trace endpoint rebuilt current evidence or omitted record');END IF;
 invoke('observe','Component fixture: discussed relevance, no measured outcome','discussion','Check the source scope');require_ok;
 -- A new APEX login session, even with the same username, cannot reuse the old scenario.
 apex_session.create_session(p_app_id=>17001,p_page_id=>1,p_username=>'KCV_EDITOR');
 invoke('state');
 IF data.get_boolean('ok') OR INSTR(data.get_string('error'),'ORA-20100')=0 THEN RAISE_APPLICATION_ERROR(-20990,'Cross-APEX-session access accepted');END IF;
 DBMS_OUTPUT.PUT_LINE('PASS: APEX callback JSON, start, graph evidence, staged/applied refinement, transcript, observation, cross-session isolation');
END;
/
