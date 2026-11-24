-- Isolated native acceptance: local ONNX inference only, no GenAI/provider calls.
-- Every mutation/cleanup is limited to freshly generated fixture identifiers.
DECLARE
 prefix VARCHAR2(24):=SUBSTR(RAWTOHEX(SYS_GUID()),1,24);title_prefix VARCHAR2(80);
 power_id VARCHAR2(32);building_id VARCHAR2(32);lunch_id VARCHAR2(32);copy_id VARCHAR2(32);unicode_id VARCHAR2(32);unicode_title VARCHAR2(1000);
 foreign_id VARCHAR2(32):='C'||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
 owned_scope VARCHAR2(128):=kcv_access.owner_scope;owned_subject VARCHAR2(128):=kcv_access.owner_subject;
 body JSON_OBJECT_T;answer JSON_OBJECT_T;item JSON_OBJECT_T;preview JSON_OBJECT_T;items JSON_ARRAY_T;preview_text VARCHAR2(1000);
 result CLOB;cursor_id VARCHAR2(32);seen VARCHAR2(1000):='|';n NUMBER;v NUMBER;foreign_hash VARCHAR2(64);before_hash VARCHAR2(64);after_hash VARCHAR2(64);before_refresh TIMESTAMP WITH TIME ZONE;after_refresh TIMESTAMP WITH TIME ZONE;
 before_sources NUMBER;before_passages NUMBER;before_graphs NUMBER;
 PROCEDURE ok(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;END;
 FUNCTION has_id(p_result CLOB,p_id VARCHAR2) RETURN BOOLEAN IS doc JSON_OBJECT_T:=JSON_OBJECT_T.parse(p_result);a JSON_ARRAY_T:=doc.get_array('contexts');BEGIN
  FOR i IN 0..a.get_size-1 LOOP IF TREAT(a.get(i) AS JSON_OBJECT_T).get_string('context_id')=p_id THEN RETURN TRUE;END IF;END LOOP;RETURN FALSE;
 END;
 FUNCTION make_draft(p_suffix VARCHAR2,p_objective VARCHAR2,p_situation VARCHAR2) RETURN VARCHAR2 IS doc JSON_OBJECT_T:=JSON_OBJECT_T();res JSON_OBJECT_T;BEGIN
  doc.put('objective',p_objective);doc.put('known_situation',p_situation);doc.put('objective_clarity','defined');
  res:=JSON_OBJECT_T.parse(kcv_personal_context_api.save_draft(NULL,title_prefix||' '||p_suffix,doc.to_clob(),NULL,prefix||'_'||p_suffix));
  RETURN res.get_string('context_id');
 END;
 PROCEDURE cleanup IS BEGIN
  -- No native graph/model resources are created by these draft-only fixtures.
  DELETE FROM kcv_context_delete_resources WHERE context_id IN(power_id,building_id,lunch_id,copy_id,foreign_id,unicode_id);
  DELETE FROM kcv_context_deletions WHERE context_id IN(power_id,building_id,lunch_id,copy_id,foreign_id,unicode_id);
  DELETE FROM kcv_context_requests WHERE owner_scope=owned_scope AND owner_subject=owned_subject
   AND (request_token LIKE prefix||'\_%' ESCAPE '\');
  DELETE FROM kcv_personal_contexts WHERE context_id IN(power_id,building_id,lunch_id,copy_id,foreign_id,unicode_id);
  COMMIT;
 END;
BEGIN
 ok(SYS_CONTEXT('USERENV','SESSION_USER') IN('KCV_V2_TEST','KCV_HOL_TEST','KCV_V2_FRESH')
  AND SYS_CONTEXT('USERENV','SESSION_USER')=SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),'Use the isolated schema owner');
 SELECT COUNT(*) INTO n FROM user_mining_models WHERE model_name='KCV_CONTEXT_MINILM';ok(n=1,'Load the local embedding model before semantic acceptance');
 body:=JSON_OBJECT_T();body.put('objective',RPAD('A clear learning objective ',300,'A clear learning objective '));
 preview_text:=kcv_context_search.objective_preview(body.to_clob());ok(LENGTH(preview_text)=240 AND SUBSTR(preview_text,-3)='...','Long objective preview needs an explicit truncation marker');
 SELECT COUNT(*) INTO before_sources FROM kcv_sources;SELECT COUNT(*) INTO before_passages FROM kcv_passages;SELECT COUNT(*) INTO before_graphs FROM kcv_graph_runs;
 title_prefix:='Search fixture '||prefix;
 power_id:=make_draft('power','Keep the electrical grid dependable and prevent blackouts across the distribution network.','Network operators maintain reliable power for homes and critical facilities.');
 building_id:=make_draft('building','Coordinate building construction schedules and structural engineering drawings.','Architects and contractors plan renovations and concrete installation.');
 lunch_id:=make_draft('lunch','Organise a restaurant booking and prepare a vegetarian menu.','Friends are planning a social meal.');
 SELECT COUNT(*) INTO n FROM kcv_context_search_chunks WHERE context_id IN(power_id,building_id,lunch_id) AND embedding_status='READY';ok(n>=3,'Save hooks did not create ready local vectors');
 -- Call through SQL, not just PL/SQL, to prove list/search remains SQL-safe.
 SELECT kcv_personal_context_api.list_contexts(NULL,'avoid electricity outages',NULL,50) INTO result FROM dual;
 answer:=JSON_OBJECT_T.parse(result);items:=answer.get_array('contexts');
 ok(has_id(result,power_id),'Semantic paraphrase did not retrieve the electricity context');
 ok(TREAT(items.get(0) AS JSON_OBJECT_T).get_string('context_id')=power_id,'Semantic paraphrase did not rank the electricity context first');
 ok(NOT has_id(result,lunch_id),'Unrelated restaurant context passed the semantic relevance threshold');
 FOR i IN 0..items.get_size-1 LOOP item:=TREAT(items.get(i) AS JSON_OBJECT_T);
  IF item.get_string('context_id')=power_id THEN ok(item.get_string('match_reason')='Similar meaning','Paraphrase should exercise semantic-only retrieval');END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_SEMANTIC_PARAPHRASE=PASS');
 result:=kcv_personal_context_api.list_contexts(p_search=>'structural engineering drawings',p_limit=>50);
 ok(has_id(result,building_id),'Saved objective was not searched');answer:=JSON_OBJECT_T.parse(result);items:=answer.get_array('contexts');
 FOR i IN 0..items.get_size-1 LOOP item:=TREAT(items.get(i) AS JSON_OBJECT_T);
  IF item.get_string('context_id')=building_id THEN ok(INSTR(item.get_string('objective_preview'),'structural engineering drawings')>0,'Objective preview missing');END IF;
 END LOOP;
 result:=kcv_personal_context_api.save_draft(lunch_id,title_prefix||' literal %_',TO_CLOB('{"objective":"A literal wildcard title"}'),1,prefix||'_literal');
 result:=kcv_personal_context_api.list_contexts(p_search=>'%_',p_limit=>50);ok(has_id(result,lunch_id),'Literal wildcard title stopped matching');
 result:=kcv_personal_context_api.duplicate_context(building_id,title_prefix||' copied',prefix||'_copy');answer:=JSON_OBJECT_T.parse(result);copy_id:=answer.get_string('context_id');
 SELECT COUNT(*) INTO n FROM kcv_context_search_chunks WHERE context_id=copy_id AND embedding_status='READY';ok(n>0,'Copy did not create its private search index');
 body:=JSON_OBJECT_T();body.put('known_situation',RPAD('Construction scheduling ',2000,'Construction scheduling ')||' subsea cable inspections');
 result:=kcv_personal_context_api.save_draft(copy_id,title_prefix||' copied',body.to_clob(),1,prefix||'_long');
 SELECT COUNT(*),MAX(LENGTH(chunk_text)) INTO n,v FROM kcv_context_search_chunks WHERE context_id=copy_id;
 ok(n>1 AND v<=480,'Long saved information was not split into bounded local chunks');
 SELECT COUNT(*) INTO n FROM kcv_context_search_chunks WHERE context_id=copy_id AND INSTR(chunk_text,'subsea cable inspections')>0;
 ok(n>0,'Late saved information was truncated before indexing');
 result:=kcv_personal_context_api.list_contexts(p_search=>'subsea cable inspections',p_limit=>50);ok(has_id(result,copy_id),'Late saved information was not searchable');
 FOR i IN 1..200 LOOP unicode_title:=unicode_title||UNISTR('\4F60');END LOOP;
 result:=kcv_personal_context_api.save_draft(NULL,unicode_title,TO_CLOB('{}'),NULL,prefix||'_unicode');answer:=JSON_OBJECT_T.parse(result);unicode_id:=answer.get_string('context_id');
 result:=kcv_personal_context_api.list_contexts(p_search=>unicode_title,p_limit=>50);ok(has_id(result,unicode_id),'Valid multibyte title/search failed');
 -- An exact-title foreign row would outrank the owned rows if filtering leaked.
 INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json,base_graph)
  SELECT foreign_id,owner_scope,'SYNTHETIC_SEARCH_OTHER',title_prefix,draft_json,base_graph FROM kcv_personal_contexts WHERE context_id=power_id;
 SELECT draft_json INTO result FROM kcv_personal_contexts WHERE context_id=foreign_id;
 result:=kcv_context_search.document_text(title_prefix,result);foreign_hash:=LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(result,DBMS_CRYPTO.HASH_SH256)));
 INSERT INTO kcv_context_search_chunks(context_id,chunk_no,content_sha256,model_key,chunk_text,embedding,embedding_status,error_code)
  SELECT foreign_id,chunk_no,foreign_hash,model_key,chunk_text,embedding,embedding_status,error_code FROM kcv_context_search_chunks WHERE context_id=power_id;
 COMMIT;
 result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_limit=>50);ok(NOT has_id(result,foreign_id),'Foreign context leaked through lexical/semantic search');
 result:=kcv_personal_context_api.list_contexts(p_search=>'avoid electricity outages',p_limit=>50);ok(NOT has_id(result,foreign_id),'Foreign context leaked through semantic-only search');
 BEGIN kcv_context_search.refresh_context(foreign_id);RAISE_APPLICATION_ERROR(-20991,'Foreign search refresh succeeded');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_before_id=>foreign_id);RAISE_APPLICATION_ERROR(-20991,'Foreign search cursor succeeded');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 cursor_id:=NULL;
 FOR i IN 1..4 LOOP
  result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_before_id=>cursor_id,p_limit=>1);answer:=JSON_OBJECT_T.parse(result);items:=answer.get_array('contexts');
  ok(items.get_size=1,'Ranked pagination lost an owned matching fixture');item:=TREAT(items.get(0) AS JSON_OBJECT_T);
  ok(item.get_string('context_id') IN(power_id,building_id,lunch_id,copy_id),'Title-ranked fixture did not precede semantic-only matches');
  ok(INSTR(seen,'|'||item.get_string('context_id')||'|')=0,'Ranked pagination duplicated a row');seen:=seen||item.get_string('context_id')||'|';cursor_id:=answer.get_string('next_cursor');
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_OWNER_AND_PAGINATION=PASS');
 INSERT INTO kcv_context_deletions(context_id,owner_scope,owner_subject,status,request_token,expected_version,preview_digest,title,counts_json)
  VALUES(copy_id,owned_scope,owned_subject,'PENDING',prefix||'_pending',2,RPAD('0',64,'0'),'Synthetic pending search fixture','{}');COMMIT;
 result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_limit=>50);ok(NOT has_id(result,copy_id),'Pending deletion exposed indexed context information');
 result:=kcv_personal_context_api.list_contexts(p_limit=>50);answer:=JSON_OBJECT_T.parse(result);items:=answer.get_array('contexts');
 FOR i IN 0..items.get_size-1 LOOP item:=TREAT(items.get(i) AS JSON_OBJECT_T);
  IF item.get_string('context_id')=copy_id THEN ok(item.get_string('deletion_status')='PENDING' AND item.get_string('objective_preview') IS NULL,'Pending deletion list exposed saved objective');END IF;
 END LOOP;
 BEGIN kcv_context_search.refresh_context(copy_id);RAISE_APPLICATION_ERROR(-20991,'Pending deletion refresh succeeded');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20248 THEN RAISE;END IF;END;
 DELETE FROM kcv_context_deletions WHERE context_id=copy_id AND request_token=prefix||'_pending';COMMIT;
 SELECT MIN(content_sha256),MIN(refreshed_at) INTO before_hash,before_refresh FROM kcv_context_search_chunks WHERE context_id=building_id;
 result:=kcv_personal_context_api.archive_context(building_id,1,prefix||'_archive');
 result:=kcv_personal_context_api.restore_context(building_id,2,prefix||'_restore');
 SELECT MIN(content_sha256),MIN(refreshed_at) INTO after_hash,after_refresh FROM kcv_context_search_chunks WHERE context_id=building_id;
 ok(before_hash=after_hash AND before_refresh=after_refresh,'Lifecycle-only changes unnecessarily re-embedded content');
 BEGIN result:=kcv_personal_context_api.save_draft(building_id,'Stale title',TO_CLOB('{}'),1,prefix||'_stale');RAISE_APPLICATION_ERROR(-20991,'Stale save accepted');EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 SELECT MIN(content_sha256) INTO after_hash FROM kcv_context_search_chunks WHERE context_id=building_id;ok(before_hash=after_hash,'Rejected save changed search content');
 result:=kcv_personal_context_api.save_draft(building_id,title_prefix||' building',TO_CLOB('{"objective":"Study marine ecosystems and protect coral reefs."}'),3,prefix||'_edit');
 SELECT MIN(content_sha256) INTO after_hash FROM kcv_context_search_chunks WHERE context_id=building_id;ok(before_hash<>after_hash,'Edited saved context reused stale vectors');
 -- Stale derived data must never be used semantically; lexical data is current.
 UPDATE kcv_context_search_chunks SET content_sha256=RPAD('0',64,'0') WHERE context_id=building_id;
 result:=kcv_personal_context_api.list_contexts(p_search=>'protect coral reefs',p_limit=>50);answer:=JSON_OBJECT_T.parse(result);
 ok(answer.get_string('search_mode')='PARTIAL' AND has_id(result,building_id),'Incomplete index did not give honest complete keyword fallback');
 kcv_context_search.refresh_context(building_id);COMMIT;
 preview:=JSON_OBJECT_T.parse(kcv_context_delete.preview(copy_id));
 result:=kcv_context_delete.delete_context(copy_id,preview.get_number('expected_version'),preview.get_string('expected_head'),preview.get_string('preview_digest'),prefix||'_delete');
 answer:=JSON_OBJECT_T.parse(result);ok(answer.get_string('status')='DELETED','Fixture deletion did not complete');
 SELECT COUNT(*) INTO n FROM kcv_context_search_chunks WHERE context_id=copy_id;ok(n=0,'Deleted context retained private search chunks');
 result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_limit=>50);ok(NOT has_id(result,copy_id),'Deleted context remained searchable');
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_REFRESH_FALLBACK_DELETE=PASS');
 cleanup;
 SELECT COUNT(*) INTO n FROM kcv_sources;ok(n=before_sources,'Public source count changed');SELECT COUNT(*) INTO n FROM kcv_passages;ok(n=before_passages,'Public passage count changed');
 SELECT COUNT(*) INTO n FROM kcv_graph_runs;ok(n=before_graphs,'Public graph count changed');
 SELECT COUNT(*) INTO n FROM kcv_context_search_chunks WHERE context_id IN(power_id,building_id,lunch_id,copy_id,foreign_id,unicode_id);ok(n=0,'Fixture chunks survived cleanup');
 DBMS_OUTPUT.PUT_LINE('CONTEXT_SEARCH_FIXTURE_CLEANUP=PASS');
EXCEPTION WHEN OTHERS THEN cleanup;RAISE;
END;
/
