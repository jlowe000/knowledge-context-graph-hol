-- KCV_LAB: native read/graph probes; no model call in this script.
DECLARE
  l_packet JSON_OBJECT_T;
  l_evidence JSON_ARRAY_T;
  l_context JSON_OBJECT_T;
  l_row JSON_OBJECT_T;
  l_page3 BOOLEAN:=FALSE;
  l_page10 BOOLEAN:=FALSE;
  l_raw CLOB;
BEGIN
  SELECT kcv_context_packet('{"context_id":"CTX01"}') INTO l_raw FROM dual;
  l_context:=JSON_OBJECT_T.parse(l_raw);
  IF l_context.get_string('id') IS NULL OR l_context.get_string('id')<>'CTX01' THEN RAISE_APPLICATION_ERROR(-20020,'Context identity mismatch'); END IF;
  SELECT kcv_evidence_packet('{"context_id":"CTX03"}') INTO l_raw FROM dual;
  l_packet:=JSON_OBJECT_T.parse(l_raw);
  IF l_packet.has('error') THEN RAISE_APPLICATION_ERROR(-20021,'Evidence packet returned an error'); END IF;
  l_evidence:=l_packet.get_array('evidence');
  IF l_evidence.get_size=0 THEN RAISE_APPLICATION_ERROR(-20022,'No native evidence returned'); END IF;
  FOR i IN 0..l_evidence.get_size-1 LOOP
    l_row:=TREAT(l_evidence.get(i) AS JSON_OBJECT_T);
    IF l_row.get_string('source_id')='S10' THEN
      IF l_row.get_number('pdf_page')=3 THEN l_page3:=TRUE; END IF;
      IF l_row.get_number('pdf_page')=10 THEN l_page10:=TRUE; END IF;
    END IF;
  END LOOP;
  IF NOT l_page3 OR NOT l_page10 THEN RAISE_APPLICATION_ERROR(-20024,'Missing overview or scope qualification'); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS: active context and native RDF evidence include overview and disclaimer');
END;
/
