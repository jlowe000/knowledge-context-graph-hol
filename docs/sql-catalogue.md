# SQL catalogue and execution order

App-only learners run no SQL. Developer learners use [Understand the collection](../labs/understand-collection/understand-collection.md). Facilitators choose [APEX-led or SQL-first, clean or upgrade](installation-paths.md); never run every file alphabetically. This v2.1.0 distribution's four prepared-environment path tests passed within the scopes in [validation](scenario-validation.md).

Use Run Statement for complete bind-bearing blocks, excluding the trailing slash. Use Run Script/F5 for generated schema parts and explicitly script-mode files. Read each result before the next step.

## SQL-first clean installation

| Phase | Account | Files/order |
| --- | --- | --- |
| Platform | ADMIN | sql/admin/00_readiness.sql and 00_java_status.sql; only if needed/approved, 01_enable_java.sql and OCI restart |
| Password owner | ADMIN | sql/admin/01_create_user_worksheet.sql, 02_grants.sql, 04_enable_database_actions.sql |
| Static schema | Owner | [Fresh parts](../sql/install/schema-parts/README.md), then [02_verify_schema.sql](../sql/install/02_verify_schema.sql) |
| Workspace/accounts | ADMIN | sql/admin/06_cloud_apex_preflight.sql and 07_create_apex_workspace.sql; native installer workspace-admin account through APEX Administration Services; separate learners through 08_create_apex_app_user.sql |
| New app | Owner | [20_install_apex.sql](../sql/install/20_install_apex.sql), complete outer block with Run Statement, or the documented configured F5 wrapper |
| Binding | Owner | [03_bind_deployment_owner.sql](../sql/install/03_bind_deployment_owner.sql) after import |
| Credential/model/runtime setup | Installer APEX account | [Deployment setup](deployment-setup.md#apex-guided-setup): network, credential, profile/test, registrations, public collection, explicit enablement |
| Optional embeddings | ADMIN, owner | [Context-search setup](context-search.md#worksheet-setup), separate from OCI chat profile |
| Verification | App user, owner | Learner evidence/persistence and native scenario checks after readiness is enabled |

Manual credential creation, 05_profile_worksheet.sql, 06_register_profile.sql, 02_network.sql, 10_load_github.sql and standalone agent registration remain available for separately chosen [headless/diagnostic alternatives](authentication.md). They are not additional steps in the normal app-guided setup sequence. Retain existing profile/data/registrations on upgrade.

A manual sql/queries/00_test_genai.sql greeting is an optional diagnostic model call, not the v2.1 setup-test receipt. Avoid duplicating calls when the required setup test already passed.

## SQL-first upgrade

Follow [v2.0.0 to v2.1.0](migrate-to-v2.1.md): verify the published baseline, apply the upgrade parts and full verifier, replace the **same app ID** with [20_upgrade_apex.sql](../sql/install/20_upgrade_apex.sql), run 03 binding and complete only missing readiness in the runtime app as the workspace-administrator installer. Preserve credentials, collection and personal history. Use bounded REGISTER_RUNTIME only when required components are missing; do not rerun fresh registrations blindly.

The v1 completion/adoption helpers are not part of this v2.1 package. Use the [published v2.0.0 bridge](migrate-to-v2.md), with that package's matching scripts, before upgrading again. Unknown or partial checkpoints need maintainer review.

Combined 00_install_schema/01_upgrade_schema files use the same ordered payloads as their parts; select one transport. Recovery is a response to an identified failed step, not permission to clear receipts or rerun all raw SQL.

## APEX-led preparation

The facilitator uses [neutral preparation](apex-led-administrator-preparation.md): new schema-only sql/admin/15_create_apex_owner.sql, 02_grants and 07 workspace; 12 authenticated REST metadata for APEXlang import; optional 13 CREATE SESSION-only Builder login and 14 private owner-credential helper. Workspace admin/developer membership and learner accounts are separate tasks. The application ZIP's Supporting Objects installs/upgrades and binds the backend; do not duplicate that with SQL-first schema scripts. Dev bootstrap/proxy tools are not part of this route.

## Developer learning and optional exercises

- sql/scenarios/01_start.sql through 06_observe.sql, 08_audit.sql and 09_propose_change.sql use your own Worksheet session after readiness. An APEX conversation is not a session to take over.
- [Scenario API](../sql/extensions/02_scenario_api.sql) and [response provenance](../sql/extensions/06_response_provenance.sql) are implementation reading for SPARQL, bounded evidence and trace capture; do not execute them as ad hoc upgrades.
- Domain/OWL extraction exercises are separate optional labs, not prerequisites for My Contexts or business-value proof.
- sql/queries contains targeted diagnosis; read each file's account/prerequisites.

Migration authoring, PDF extraction, APEXlang editing and automated build tools belong to dev. The release is prepared for using or understanding this collection.
