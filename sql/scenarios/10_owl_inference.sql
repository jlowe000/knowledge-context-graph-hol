-- Optional native OWL2RL scenario. Run as KCV_LAB, using an unrefined context with topics.
DECLARE
 st JSON_OBJECT_T:=JSON_OBJECT_T.parse(kcv_scenario.state(:KCV_SESSION_ID));
 base VARCHAR2(128):=st.get_string('base_graph');overlay VARCHAR2(128):=st.get_string('overlay_graph');
 rule_graph VARCHAR2(128):='KCV_W_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);inferred VARCHAR2(128):='KCV_I_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);
 before_n NUMBER;after_n NUMBER;models VARCHAR2(1000);q VARCHAR2(1000);
BEGIN
 SEM_APIS.CREATE_RDF_GRAPH(rule_graph,NULL,NULL,network_owner=>USER,network_name=>'KCV_NET');
 SEM_APIS.UPDATE_RDF_GRAPH(apply_rdf_graph=>rule_graph,update_stmt=>q'~INSERT DATA {
   <https://example.org/kcv/FocusedContext> a <http://www.w3.org/2002/07/owl#Class> .
   _:focus a <http://www.w3.org/2002/07/owl#Restriction> ;
     <http://www.w3.org/2002/07/owl#onProperty> <https://example.org/kcv/focusesOn> ;
     <http://www.w3.org/2002/07/owl#someValuesFrom> <https://example.org/kcv/Topic> ;
     <http://www.w3.org/2000/01/rdf-schema#subClassOf> <https://example.org/kcv/FocusedContext> .
 }~',options=>NULL,network_owner=>USER,network_name=>'KCV_NET');
 models:='SEM_MODELS('||DBMS_ASSERT.ENQUOTE_LITERAL(base)||','||DBMS_ASSERT.ENQUOTE_LITERAL(overlay)||','||DBMS_ASSERT.ENQUOTE_LITERAL(rule_graph)||')';
 q:='SELECT ?ctx WHERE { ?ctx a <https://example.org/kcv/FocusedContext> }';
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM TABLE(SEM_MATCH('||DBMS_ASSERT.ENQUOTE_LITERAL(q)||','||models||
   ',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'||DBMS_ASSERT.ENQUOTE_LITERAL(USER)||',''KCV_NET''))' INTO before_n;
 SEM_APIS.CREATE_INFERRED_GRAPH(inferred,SEM_MODELS(base,overlay,rule_graph),SEM_RULEBASES('OWL2RL'),network_owner=>USER,network_name=>'KCV_NET');
 EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM TABLE(SEM_MATCH('||DBMS_ASSERT.ENQUOTE_LITERAL(q)||','||models||
   ',SEM_RULEBASES(''OWL2RL''),NULL,NULL,NULL,NULL,NULL,NULL,'||DBMS_ASSERT.ENQUOTE_LITERAL(USER)||',''KCV_NET''))' INTO after_n;
 DBMS_OUTPUT.PUT_LINE('Before inference: '||before_n||'; after inference: '||after_n);
 DBMS_OUTPUT.PUT_LINE('Rules: '||rule_graph||'; inferred graph: '||inferred);
 IF before_n<>0 OR after_n<1 THEN RAISE_APPLICATION_ERROR(-20140,'Expected an inferred FocusedContext; inspect input topics and native inference');END IF;
END;
/
