-- TEST ONLY: mock model output exercises validation/persistence, not semantic truth.
DECLARE
 fact JSON_OBJECT_T:=JSON_OBJECT_T();root JSON_OBJECT_T:=JSON_OBJECT_T();facts JSON_ARRAY_T:=JSON_ARRAY_T();
 body CLOB;pid VARCHAR2(200);reply CLOB;response JSON_OBJECT_T;before_n NUMBER;after_n NUMBER;
 PROCEDURE set_response IS encoded CLOB;BEGIN facts:=JSON_ARRAY_T();facts.append(fact);root.put('facts',facts);encoded:=root.to_clob();UPDATE kcv_test_ai_response SET body=encoded;COMMIT;END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA')<>'KCV_HOL_TEST' THEN RAISE_APPLICATION_ERROR(-20999,'Isolated test schema required');END IF;
 SELECT passage_id,passage_text INTO pid,body FROM kcv_passages WHERE version_id='S02-v1' AND pdf_page=10 FETCH FIRST 1 ROW ONLY;
 fact.put('subject','Semantic retrieval');fact.put('predicate','usesConcept');fact.put('object','Embeddings');fact.put('evidence_id',pid);
 fact.put('quote',DBMS_LOB.SUBSTR(body,60,1));fact.put('qualification','Component-test fixture; not an accepted or model-validated fact.');set_response;
 SELECT COUNT(*) INTO before_n FROM kcv_domain_runs;
 reply:=kcv_extract_domain('S02');response:=JSON_OBJECT_T.parse(reply);
 IF response.get_number('fact_count')<>1 THEN RAISE_APPLICATION_ERROR(-20990,'Expected one validated proposal');END IF;
 SELECT COUNT(*) INTO after_n FROM kcv_domain_runs;IF after_n<>before_n+1 THEN RAISE_APPLICATION_ERROR(-20990,'Run not persisted');END IF;
 fact.put('predicate','inventedPredicate');set_response;
 BEGIN reply:=kcv_extract_domain('S02');RAISE_APPLICATION_ERROR(-20991,'Unknown predicate accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20122 THEN RAISE;END IF;END;
 fact.put('predicate','usesConcept');fact.put('quote','This fabricated quote is absent from the source.');set_response;
 BEGIN reply:=kcv_extract_domain('S02');RAISE_APPLICATION_ERROR(-20991,'Invented quote accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20123 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO after_n FROM kcv_domain_runs;IF after_n<>before_n+1 THEN RAISE_APPLICATION_ERROR(-20990,'Invalid output created a run');END IF;
 UPDATE kcv_test_ai_response SET body='{"facts":[]}';COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: source relationship extraction validates vocabulary and exact evidence before persisting proposals');
END;
/
