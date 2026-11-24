 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('{"name":"KCV_SETTINGS","temporary":"N","columns":[{"name":"SETTING_KEY","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":64,"char_used":"B"},{"name":"SETTING_VALUE","type":"VARCHAR2","nullable":"N","identity":"NO","default":null,"length":4000,"char_used":"B"}],"constraints":[{"type":"P","columns":"SETTING_KEY"}]}');
 check_table(l_expected);
