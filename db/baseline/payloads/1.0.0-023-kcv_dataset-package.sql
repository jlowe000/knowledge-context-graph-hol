CREATE OR REPLACE PACKAGE kcv_dataset AUTHID DEFINER AS
  PROCEDURE load_github(
    p_ref VARCHAR2, p_expected_manifest_sha256 VARCHAR2,
    p_owner VARCHAR2 DEFAULT 'jlowe000',
    p_repo VARCHAR2 DEFAULT 'knowledge-context-graph-hol');
END kcv_dataset;
