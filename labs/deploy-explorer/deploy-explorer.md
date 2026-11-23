# Deploy Knowledge Context Explorer

## Introduction

Install the supplied app without building an APEX application yourself. The primary route uses SQL Worksheet; App Builder is an alternative for readers who already have a workspace developer account.

Estimated Lab Time: 15–25 minutes; planning estimate.

### Objectives

In this lab, you will:

- Create an APEX workspace mapped to KCV_LAB.
- Create a separate app-user login.
- Import the app and open its private URL.

### Prerequisites

The native scenario check passed, you can sign in as ADMIN and KCV_LAB, and `work/worksheet/20_install_apex.sql` is available on your browser computer.

## Task 1: Check APEX and create the workspace

**Where:** SQL Worksheet. **Account:** ADMIN.

1. Sign into ADMIN Worksheet. Run [06_cloud_apex_preflight.sql](../../sql/admin/06_cloud_apex_preflight.sql) with F5. The app export was generated on APEX 26.1.5 and validated on Serverless 26.1.6; use a compatible APEX 26.1+ service. Do not edit the version number inside the export to force an older installation.

2. Check whether KCV_KNOWLEDGE already appears in the workspace query. On a fresh installation it should not. If it exists from an earlier attempt, check that it maps to KCV_LAB rather than creating a second workspace blindly.

3. If absent, create it with F5:

<!-- include-sql: sql/admin/07_create_apex_workspace.sql -->

```sql
<copy>
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
    p_workspace=>'KCV_KNOWLEDGE',p_primary_schema=>'KCV_LAB');
END;
/
</copy>
```

[Script: 07_create_apex_workspace.sql](../../sql/admin/07_create_apex_workspace.sql)

<!-- /include-sql -->

**Expected outcome:** the procedure completes. KCV_KNOWLEDGE is an APEX workspace using the existing KCV_LAB schema. It is not another database and does not create a login password.

## Task 2: Create the application user

**Where:** SQL Worksheet. **Account:** ADMIN.

1. Use the block below with **Run Statement**, excluding the slash. Enter a new private password in the KCV_APEX_PASSWORD bind dialog and submit it. Do not put the password in the SQL text.

<!-- include-sql: sql/admin/08_create_apex_app_user.sql -->

```sql
<copy>
BEGIN
  APEX_UTIL.SET_SECURITY_GROUP_ID(APEX_UTIL.FIND_SECURITY_GROUP_ID('KCV_KNOWLEDGE'));
  APEX_UTIL.CREATE_USER(p_user_name=>'KCV_USER',p_web_password=>:KCV_APEX_PASSWORD,
    p_developer_privs=>NULL,p_allow_app_building_yn=>'N',p_allow_sql_workshop_yn=>'N',
    p_allow_team_development_yn=>'N',p_change_password_on_first_use=>'N');
  COMMIT;
END;
</copy>
```

[Script: 08_create_apex_app_user.sql](../../sql/admin/08_create_apex_app_user.sql)

<!-- /include-sql -->

2. Keep this password associated with **KCV_USER**, not KCV_LAB. This is an APEX end user: it can use the application but cannot open App Builder or SQL Workshop. Account creation is an ADMIN task on the validated Serverless route.

**Expected outcome:** the procedure completes and the new APEX login exists. Existing accounts are not reset. If policy rejects the password or the account exists, resolve that specific message with the administrator; do not rerun database provisioning.

## Task 3: Install the application

**Where:** SQL Worksheet. **Account:** KCV_LAB.

1. Sign back into KCV_LAB Worksheet and check `SELECT USER FROM dual;`.

2. Open the generated `work/worksheet/20_install_apex.sql`, replace the editor contents with the whole script and run **F5**. This can take time; do not submit it repeatedly while it is running. The script sets the workspace/schema and allocates a new app ID.

3. Look for compatibility/import success and `KCV_APPLICATION_ID=` followed by a number. Record the number privately. Your number need not be 100; screenshots from the working demonstration are examples.

**Expected outcome:** a new app named Knowledge Context Explorer is installed in KCV_KNOWLEDGE with parsing schema KCV_LAB and alias KCV-EXPLORER. If a duplicate alias is reported, inspect the existing app from your earlier attempt. Do not change the script to overwrite an unrelated application.

If the generated file is missing, return to your Oracle Linux terminal at the project root and run:

```bash
<copy>
.venv/bin/python scripts/build_apex_worksheet.py
</copy>
```

The app SQL export is already supplied. SQLcl, a frontend build framework and local APEX are not required to install it. [App Builder import](../../apex/README.md) requires a separate developer account; KCV_USER is intentionally not one.

## Task 4: Open and sign in to the app

**Where:** browser. **Account:** KCV_USER.

1. Take the host from your own Database Actions URL, retaining `https://` and everything before `/ords/`. Add this application path:

   ```text
   /ords/r/kcv_knowledge/kcv-explorer/home
   ```

2. Open the resulting URL in a new tab. The pattern is `https://YOUR-DATABASE-HOST/ords/r/kcv_knowledge/kcv-explorer/home`; replace the placeholder with your own host. Do not use the author's temporary database URL.

3. Sign in as KCV_USER with the password from Task 2. If the login fails, check that you are on the application login rather than Database Actions, and that the account was created in KCV_KNOWLEDGE.

**Expected outcome:** the app displays the Learner scenario selector and Conversation, Evidence, Context and Observations views. Iris styling is part of the supplied Universal Theme app. A successful app import does not yet establish that model calls work from the application session.

The current export includes non-PDF source links, locator labels and versioned JavaScript assets. No additional application-file upload is required. If you intentionally retained an older export instead of importing this version, use the [older-installation fallback](../../docs/content-ingestion-upgrade.md#manual-fallback-for-an-older-installed-export) before testing non-PDF evidence.

Continue to [Explore the evidence](../explore-evidence/explore-evidence.md).

## Learn More

- [APEX installation reference](../../apex/README.md)
- [Existing-installation upgrade route](../../docs/epics-upgrade.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
