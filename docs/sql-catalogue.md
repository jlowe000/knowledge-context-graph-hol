# SQL catalogue and execution order

An app-only user runs no SQL. Developer learners use [Understand the collection](../labs/understand-collection/understand-collection.md). Administrators first select [clean installation or migration](installation-paths.md); do not run every SQL file alphabetically.

Use **Run Statement** for the documented private-bind PL/SQL blocks, excluding their trailing slash. Use **Run Script (F5)** for complete generated parts and other slash-delimited files. Check each result before the next step.

## Clean installation

| Phase | Account | Files/order |
| --- | --- | --- |
| Platform | ADMIN | `sql/admin/00_readiness.sql`, `00_java_status.sql`; only if needed and authorized, `01_enable_java.sql` then OCI restart |
| New owner | ADMIN | `01_create_user_worksheet.sql`, `02_grants.sql`, `04_enable_database_actions.sql`; consistent `KCV_SCHEMA`, private password |
| Static schema | Owner | [Fresh schema parts](../sql/install/schema-parts/README.md), then [02_verify_schema.sql](../sql/install/02_verify_schema.sql) |
| RDF network | Owner | [02_network.sql](../sql/schema/02_network.sql), once |
| Model authentication | Owner; ADMIN for resource-principal alternative | [Authentication guide](authentication.md); do not configure both paths accidentally |
| Model profile | Owner | `05_profile_worksheet.sql`, `06_register_profile.sql`, `sql/queries/00_test_genai.sql` (real inference) |
| Public dataset | Owner | [10_load_github.sql](../sql/install/10_load_github.sql), inspection and source-scope checks |
| Fresh registrations | Owner | [03_scenario_agents.sql](../sql/extensions/03_scenario_agents.sql), then native scenario verification |
| Local library search | ADMIN, then owner | [Worksheet search setup](context-search.md#worksheet-setup): grants11, model22 and coverage |
| Workspace/account | ADMIN | `06_cloud_apex_preflight.sql`, `07_create_apex_workspace.sql`, `08_create_apex_app_user.sql` |
| New application | Owner | [20_install_apex.sql](../sql/install/20_install_apex.sql): select the complete outer block excluding the final slash, use **Run Statement**, then app-user tests |

Paths without a directory in the table belong to the directory identified by that phase: ADMIN files in `sql/admin/`, profile files in `sql/schema/`. The [configuration](../labs/configure-database/configure-database.md) and [deployment](../labs/deploy-explorer/deploy-explorer.md) labs provide full links, binds and expected outcomes.

## Existing installation

Follow [migration](migrate-to-v2.md). A compatible v1 installation first runs [00_complete_v1_optional.sql](../sql/install/00_complete_v1_optional.sql) to verify required objects and complete only missing optional baseline objects, then [00_adopt_schema_baseline.sql](../sql/install/00_adopt_schema_baseline.sql). Supported migration-managed checkpoints skip adoption. Both use the **upgrade** schema parts, the full verifier, [16_refresh_grounded_answers.sql](../sql/extensions/16_refresh_grounded_answers.sql), needed search setup and [20_upgrade_apex.sql](../sql/install/20_upgrade_apex.sql) with the existing app ID. For that APEX installer, select its complete outer block excluding the final slash and use **Run Statement** for the bind prompts. The public dataset and credentials stay unchanged unless separately reviewed.

The combined `00_install_schema.sql` and `01_upgrade_schema.sql` retain the same ordered payloads as their generated parts. Choose one form for a route. Do not reinstall individual raw table/package files alongside it. Recovery is a reviewed response to a recorded failed step, not an instruction to clear receipts or rerun all SQL.

## Developer learning and optional exercises

- `sql/scenarios/01_start.sql` through `06_observe.sql`, `08_audit.sql` and `09_propose_change.sql`: inspect and exercise your own Worksheet sample session. Its ID is not an APEX conversation you can take over.
- [02_scenario_api.sql](../sql/extensions/02_scenario_api.sql) and [06_response_provenance.sql](../sql/extensions/06_response_provenance.sql): implementation reading for SPARQL, packet bounds and observable trace capture; do not run these as ad hoc upgrades.
- `sql/extensions/04_domain_extraction.sql` and scenarios07/10: separate domain/OWL exercises where their prerequisites are provided. They are not required for My Contexts; class entailment and extracted proposals are not business-value proof.
- `sql/queries/`: targeted inspection/diagnosis. Check the file's account/prerequisites before execution; view availability can vary by service version.

The release contains prepared SQL. Source extraction, migration authoring, APEXlang changes, mocks and automated build/test tools belong to dev.
