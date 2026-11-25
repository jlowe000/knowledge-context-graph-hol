-- Owner runtime setup after current schema installation and ADMIN search grants.
-- Select DECLARE through END; use Run Statement, without the final slash.
-- Bind KCV_MODEL_URI to the direct, augmented all_MiniLM_L12_v2.onnx download
-- from Oracle's public model catalogue. Do not save a populated URI in Git.
-- The model bytes are fetched into the database; context text is never uploaded.
DECLARE
 l_uri VARCHAR2(4000):=:KCV_MODEL_URI;
 l_blob BLOB;l_count PLS_INTEGER;l_hash VARCHAR2(64);l_dimensions PLS_INTEGER;
 l_expected CONSTANT VARCHAR2(64):='3929907d138051f818619fce3ba054185f748f2739d7a4dbc26e2502dd2499ea';
BEGIN
 IF SYS_CONTEXT('USERENV','SESSION_USER') IN ('ADMIN','SYS','SYSTEM')
  OR SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>SYS_CONTEXT('USERENV','SESSION_USER')
  OR SYS_CONTEXT('APEX$SESSION','APP_ID') IS NOT NULL THEN
  RAISE_APPLICATION_ERROR(-20360,'Connect as the project schema owner outside APEX');END IF;
 SELECT COUNT(*) INTO l_count FROM user_mining_models WHERE model_name='KCV_CONTEXT_MINILM';
 IF l_count=0 THEN
  IF l_uri IS NULL OR SUBSTR(l_uri,1,8)<>'https://' THEN
   RAISE_APPLICATION_ERROR(-20360,'Supply the HTTPS address of the documented augmented ONNX model');END IF;
  l_blob:=DBMS_CLOUD.GET_OBJECT(credential_name=>NULL,object_uri=>l_uri);
  l_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(l_blob,DBMS_CRYPTO.HASH_SH256)));
  IF l_hash<>l_expected THEN
   RAISE_APPLICATION_ERROR(-20360,'Model checksum differs from the tested artifact; review the model before changing the pin');END IF;
  DBMS_VECTOR.LOAD_ONNX_MODEL(model_name=>'KCV_CONTEXT_MINILM',model_data=>l_blob);
 ELSE
  DBMS_OUTPUT.PUT_LINE('Existing model retained. This step does not replace or certify its original bytes.');
 END IF;
 EXECUTE IMMEDIATE 'SELECT VECTOR_DIMENSION_COUNT(VECTOR_EMBEDDING(KCV_CONTEXT_MINILM USING :t AS DATA)) FROM dual'
  INTO l_dimensions USING 'Find saved learning ideas by meaning';
 IF l_dimensions<>384 THEN RAISE_APPLICATION_ERROR(-20360,'Expected a 384-dimensional embedding model');END IF;
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_MODEL_READY=384');
 -- Keep loading, validation and backfill in one block: an error cannot fall
 -- through to a later Worksheet block and refresh with an unintended model.
 kcv_context_search.reindex_all;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_BACKFILL=COMPLETE; inspect coverage below');
EXCEPTION WHEN OTHERS THEN ROLLBACK;RAISE;
END;
/
-- Run this read-only query separately only after both success markers above.
SELECT embedding_status, COUNT(*) AS chunks
FROM kcv_context_search_chunks
GROUP BY embedding_status
/
