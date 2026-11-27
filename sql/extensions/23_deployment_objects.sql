-- APEX-led setup candidate: native execution-context acceptance is still required.
-- Install through the versioned schema transport. This file creates no binding,
-- credential, profile, application, workspace, grant or runtime configuration.
-- Trusted Supporting Objects or the separate authenticated-owner binding script
-- may insert the singleton after verifying the application and workspace.
-- Browser APIs cannot bind. An owner-session operation records account_id=0;
-- native APEX account IDs are positive and remain a separate identity namespace.
CREATE TABLE kcv_deploy_state (
  singleton_id NUMBER PRIMARY KEY CHECK (singleton_id=1),
  schema_owner VARCHAR2(128) NOT NULL,
  workspace_id NUMBER NOT NULL CHECK (workspace_id>0),
  application_id NUMBER NOT NULL CHECK (application_id>0),
  network_tablespace VARCHAR2(128) NOT NULL,
  maintenance VARCHAR2(3) DEFAULT 'ON' NOT NULL CHECK (maintenance IN ('ON','OFF')),
  config_hash VARCHAR2(64),
  model_test_hash VARCHAR2(64),
  model_test_status VARCHAR2(16) DEFAULT 'NOT_TESTED' NOT NULL
    CHECK (model_test_status IN ('NOT_TESTED','SUCCEEDED','FAILED')),
  model_test_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
/
CREATE TABLE kcv_deploy_runs (
  run_id VARCHAR2(32) PRIMARY KEY,
  request_token VARCHAR2(80) NOT NULL UNIQUE,
  operation VARCHAR2(24) NOT NULL CHECK (operation IN
    ('CONFIGURE_PROFILE','TEST_MODEL','ENSURE_NETWORK','REGISTER_RUNTIME','LOAD_DATASET','ENABLE_LEARNING')),
  input_hash VARCHAR2(64) NOT NULL,
  workspace_id NUMBER NOT NULL,
  application_id NUMBER NOT NULL,
  account_id NUMBER NOT NULL CHECK (account_id>=0),
  status VARCHAR2(16) NOT NULL CHECK (status IN ('RUNNING','SUCCEEDED','FAILED','INTERRUPTED')),
  phase VARCHAR2(64) NOT NULL,
  error_code NUMBER,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE
)
/
-- Inputs, SQL text, model responses, credential values and raw errors are never
-- journalled. A request hash detects changed inputs without retaining them.
CREATE INDEX kcv_deploy_runs_recent ON kcv_deploy_runs (started_at,run_id)
/
