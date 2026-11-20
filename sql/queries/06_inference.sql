-- KCV_LAB: optional native OWL2RL operation, after RDF loading.
DECLARE
  l_graph VARCHAR2(128);
  l_inferred VARCHAR2(128):='KCV_I_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,16);
BEGIN
  SELECT setting_value INTO l_graph FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
  SEM_APIS.CREATE_INFERRED_GRAPH(l_inferred,SEM_MODELS(l_graph),SEM_RULEBASES('OWL2RL'),
    network_owner=>USER,network_name=>'KCV_NET');
  DBMS_OUTPUT.PUT_LINE('Created inferred graph: '||l_inferred);
END;
/
