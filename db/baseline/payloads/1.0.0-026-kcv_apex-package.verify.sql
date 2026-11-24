 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE kcv_apex AUTHID DEFINER AS
 PROCEDURE dispatch;
END;
');
 check_program('KCV_APEX','PACKAGE',l_expected);
