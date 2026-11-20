# SQL catalogue and execution order

Use Database Actions SQL Worksheet. Do not run every SQL file alphabetically. Run complete slash-delimited files with F5; follow each lab's Run Statement instructions for private bind-input blocks.

## Required fresh installation

| Phase | Account | Files, in order |
| --- | --- | --- |
| Java readiness | ADMIN | `sql/admin/00_readiness.sql`; `00_java_status.sql`. Only if absent and intended: `01_enable_java.sql`, then OCI restart and wait for VALID |
| User/access | ADMIN | `sql/admin/01_create_user_worksheet.sql`, `02_grants.sql`, `04_enable_database_actions.sql` |
| Base graph schema | KCV_LAB | `sql/schema/01_objects.sql`, `02_network.sql`, `03_tools.sql` |
| Authentication | KCV_LAB | `sql/schema/00_user_credential_worksheet.sql`; resource-principal alternative instead requires documented IAM and ADMIN `sql/admin/03_resource_principal.sql` |
| Model | KCV_LAB | `sql/schema/05_profile_worksheet.sql`, `06_register_profile.sql`, then `sql/queries/00_test_genai.sql` (inference charge possible) |
| Dataset | KCV_LAB | [sql/install/10_load_dataset.sql](../sql/install/10_load_dataset.sql), `sql/queries/01_inspect.sql`, [verify_worksheet.sql](../integration-test/verify_worksheet.sql) |
| Explorer backend | KCV_LAB | `sql/extensions/01_scenario_objects.sql`, **`06_response_provenance.sql`**, `02_scenario_api.sql`, `03_scenario_agents.sql`, `05_apex_api.sql` |
| Native graph check | KCV_LAB | [verify_scenario_native.sql](../integration-test/verify_scenario_native.sql) |
| APEX accounts | ADMIN | `sql/admin/06_cloud_apex_preflight.sql`, `07_create_apex_workspace.sql`, `08_create_apex_app_user.sql` |
| Application | KCV_LAB | [sql/install/20_install_apex.sql](../sql/install/20_install_apex.sql) |

Read the [beginner labs](fresh-serverless-deployment.md) for all expected results, account changes and troubleshooting. The table is an index, not a substitute for the steps.

## Optional and reference SQL

- `sql/scenarios/01_start.sql` through `06_observe.sql`, `08_audit.sql` and `09_propose_change.sql`: perform the scenario through Worksheet rather than the UI. Bind session IDs from your own run.
- `sql/extensions/00_readiness.sql`: inspect an existing base installation before adding the scenario.
- `sql/extensions/07_trace_tool_wrappers.sql`: upgrade existing registrations; not required after a fresh `03_scenario_agents.sql` installation.
- `sql/extensions/04_domain_extraction.sql`, `sql/scenarios/07_extract_domain.sql`, `10_owl_inference.sql`: advanced curation/inference, separate from the learner path. Extraction quotes the supplied summary, not the original slide; do not mistake that for source verification.
- `sql/schema/04_agents.sql`, `sql/queries/00_create_conversation.sql`, `03_extract_candidates.sql`, `04_run_agents.sql`: older optional base-agent/curation flow, not KCV_EXPLORER_TEAM installation.
- Remaining `sql/queries/`: inspection, Java/runtime/profile diagnosis, feedback and optional inference/history queries. Availability of agent history views can vary by service version.

Some creation scripts are intentionally not rerunnable. Inspect the specific failure and earlier result instead of dropping users, resetting accounts or rerunning the whole installation.
