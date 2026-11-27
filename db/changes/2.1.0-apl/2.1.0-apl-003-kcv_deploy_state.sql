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
