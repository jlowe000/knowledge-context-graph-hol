CREATE TABLE kcv_scenario_revisions (
 revision_id VARCHAR2(40) PRIMARY KEY, parent_revision VARCHAR2(40),
 context_id VARCHAR2(32) NOT NULL, base_graph VARCHAR2(128) NOT NULL,
 overlay_graph VARCHAR2(128) NOT NULL UNIQUE, context_json CLOB NOT NULL CHECK(context_json IS JSON),
 created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
)
