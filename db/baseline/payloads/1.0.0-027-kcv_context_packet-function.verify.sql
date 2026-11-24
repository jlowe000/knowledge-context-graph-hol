 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('FUNCTION kcv_context_packet(p_request CLOB) RETURN CLOB AUTHID DEFINER AS
  l_context VARCHAR2(32);
  l_body CLOB;
BEGIN
  l_context:=JSON_VALUE(p_request,''$.context_id'' RETURNING VARCHAR2(32) ERROR ON ERROR);
  SELECT c.context_json INTO l_body FROM kcv_contexts c
   JOIN kcv_graph_contexts gc ON gc.snapshot_id=c.snapshot_id
   JOIN kcv_settings a ON a.setting_key=''ACTIVE_GRAPH'' AND a.setting_value=gc.graph_name
   WHERE c.context_id=l_context
   ORDER BY c.snapshot_version DESC FETCH FIRST 1 ROW ONLY;
  RETURN l_body;
EXCEPTION WHEN NO_DATA_FOUND THEN
  RETURN ''{"error":"Unknown context; do not infer personal intent"}'';
END;
');
 check_program('KCV_CONTEXT_PACKET','FUNCTION',l_expected);
