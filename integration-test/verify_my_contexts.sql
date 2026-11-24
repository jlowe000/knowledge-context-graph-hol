-- Native C2 acceptance. Run as the owner of an isolated KCV_V2_TEST/KCV_HOL_TEST schema.
-- Uses synthetic runtime drafts only. Does not call a model or alter the public graph.
DECLARE
 result CLOB;again CLOB;j JSON_OBJECT_T;items JSON_ARRAY_T;
 cid VARCHAR2(32);copy_id VARCHAR2(32);unicode_id VARCHAR2(32);unicode_title VARCHAR2(1000);unicode_text VARCHAR2(16000);foreign_id VARCHAR2(32):='C'||SUBSTR(RAWTOHEX(SYS_GUID()),1,31);
 token_prefix VARCHAR2(32):=RAWTOHEX(SYS_GUID());title_prefix VARCHAR2(100);
 before_revs NUMBER;before_chats NUMBER;n NUMBER;first_id VARCHAR2(32);second_id VARCHAR2(32);lock_id PLS_INTEGER;lock_result PLS_INTEGER;
 PROCEDURE check_true(p_ok BOOLEAN,p_message VARCHAR2) IS BEGIN
   IF p_ok IS NULL OR NOT p_ok THEN RAISE_APPLICATION_ERROR(-20990,p_message);END IF;
 END;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA') NOT IN ('KCV_V2_TEST','KCV_HOL_TEST') THEN
   RAISE_APPLICATION_ERROR(-20999,'Use the isolated My Contexts test schema');END IF;
 check_true(kcv_access.owner_scope='DB:'||SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),'Worksheet scope mismatch');
 title_prefix:='C2 test '||token_prefix;
 SELECT COUNT(*) INTO before_revs FROM kcv_scenario_revisions;
 SELECT COUNT(*) INTO before_chats FROM kcv_chat_sessions;
 result:=kcv_personal_context_api.save_draft(NULL,title_prefix,TO_CLOB('{}'),NULL,token_prefix||'_create');
 j:=JSON_OBJECT_T.parse(result);cid:=j.get_string('context_id');
 check_true(j.get_string('lifecycle')='DRAFT' AND j.get_number('draft_version')=1,'Draft creation failed');
 check_true(LENGTH(cid)=32 AND SUBSTR(cid,1,1)='C','Context identifier incompatible with existing graph IDs');
 check_true(j.get_object('capabilities').get_boolean('activate'),'Draft must offer the reviewed activation flow');
 check_true(NOT j.get_object('capabilities').get_boolean('start_conversation'),'An incomplete draft must not start a conversation');
 check_true(j.get_array('selected_topics').get_size=0,'Blank draft must expose an empty selected-topic list');
 again:=kcv_personal_context_api.save_draft(NULL,title_prefix,TO_CLOB('{}'),NULL,token_prefix||'_create');
 check_true(DBMS_LOB.COMPARE(result,again)=0,'Retry did not return original receipt');
 SELECT COUNT(*) INTO n FROM kcv_personal_contexts WHERE title=title_prefix;
 check_true(n=1,'Retry duplicated a context');
 BEGIN
   result:=kcv_personal_context_api.save_draft(NULL,title_prefix||' changed',TO_CLOB('{}'),NULL,token_prefix||'_create');
   RAISE_APPLICATION_ERROR(-20991,'Changed request token accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20245 THEN RAISE;END IF;END;
 result:=kcv_personal_context_api.save_draft(cid,title_prefix,
   TO_CLOB('{"question":"What matters to me?","objective_clarity":"emerging","known_situation":"<script>literal user text</script>","constraints":["User supplied"],"topic_preferences":{}}'),
   1,token_prefix||'_save');
 j:=JSON_OBJECT_T.parse(result);check_true(j.get_number('draft_version')=2,'Draft version did not advance');
 check_true(j.get_object('draft').get_string('objective_clarity')='emerging','Clarity was overwritten');
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{}'),1,token_prefix||'_stale');
   RAISE_APPLICATION_ERROR(-20991,'Stale draft version accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20242 THEN RAISE;END IF;END;
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{"owner_subject":"other"}'),2,token_prefix||'_owner');
   RAISE_APPLICATION_ERROR(-20991,'Client-supplied identity accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{"unknowns":["first\nsecond"]}'),2,token_prefix||'_multiline');
   RAISE_APPLICATION_ERROR(-20991,'Multiline unknown would be silently split by the native editor');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{"constraints":null}'),2,token_prefix||'_null');
   RAISE_APPLICATION_ERROR(-20991,'JSON null accepted as a constraint array');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{"unknowns":[42]}'),2,token_prefix||'_type');
   RAISE_APPLICATION_ERROR(-20991,'Numeric unknown accepted as text');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 -- Prove an already-held advisory lock does not enter or silently release a request.
 lock_id:=DBMS_UTILITY.GET_HASH_VALUE('KCV_CONTEXT_REQUEST:'||kcv_access.owner_scope||':'||kcv_access.owner_subject||':'||token_prefix||'_busy',1,1073741823);
 lock_result:=DBMS_LOCK.REQUEST(id=>lock_id,lockmode=>DBMS_LOCK.X_MODE,timeout=>0,release_on_commit=>TRUE);
 check_true(lock_result=0,'Could not acquire test advisory lock');
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{}'),2,token_prefix||'_busy');
   RAISE_APPLICATION_ERROR(-20991,'Already-held request lock was ignored');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20246 THEN RAISE;END IF;END;
 lock_result:=DBMS_LOCK.RELEASE(lock_id);check_true(lock_result=0,'Failed API request released a lock it did not acquire');
 result:=kcv_personal_context_api.duplicate_context(cid,title_prefix||' copy',token_prefix||'_copy');
 j:=JSON_OBJECT_T.parse(result);copy_id:=j.get_string('context_id');
 check_true(copy_id<>cid AND j.get_number('draft_version')=1,'Copy is not a new draft');
 check_true(j.get_object('provenance').get_string('context_id')=cid,'Copy provenance missing');
 result:=kcv_personal_context_api.save_draft(copy_id,title_prefix||' copy',TO_CLOB('{"constraints":[],"unknowns":[],"topic_preferences":{}}'),1,token_prefix||'_empty');
 j:=JSON_OBJECT_T.parse(result);check_true(j.get_object('draft').get_array('constraints').get_size=0,'Empty arrays were not preserved');
 result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_limit=>1);j:=JSON_OBJECT_T.parse(result);
 items:=j.get_array('contexts');check_true(items.get_size=1 AND j.get_string('next_cursor') IS NOT NULL,'Pagination missing');
 first_id:=TREAT(items.get(0) AS JSON_OBJECT_T).get_string('context_id');
 result:=kcv_personal_context_api.list_contexts(p_search=>title_prefix,p_before_id=>j.get_string('next_cursor'),p_limit=>1);
 j:=JSON_OBJECT_T.parse(result);items:=j.get_array('contexts');second_id:=TREAT(items.get(0) AS JSON_OBJECT_T).get_string('context_id');
 check_true(first_id<>second_id,'Pagination repeated the same context');
 FOR i IN 1..200 LOOP unicode_title:=unicode_title||UNISTR('\4F60');END LOOP;
 result:=kcv_personal_context_api.save_draft(NULL,unicode_title,TO_CLOB('{}'),NULL,token_prefix||'_unicode');
 j:=JSON_OBJECT_T.parse(result);unicode_id:=j.get_string('context_id');
 check_true(j.get_string('title')=unicode_title AND LENGTH(j.get_string('title'))=200,'Valid multibyte title was not preserved');
 FOR i IN 1..20 LOOP unicode_text:=unicode_text||unicode_title;END LOOP;
 j:=JSON_OBJECT_T();j.put('known_situation',unicode_text);j.put('question',SUBSTR(unicode_text,1,2000));
 BEGIN
   result:=kcv_personal_context_api.save_draft(copy_id,title_prefix||' copy',j.to_clob(),2,token_prefix||'_oversize_utf8');
   RAISE_APPLICATION_ERROR(-20991,'Draft byte limit checked characters instead of UTF-8 bytes');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20244 THEN RAISE;END IF;END;
 result:=kcv_personal_context_api.archive_context(cid,2,token_prefix||'_archive');j:=JSON_OBJECT_T.parse(result);
 check_true(j.get_string('lifecycle')='ARCHIVED' AND j.get_number('draft_version')=3,'Archive failed');
 result:=kcv_personal_context_api.get_context(cid);check_true(result IS NOT NULL,'Archived context is not readable');
 BEGIN
   result:=kcv_personal_context_api.save_draft(cid,title_prefix,TO_CLOB('{}'),3,token_prefix||'_archived_save');
   RAISE_APPLICATION_ERROR(-20991,'Archived context was edited');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20243 THEN RAISE;END IF;END;
 result:=kcv_personal_context_api.restore_context(cid,3,token_prefix||'_restore');j:=JSON_OBJECT_T.parse(result);
 check_true(j.get_string('lifecycle')='DRAFT' AND j.get_number('draft_version')=4,'Restore activated a draft');
 INSERT INTO kcv_personal_contexts(context_id,owner_scope,owner_subject,title,draft_json)
   VALUES(foreign_id,'APEX:TEST:OTHER','ACCOUNT:OTHER',title_prefix||' foreign','{}');COMMIT;
 BEGIN result:=kcv_personal_context_api.get_context(foreign_id);RAISE_APPLICATION_ERROR(-20991,'Foreign context read accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.duplicate_context(foreign_id,title_prefix,token_prefix||'_foreign_copy');
   RAISE_APPLICATION_ERROR(-20991,'Foreign duplicate accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 BEGIN result:=kcv_personal_context_api.list_contexts(p_before_id=>foreign_id);RAISE_APPLICATION_ERROR(-20991,'Foreign cursor accepted');
 EXCEPTION WHEN OTHERS THEN IF SQLCODE<>-20241 THEN RAISE;END IF;END;
 SELECT COUNT(*) INTO n FROM kcv_scenario_revisions;check_true(n=before_revs,'Drafts created RDF revisions');
 SELECT COUNT(*) INTO n FROM kcv_chat_sessions;check_true(n=before_chats,'Drafts created model conversations');
 SELECT COUNT(*) INTO n FROM kcv_context_requests WHERE result_json IS NULL;
 check_true(n=0,'Failed request left a committed unfinished receipt');
 DELETE FROM kcv_context_requests WHERE request_token LIKE token_prefix||'%';
 DELETE FROM kcv_personal_contexts WHERE context_id IN (cid,copy_id,unicode_id,foreign_id);COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: native C2 drafts, optimistic concurrency, idempotency, pagination, archive/restore, owner filtering and no graph/model side effects');
 DBMS_OUTPUT.PUT_LINE('PENDING: actual APEX login/relogin and two-account browser acceptance are separate checks');
END;
/
