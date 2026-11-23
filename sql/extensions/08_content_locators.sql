-- Existing KCV_LAB installations only. Fresh installs already permit non-PDF passages.
-- Preserve all evidence rows and historic response snapshots.
DECLARE nullable_flag VARCHAR2(1);
BEGIN
 SELECT nullable INTO nullable_flag FROM user_tab_columns
  WHERE table_name='KCV_PASSAGES' AND column_name='PDF_PAGE';
 IF nullable_flag='N' THEN EXECUTE IMMEDIATE 'ALTER TABLE kcv_passages MODIFY (pdf_page NULL)'; END IF;
END;
/
