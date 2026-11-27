# Deploy a fresh v2 development instance

Use this route to install the maintained dev application into a **new schema and APEX workspace on an existing ADB Serverless database**. It preserves other schemas, applications and their data. It does not provision a new database or repeat Java enablement. The curated release has its own [APEX-led and SQL-first learning/deployment experience](../release-docs/docs/installation-paths.md).

**Current dev contract:** use an unused build-named owner and workspace, identified by `<KCV_SCHEMA>`, for the v2.1.0 schema ending at `2.1.0-apl-r4-ready` and the 11-page application with 16 maintained assets. The [build lifecycle guide](dev-build-lifecycle.md) defines the naming, replacement and retirement process. A replacement build gets a new identity; an in-place migration preserves the existing identity and saved work. The historical direct DEV-led rehearsal below is not a new v2.1.0 Liquibase acceptance claim.

**25 November 2026 validation:** a fresh build from dev commit `32e111f6340ab97beb0720dc867e7c2ab8ab46ae` passed the schema-only owner/workspace setup, Liquibase installation, owner-local model access, public data load, local search and native APEXlang import. It had 96 COMPLETE project receipts, 97 Liquibase changesets, zero invalid objects, nine pages and seven assets. Native grounded-answer checks passed initial, adopted-revision and provider-history-expiry requests. The signed-in browser passed sample/personal navigation, draft publication, evidence graphs, explicit adoption, a grounded follow-up, semantic search and reopening historical evidence. See the [validation scope](dev-build-lifecycle.md#validation-scope) for limits.

The [v2.1.0 four-route record](../db/verification/release-v2.1-paths-validation.json) covers the separate curated APEX-led and SQL-first prepared-environment rehearsals. The [v2.0.0 SQL-first record](../db/verification/release-v2-paths-validation.json), [R4 fresh acceptance](../db/verification/fresh-dev-validation.json), [navigation](../db/verification/sample-navigation-validation.json), [search](../db/verification/context-search-validation.json) and [deletion](../db/verification/context-delete-validation.json) records retain their historical scope. Record the results for the actual dev transport you execute.


**Setup order:** install and verify the static schema, create the workspace and installer/learner accounts, import the app, bind it to the owner, then configure the credential, model and runtime services through **Deployment setup**. SQLcl/Liquibase remains the DEV-led schema workflow. This revised ordering is documentation guidance over the existing setup APIs; it does not relabel the earlier direct DEV-led rehearsal as a new end-to-end pass.

## 1. Choose a separate target and check prerequisites

Use Oracle Linux/Bash and the [local SQLcl launcher](dev-connection-setup.md). Java and SQLcl run locally; a container is not required. Keep the wallet, saved connections, credentials and execution logs outside published files.

Use `KCV_V<KCV_MAJOR>_<KCV_BUILD>` for both schema and workspace. Read the major from [VERSION](../VERSION) and allocate the next unused build number, padded to at least three digits. A replacement gets a new build number even when the product version is unchanged. Never reuse a retired build number. These are deployment identities, separate from semantic versioning and Git commit IDs.

**Before running any example, replace every `<TOKEN>` using the [deployment parameter guide](deployment-parameters.md).** Tokens are documentation placeholders, not automatic SQLcl or Bash variables. Keep SQL string quotes and proxy square brackets as shown.

| Item | Selected build token | Replacement |
| --- | --- | --- |
| Database schema | `<KCV_SCHEMA>` | `<KCV_REPLACEMENT_SCHEMA>` |
| APEX workspace | `<KCV_WORKSPACE>` | `<KCV_REPLACEMENT_WORKSPACE>` |
| Private SQLcl owner alias | `<KCV_OWNER_CONNECTION>` | `<KCV_REPLACEMENT_OWNER_CONNECTION>` |
| APEX application ID | `<KCV_APP_ID>`, **only if unused** | A different unused ID; not derived from the build |
| Application alias | `<KCV_APP_ALIAS>` | `<KCV_REPLACEMENT_APP_ALIAS>` |
| Workspace-scoped app user | `KCV_USER` | A new `KCV_USER` account in the new workspace |

The remaining examples use your selected build. If its identity exists already, choose the next unused build and substitute its owner, workspace, owner connection and app alias consistently. Preserve the separate ADMIN connection and all other installations until the replacement passes. The bootstrap accepts broader uppercase `KCV_` names; the build convention and matching schema/workspace names are documented choices, not additional enforcement in those scripts.

As ADMIN, run the read-only [Java/RDF readiness script](../sql/admin/00_readiness.sql) and check `SELECT version_no FROM apex_release;`. Expected: JAVAVM VALID, valid RDF/Select AI APIs and APEX 26.1 or later. Existing acceptance used APEX 26.1.6; a different version needs its own validation. Leave Java enabled. If readiness fails, resolve the prerequisite before creating the test schema.

Record the exact source commit, product version, dataset commit/hash and target identities privately. Record existing applications and counts/digests of contexts, conversations, turns and observations for every installation being preserved. Compare them after setup and testing. The legacy reset/teardown scripts are not part of this route. Reusing the app username does not transfer saved contexts to a new workspace; see [saved work and replacement](dev-build-lifecycle.md#saved-work-and-replacement).

## 2. Create the isolated owner as ADMIN

The fresh bootstrap uses a schema with **NO AUTHENTICATION**, grants its required object/package privileges and a 1 GB DATA quota, and authorizes ADMIN to connect through it. There is no new database password to copy into a script. The owner is still a separate database identity; changing `CURRENT_SCHEMA` in an ADMIN session is not a substitute for an owner connection.

In ADMIN SQLcl, set the non-secret target bind and run [09_create_dev_schema.sql](../sql/admin/09_create_dev_schema.sql):

```sql
SET SERVEROUTPUT ON
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := '<KCV_SCHEMA>';
@sql/admin/09_create_dev_schema.sql
```

Expected: `KCV_DEV_SCHEMA_CREATED=<KCV_SCHEMA>`, with scoped grants and ADMIN proxy access. The bootstrap requires an uppercase `KCV_` name of 5–30 characters, an absent owner, VALID Java, an online DATA tablespace and valid package prerequisites. An existing schema causes a stop, not password replacement or teardown. The shared release scripts `01_create_user_worksheet.sql` and `02_grants.sql` now take KCV_SCHEMA. This dev route deliberately uses the NO AUTHENTICATION/proxy bootstrap instead; do not mix its account model with a password-enabled Worksheet installation.

## 3. Save a new owner connection privately

Open SQLcl from the same Oracle Linux environment that holds the wallet and saved ADMIN connection. Use the wallet's TNS service name, not the Database Actions HTTPS URL:

```text
connect -cloudconfig "<WALLET_ZIP>" -save <KCV_OWNER_CONNECTION> -savepwd ADMIN[<KCV_SCHEMA>]@<TNS_SERVICE>
```

Enter the ADMIN password at SQLcl's private prompt. Replace the path and service name privately; do not store them in the repository or a public log. `-savepwd` saves the credential in SQLcl's private connection store; omit it if interactive entry is preferred. Save a different owner alias for each build and retain the previous alias until retirement is verified.

```sql
SET SERVEROUTPUT ON
SELECT USER AS schema_owner,
       SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
       SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS current_schema
FROM dual;
```

Expected: `<KCV_SCHEMA>`, `ADMIN`, `<KCV_SCHEMA>`. Use this owner connection for all following database steps except explicitly labelled ADMIN actions. This NO AUTHENTICATION schema cannot sign in directly to Database Actions with a database password. SQLcl proxy access is the development route; APEX has a separate application login.

For later sessions, use `connect -name <KCV_OWNER_CONNECTION>` and repeat the identity query. If the alias is not found, confirm you opened SQLcl from the same operating-system account and WSL/Windows environment where it was saved. Do not replace the existing deployment's saved alias as a workaround.

## 4. Install and verify the schema through Liquibase

From the repository root, check the generated artifacts before connecting:

```bash
python scripts/build_database_installers.py --check
python -m unittest discover -s tests -p test_migrations.py -v
```

Then, in the new owner session, set SQLcl's working directory explicitly to the repository root. Replace the path privately. SQLcl can resolve relative paths from a previously executed script's directory; this matters when a launcher/header lives under `work/`.

```text
cd /path/to/knowledge-context-graph-hol
```

Run the migration commands from that directory:

```sql
lb validate -changelog-file db/changelog.xml
lb status -changelog-file db/changelog.xml
lb update -changelog-file db/changelog.xml
@sql/install/02_verify_schema.sql
```

Expected current contract: 121 COMPLETE project migration receipts, the `2.1.0-apl-r4-ready` checkpoint and zero invalid project objects. Use the full verifier; Liquibase's bookkeeping count is separate. Repeat `lb update` and the verifier: no pending migration should execute. Inspect SQLcl output for errors as well as its process exit code. Follow [migration failure/recovery](database-migrations.md#failure-and-recovery) if a step fails; do not clear checksums or fabricate receipts.

Migrations already install the tables, packages, dataset importer and tool functions. Do not run `01_objects.sql`, `03_tools.sql`, `06_dataset_import.sql` or individual scenario package files over them. The remaining steps configure runtime services and data, which migrations deliberately do not create.

For a candidate that includes hybrid My Contexts search, follow the separate [context-search runtime setup](context-search.md) after its schema migration. It uses [ADMIN grants](../sql/admin/11_context_search_grants.sql) and an [owner-run model setup/backfill](../sql/extensions/22_setup_context_search.sql). The embedding model is downloaded separately and runs inside the database; it does not use or replace the conversational GenAI profile configured in Deployment setup. Keep the populated model URI private and record search acceptance separately from the earlier fresh-deployment results.

## 5. Create a new APEX workspace and app account

Return to ADMIN. Create and enable the workspace mapped only to the new schema using [10_create_dev_workspace.sql](../sql/admin/10_create_dev_workspace.sql). The script runs ADD_WORKSPACE, ENABLE_WORKSPACE and COMMIT in that order:

```sql
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
VARIABLE KCV_DEV_WORKSPACE VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := '<KCV_SCHEMA>';
EXEC :KCV_DEV_WORKSPACE := '<KCV_WORKSPACE>';
@sql/admin/10_create_dev_workspace.sql
```

Expected: both `KCV_DEV_WORKSPACE_CREATED=<KCV_WORKSPACE>` and `KCV_DEV_WORKSPACE_ENABLED=<KCV_WORKSPACE>`. The schema must have NO AUTHENTICATION and the ADMIN proxy grant and must not already be mapped to a workspace. Existing workspaces cause a stop, not remapping. This step does not create an application login or change a database password.

Explicit enablement matters: an earlier rehearsal left the workspace inactive after ADD_WORKSPACE. The combined creation/enablement bootstrap passed for the numbered build. If an existing workspace is inactive, inspect and enable that exact workspace; do not rerun ADD_WORKSPACE or change its owner authentication model.

Create a native APEX workspace-administrator account, such as `KCV_INSTALLER`, in this workspace through **APEX Administration Services → Manage Workspaces → Manage Developers and Users**. Give it the workspace-administrator rights required by Deployment setup. A developer-only or app-only account is insufficient. This is an APEX account, not the schema owner or the ADMIN database connection. The account's name alone grants no rights. Database SSO access to Builder is separate and is not needed merely to use the installed app's setup page.

Create a separate app-only end user privately through APEX Administration Services, or use this block in the **ADMIN Database Actions Worksheet**. Confirm the fresh workspace name first, select BEGIN through END without the final slash, and choose **Run Statement**. Enter and submit the password yourself in the private `KCV_APEX_PASSWORD` bind dialog:

```sql
BEGIN
  APEX_UTIL.SET_SECURITY_GROUP_ID(APEX_UTIL.FIND_SECURITY_GROUP_ID('<KCV_WORKSPACE>'));
  APEX_UTIL.CREATE_USER(p_user_name=>'KCV_USER',p_web_password=>:KCV_APEX_PASSWORD,
    p_developer_privs=>NULL,p_allow_app_building_yn=>'N',p_allow_sql_workshop_yn=>'N',
    p_allow_team_development_yn=>'N',p_change_password_on_first_use=>'N');
  COMMIT;
END;
/
```

Expected: a new end-user account only in the fresh workspace. An existing username is not reset. The shared [app-user script](../sql/admin/08_create_apex_app_user.sql) now takes KCV_SCHEMA, KCV_WORKSPACE and KCV_APP_USER plus the private password bind. Use those actual target names when choosing that Worksheet path; its default workspace is not this isolated dev workspace. Use a separate app account for each person. Keep passwords in the private input interface; database proxy access is not an application password.

## 6. Validate and import a new APEX application

Use a **direct ADMIN connection**, as exercised in this rehearsal, or the intended owner after verifying its workspace activation. Specify every import target explicitly. Confirm the fresh workspace is enabled, its schema mapping is correct and the proposed application ID is unused. Do not change CURRENT_SCHEMA, grant broad APEX roles or change the new owner's authentication mode to work around an inactive workspace. The documented fresh example is:

```text
apex validate -input apex/application -workspace <KCV_WORKSPACE>
apex import -input apex/application -workspace <KCV_WORKSPACE> -schema <KCV_SCHEMA> -id <KCV_APP_ID> -alias <KCV_APP_ALIAS> -name "Knowledge Context Explorer"
```

Use `<KCV_APP_ID>` only after checking it is unused; choose another unused ID for each replacement build. Import can replace an existing selected application. The historical v2.0.0 numbered-build rehearsal used direct ADMIN with explicit targets and produced nine pages and seven static assets, with the existing `regionBody` deprecation warning. Current v2.1.0 metadata identifies 11 pages and 16 maintained assets. Inspect the output and installed target rather than relying only on SQLcl's process exit code. See [APEXlang authoring](apexlang-development.md) for engine export and receipt requirements.

The earlier owner-proxy import/activation failure is retained in the validation record. The cause was workspace inactivity, confirmed through the public APEX error message. After ENABLE_WORKSPACE, `APEX_UTIL.SET_WORKSPACE` succeeded in the same true-owner proxy identity. NO AUTHENTICATION and proxy access required no change. The actual app import in this rehearsal used direct ADMIN with explicit targets; successful owner workspace activation does not itself constitute a separate owner-import test.

Switch back to `<KCV_OWNER_CONNECTION>` for database-side checks and verify USER/CURRENT_SCHEMA again. The numbered-build acceptance parsed 33 application SQL components, with the native Close Window process intentionally skipped. Earlier APEX_SESSION harness results retain their own identity/isolation scope in the historical validation record. These server-side checks are distinct from the authenticated browser journey below, which tests the end user's actual login and UI.

The verified static schema is sufficient for this app import. A missing credential/profile, RDF network or dataset is expected on a fresh owner and is handled after binding. Do not configure the model in a private SQL file merely to satisfy import.

The alternate Worksheet installer is a separate acceptance route. Generate it with explicit target arguments rather than the KCV_LAB defaults:

```text
python scripts/build_apex_worksheet.py --mode new --workspace <KCV_WORKSPACE> --schema <KCV_SCHEMA> --alias <KCV_APP_ALIAS> --output "<KCV_BUILD_ROOT>/20_install_apex.sql"
```

This alternative needs a password-enabled owner Worksheet, as used in the separate [SQL-first clean/migration rehearsal](../db/verification/release-v2-paths-validation.json). Use a release checkout's own setup guide for that account model; the schema-only dev owner above cannot sign in directly to Worksheet. In a supported owner Worksheet, select the complete outer `DECLARE` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. Supply any prompted target binds. The installer allocates a new application ID. Choose one import route for a deployment; running both creates separate apps. Native APEXlang acceptance does not by itself validate the generated wrapper.

## 7. Bind the app and complete Deployment setup

As the actual new owner, follow [owner binding](deployment-owner-binding.md) with the imported app ID and its mapped workspace. This uses the generated verifier; ADMIN changing CURRENT_SCHEMA is not sufficient. Expect READY_FOR_SETUP on the first binding. The app stays closed to ordinary learners until readiness passes and learning is explicitly enabled.

Open the installed runtime app and sign in using this workspace's **KCV_INSTALLER** APEX account. Follow the [shared Deployment setup guide](../release-docs/docs/deployment-setup.md#apex-guided-setup) in this order:

1. **Prepare graph network** if it is missing. The owner-private network is separate from any older build's network.
2. If using an OCI API signing key and the owner has no suitable credential, use **Create local OCI credential**. Enter the four matching values only in its dedicated masked fields, using the unencrypted key body without PEM markers or SQL quotation syntax. Submit privately. The form creates only owner-local OCI_USER_CRED and refuses replacement. For an upgrade, retain a suitable existing credential. Resource principal remains a separately prepared [IAM alternative](authentication.md).
3. Under **Configure model access**, select the prepared credential and enter the approved region, inference compartment and supported model name. Save. The app creates/configures KCV_GENAI and registers it for the project; do not separately run 05_profile_worksheet.sql or 06_register_profile.sql.
4. Use **Test model connection once** when its check is not READY. This is a real model request and records the result for the current profile; a standalone greeting does not satisfy readiness.
5. **Prepare conversation components** after the profile is ready. This verifies or creates the required teams/tasks/tools without resetting conversations.
6. **Load approved public collection** for the supplied demo. It uses the packaged immutable public commit/hash. Wait for completion; do not also run the standalone loader or agent-registration scripts.
7. Refresh readiness. When all six checks are READY, choose **Enable learning** deliberately. On an upgrade, act only on missing checks; do not save/reload ready resources merely because a version changed.

Keep private input out of chat, source files, screenshots and logs. OCI user/key registration and inference permissions remain prerequisites; the form does not create them. A failed model test does not require reinstalling the schema or app. See [setup recovery](../release-docs/docs/deployment-recovery.md).

For a headless maintenance or diagnostic need, the [manual authentication alternatives](authentication.md) and owner setup API remain available. They are not additional steps after successful app setup. A separately chosen custom collection still needs its own DEV-led ingestion/configuration and acceptance; the guided public loader is not a generic importer for arbitrary research.

## 8. Optional local semantic search

The conversational OCI profile does not configure local embedding search. If wanted, follow [context-search setup](context-search.md): the administrator grants the scoped capabilities and the owner uses [22_setup_context_search.sql](../sql/extensions/22_setup_context_search.sql) to load/retain the local model and backfill derived search data. Keep any private model download URI out of source and logs. Without this model, expect the app's explicit keyword-only banner; this is not a failure of chat-model setup.

Use read-only dataset/graph checks after setup. The supplied public demo has its own manifest counts; an adapted collection requires separately recorded expectations. Do not run raw schema packages or initial registration scripts over a configured installation.

## 9. Test the fresh experience and record its limits

Sign in to the new application using its new workspace account. Follow the [My Contexts manual review](my-contexts-manual-test.md): create or copy a draft, review/apply, start a conversation, ask a real question, inspect Sources and Answer lineage, record an observation, refine deliberately and reopen the saved conversation. Check that retrieval has APPLICATION origin before model dispatch, citations match supplied passages and earlier evidence remains unchanged. Exercise the sample route separately.

The native [personal journey](../integration-test/verify_personal_journey.sql), [sample regression](../integration-test/verify_sample_journey_regression.sql), [search](../integration-test/verify_context_search.sql) and [grounded continuation](../integration-test/verify_grounded_continuation.sql) fixtures have explicit historical test-owner allowlists. They do **not** accept a build-named owner unchanged. For a new build, review a private copy with an exact target guard, app ID and fixture cleanup scope; retain its diff and results. Do not remove the guard, admit every `KCV_` owner or run against the old build just to obtain a pass. The numbered-build native acceptance used such reviewed adapters. APEX harnesses may also need their own synthetic test accounts; a single end-user account does not establish two-account isolation.

Never run `verify_my_contexts_identity_lifecycle.sql` unchanged for this target: it explicitly modifies accounts in KCV_V2_TEST and is excluded from the fresh test selection. Local service mocks and the legacy teardown scripts are also excluded.

Compare the preserved installations' counts and application identities with the preflight record. Retain only non-sensitive acceptance facts publicly: code/data hashes, tool/database versions, checkpoints, counts, actual pass/fail results and limitations. Do not publish endpoints, wallet/service details, credentials, screenshots of login/bind screens, personal drafts or raw model transcripts.

A fresh schema/app test does not validate new-database provisioning, initial Java enablement, every model response, Worksheet transport or release promotion. Record each route separately and leave release unchanged until its own acceptance and explicit promotion.

## 10. Replace or retire a build

Follow the [dev build lifecycle](dev-build-lifecycle.md) for replacement, private recovery material, exact-target retirement, local work cleanup and obsolete SQLcl connections. Keep the previous installation until the replacement passes and the saved-work decision is recorded. Retirement preserves JAVAVM and shared infrastructure; it is not a Liquibase rollback.
