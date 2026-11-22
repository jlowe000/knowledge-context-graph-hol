-- DESTRUCTIVE: explicitly requested reset of the dedicated disposable KCV_LAB lab.
-- ADMIN installs/runs a definer-rights helper; no credential or key is exported.
-- Stop if the final PASS is absent. Run 92 only after this file succeeds.
CREATE OR REPLACE PROCEDURE KCV_LAB.KCV_TEARDOWN_RUNTIME AUTHID DEFINER AS
 n NUMBER;
BEGIN
 IF SYS_CONTEXT('USERENV','CURRENT_USER')<>'KCV_LAB' OR
    SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('ADMIN','KCV_LAB') THEN
  RAISE_APPLICATION_ERROR(-20200,'Only the dedicated lab owner/admin may reset this lab'); END IF;
 SELECT COUNT(*) INTO n FROM user_scheduler_running_jobs;
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20201,'Lab jobs are running; inspect and stop the specific executions first'); END IF;
 SELECT COUNT(*) INTO n FROM user_ai_agent_teams WHERE oracle_maintained='N'
  AND agent_team_name NOT IN ('KCV_TEAM','KCV_EXPLORER_TEAM');
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20202,'Unexpected agent team in dedicated lab owner; inspect before deletion'); END IF;
 FOR r IN (SELECT 'KCV_TEAM' name FROM dual UNION ALL SELECT 'KCV_EXPLORER_TEAM' FROM dual) LOOP
  DBMS_CLOUD_AI_AGENT.DROP_TEAM(team_name=>r.name,force=>TRUE);
 END LOOP;
 FOR r IN (SELECT 'KCV_SOURCE_AGENT' name FROM dual UNION ALL SELECT 'KCV_CONTEXT_AGENT' FROM dual
  UNION ALL SELECT 'KCV_RELEVANCE_AGENT' FROM dual UNION ALL SELECT 'KCV_COORDINATOR' FROM dual
  UNION ALL SELECT 'KCV_SCENARIO_QA' FROM dual UNION ALL SELECT 'KCV_SCENARIO_PLANNER' FROM dual
  UNION ALL SELECT 'KCV_SCENARIO_ROUTER' FROM dual) LOOP
  DBMS_CLOUD_AI_AGENT.DROP_AGENT(agent_name=>r.name,force=>TRUE);
 END LOOP;
 FOR r IN (SELECT 'KCV_SOURCE_TASK' name FROM dual UNION ALL SELECT 'KCV_CONTEXT_TASK' FROM dual
  UNION ALL SELECT 'KCV_RELEVANCE_TASK' FROM dual UNION ALL SELECT 'KCV_SCENARIO_QA_TASK' FROM dual
  UNION ALL SELECT 'KCV_SCENARIO_CHANGE_TASK' FROM dual) LOOP
  DBMS_CLOUD_AI_AGENT.DROP_TASK(task_name=>r.name,force=>TRUE);
 END LOOP;
 FOR r IN (SELECT 'KCV_SOURCE_TOOL' name FROM dual UNION ALL SELECT 'KCV_CONTEXT_TOOL' FROM dual
  UNION ALL SELECT 'KCV_EVIDENCE_TOOL' FROM dual UNION ALL SELECT 'KCV_SCENARIO_EVIDENCE' FROM dual
  UNION ALL SELECT 'KCV_SCENARIO_PROPOSE' FROM dual) LOOP
  DBMS_CLOUD_AI_AGENT.DROP_TOOL(tool_name=>r.name,force=>TRUE);
 END LOOP;
 FOR r IN (SELECT conversation_id FROM user_cloud_ai_conversations) LOOP
  DBMS_CLOUD_AI.DROP_CONVERSATION(conversation_id=>r.conversation_id,force=>TRUE);
 END LOOP;
 DBMS_CLOUD_AI.DROP_PROFILE(profile_name=>'KCV_GENAI',force=>TRUE);
 SELECT COUNT(*) INTO n FROM user_credentials WHERE credential_name='OCI_USER_CRED';
 IF n=1 THEN DBMS_CLOUD.DROP_CREDENTIAL(credential_name=>'OCI_USER_CRED'); END IF;
 SELECT COUNT(*) INTO n FROM user_tables WHERE table_name='KCV_NET#RDF_PARAMETER';
 IF n=1 THEN SEM_APIS.DROP_SEM_NETWORK(cascade=>TRUE,network_owner=>'KCV_LAB',network_name=>'KCV_NET'); END IF;
 SELECT COUNT(*) INTO n FROM user_ai_agent_teams WHERE agent_team_name IN ('KCV_TEAM','KCV_EXPLORER_TEAM');
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20203,'Agent team cleanup incomplete'); END IF;
 SELECT COUNT(*) INTO n FROM user_cloud_ai_profiles WHERE profile_name='KCV_GENAI';
 IF n<>0 THEN RAISE_APPLICATION_ERROR(-20204,'Model profile cleanup incomplete'); END IF;
 MERGE INTO kcv_settings t USING(SELECT 'TEARDOWN_RUNTIME' k FROM dual) s ON(t.setting_key=s.k)
  WHEN MATCHED THEN UPDATE SET setting_value='COMPLETE'
  WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(s.k,'COMPLETE');
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('PASS: project agents, conversations, model profile, stored credential and RDF network removed');
END;
/
BEGIN KCV_LAB.KCV_TEARDOWN_RUNTIME; END;
/
