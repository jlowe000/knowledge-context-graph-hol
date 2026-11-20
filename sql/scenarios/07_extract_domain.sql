-- Optional model call. S02 is a good first source; an empty result is valid.
DECLARE l_reply CLOB;
BEGIN
  l_reply:=kcv_extract_domain(:KCV_SOURCE_ID);
  DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_reply,32000,1));
END;
/
