# Configure the Database Schema

## Introduction

For complete SQL files, use Worksheet **Open File / upload SQL** to load the intended file into its editor, then run it in the mode stated below. Confirm the file is complete. Do not paste a filename as SQL or split a large block by hand. The accepted schema rehearsal used complete numbered files through Worksheet.

Prepare an empty project schema for the supplied v2.1.0 distribution. For an existing project, use [migration](../../docs/migrate-to-v2.1.md); do not run fresh schema creation over it. This is the SQL-first route; APEX-led installers use [their guide](../../docs/apex-led-installation.md) instead. The documented Worksheet flow requires no local software. Its [accepted rehearsal](../../db/verification/release-v2.1-paths-validation.json) used Worksheet for schema/app installation and genuine-owner SQLcl for the successful model test and enablement, so it does not establish all-Worksheet completion.

Estimated Lab Time: 30–60 minutes plus Java enablement/restart and model waiting time; planning estimate.

### Objectives

- Check Java readiness, create a password-enabled owner and apply its grants.
- Install and verify the ordered static schema.
- Prepare the handoff to app import and binding; configure credentials and the model in Deployment setup afterward.

### Prerequisites

[Prepared release files](../prepare-environment/prepare-environment.md), approved ADB Serverless, ADMIN access and OCI inference permission. Use the same chosen schema/workspace names throughout. Blank nonsecret binds use the documented defaults; passwords never default.

## Task 1: Check the platform

**Account: ADMIN.** Run [00_readiness.sql](../../sql/admin/00_readiness.sql) and [00_java_status.sql](../../sql/admin/00_java_status.sql) with F5. ADB Serverless is the minimum supported platform; local-container success is not equivalent.

If JAVAVM is already VALID, leave it enabled. Otherwise the administrator must confirm that this database is suitable for the one-way Java enablement, run [01_enable_java.sql](../../sql/admin/01_enable_java.sql), restart through OCI Console and wait for VALID. Java cannot be disabled afterward. Do not repeat enablement/restart to bypass a different error.

**Expected outcome:** required services are available and JAVAVM is VALID. Retain unrelated databases and applications.

## Task 2: Create the lab owner

**Account: ADMIN.** Run each linked PL/SQL block with **Run Statement**, excluding its trailing slash. Enter values in Worksheet bind prompts privately.

| Order | File | Bind values |
| --- | --- | --- |
| 1 | [01_create_user_worksheet.sql](../../sql/admin/01_create_user_worksheet.sql) | `KCV_SCHEMA`: chosen new owner, default KCV_LAB; `KCV_LAB_PASSWORD`: new private database password |
| 2 | [02_grants.sql](../../sql/admin/02_grants.sql) | The same `KCV_SCHEMA` |
| 3 | [04_enable_database_actions.sql](../../sql/admin/04_enable_database_actions.sql) | The same `KCV_SCHEMA` |

Record the nonsecret owner name privately. An existing owner is not reset by creation: investigate an earlier attempt or choose migration. The custom schema must satisfy the scripts' KCV-prefixed naming validation. Keep passwords out of SQL files, screenshots and chat.

**Expected outcome:** the password-enabled owner has the required quota/grants and its own Database Actions route. It is separate from the later APEX app-user login.

## Task 3: Install the complete static schema

Sign into the owner's Database Actions Worksheet, normally KCV_LAB. Switching database accounts may expire an earlier Worksheet login. Confirm the identity with Run Statement:

```sql
SELECT USER FROM dual;
```

Use the generated [schema-parts guide](../../sql/install/schema-parts/README.md). Run **fresh** parts in the exact manifest order, each as a complete F5 script; wait for success before the next file. Never split a PL/SQL block by hand. The combined [00_install_schema.sql](../../sql/install/00_install_schema.sql) is an alternative only for a supported transport; choose one form. Do not also run raw tables/packages from `sql/schema/` or `sql/extensions/`.

Then run [02_verify_schema.sql](../../sql/install/02_verify_schema.sql) with F5. Expect 121 COMPLETE project receipts, 2.1.0-apl-r4-ready, no invalid objects and matching installed source. The Worksheet route does not need a Liquibase ledger. Stop on any error; earlier DDL may already be committed.

**Expected outcome:** tables, APIs, migration receipts and static search/deletion objects are installed. No user credential, model, dataset or RDF network was created by these bundles.

## Task 4: Continue to the app installation

The verified static schema is enough to import the application. Its RDF network, credential, model profile, conversation components and public dataset can be absent at this point.

Continue to [deploy the app](../deploy-explorer/deploy-explorer.md): create the workspace and separate installer/learner accounts, import the app, then run the generated owner binding. Sign into the runtime app as the workspace-administrator installer and complete **Deployment setup** there.

Do not run the old manual credential/profile/greeting sequence before that flow. The app creates or selects the owner-local credential, configures/registers KCV_GENAI and records the required model test. [Authentication](../../docs/authentication.md) explains the OCI identity/IAM prerequisites and separately labelled headless alternatives. Resource-principal IAM preparation remains an administrator task; it is not performed by the credential form.

**Expected outcome:** the owner has the complete static schema and is ready for app import. Successful schema installation alone does not establish model access or learner readiness.

## Learn More

- [Installation paths](../../docs/installation-paths.md)
- [Need help?](../need-help/need-help.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
