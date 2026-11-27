# Prepare ADB and the APEX workspace

This prepares a facilitator-managed environment for the **v2.1.0 distribution**. All four APEX-led and SQL-first core paths passed on prepared environments, but positive execution of these public preparation templates remains untested. The prepared-environment tests did not rehearse new-database creation or first Java enablement/restart. See [validation](scenario-validation.md).

## 1. Select the database and access

An OCI administrator creates or selects an approved ADB Serverless instance with the required Oracle AI Database/APEX capabilities, adequate storage and a reachable network path. Wait for **Available**, then open Database Actions and APEX from its Console details. Model access/IAM and operating costs remain facilitator responsibilities.

A working APEX host alone is insufficient: this example needs database Java/RDF, VECTOR, DBMS_CLOUD, Select AI and agent APIs. Do not assume oracleapex.com provides these capabilities. Use [platform readiness](../sql/admin/00_readiness.sql) and [Java status](../sql/admin/00_java_status.sql) as ADMIN. If Java is already VALID, leave it enabled. If absent, the administrator must approve the one-way enablement, use [01_enable_java.sql](../sql/admin/01_enable_java.sql), restart in OCI and wait for VALID. Local laptop Java is not database JAVAVM.

```sql
SELECT comp_id,status FROM dba_registry WHERE comp_id='JAVAVM';
```

Expected: JAVAVM is VALID and the required API/capability checks pass. Review [Oracle's provisioning guide](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-provision.html) for Console fields. Keep account passwords, live endpoints and tenancy identifiers private.

## 2. Choose the owner route

The project owner stores tables, packages and graphs. The APEX workspace maps to that owner; an APEX learner account is a separate identity.

| Route | ADMIN steps | Result |
| --- | --- | --- |
| **APEX-led clean** | [15_create_apex_owner.sql](../sql/admin/15_create_apex_owner.sql), then [02_grants.sql](../sql/admin/02_grants.sql) | New schema-only owner, 1 GB DATA quota, required grants; no owner password or proxy account is created |
| **SQL-first clean** | [01_create_user_worksheet.sql](../sql/admin/01_create_user_worksheet.sql), [02_grants.sql](../sql/admin/02_grants.sql), then [04_enable_database_actions.sql](../sql/admin/04_enable_database_actions.sql) | Password-enabled owner with its own Worksheet |
| **Upgrade** | Retain the existing owner; verify required privileges and add missing grants only | Existing identity, data and credentials preserved |

For bind-bearing setup files, load the complete file into ADMIN Worksheet, select its complete outer DECLARE/BEGIN through END without the trailing slash, and use **Run Statement**. Match private values by bind name. Use the same `KCV_SCHEMA` everywhere; blank nonsecret defaults select KCV_LAB. Passwords have no default. Do not use both creation routes for the same owner.

The APEX-led owner deliberately cannot sign into Worksheet with a password. Supporting Objects runs in the mapped owner. Owner-assisted recovery is a separately reviewed administrator task; the release does not require dev's SQLcl, wallet or ADMIN-proxy bootstrap.

Expected: the intended empty owner has quota/grants, but no project backend yet. Do not install SQL-first schema parts before an APEX-led clean import.

## 3. Create the workspace and accounts

1. As ADMIN, run [06_cloud_apex_preflight.sql](../sql/admin/06_cloud_apex_preflight.sql), then [07_create_apex_workspace.sql](../sql/admin/07_create_apex_workspace.sql). Supply the intended `KCV_SCHEMA` and `KCV_WORKSPACE`; blank defaults are KCV_LAB/KCV_KNOWLEDGE. The latter creates or verifies the mapping and explicitly enables the workspace. A mismatch must stop.
2. In **APEX Administration Services → Manage Workspaces → Manage Developers and Users**, create an installer account in that workspace with developer and workspace-administrator rights. Use private password entry. See [Oracle's workspace account instructions](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/apex-create-accounts.html).
3. If ADB's Builder sign-in uses database SSO, confirm the corresponding database login. When absent, [13_create_builder_login.sql](../sql/admin/13_create_builder_login.sql) creates the chosen `KCV_INSTALLER_USER` with **CREATE SESSION only**, using private `KCV_BUILDER_PASSWORD`. It grants no roles, project-object access or workspace membership and refuses to reset an existing login. Complete workspace membership separately in step 2.
4. Create individual learner accounts with [08_create_apex_app_user.sql](../sql/admin/08_create_apex_app_user.sql), supplying the same owner/workspace and a distinct `KCV_APP_USER` with private `KCV_APEX_PASSWORD`. These are app-only APEX accounts; they do not need database logins or Builder privileges.
5. Verify the installer reaches the intended workspace's **App Builder → Import**. Administration Services and the runtime app login are different destinations. Do not reset passwords to guess which sign-in a page expects.

For an upgrade, keep the existing workspace and learner accounts. Verify or add the authorised installer separately; do not recreate the application users.

## 4. Prepare APEXlang browser import

The APEX-led route requires APEX 26.1-compatible application support, **ORDS 26.1.1+** and at least one REST-enabled schema mapped to the workspace. Earlier rehearsal used APEX 26.1.6. Follow [Oracle's APEXlang import requirements](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/importing-apexlang-app-builder.html); do not edit export version metadata to bypass incompatibility.

After approving this access change, ADMIN runs [12_prepare_apexlang_rest.sql](../sql/admin/12_prepare_apexlang_rest.sql) with the exact owner/workspace binds. It enables authenticated metadata and no table APIs. Existing ORDS configuration is retained for review; verify its required state rather than silently replacing it. This prerequisite is specific to the APEXlang import route, not permission to publish project tables.

Expected: the installer can select the intended parsing schema and import the reviewed application ZIP. Workspace creation alone does not prove browser ZIP readiness.

## 5. Prepare private model access and hand over

Agree an approved OCI identity, inference region/compartment, supported model name and credential route using [model authentication](authentication.md). An API signing key differs from a Console password. A resource principal requires separate dynamic-group/IAM preparation. The package contains neither identity configuration nor private keys.

Choose one owner-local credential route:

- Retain a suitable existing credential on an upgrade.
- After Supporting Objects succeeds, use the installer's [dedicated credential form](deployment-setup.md#create-a-credential-privately-if-needed).
- As a facilitator alternative, use [14_prepare_owner_credential.sql](../sql/admin/14_prepare_owner_credential.sql) in ADMIN Worksheet with exact schema/workspace and four private OCI binds. It supports the prepared schema-only or password owner, refuses replacement and removes its temporary helper. Review existence/error status before retrying a partially successful operation. Never save a populated key block.
- A SQL-first owner can use its own private [credential Worksheet block](authentication.md#a-existing-oci-user-credentials).

Review outbound connectivity for the selected model and anonymous public GitHub dataset fetch. Do not grant blanket network access merely because a different operation needs an ACL; use the [dataset access guidance](github-dataset-load.md). Optional [local semantic search](context-search.md) is separate from chat inference. Without its model the app explicitly uses keyword matching.

Hand over the matching package, privately recorded target identity, Builder/runtime sign-in distinction and approved model settings. Continue with [APEX-led clean installation](apex-led-installation.md) or [APEX-led upgrade](apex-led-upgrade.md). **Environment prepared** is not yet **Ready for learners**; schema installation, six checks, explicit enablement and a real learner test still follow.
