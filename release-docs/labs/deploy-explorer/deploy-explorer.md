# Deploy Knowledge Context Explorer through SQL Worksheet

## Introduction

This is the **SQL-first clean** app-installation lab for the v2.1.0 distribution. App Builder users follow [APEX-led installation](../../docs/apex-led-installation.md). Existing apps use [same-ID upgrade](../../docs/migrate-to-v2.1.md). Do not combine schema transports.

Estimated Lab Time: 15–25 minutes plus import/model waiting time; planning estimate.

### Objectives

- Create/verify a mapped workspace and individual app-only accounts.
- Import a new app, establish the owner binding and complete readiness.
- Verify a real question, recorded evidence and saved-history reopening.

### Prerequisites

Current static-schema verification and approved OCI identity/model access. The RDF network, stored credential/profile, collection and conversation registrations are configured after app import and binding through Deployment setup. Use the matching curated package and actual password-enabled owner Worksheet. This route's [package acceptance](../../db/verification/release-v2.1-paths-validation.json) passed within its recorded mixed Worksheet/SQLcl scope; the schema/app installation and binding ran in Worksheet.

## Task 1: Create and enable the workspace

As ADMIN, run the complete bind blocks in [06_cloud_apex_preflight.sql](../../sql/admin/06_cloud_apex_preflight.sql) and [07_create_apex_workspace.sql](../../sql/admin/07_create_apex_workspace.sql), excluding the slash and using **Run Statement**. Supply the intended KCV_SCHEMA/KCV_WORKSPACE. Confirm correct mapping and explicit enablement; stop on a mismatch. Do not repoint another workspace.

## Task 2: Create installer and learner accounts

As ADMIN, run [08_create_apex_app_user.sql](../../sql/admin/08_create_apex_app_user.sql) with Run Statement. Supply the same schema/workspace, a chosen KCV_APP_USER and private KCV_APEX_PASSWORD. Use distinct accounts for separate libraries. These APEX accounts do not need database logins.

Also create a separate native **APEX workspace-administrator** account, such as KCV_INSTALLER, through [administrator preparation](../../docs/apex-led-administrator-preparation.md#3-create-the-workspace-and-accounts). A developer-only or app-only account cannot use Deployment setup; the username alone grants no rights. This runtime installer account is distinct from ADMIN or the schema-owner database login. SQL import does not require the optional Builder database login/REST import prerequisites. Do not grant setup rights to ordinary learners.

## Task 3: Import a new application

Sign into the actual owner's Worksheet and confirm:

```sql
SELECT USER FROM dual;
```

Open [20_install_apex.sql](../../sql/install/20_install_apex.sql). Select its complete outer DECLARE through final END, excluding the slash, and use **Run Statement**. Enter consistent KCV_SCHEMA, KCV_WORKSPACE and KCV_APP_ALIAS. Record the new app ID/launch link privately. F5 does not open these installer binds. Do not edit the SQL or create another workspace to bypass an undeclared-bind error.

Expected: a new app against the verified schema. The SQL export is definition-only, so no second Supporting Objects backend installation is needed.

## Task 4: Bind and enable learning

Run generated [03_bind_deployment_owner.sql](../../sql/install/03_bind_deployment_owner.sql) as the owner with the imported KCV_APPLICATION_ID and mapped KCV_WORKSPACE, using Run Statement on its complete block. Expect READY_FOR_SETUP, or ALREADY_VERIFIED for the exact existing binding.

Open the installed runtime app and sign in using the workspace's installer APEX account. Follow [guided Deployment setup](../../docs/deployment-setup.md#apex-guided-setup): prepare the graph network; create/select the owner-local credential; configure and test the model; register conversation components; load the public collection; then explicitly enable learning when all six checks are READY. Enter the signing key only in its dedicated masked form, not Worksheet, profile fields or chat. A manual greeting does not satisfy the readiness receipt. Skip actions already READY during an upgrade.

The [owner SQL API](../../docs/deployment-setup.md#sql-first-final-readiness) remains a separately chosen headless/diagnostic alternative. Do not run both setup paths as duplicate work. The updated common-UI sequence is distinct from the earlier recorded SQL-first rehearsal's execution mode.

Expected: all required checks READY and learning explicitly enabled. Optional local embeddings can be absent with the keyword-only banner.

## Task 5: Verify the learner experience

Sign in as an app-only learner. Open Sample Contexts and My Contexts and check menu navigation. Copy a sample or save a synthetic personal draft, review/apply it, ask one learning question and inspect Sources and Answer lineage. Sign out/in and reopen the same answer without asking again.

For read-only collection inspection and optional native checks, follow [Load knowledge and inspect registrations](../load-knowledge/load-knowledge.md) after setup. As the owner, run the [native scenario check](../../integration-test/verify_scenario_native.sql) only after readiness is enabled: complete block, Run Statement, actual KCV_SCHEMA. Its no-inference graph/refinement checks are separate from the real answer. Verify another app-only account cannot see private work or open setup; report unperformed checks.

Record the exact package/result in [validation](../../docs/scenario-validation.md). If checks fail, keep learners out and use [recovery](../../docs/deployment-recovery.md). A successful import alone does not establish inference or ownership.

## Learn More

- [My Contexts](../my-contexts/my-contexts.md)
- [Sample evidence](../explore-evidence/explore-evidence.md)
- [APEX deployment reference](../../apex/README.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
