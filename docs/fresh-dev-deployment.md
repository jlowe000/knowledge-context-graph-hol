# Deploy a fresh v2 development instance

Use this route to install the maintained dev application into a **new schema and APEX workspace on an existing ADB Serverless database**. It preserves other schemas, applications and their data. It does not provision a new database or repeat Java enablement. The curated release has its own [APEX-led and SQL-first learning/deployment experience](../release-docs/docs/installation-paths.md).

**Current dev contract:** use an unused build-named owner and workspace, such as `KCV_V2_001`, for the v2.1.0 schema ending at `2.1.0-apl-r4-ready` and the 11-page application with 16 maintained assets. The [build lifecycle guide](dev-build-lifecycle.md) defines the naming, replacement and retirement process. A replacement build gets a new identity; an in-place migration preserves the existing identity and saved work. The historical direct DEV-led rehearsal below is not a new v2.1.0 Liquibase acceptance claim.

**25 November 2026 validation:** a fresh build from dev commit `32e111f6340ab97beb0720dc867e7c2ab8ab46ae` passed the schema-only owner/workspace setup, Liquibase installation, owner-local model access, public data load, local search and native APEXlang import. It had 96 COMPLETE project receipts, 97 Liquibase changesets, zero invalid objects, nine pages and seven assets. Native grounded-answer checks passed initial, adopted-revision and provider-history-expiry requests. The signed-in browser passed sample/personal navigation, draft publication, evidence graphs, explicit adoption, a grounded follow-up, semantic search and reopening historical evidence. See the [validation scope](dev-build-lifecycle.md#validation-scope) for limits.

The [v2.1.0 four-route record](../db/verification/release-v2.1-paths-validation.json) covers the separate curated APEX-led and SQL-first prepared-environment rehearsals. The [v2.0.0 SQL-first record](../db/verification/release-v2-paths-validation.json), [R4 fresh acceptance](../db/verification/fresh-dev-validation.json), [navigation](../db/verification/sample-navigation-validation.json), [search](../db/verification/context-search-validation.json) and [deletion](../db/verification/context-delete-validation.json) records retain their historical scope. Record the results for the actual dev transport you execute.

## 1. Choose a separate target and check prerequisites

Use Oracle Linux/Bash and the [local SQLcl launcher](dev-connection-setup.md). Java and SQLcl run locally; a container is not required. Keep the wallet, saved connections, credentials and execution logs outside published files.

Use `KCV_V<major>_<build>` for both schema and workspace. The major comes from the product version; the build is a sequence starting at `001`. For example, a replacement of `KCV_V2_001` is `KCV_V2_002`, even when the product version is still 2.0.0. Never reuse a retired build number. These are deployment identities, not a replacement for semantic versioning or Git commit IDs.

| Item | First-build example | Replacement example |
| --- | --- | --- |
| Database schema | `KCV_V2_001` | `KCV_V2_002` |
| APEX workspace | `KCV_V2_001` | `KCV_V2_002` |
| Private SQLcl owner alias | `KCV_V2_001_OWNER` | `KCV_V2_002_OWNER` |
| APEX application ID | `123`, **only if unused** | A different unused ID; not derived from the build |
| Application alias | `KCV-V2-001` | `KCV-V2-002` |
| Workspace-scoped app user | `KCV_USER` | A new `KCV_USER` account in the new workspace |

The remaining examples show the first build. If it exists already, choose the next unused build and substitute its owner, workspace, owner connection and app alias consistently. Preserve the separate ADMIN connection and all other installations until the replacement passes. The bootstrap accepts broader uppercase `KCV_` names; the build convention and matching schema/workspace names are documented choices, not additional enforcement in those scripts.

As ADMIN, run the read-only [Java/RDF readiness script](../sql/admin/00_readiness.sql) and check `SELECT version_no FROM apex_release;`. Expected: JAVAVM VALID, valid RDF/Select AI APIs and APEX 26.1 or later. Existing acceptance used APEX 26.1.6; a different version needs its own validation. Leave Java enabled. If readiness fails, resolve the prerequisite before creating the test schema.

Record the exact source commit, product version, dataset commit/hash and target identities privately. Record existing applications and counts/digests of contexts, conversations, turns and observations for every installation being preserved. Compare them after setup and testing. The legacy reset/teardown scripts are not part of this route. Reusing the app username does not transfer saved contexts to a new workspace; see [saved work and replacement](dev-build-lifecycle.md#saved-work-and-replacement).

## 2. Create the isolated owner as ADMIN

The fresh bootstrap uses a schema with **NO AUTHENTICATION**, grants its required object/package privileges and a 1 GB DATA quota, and authorizes ADMIN to connect through it. There is no new database password to copy into a script. The owner is still a separate database identity; changing `CURRENT_SCHEMA` in an ADMIN session is not a substitute for an owner connection.

In ADMIN SQLcl, set the non-secret target bind and run [09_create_dev_schema.sql](../sql/admin/09_create_dev_schema.sql):

```sql
SET SERVEROUTPUT ON
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := 'KCV_V2_001';
@sql/admin/09_create_dev_schema.sql
```

Expected: `KCV_DEV_SCHEMA_CREATED=KCV_V2_001`, with scoped grants and ADMIN proxy access. The bootstrap requires an uppercase `KCV_` name of 5–30 characters, an absent owner, VALID Java, an online DATA tablespace and valid package prerequisites. An existing schema causes a stop, not password replacement or teardown. The shared release scripts `01_create_user_worksheet.sql` and `02_grants.sql` now take KCV_SCHEMA. This dev route deliberately uses the NO AUTHENTICATION/proxy bootstrap instead; do not mix its account model with a password-enabled Worksheet installation.

## 3. Save a new owner connection privately

Open SQLcl from the same Oracle Linux environment that holds the wallet and saved ADMIN connection. Use the wallet's TNS service name, not the Database Actions HTTPS URL:

```sql
connect -cloudconfig "/private/path/Wallet.zip" -save KCV_V2_001_OWNER -savepwd ADMIN[KCV_V2_001]@your_tns_service_name
```

Enter the ADMIN password at SQLcl's private prompt. Replace the path and service name privately; do not store them in the repository or a public log. `-savepwd` saves the credential in SQLcl's private connection store; omit it if interactive entry is preferred. Save a different owner alias for each build and retain the previous alias until retirement is verified.

```sql
SET SERVEROUTPUT ON
SELECT USER AS schema_owner,
       SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
       SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS current_schema
FROM dual;
```

Expected: `KCV_V2_001`, `ADMIN`, `KCV_V2_001`. Use this owner connection for all following database steps except explicitly labelled ADMIN actions. This NO AUTHENTICATION schema cannot sign in directly to Database Actions with a database password. SQLcl proxy access is the development route; APEX has a separate application login.

For later sessions, use `connect -name KCV_V2_001_OWNER` and repeat the identity query. If the alias is not found, confirm you opened SQLcl from the same operating-system account and WSL/Windows environment where it was saved. Do not replace the existing deployment's saved alias as a workaround.

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

Expected for current R7: 96 COMPLETE project migrations, 97 Liquibase changesets including bootstrap, the `2.0.0-c3-r7-ready` checkpoint and zero invalid project objects. Repeat `lb update` and the verifier: no pending migration should execute. Inspect SQLcl output for errors as well as its process exit code. Follow [migration failure/recovery](database-migrations.md#failure-and-recovery) if a step fails; do not clear checksums or fabricate receipts.

Migrations already install the tables, packages, dataset importer and tool functions. Do not run `01_objects.sql`, `03_tools.sql`, `06_dataset_import.sql` or individual scenario package files over them. The remaining steps configure runtime services and data, which migrations deliberately do not create.

For a candidate that includes hybrid My Contexts search, follow the separate [context-search runtime setup](context-search.md) after its schema migration. It uses [ADMIN grants](../sql/admin/11_context_search_grants.sql) and an [owner-run model setup/backfill](../sql/extensions/22_setup_context_search.sql). The embedding model is downloaded separately and runs inside the database; it does not use or replace the conversational GenAI profile configured below. Keep the populated model URI private and record search acceptance separately from the earlier fresh-deployment results.

## 5. Create the owner-private RDF network

Run the one-time [02_network.sql](../sql/schema/02_network.sql) as the new owner:

<!-- include-sql: sql/schema/02_network.sql -->

```sql
BEGIN
  SEM_APIS.CREATE_RDF_NETWORK('DATA',network_owner=>USER,network_name=>'KCV_NET');
END;
/
```

[Script: 02_network.sql](../sql/schema/02_network.sql)

<!-- /include-sql -->

Expected: KCV_NET belongs to the new schema. The same network name in another owner is a separate network. If this step reports that the network already exists, inspect the current owner and previous execution; do not drop any network to force a clean result.

## 6. Configure and test model access

The new schema needs its own working model configuration. A saved ADMIN connection, an existing profile in another schema or a successful model call in the older app does not establish access for this owner.

Choose the [user signing-key or resource-principal path](authentication.md) deliberately. KCV_LAB is the default example name; shared ADMIN scripts now accept KCV_SCHEMA. Supply the actual fresh owner for reviewed administration actions, including optional resource-principal enablement. For the signing-key route tested here, create OCI_USER_CRED in the new owner; do not export another schema's private key to copy it.

For a new signing-key credential, open SQLcl using `bash scripts/open_dev_sqlcl.sh`. The launcher starts SQLcl with `-nohistory`. Connect privately as the new owner, run `SPOOL OFF`, and use a terminal without session recording or screen sharing. Enter the following block directly in that private interactive session, replacing the placeholders yourself. Do not save the populated block to a file, a chat or an agent tool invocation. The matching unencrypted key body excludes its PEM BEGIN/END lines:

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name=>'OCI_USER_CRED',
    user_ocid=>'<YOUR_USER_OCID>', tenancy_ocid=>'<YOUR_TENANCY_OCID>',
    private_key=>q'~<YOUR_MATCHING_UNENCRYPTED_KEY_BODY>~',
    fingerprint=>'<YOUR_REGISTERED_KEY_FINGERPRINT>');
END;
/
```

The `q'~...~'` form is an Oracle string literal: retain both delimiters around the full key body, including any line breaks. A syntax error can quote part of the input, so share only its error code, not the populated statement or error excerpt. SQLcl does not automatically reproduce Worksheet's bind dialog, and this NO AUTHENTICATION schema cannot use a direct Worksheet login. [00_user_credential_worksheet.sql](../sql/schema/00_user_credential_worksheet.sql) remains the bind-based variant for a separately supported private entry interface. Local no-history mode does not change database audit policy. Close the private session after input; never print the credential or key to verify it.

**Fresh-rehearsal finding:** an explicitly authorized attempt to use a stored credential from another schema failed at `DBMS_CLOUD_AI.CREATE_PROFILE`: its schema-qualified `credential_name` was rejected with `ORA-20010: Invalid credential name`. No profile was created and no greeting/model request was made. The temporary helper and scoped grant were removed, and the original credential was unchanged. This does not establish universal lack of cross-schema credential support, but that route is not supported by the observed Select AI profile behavior here. Use the new owner's OCI_USER_CRED for this deployment; an approved database grant alone does not prove that a profile accepts the qualified name.

Use a private working copy of [05_profile_worksheet.sql](../sql/schema/05_profile_worksheet.sql) to set the approved model name, region, inference compartment and credential name, then execute it as the new owner. It creates KCV_GENAI without replacing an existing profile. Register it with [06_register_profile.sql](../sql/schema/06_register_profile.sql), now that migrations have created KCV_SETTINGS. Both files operate in the connected owner despite their historical KCV_LAB comments.

Run [00_test_genai.sql](../sql/queries/00_test_genai.sql) to make one greeting request:

<!-- include-sql: sql/queries/00_test_genai.sql -->

```sql
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt=>'Reply with a short greeting.',profile_name=>'KCV_GENAI',action=>'chat') AS response
FROM dual
/
```

[Script: 00_test_genai.sql](../sql/queries/00_test_genai.sql)

<!-- /include-sql -->

Expected: a real greeting, with `AI_PROFILE` set to KCV_GENAI in this owner. This makes a model request and may incur inference charges. On authorization or parsing failure, retain only the error code in shared records and investigate that specific profile/credential path before registering agents.

## 7. Load the public dataset from the published dev commit

The new owner already has KCV_DATASET from migrations. Use the [GitHub loader](github-dataset-load.md) directly; skip that guide's historical v1 raw initialization. This pinned call loads public JSON and verifies its hashes; it does not execute SQL from GitHub:

```sql
BEGIN
  KCV_DATASET.LOAD_GITHUB(
    p_ref=>'bcabe1ceb14a07c7338fcb58e96bdbf02429d886',
    p_expected_manifest_sha256=>'dae8efdcd9e99874c8dfc3d9a3ccaf4a861f76b3b5442f71f075a6d9b64ef8ad');
END;
/
```

Expected: SUCCEEDED, a ready ACTIVE_GRAPH and **834 sources, 762 passages, 3 fictional contexts and 30,144 triples**. These counts describe that exact published summary dataset. Check [01_inspect.sql](../sql/queries/01_inspect.sql) and run [verify_worksheet.sql](../integration-test/verify_worksheet.sql); the latter makes no model call and checks the healthcare overview and qualification through native RDF retrieval.

The download is anonymous and needs no GitHub token. Follow the loader guide's network/error checks if it fails. Do not change database-wide outbound routing or a preserved schema's grants merely to retry a new-owner download.

## 8. Register the fresh scenario agents

After the profile greeting and dataset checks pass, run [03_scenario_agents.sql](../sql/extensions/03_scenario_agents.sql) **once as the new owner**. It registers the read-only grounded answer task/team and the existing question/proposal routes. New questions retrieve evidence in application code before dispatching to KCV_GROUNDED_TEAM.

Expected: KCV_GROUNDED_TEAM, KCV_EVIDENCE_TEAM and KCV_EXPLORER_TEAM in this owner's agent-team view. Run the full schema verifier again after runtime registration. An existing task/team is a reason to inspect prior setup, not drop and recreate all teams. Script16 is the repeatable R4 upgrade-registration path; it is unnecessary after successful fresh script03 registration. Script15 installs the older R3 route.

[04_agents.sql](../sql/schema/04_agents.sql) is optional when exercising the original source/context/evidence worker labs. Its KCV_TEAM is not a prerequisite for My Contexts.

## 9. Create a new APEX workspace and app account

Return to ADMIN. Create and enable the workspace mapped only to the new schema using [10_create_dev_workspace.sql](../sql/admin/10_create_dev_workspace.sql). The script runs ADD_WORKSPACE, ENABLE_WORKSPACE and COMMIT in that order:

```sql
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
VARIABLE KCV_DEV_WORKSPACE VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := 'KCV_V2_001';
EXEC :KCV_DEV_WORKSPACE := 'KCV_V2_001';
@sql/admin/10_create_dev_workspace.sql
```

Expected: both `KCV_DEV_WORKSPACE_CREATED=KCV_V2_001` and `KCV_DEV_WORKSPACE_ENABLED=KCV_V2_001`. The schema must have NO AUTHENTICATION and the ADMIN proxy grant and must not already be mapped to a workspace. Existing workspaces cause a stop, not remapping. This step does not create an application login or change a database password.

Explicit enablement matters: an earlier rehearsal left the workspace inactive after ADD_WORKSPACE. The combined creation/enablement bootstrap passed for the numbered build. If an existing workspace is inactive, inspect and enable that exact workspace; do not rerun ADD_WORKSPACE or change its owner authentication model.

Create an app end user privately through APEX Administration Services, or use this block in the **ADMIN Database Actions Worksheet**. Confirm the fresh workspace name first, select BEGIN through END without the final slash, and choose **Run Statement**. Enter and submit the password yourself in the private `KCV_APEX_PASSWORD` bind dialog:

```sql
BEGIN
  APEX_UTIL.SET_SECURITY_GROUP_ID(APEX_UTIL.FIND_SECURITY_GROUP_ID('KCV_V2_001'));
  APEX_UTIL.CREATE_USER(p_user_name=>'KCV_USER',p_web_password=>:KCV_APEX_PASSWORD,
    p_developer_privs=>NULL,p_allow_app_building_yn=>'N',p_allow_sql_workshop_yn=>'N',
    p_allow_team_development_yn=>'N',p_change_password_on_first_use=>'N');
  COMMIT;
END;
/
```

Expected: a new end-user account only in the fresh workspace. An existing username is not reset. The shared [app-user script](../sql/admin/08_create_apex_app_user.sql) now takes KCV_SCHEMA, KCV_WORKSPACE and KCV_APP_USER plus the private password bind. Use those actual target names when choosing that Worksheet path; its default workspace is not this isolated dev workspace. Use a separate app account for each person. Keep passwords in the private input interface; database proxy access is not an application password.

## 10. Validate and import a new APEX application

Use a **direct ADMIN connection**, as exercised in this rehearsal, or the intended owner after verifying its workspace activation. Specify every import target explicitly. Confirm the fresh workspace is enabled, its schema mapping is correct and the proposed application ID is unused. Do not change CURRENT_SCHEMA, grant broad APEX roles or change the new owner's authentication mode to work around an inactive workspace. The documented fresh example is:

```text
apex validate -input apex/application -workspace KCV_V2_001
apex import -input apex/application -workspace KCV_V2_001 -schema KCV_V2_001 -id 123 -alias KCV-V2-001 -name "Knowledge Context Explorer"
```

Use `123` only after checking it is unused; choose another unused ID for each replacement build. Import can replace an existing selected application. The historical v2.0.0 numbered-build rehearsal used direct ADMIN with explicit targets and produced nine pages and seven static assets, with the existing `regionBody` deprecation warning. Current v2.1.0 metadata identifies 11 pages and 16 maintained assets. Inspect the output and installed target rather than relying only on SQLcl's process exit code. See [APEXlang authoring](apexlang-development.md) for engine export and receipt requirements.

The earlier owner-proxy import/activation failure is retained in the validation record. The cause was workspace inactivity, confirmed through the public APEX error message. After ENABLE_WORKSPACE, `APEX_UTIL.SET_WORKSPACE` succeeded in the same true-owner proxy identity. NO AUTHENTICATION and proxy access required no change. The actual app import in this rehearsal used direct ADMIN with explicit targets; successful owner workspace activation does not itself constitute a separate owner-import test.

Switch back to `KCV_V2_001_OWNER` for database-side checks and verify USER/CURRENT_SCHEMA again. The numbered-build acceptance parsed 33 application SQL components, with the native Close Window process intentionally skipped. Earlier APEX_SESSION harness results retain their own identity/isolation scope in the historical validation record. These server-side checks are distinct from the authenticated browser journey below, which tests the end user's actual login and UI.

The alternate Worksheet installer is a separate acceptance route. Generate it with explicit target arguments rather than the KCV_LAB defaults:

```bash
python scripts/build_apex_worksheet.py --mode new --workspace KCV_V2_001 --schema KCV_V2_001 --alias KCV-V2-001 --output work/builds/v2_001/20_install_apex.sql
```

This alternative needs a password-enabled owner Worksheet, as used in the separate [SQL-first clean/migration rehearsal](../db/verification/release-v2-paths-validation.json). Use a release checkout's own setup guide for that account model; the schema-only dev owner above cannot sign in directly to Worksheet. In a supported owner Worksheet, select the complete outer `DECLARE` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. Supply any prompted target binds. The installer allocates a new application ID. Choose one import route for a deployment; running both creates separate apps. Native APEXlang acceptance does not by itself validate the generated wrapper.

## 11. Test the fresh experience and record its limits

For **2.1.0**, complete the [owner binding and setup readiness step](deployment-owner-binding.md) after importing the matching app and before attempting the gated learner pages. The curated SQL-first routes exercised this binding and readiness contract within their recorded scopes; they do not establish a separate direct DEV-led Liquibase/native-import rehearsal.

Sign in to the new application using its new workspace account. Follow the [My Contexts manual review](my-contexts-manual-test.md): create or copy a draft, review/apply, start a conversation, ask a real question, inspect Sources and Answer lineage, record an observation, refine deliberately and reopen the saved conversation. Check that retrieval has APPLICATION origin before model dispatch, citations match supplied passages and earlier evidence remains unchanged. Exercise the sample route separately.

The native [personal journey](../integration-test/verify_personal_journey.sql), [sample regression](../integration-test/verify_sample_journey_regression.sql), [search](../integration-test/verify_context_search.sql) and [grounded continuation](../integration-test/verify_grounded_continuation.sql) fixtures have explicit historical test-owner allowlists. They do **not** accept a build-named owner unchanged. For a new build, review a private copy with an exact target guard, app ID and fixture cleanup scope; retain its diff and results. Do not remove the guard, admit every `KCV_` owner or run against the old build just to obtain a pass. The numbered-build native acceptance used such reviewed adapters. APEX harnesses may also need their own synthetic test accounts; a single end-user account does not establish two-account isolation.

Never run `verify_my_contexts_identity_lifecycle.sql` unchanged for this target: it explicitly modifies accounts in KCV_V2_TEST and is excluded from the fresh test selection. Local service mocks and the legacy teardown scripts are also excluded.

Compare the preserved installations' counts and application identities with the preflight record. Retain only non-sensitive acceptance facts publicly: code/data hashes, tool/database versions, checkpoints, counts, actual pass/fail results and limitations. Do not publish endpoints, wallet/service details, credentials, screenshots of login/bind screens, personal drafts or raw model transcripts.

A fresh schema/app test does not validate new-database provisioning, initial Java enablement, every model response, Worksheet transport or release promotion. Record each route separately and leave release unchanged until its own acceptance and explicit promotion.

## 12. Replace or retire a build

Follow the [dev build lifecycle](dev-build-lifecycle.md) for replacement, private recovery material, exact-target retirement, local work cleanup and obsolete SQLcl connections. Keep the previous installation until the replacement passes and the saved-work decision is recorded. Retirement preserves JAVAVM and shared infrastructure; it is not a Liquibase rollback.
