 l_expected:=TO_CLOB('');
 l_expected:=l_expected||TO_CLOB('PACKAGE kcv_access AUTHID DEFINER AS
 FUNCTION owner_scope RETURN VARCHAR2;
 FUNCTION owner_subject RETURN VARCHAR2;
 PROCEDURE assert_context(p_context VARCHAR2);
END;
');
 check_program('KCV_ACCESS','PACKAGE',l_expected);
