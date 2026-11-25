-- Project owner: complete the ordered v2 schema installation or migration first.
-- Run sql/install/02_verify_schema.sql and configure the owner RDF network before loading.
-- Run this caller with Run Script (F5).
-- Replace the commit placeholder with the full 40-character published commit SHA.
-- This exact commit must contain the matching data/load/manifest.json.
-- Public data only; no GitHub token or Python is required.
BEGIN
  KCV_DATASET.LOAD_GITHUB(
    p_ref => 'PASTE_FULL_40_CHARACTER_COMMIT_SHA',
    p_expected_manifest_sha256 => 'dae8efdcd9e99874c8dfc3d9a3ccaf4a861f76b3b5442f71f075a6d9b64ef8ad');
END;
/
