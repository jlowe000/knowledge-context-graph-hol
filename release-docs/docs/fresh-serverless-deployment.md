# SQL-first clean installation of v2.1.0

**v2.1.0: this prepared-environment SQL-first clean route passed within its recorded mixed-transport scope.** Schema/app installation and owner binding passed in Worksheet; the successful model test and explicit enablement used genuine-owner SQLcl. Learner evidence, persistence and bounded reviewer checks passed. See [validation](scenario-validation.md) for exact execution forms and limits. Use an empty project schema on an approved ADB Serverless database. Existing projects use [v2.0.0 to v2.1.0 upgrade](migrate-to-v2.1.md). The [installation selector](installation-paths.md) also offers App Builder installation.

The [published v2.0.0 SQL-first record](../db/verification/release-v2-paths-validation.json) retains its earlier passing scope. It does not establish this 121-step package's transport, binding or readiness gates; see [v2.1 validation](../db/verification/release-v2.1-paths-validation.json). New database provisioning was not exercised by the earlier rehearsal.

If a facilitator supplied an app, go directly to [My Contexts](../labs/my-contexts/my-contexts.md). Deployment needs ADMIN/owner access; learners do not.

## Before starting

Obtain one matching versioned package. Use a **password-enabled owner with its own Database Actions Worksheet**. The schema-only APEX-led route and dev's proxy/SQLcl workflow are not prerequisites for this SQL-first path. No local Python, Java, wallet, SQLcl, Liquibase or shell is needed.

For complete SQL files, use Worksheet **Open File/upload SQL**, confirm the file is complete and choose its documented execution mode. Use **Run Script (F5)** for the chosen schema execution form and the optional application-script wrapper described below. For bind-bearing setup and app-installer blocks, select the complete outer DECLARE/BEGIN through END without the trailing slash and use **Run Statement**. Do not split PL/SQL blocks or paste filenames as SQL. Stop on an error before dependent work.

For the schema, choose **one execution form**: the complete [00_install_schema.sql](../sql/install/00_install_schema.sql) file or the numbered **fresh** [schema parts](../sql/install/schema-parts/README.md). Both contain the same ordered canonical steps. Upload the chosen complete file(s) through Open File and use **Run Script (F5)**. The numbered parts were used in the accepted rehearsal. The combined file reduces file handling, but its large-file Worksheet transport remains unverified; it is not a preferred or accepted transport.

If upload is rejected before execution, use the parts instead. After any migration starts—or a timeout leaves execution uncertain—inspect receipts and [recovery guidance](deployment-recovery.md) before switching forms or retrying. Do not run both as separate installations.

## Installation sequence

SQL-first controls schema and application installation; **Deployment setup** is the common credential/model/runtime configuration interface. The sequence below moves those settings after app import and binding. Earlier route evidence retains its recorded manual/mixed-transport scope; this documentation change is not a new end-to-end test. Keep [manual/headless alternatives](authentication.md) for a separately chosen need, not as duplicate work before the app flow.

| Step | Account | Action and expected result |
| --- | --- | --- |
| 1. Platform | ADMIN | Run readiness/Java checks; retain VALID JAVAVM. Complete separately approved first enablement/restart only if required. |
| 2. Owner | ADMIN | Use 01_create_user_worksheet, 02_grants and 04_enable_database_actions with the same KCV_SCHEMA/private password. Confirm the empty owner can open its Worksheet. |
| 3. Schema | Owner | Run the chosen complete [clean script](../sql/install/00_install_schema.sql) or ordered **fresh** [parts](../sql/install/schema-parts/README.md), then [02_verify_schema.sql](../sql/install/02_verify_schema.sql). Expect the matching 121-step contract and valid source. Do not also run raw tables/packages. |
| 4. Workspace and accounts | ADMIN | Create/enable the mapped workspace; create a native APEX workspace-administrator installer account such as KCV_INSTALLER and separate app-only learner accounts. See [account preparation](apex-led-administrator-preparation.md#3-create-the-workspace-and-accounts). SQL import does not require a separate Builder database login or REST setup. |
| 5. New app | Owner | Use [20_install_apex.sql](../sql/install/20_install_apex.sql) with Run Statement/binds, or [20_install_apex_script.sql](../sql/install/20_install_apex_script.sql) with explicit configuration/F5. Record the new app ID/alias privately. A credential, profile and dataset are not import prerequisites. |
| 6. Bind owner | Owner | Run generated [03 binding](../sql/install/03_bind_deployment_owner.sql) with the new app ID and mapped workspace. Expect READY_FOR_SETUP. |
| 7. Shared Deployment setup | Installer APEX account | Sign into the runtime app and [prepare network, create/select credential, configure/test model, register components and load the collection](deployment-setup.md#apex-guided-setup). Enable learning when all six checks are READY. No manual profile/registration SQL is needed for this normal path. |
| 8. Optional search | ADMIN, owner | Follow [local search setup](context-search.md#worksheet-setup) only if wanted. Without it the app labels keyword-only search; chat uses its separate profile. |
| 9. Learner verification | App user, then owner | Test Sample Contexts/My Contexts, a real answer and its evidence, then sign out/in and reopen it. Run scenario checks only after readiness is enabled. |

ADMIN filenames above are under sql/admin. The [configuration lab](../labs/configure-database/configure-database.md) and [app deployment lab](../labs/deploy-explorer/deploy-explorer.md) provide full links and expected outcomes.

### Choose the application execution form

The original **Run Statement** installer remains valid. It opens bind prompts for the target schema, workspace and alias. Alternatively, open [20_install_apex_script.sql](../sql/install/20_install_apex_script.sql) and edit only its labelled configuration block: replace the NULL values for `l_schema`, `l_workspace` and `l_alias` with your exact uppercase values in single quotes. These are non-secret target identifiers; do not add passwords, keys or model configuration. Unfilled NULL targets fail before import.

Run the **complete script file, including its final slash, with Run Script (F5)**. This form needs no SQLcl and retains the authenticated-owner, alias and full-schema checks. It creates a new application; it must not replace an existing app. Then continue with the separate owner-binding step, whose original Run Statement/bind form is unchanged. The [validation record](../db/verification/release-v2.1-paths-validation.json) distinguishes the execution forms actually tested; generating a wrapper does not establish native acceptance.

Choose one application execution form. If the browser stalls, a bind prompt is delayed or the result is unknown, inspect applications, activity and status using [recovery guidance](deployment-recovery.md#worksheet-application-import-or-bind-prompt-delay) before retrying or changing forms. Do not blindly repeat the new-app allocator. Changing how the application SQL is submitted does not require repeating schema installation, data loading or conversation-component registration.

Confirm the owner before owner scripts:

```sql
SELECT USER FROM dual;
```

After the full verifier, this additional checkpoint query should return one COMPLETE row for version 2.1.0:

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.1.0-apl-r4-ready';
```

Neither query substitutes for the physical/program verifier, model test or learner checks. Worksheet installation does not require a Liquibase ledger.

## Completion and recovery

Record the exact package and separate clean-route outcome in [v2.1 validation](../db/verification/release-v2.1-paths-validation.json). Verify saved personal evidence survives a new sign-in without another question, and record account-isolation checks actually performed.

A failed step may leave committed DDL. Retain receipts and use [recovery](deployment-recovery.md); do not drop the owner/network or recreate credentials to hide a failed step. See [safe screenshot guidance](screenshots.md) for beginner documentation without private details.
