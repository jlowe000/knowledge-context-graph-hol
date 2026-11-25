# Deploy Knowledge Context Explorer

## Introduction

For complete SQL files, use Worksheet **Open File / upload SQL** to load the intended file into its editor, then run it in the mode stated below. Confirm the file is complete. Do not paste a filename as SQL or split a large block by hand; browser upload/execution remains part of the candidate rehearsal.

Install the prepared APEX application into the configured owner schema. This is the clean route; an existing app must use the [same-ID migration](../../docs/migrate-to-v2.md). APEXlang is used by maintainers; learners run supplied SQL.

Estimated Lab Time: 15–25 minutes plus import time; planning estimate.

### Objectives

- Create and enable an APEX workspace mapped to the chosen owner.
- Create an individual app-only login without exposing its password.
- Install a new application and verify both sample and personal entry points.

### Prerequisites

Schema R7 verification, dataset load, grounded-team registration and model greeting have succeeded. Have ADMIN and owner Worksheet access plus the complete release installer. Local search requires its [separate setup](../../docs/context-search.md#worksheet-setup); absence of that model should show keyword fallback.

## Task 1: Prepare the workspace

**Account: ADMIN.** Use the same `KCV_SCHEMA` throughout. `KCV_WORKSPACE` identifies the APEX workspace; it is not another database user. Defaults are KCV_LAB and KCV_KNOWLEDGE.

Run the complete block in [06_cloud_apex_preflight.sql](../../sql/admin/06_cloud_apex_preflight.sql) with Run Statement, excluding the slash and supplying the target binds. Use a compatible APEX 26.1+ service; the app has been tested on 26.1.6. Do not edit an export version to force compatibility.

Run [07_create_apex_workspace.sql](../../sql/admin/07_create_apex_workspace.sql) with Run Statement, excluding its slash. Supply `KCV_SCHEMA` and `KCV_WORKSPACE`. It creates the workspace if absent, verifies the mapping, explicitly enables it and commits. A mismatched mapping must stop; do not repoint an unrelated workspace.

**Expected outcome:** the enabled workspace maps to the intended owner. A workspace API call alone is not proof that it is active or persisted.

## Task 2: Create an app account

As ADMIN, run [08_create_apex_app_user.sql](../../sql/admin/08_create_apex_app_user.sql) with Run Statement, excluding its slash. Supply `KCV_SCHEMA`, `KCV_WORKSPACE`, `KCV_APP_USER` and a private `KCV_APEX_PASSWORD`. The default app username is KCV_USER; use distinct accounts for separate learners. Keep passwords in the browser bind prompt.

**Expected outcome:** an app-only account exists in this workspace. It cannot use App Builder or SQL Workshop. This password is distinct from the owner database password. Existing accounts are not reset. A shared app login shares its My Contexts library.

## Task 3: Install a new app

Sign into the owner's Worksheet and confirm `SELECT USER FROM dual;`. Open [20_install_apex.sql](../../sql/install/20_install_apex.sql), select the complete outer `DECLARE` through the final `END;`, excluding the final slash, and choose **Run Statement (Ctrl+Enter)**. Enter `KCV_SCHEMA`, `KCV_WORKSPACE` and `KCV_APP_ALIAS` consistently; defaults are KCV_LAB, KCV_KNOWLEDGE and KCV-EXPLORER. F5 does not open these bind prompts. A "variable not declared" error requires the complete-block Run Statement selection, not a change to the SQL or a new workspace.

Wait for completion rather than submitting twice. The installer checks schema readiness and allocates a new application ID. Record the reported ID and launch information privately. A duplicate alias or wrong-schema error needs diagnosis, not a forced overwrite.

**Expected outcome:** a new app is installed against this verified schema, with nine pages and seven packaged assets. No separate frontend build or JavaScript upload is required. If the file is absent, obtain the complete release package; do not install development tools to manufacture it.

## Task 4: Sign in and choose an experience

Use the installer launch information or the standard pattern below, replacing every placeholder with your own values. Do not publish an environment URL in a screenshot.

```text
https://YOUR-DATABASE-HOST/ords/r/YOUR-WORKSPACE/YOUR-APP-ALIAS/home
```

Sign into the application with the app account from Task 2, not ADMIN or the database owner. Open **Sample Contexts** to explore Alex/Sam/Casey, or **My Contexts** to create owned work. Verify menu navigation, then ask a sample question and inspect its evidence. Create a synthetic draft, review/apply it and reopen it after signing in again.

**Expected outcome:** the app authenticates, both entry points work, and a real answer has recorded evidence. An import alone does not validate inference or ownership. Use [validation status](../../docs/scenario-validation.md) to record actual results and remaining checks.

## Learn More

- [My Contexts lab](../my-contexts/my-contexts.md)
- [Sample evidence lab](../explore-evidence/explore-evidence.md)
- [APEX deployment reference](../../apex/README.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
