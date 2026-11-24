 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_RDF_STAGE","temporary":"N","columns":[{"name":"RDF$STC_SUB","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":4000,"char_used":"B"},{"name":"RDF$STC_PRED","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":4000,"char_used":"B"},{"name":"RDF$STC_OBJ","type":"VARCHAR2","nullable":"Y","identity":"NO","default":null,"length":4000,"char_used":"B"}],"constraints":[]}');
 check_table(l_expected);
