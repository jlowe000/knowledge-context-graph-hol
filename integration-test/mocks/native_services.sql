-- TEST ONLY. Never install these mocks in KCV_LAB or a production schema.
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'KCV_HOL_TEST' THEN RAISE_APPLICATION_ERROR(-20999,'Mocks require isolated KCV_HOL_TEST schema');END IF;
END;
/
CREATE TABLE kcv_test_updates(graph_name VARCHAR2(128),sparql CLOB)
/
CREATE TABLE kcv_test_ai_response(body CLOB)
/
INSERT INTO kcv_test_ai_response VALUES('{"facts":[]}')
/
CREATE OR REPLACE PACKAGE sem_apis AS
 PROCEDURE create_rdf_graph(graph_name VARCHAR2,table_name VARCHAR2,column_name VARCHAR2,network_owner VARCHAR2,network_name VARCHAR2);
 PROCEDURE update_rdf_graph(apply_rdf_graph VARCHAR2,update_stmt CLOB,options VARCHAR2,network_owner VARCHAR2,network_name VARCHAR2);
END;
/
CREATE OR REPLACE PACKAGE BODY sem_apis AS
 PROCEDURE create_rdf_graph(graph_name VARCHAR2,table_name VARCHAR2,column_name VARCHAR2,network_owner VARCHAR2,network_name VARCHAR2) IS BEGIN NULL;END;
 PROCEDURE update_rdf_graph(apply_rdf_graph VARCHAR2,update_stmt CLOB,options VARCHAR2,network_owner VARCHAR2,network_name VARCHAR2) IS BEGIN
   INSERT INTO kcv_test_updates VALUES(apply_rdf_graph,update_stmt);END;
END;
/
CREATE OR REPLACE PACKAGE dbms_cloud_ai AS
 FUNCTION create_conversation(attributes CLOB DEFAULT NULL) RETURN VARCHAR2;
 FUNCTION generate(prompt CLOB,profile_name VARCHAR2,action VARCHAR2) RETURN CLOB;
END;
/
CREATE OR REPLACE PACKAGE BODY dbms_cloud_ai AS
 FUNCTION create_conversation(attributes CLOB DEFAULT NULL) RETURN VARCHAR2 IS BEGIN RETURN RAWTOHEX(SYS_GUID());END;
 FUNCTION generate(prompt CLOB,profile_name VARCHAR2,action VARCHAR2) RETURN CLOB IS body CLOB;BEGIN
   SELECT r.body INTO body FROM kcv_test_ai_response r FETCH FIRST 1 ROW ONLY;RETURN body;END;
END;
/
CREATE OR REPLACE PACKAGE dbms_cloud_ai_agent AS
 FUNCTION run_team(team_name VARCHAR2,user_prompt CLOB,params CLOB) RETURN CLOB;
 PROCEDURE create_tool(tool_name VARCHAR2,description VARCHAR2,attributes CLOB);
 PROCEDURE create_task(task_name VARCHAR2,attributes CLOB);
 PROCEDURE create_agent(agent_name VARCHAR2,attributes CLOB);
 PROCEDURE create_team(team_name VARCHAR2,attributes CLOB);
END;
/
CREATE OR REPLACE PACKAGE BODY dbms_cloud_ai_agent AS
 FUNCTION run_team(team_name VARCHAR2,user_prompt CLOB,params CLOB) RETURN CLOB IS
   packet CLOB;fixture_mode VARCHAR2(30);answer JSON_OBJECT_T:=JSON_OBJECT_T();c JSON_ARRAY_T:=JSON_ARRAY_T();pid VARCHAR2(200);
 BEGIN
   SELECT JSON_VALUE(body,'$.test_mode') INTO fixture_mode FROM kcv_test_ai_response FETCH FIRST 1 ROW ONLY;
   IF fixture_mode='model_failure' THEN RAISE_APPLICATION_ERROR(-20980,'Fixture model failure');END IF;
   IF fixture_mode='no_tool' THEN RETURN '{"assessment":"Mock without tool capture"}';END IF;
   IF JSON_VALUE(user_prompt,'$.task')='propose_change' THEN
    EXECUTE IMMEDIATE 'BEGIN :r:=kcv_scenario_propose(:q); END;' USING OUT packet,IN user_prompt;RETURN packet;
   END IF;
   EXECUTE IMMEDIATE 'BEGIN :r:=kcv_scenario_evidence(:q); END;' USING OUT packet,IN user_prompt;
   IF fixture_mode='repeat_tool' THEN EXECUTE IMMEDIATE 'BEGIN :r:=kcv_scenario_evidence(:q); END;' USING OUT packet,IN user_prompt;END IF;
   pid:=JSON_VALUE(packet,'$.evidence[0].id');IF pid IS NOT NULL THEN c.append(pid);END IF;
   IF fixture_mode='unknown_citation' THEN c.append('invented-passage');END IF;
   answer.put('assessment','LOCAL MOCK: actual tool wrapper exercised; no OCI model inference.');IF fixture_mode='nested_citations' THEN DECLARE nested JSON_OBJECT_T:=JSON_OBJECT_T();BEGIN nested.put('citations',c);answer.put('assessment',nested);END;ELSE answer.put('citations',c);END IF;IF fixture_mode='nested_citations' THEN RETURN TO_CLOB(CHR(10)||'```json'||CHR(10))||answer.to_clob()||TO_CLOB(CHR(10)||'```'||CHR(10));END IF;RETURN answer.to_clob();
 END;
 PROCEDURE create_tool(tool_name VARCHAR2,description VARCHAR2,attributes CLOB) IS j JSON_OBJECT_T;BEGIN j:=JSON_OBJECT_T.parse(attributes);END;
 PROCEDURE create_task(task_name VARCHAR2,attributes CLOB) IS j JSON_OBJECT_T;BEGIN j:=JSON_OBJECT_T.parse(attributes);END;
 PROCEDURE create_agent(agent_name VARCHAR2,attributes CLOB) IS j JSON_OBJECT_T;BEGIN j:=JSON_OBJECT_T.parse(attributes);END;
 PROCEDURE create_team(team_name VARCHAR2,attributes CLOB) IS j JSON_OBJECT_T;BEGIN j:=JSON_OBJECT_T.parse(attributes);END;
END;
/
CREATE TYPE sem_models AS TABLE OF VARCHAR2(128)
/
CREATE TYPE kcv_test_row AS OBJECT(item VARCHAR2(4000),ver VARCHAR2(4000),topic VARCHAR2(4000),passage VARCHAR2(4000))
/
CREATE TYPE kcv_test_rows AS TABLE OF kcv_test_row
/
CREATE OR REPLACE FUNCTION sem_match(p_query VARCHAR2,p_models sem_models,
 p3 VARCHAR2 DEFAULT NULL,p4 VARCHAR2 DEFAULT NULL,p5 VARCHAR2 DEFAULT NULL,p6 VARCHAR2 DEFAULT NULL,
 p7 VARCHAR2 DEFAULT NULL,p8 VARCHAR2 DEFAULT NULL,p9 VARCHAR2 DEFAULT NULL,p10 VARCHAR2 DEFAULT NULL,p11 VARCHAR2 DEFAULT NULL)
 RETURN kcv_test_rows PIPELINED AUTHID DEFINER IS
 rid VARCHAR2(40);body CLOB;obj JSON_OBJECT_T;prefs JSON_OBJECT_T;ns VARCHAR2(100):='https://example.org/kcv/';
BEGIN
 rid:=REGEXP_SUBSTR(p_query,'/('||'R[A-F0-9]+'||')>',1,1,'c',1);
 SELECT context_json INTO body FROM kcv_scenario_revisions WHERE revision_id=rid;obj:=JSON_OBJECT_T.parse(body);prefs:=obj.get_object('topic_preferences');
 FOR r IN (SELECT src.source_id,gs.version_id,t.label,ps.passage_id FROM kcv_graph_sources gs JOIN kcv_sources src ON src.version_id=gs.version_id
   JOIN kcv_passages ps ON ps.version_id=gs.version_id,JSON_TABLE(gs.metadata_json,'$.topics[*]' COLUMNS(label VARCHAR2(200) PATH '$')) t
   WHERE gs.graph_name=p_models(1) ORDER BY src.source_id,t.label,ps.passage_id) LOOP
   IF prefs.has(r.label) THEN PIPE ROW(kcv_test_row(ns||r.source_id,ns||r.version_id,ns||'topic-'||TRIM(BOTH '-' FROM REGEXP_REPLACE(r.label,'[^A-Za-z0-9]+','-')),ns||r.passage_id));END IF;
 END LOOP;
 RETURN;
END;
/
