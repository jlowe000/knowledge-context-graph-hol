# Prepare an environment for APEX-led installation — development reference

This page retains the r13 development preparation procedure and its historical scope. For the current curated v2.1.0 package, use [administrator preparation](../release-docs/docs/apex-led-administrator-preparation.md) and the [installation selector](../release-docs/docs/installation-paths.md). The subsequent [four-route record](../db/verification/release-v2.1-paths-validation.json) covers prepared environments, not new-database provisioning or first Java activation. Publication statements below describe the earlier checkpoint.

**Unpublished dev candidate guidance; both prepared-environment core paths passed with stated limits.** Follow the [candidate validation record](../db/verification/apex-led-candidate-validation.json) for measured scope. Preparation is performed by an administrator or facilitator before the workspace installer follows [Install through APEX](apex-led-deployment.md). The published v2.0.0 package remains SQL-first.

R13 passed actual clean ZIP installation, guided setup and learner persistence on an already prepared ADB, plus a populated published-v2 same-application upgrade with retained historical evidence. Reviewer isolation and bounded native credential/concurrency/recovery checks also passed. The [acceptance review](apex-led-acceptance-review.md) preserves the exact comparisons and earlier checkpoints. These results do not establish new-database provisioning, first Java activation/restart or universal audit/request-log protection; the candidate remains unpublished.

The intended handoff is a prepared ADB Serverless database and workspace plus one reviewed APEXlang application ZIP. The installer uploads that ZIP intact through App Builder, installs its Supporting Objects backend and compilation steps, then uses guided configuration and collection loading. It does not require every learner to have an OCI account. The facilitator remains responsible for database availability, permissions, model access, operating costs and recovery.

## Start from your current position

| Starting point | Begin here | Do not repeat |
| --- | --- | --- |
| No suitable database | Step 1: create ADB in OCI, then complete steps 2–5 | Nothing is assumed to exist |
| Approved existing ADB, no project workspace | Step 2: verify capabilities, then prepare a separate schema and workspace | Database provisioning or Java enablement when already ready |
| Facilitator-prepared schema and workspace | Confirm the step 5 handoff, then [import the ZIP](apex-led-deployment.md#1-import-the-supplied-application-zip) | User creation, grants, workspace creation or credential replacement |
| Existing project application to upgrade | Follow the preservation checks below and the supported upgrade route | A fresh owner/workspace, fresh schema installation or deletion of saved work |

The complete sequence is **OCI database → database readiness and owner → APEX workspace and access → private model preparation → application ZIP → Supporting Objects → guided setup → learner verification**. These preparation steps belong in the installation journey even when a facilitator completes them for participants. The current rehearsal uses an existing database; creating a new database and first-time Java enablement have not been validated by that rehearsal.

## 1. Create or select ADB in OCI

**Account: your OCI Console identity.** Obtain permission to use the intended compartment and region before starting.

1. Open the OCI Console and navigate to **Oracle AI Database → Autonomous AI Database**. Select the intended region and compartment.
2. Choose **Create Autonomous AI Database**. Select the Serverless deployment and an Oracle AI Database **26ai** configuration that meets the package's required capabilities. Transaction Processing is the intended lab workload; confirm it in the eventual acceptance record.
3. Enter a display name and an alphanumeric database name. The database name is separate from a schema/workspace name such as `KCV_V2_004`; do not put underscores into the database-name field.
4. Review the tenancy-approved compute, storage, autoscaling, licensing and network settings. Use a network path reachable by the installer and learners. This guide does not assume a particular Free, Developer or Paid configuration has passed acceptance.
5. Set the **ADMIN** password privately, review the creation summary and create the database. Wait for its lifecycle state to become **Available**.

Expected outcome: the intended ADB is available and its Database Actions and APEX launch links can be opened from its details page. OCI sign-in and the database ADMIN password are separate credentials. See [Oracle's provisioning instructions](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-provision.html) for current Console fields.

## 2. Check database capabilities

**Account: database ADMIN in Database Actions → SQL Worksheet.** Open Database Actions from the database details page, sign in privately, and open **SQL**.

Run this short query to check database Java:

```sql
SELECT status, version
FROM dba_registry
WHERE comp_id = 'JAVAVM';
```

Expected: one row with `VALID`. No row means Java is not installed; `LOADING` means installation is incomplete. If it is already `VALID`, keep it enabled and continue.

For a new database that needs Java, the administrator must review the database-wide, irreversible enablement before running:

```sql
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_FEATURE(feature_name => 'JAVAVM');
END;
```

Select the whole block and use **Run Statement**. Restart the database through OCI, wait for **Available**, reopen Worksheet and repeat the status query until `VALID`. Availability alone does not mean Java has finished installing. Oracle documents the [enablement, restart and status checks](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-oracle-java.html).

Check the database/APEX/ORDS versions, native VECTOR support and the required APIs listed in the capability table below. A package synonym alone does not prove usable access. Expected outcome: the administrator can prepare a project owner with the required direct grants, and any missing platform capability is resolved before importing an application.

## 3. Prepare the project owner and grants

**Account: database ADMIN.** Select a new schema/workspace identity using `KCV_V<major>_<three-digit-build>`, for example `KCV_V2_004` when that name is unused. The schema owns the application's tables, packages and graphs; the workspace is the APEX development area mapped to it.

For the current isolated dev rehearsal, open [09_create_dev_schema.sql](../sql/admin/09_create_dev_schema.sql) in ADMIN Worksheet. Select its complete `DECLARE`–`END;` block, excluding the final slash, use **Run Statement**, and supply the chosen schema as `KCV_DEV_SCHEMA`. The helper checks prerequisites and name availability before creating the owner, its quota, direct grants and approved ADMIN proxy access. It intentionally stops if that owner already exists.

Expected outcome: the new owner exists with the required privileges and storage, while the project backend tables have not yet been installed. Those tables and compilation steps belong to Supporting Objects. The helper creates a `NO AUTHENTICATION` owner; it cannot sign into Worksheet with a password. The facilitator can prepare its credential from ADMIN Worksheet using step 5 below, or use the reviewed installer form after Supporting Objects. The [private owner connection](fresh-dev-deployment.md) remains the dev alternative; SQLcl is not required by the workspace installer.

Use the matching, reviewed preparation scripts for the chosen route. Older files that name `KCV_LAB` directly must not be run against a differently named build. Do not install the full backend with the SQL-first schema scripts before the clean Supporting Objects test.

## 4. Create the APEX workspace and installer access

**Account: database ADMIN in APEX Administration Services, then the workspace installer in App Builder.** Complete this before application import.

1. From the database details page or Database Actions, launch **APEX**. Sign in as ADMIN and select **Administration Services** when a workspace selector is shown.
2. Choose **Create Workspace**. In **Database User**, select the existing project schema prepared in step 3. Set **Workspace Name** to the chosen build name and create the workspace. For an existing database user, the creation screen does not require a new database password. ADMIN cannot be the workspace's schema. See [Oracle's workspace creation steps](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/apex-create-workspace.html).
3. Verify that the workspace is enabled and maps to the intended schema. For the scripted dev route, [10_create_dev_workspace.sql](../sql/admin/10_create_dev_workspace.sql) creates and enables that mapping with the `KCV_DEV_SCHEMA` and `KCV_DEV_WORKSPACE` binds. Choose either UI creation or the scripted creation; an existing workspace is a verification task.
4. Under **Manage Workspaces → Manage Developers and Users**, create the intended installer account in that workspace with developer and workspace-administrator rights. Enter passwords privately. Confirm its corresponding database login for the configured ADB SSO mode; see [Oracle's developer-account instructions](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/apex-create-accounts.html). If a native workspace account was created by SQL and its database login is missing, ADMIN can run [13_create_builder_login.sql](../sql/admin/13_create_builder_login.sql) with **Run Statement** and enter the password privately. This creates `KCV_INSTALLER` with **CREATE SESSION only**; it does not add roles, object grants or workspace access, and refuses to reset an existing account.
5. Sign into APEX as the installer, select the new workspace and open **App Builder**. Check that **Import** is available. Reaching Administration Services or an application login page is not this checkpoint.
6. Confirm the APEXlang ZIP prerequisites: **ORDS 26.1.1+** and **at least one REST-enabled schema in this workspace**. After reviewing this access change, ADMIN can run [12_prepare_apexlang_rest.sql](../sql/admin/12_prepare_apexlang_rest.sql) with the chosen schema and workspace binds. It enables the schema with metadata-catalog authentication and enables no table APIs. Existing ORDS configuration is retained for separate review. Workspace creation alone does not establish this prerequisite. The Import wizard can also offer **REST Enable Schema**, as described in [Oracle's APEXlang import steps](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/importing-apexlang-app-builder.html); use one approved route, not both.

Expected outcome: the installer is in the correct workspace's App Builder, its parsing schema is available, and browser ZIP import prerequisites are met. Create individual app-only learner accounts separately; learners do not need database logins or Builder privileges.

## 5. Prepare model access and hand over to the installer

Complete the private model and outbound-access sections below for this specific owner. Agree one credential route: retain an existing owner-local credential, prepare it privately as ADMIN, or use the reviewed installer form. Share the approved credential **name**, model **name**, inference region and compartment privately. The credential must be local to the project owner before profile configuration; it is never included in the ZIP.

For the facilitator-prepared route using an existing OCI user signing key:

1. In **ADMIN Database Actions → SQL Worksheet**, open [14_prepare_owner_credential.sql](../sql/admin/14_prepare_owner_credential.sql).
2. Select the complete `DECLARE`–`END;` block, excluding the final slash, and use **Run Statement**. Do not paste a populated key into the editor.
3. In the private bind dialog, set `KCV_SCHEMA` to the chosen owner. Match the four OCI fields by name: user OCID, tenancy OCID, fingerprint and the corresponding unencrypted signing-key body without PEM BEGIN/END lines. These values grant that owner use of the OCI identity; review its inference permissions first.
4. Submit privately. Expect **Owner-local OCI_USER_CRED created; temporary helper removed.** The administrator helper passes the values as binds to a temporary definer-rights procedure in the chosen owner, grants no access to it, and removes it afterwards. The procedure source contains no key. A nonfunctional credential probe verified this ownership mechanism; a successful inference test is still required for the actual signing key.
5. If creation reports an error, inspect the numeric code and credential/helper existence before retrying. Creation may have succeeded before cleanup failed; existing credentials are deliberately not replaced. Keep private inputs and raw service errors out of screenshots, source files and chat.

The helper is for a new schema-only owner with its matching workspace. Existing credentials and other owner patterns use the established [authentication guide](authentication.md). A resource-principal installation still requires the separate OCI IAM preparation described there.

The alternative **Create a local OCI signing credential** form appears in the running app's **Deployment setup**, after successful Supporting Objects installation and authorised installer sign-in. It creates only `OCI_USER_CRED` in the verified parsing owner, refuses an existing name and has no replace/update action. Do not run both creation routes for the same credential. The [installer steps](apex-led-deployment.md#optional-create-the-owner-local-credential) describe private entry and the separate model test. Private creation and scoped debug-canary checks passed in r12; the [acceptance review](apex-led-acceptance-review.md) distinguishes remaining failure/recovery and audit-coverage checks. The facilitator route remains available.

Before handing over, confirm the database is available, Java is `VALID`, the owner/grants/quota are ready, the workspace is enabled and correctly mapped, the installer can reach **App Builder → Import**, and ZIP import prerequisites are met. Record the intended new application or supported upgrade target. Then continue with [Install through APEX](apex-led-deployment.md), which begins by uploading the ZIP.

Expected outcome: **environment ready for application installation**. After ZIP import, Supporting Objects, guided model/data setup and a real evidence-backed question, the separate outcome is **application ready for learners**.

## Select and protect the target

Use the [dev build lifecycle](dev-build-lifecycle.md) for isolated acceptance: a new `KCV_V<major>_<three-digit-build>` schema/workspace, a separate application alias and an unused application ID. Do not overwrite an existing build to test this route. A replacement starts a separate personal library; it does not transfer accounts, contexts or conversations automatically.

For an upgrade, identify the exact existing schema, workspace, application ID, alias, source version, migration checkpoint and dataset edition. Capture and verify recovery material before the maintenance window. Preserve owner-private credentials, public graphs, personal revisions, conversations, evidence and account mappings. Restoring an APEX export does not restore database or graph state.

Only an explicitly supported baseline may use the APEX upgrade route. Keep published-v1 adoption/migration on the [documented SQL-first path](../release-docs/docs/migrate-to-v2.md) until separate browser acceptance establishes support. Reject unknown, newer or customised contracts rather than choosing a fresh installation over them.

## Prepare platform capabilities

| Prerequisite | Administrator action | Handoff evidence |
| --- | --- | --- |
| ADB Serverless and compatible APEX | Confirm the actual database/APEX/ORDS versions against the tested candidate | Version/capability result, without the live endpoint |
| Browser APEXlang ZIP import | Confirm ORDS 26.1.1+ and at least one REST-enabled schema in the intended workspace | Both browser-import prerequisites verified before handoff |
| Java and native RDF | Confirm JAVAVM is VALID and the required RDF APIs are available | Readiness result; do not re-enable Java or restart an existing ready database |
| Schema and storage | Create the intended owner with sufficient quota and direct object/API grants | Correct owner and quota; no use of ADMIN as the application parsing schema |
| Native vector datatype | Verify VECTOR support even if semantic search is omitted | The schema's vector column can be created |
| Installation transport APIs | Verify execution access to UTL_COMPRESS, UTL_ENCODE, DBMS_LOB and DBMS_CRYPTO as the effective parsing owner | The packaged SQL decoder and its integrity checks can execute before any schema mutation |
| Workspace | Map the enabled workspace to the intended owner | Exact mapping and workspace-enabled result |
| Installation accounts | Provide the permitted App Builder sign-in and an individual native workspace administrator account for runtime setup | Both entry points work; the runtime account has the required administrator role |
| Learner accounts | Create distinct app-only accounts when needed | Each has its own library identity and no setup privilege |

The ORDS and REST-enabled-schema requirements come from [Oracle's APEXlang browser-import documentation](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/importing-export-files.html). Verify the actual workspace configuration through the authorised administrator path. A workspace mapping or a successful SQLcl import alone does not establish that browser ZIP import is available.

For the schema-only pattern, [09_create_dev_schema.sql](../sql/admin/09_create_dev_schema.sql) and [10_create_dev_workspace.sql](../sql/admin/10_create_dev_workspace.sql) describe the administrative bootstrap. Step 5 supplies a browser credential-entry route. Follow [fresh dev preparation](fresh-dev-deployment.md) when direct owner/proxy access is needed for dev tooling or recovery. The owner has no direct Worksheet password. `ALTER SESSION SET CURRENT_SCHEMA` is not an owner login, and the application must not borrow a saved ADMIN connection.

**App Builder and the running app have separate authentication.** ADB's default Builder/Administration Services sign-in uses database credentials through ADB single sign-on. This application uses Oracle APEX Accounts. Creating a workspace account through a native APEX API does not prove that a corresponding Builder database login exists. Verify both privately before handoff; do not change the database-wide Builder authentication mode to work around a missing account. Oracle describes the [ADB sign-in modes](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/apex-access-admin-services.html) and [developer-account creation and password distinction](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/apex-create-accounts.html).

An installer database login is separate from the schema-only application owner and from the app-only learner account. Grant only what the documented Builder route requires. Do not create database logins for learners merely to let them use this application.

These bootstrap scripts are a starting point for the isolated rehearsal, not proof that all Supporting Objects operations are authorised. The APEX execution-identity proof must establish the effective parsing owner and available direct grants. Do not grant broad DBA roles, expose a schema-selection field or remove existing owner checks to make an import work.

Do not run the full fresh SQL-first backend installer and then describe a successful application import as a clean Supporting Objects installation. A clean acceptance target must let the reviewed Supporting Objects transport create and verify the backend. An upgrade acceptance target must retain a verified existing contract and runtime work.

## Prepare private model access

Use the [authentication guide](authentication.md) to prepare or select one approved credential local to the intended schema. The profile configuration lists credential names and never accepts a key, password or endpoint. The separate credential form accepts an OCI signing-key body only for creation of the fixed owner-local `OCI_USER_CRED`; private creation and the subsequent model connection passed in the r12 rehearsal. A grant to a credential in another schema does not establish Select AI compatibility: the prior qualified-name attempt failed and is not the supported setup route.

Before either signing-key route, confirm these prerequisites:

- An approved OCI IAM user and tenancy, with the user's matching public API signing key already registered. Obtain the user OCID, tenancy OCID and public-key fingerprint from that identity. This is an API signing key, not an SSH key. Follow [Oracle's API signing-key requirements](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm).
- An unencrypted private key matching that registered public key. `DBMS_CLOUD.CREATE_CREDENTIAL` does not support passphrase-protected keys. The new form accepts the base64 body only, without PEM markers or the `OCI_API_KEY` label, and bounds the entire submitted field to 4,000 bytes including whitespace. Do not truncate a larger key; use a reviewed facilitator route instead. Oracle documents [credential storage and supported signing-key parameters](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-subprograms.html).
- IAM permission for the intended model inference in the selected compartment, and a supported model available in the chosen region. Grant the required scope rather than blanket tenancy administration; see [OCI Generative AI IAM policies](https://docs.oracle.com/en-us/iaas/Content/generative-ai/iam-policies.htm). Credential creation neither grants access nor proves it works.

Give the workspace installer the approved model **name**, OCI region, inference compartment and local credential name privately. The configured OCI identity must have the required service access. If using a resource principal, prepare its dynamic-group/IAM policy and database enablement explicitly; verify that the selected credential is visible and usable by this owner. The APEX page does not create an IAM policy or dynamic group.

Use the separate private administrator/owner process for replacement, rotation or repair; the installer form deliberately has no overwrite path. Keep populated statements and private inputs out of source files, app exports, screenshots and chat. Inspect only credential name/existence when checking creation. Creation leaves learning paused and invalidates the recorded model-test result; an explicit test of the current profile is required before enabling learning.

The form uses native Password items with per-request storage and clears the values on success, failure and later rendering. Oracle recommends [per-request Password storage](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/about-items-of-type-password.html) to avoid writing values to APEX session-state tables. This does not guarantee that every database audit, ORDS request log or browser environment excludes submitted values. Application Debugging set to No also does not prevent [owning-workspace developers or programmatic code from enabling debug](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/enabling-and-disabling-debug-mode-for-an-application.html). Review the actual logging configuration and recorded synthetic-canary checks before real-key entry; do not disable platform auditing globally to make a test pass. Scoped r12 browser and LEVEL9 checks passed, but the bounded database-audit lookup returned no rows, so that audit coverage remains unproven.

The installer explicitly tests the profile through the setup page. A successful model call from another owner is not acceptance for this installation. Page rendering, readiness refresh and reopening a saved conversation must not trigger test inference.

## Prepare outbound access and the public collection

The application package fixes the approved public GitHub dataset to a full commit SHA and manifest hash. Review that pin and the package provenance before import. Retain the preference for a direct public GitHub load; do not require learners to paste a large SQL dataset or upload internal source material.

Confirm the target can reach the exact required destinations for GitHub and the configured OCI model service. Follow the existing [GitHub loading/network guidance](github-dataset-load.md). Network requirements depend on the database configuration; do not add wildcard ACLs or assume a change is required merely because DBMS_CLOUD is used.

The loader stages and validates data before activation. It must preserve an existing active collection on a failed or interrupted load. A dataset update is independent of an application/schema upgrade. Public references and attributed editorial summaries are distributable; private runtime contexts, source extracts under review, credentials and environment configuration are not seed data.

## Optional local semantic search

The optional `KCV_CONTEXT_MINILM` ONNX model runs inside the database. Use the owner-only [context-search setup](context-search.md) with its explicit grants, approved model hash, dimension check and backfill. That setup deliberately excludes APEX sessions; the current UI does not bypass it or distribute model weights.

Without the model, keyword search is a valid supported mode. With it, verify current private chunk coverage and actual semantic retrieval separately. A model name in the catalog alone is not sufficient evidence of working semantic search.

## Handoff and acceptance

When packaging is complete, provide the workspace installer with the matching **APEXlang application ZIP**, its artifact hash, intended target identity, approved non-secret configuration and the [browser steps](apex-led-deployment.md). Check that its application, assets and Supporting Objects definitions are complete. A generic source ZIP or zipped SQL files do not establish App Builder compatibility. Oracle describes the [APEXlang ZIP export format](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/exporting-an-application.html). Share live login/connection details privately. Do not distribute a shared administrator or learner password in the package.

Check clean installation and same-ID upgrade independently by uploading the actual ZIP through App Builder. Verify manifest/source checks, Supporting Objects execution, compilation, runtime readiness, a real grounded answer, evidence and sign-in persistence. Test a workspace administrator and at least two independent learner accounts, including rejected direct setup calls. Preserve existing work through interruption/retry and upgrades; inspect the complete APEXlang ZIP export for runtime data or credential leakage.

Do not mark this route ready on the basis of the earlier SQL-first or Liquibase tests. Record the actual Supporting Objects/import and runtime execution contexts, exact artifacts, failed/pending cases and recovery results. Keep release unchanged until the implementation has passed its own acceptance and promotion is separately authorised.
