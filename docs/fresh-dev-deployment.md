# Deploy a fresh v2 development instance

Use this route to install the My Contexts candidate into a **new schema and APEX workspace on an existing ADB Serverless database**. It preserves other schemas, applications and their data. It does not provision a new database or repeat Java enablement. The published SQL-first release has its own learning experience and remains unchanged.

**Current candidate:** local R7 adds hybrid search over owned saved contexts and objective previews. Its [native upgrade/repeat, search regression and scoped browser checks passed](../db/verification/context-search-validation.json), at 96 project receipts / 97 Liquibase changesets with zero invalid objects. This does not certify a fresh R7 installation or generated Worksheet execution. The [R5 deletion record](../db/verification/context-delete-validation.json) retains its pending permanent-delete browser confirmation. The following fresh acceptance summary describes R4 and the navigation followups.

**Preceding fresh acceptance:** native installation, model checks, authenticated personal/sample browser journeys and the recorded preservation checks passed. Published dev commit `bcabe1ceb14a07c7338fcb58e96bdbf02429d886` anchors that tested database runtime and public dataset. Bootstrap scripts, this guide, 15 test-owner allowlist additions and the APEX **Sample Contexts** label/navigation correction were local followups, not an unchanged-checkout acceptance of that commit. That native install had 80 COMPLETE project receipts, 81 Liquibase changesets and zero invalid objects; an independent repeat preserved the exact receipt hashes. Three strict native model requests passed, including provider expiry. The separate browser journey made two personal requests and one Casey sample request. The [fresh deployment record](../db/verification/fresh-dev-validation.json) records their scope; the historical [R4 record](../db/verification/c3-r4-validation.json) retains its earlier malformed-JSON native failure.

The inactive-workspace failure was resolved by explicit enablement, without changing NO AUTHENTICATION or proxy access. Native APEX identity/conversation checks passed. The browser verified context creation, review/apply, evidence, observations, topic removal, explicit revision adoption, unchanged historical explanations, sample copying and the repaired **Explore the samples** navigation. The final APEX import preserved the signed-in session and all 25 captured fresh-runtime hashes; its matching export/receipt contain eight pages and seven assets. All 58 original-installation count/hash assertions passed after the completed browser journey, and JAVAVM remained VALID. These are scoped comparisons, not a whole-database audit. Workspace creation and enablement were exercised separately; the corrected combined bootstrap file has not been rerun on another fresh schema. Generated Worksheet installers remain unexecuted, and release is unchanged.

**25 November followup:** the [sample navigation regression](../db/verification/sample-navigation-validation.json) passed after giving the sample selector an explicit native Alex default. Pristine menu navigation now works, genuine edits still trigger the normal warning, and Explore retains its deliberate navigation behavior. This targeted followup preserves the earlier fresh-deployment results and makes no model requests.

## 1. Choose a separate target and check prerequisites

Use Oracle Linux/Bash and the [local SQLcl launcher](dev-connection-setup.md). Java and SQLcl run locally; a container is not required. Keep the wallet, saved connections, credentials and execution logs outside published files.

The names below are examples for the separate fresh test. Verify they are unused before creation. Never reset an existing account or overwrite an app to make these names available.

| Item | Fresh example | Preserve in the existing demonstration |
| --- | --- | --- |
| Database schema | `KCV_V2_FRESH` | `KCV_LAB` and `KCV_V2_TEST` |
| APEX workspace | `KCV_V2_FRESH` | Existing workspaces and accounts |
| Private SQLcl owner alias | `KCV_V2_FRESH_OWNER` | `KCV_V2_ADMIN` and `KCV_V2_OWNER` |
| APEX application ID | `102`, **only if unused** | Applications `100` and `101` |
| Application alias | `KCV-FRESH-EXPLORER` | Existing application aliases |

As ADMIN, run the read-only [Java/RDF readiness script](../sql/admin/00_readiness.sql) and check `SELECT version_no FROM apex_release;`. Expected: JAVAVM VALID, valid RDF/Select AI APIs and APEX 26.1 or later. Existing acceptance used APEX 26.1.6; a different version needs its own validation. Leave Java enabled. If readiness fails, resolve the prerequisite before creating the test schema.

Record existing application identities and counts of contexts, conversations, turns and observations privately for the two preserved installations. Compare those counts after setup and testing. Inventory only; the legacy reset/teardown scripts are not part of this route.

## 2. Create the isolated owner as ADMIN

The fresh bootstrap uses a schema with **NO AUTHENTICATION**, grants its required object/package privileges and a 1 GB DATA quota, and authorizes ADMIN to connect through it. There is no new database password to copy into a script. The owner is still a separate database identity; changing `CURRENT_SCHEMA` in an ADMIN session is not a substitute for an owner connection.

In ADMIN SQLcl, set the non-secret target bind and run [09_create_dev_schema.sql](../sql/admin/09_create_dev_schema.sql):

```sql
SET SERVEROUTPUT ON
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := 'KCV_V2_FRESH';
@sql/admin/09_create_dev_schema.sql
```

Expected: `KCV_DEV_SCHEMA_CREATED=KCV_V2_FRESH`, with scoped grants and ADMIN proxy access. The bootstrap requires an uppercase `KCV_` name of 5–30 characters, an absent owner, VALID Java, an online DATA tablespace and valid package prerequisites. An existing schema causes a stop, not password replacement or teardown. The shared release scripts `01_create_user_worksheet.sql` and `02_grants.sql` now take KCV_SCHEMA. This dev route deliberately uses the NO AUTHENTICATION/proxy bootstrap instead; do not mix its account model with a password-enabled Worksheet installation.

## 3. Save a new owner connection privately

Open SQLcl from the same Oracle Linux environment that holds the wallet and saved ADMIN connection. Use the wallet's TNS service name, not the Database Actions HTTPS URL:

```sql
connect -cloudconfig "/private/path/Wallet.zip" -save KCV_V2_FRESH_OWNER -savepwd ADMIN[KCV_V2_FRESH]@your_tns_service_name
```

Enter the ADMIN password at SQLcl's private prompt. Replace the path and service name privately; do not store them in the repository or a public log. `-savepwd` saves the credential in SQLcl's private connection store; omit it if interactive entry is preferred. Do not replace `KCV_V2_OWNER`, which belongs to the existing test deployment.

```sql
SET SERVEROUTPUT ON
SELECT USER AS schema_owner,
       SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
       SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS current_schema
FROM dual;
```

Expected: `KCV_V2_FRESH`, `ADMIN`, `KCV_V2_FRESH`. Use this owner connection for all following database steps except explicitly labelled ADMIN actions. This NO AUTHENTICATION schema cannot sign in directly to Database Actions with a database password. SQLcl proxy access is the development route; APEX has a separate application login.

For later sessions, use `connect -name KCV_V2_FRESH_OWNER` and repeat the identity query. If the alias is not found, confirm you opened SQLcl from the same operating-system account and WSL/Windows environment where it was saved. Do not replace the existing deployment's saved alias as a workaround.

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
EXEC :KCV_DEV_SCHEMA := 'KCV_V2_FRESH';
EXEC :KCV_DEV_WORKSPACE := 'KCV_V2_FRESH';
@sql/admin/10_create_dev_workspace.sql
```

Expected: both `KCV_DEV_WORKSPACE_CREATED=KCV_V2_FRESH` and `KCV_DEV_WORKSPACE_ENABLED=KCV_V2_FRESH`. The schema must have NO AUTHENTICATION and the ADMIN proxy grant and must not already be mapped to a workspace. Existing workspaces cause a stop, not remapping. This step does not create an application login or change a database password.

Explicit enablement matters: in the fresh rehearsal, the mapped workspace was inactive after ADD_WORKSPACE. The public APEX message for `WORKSPACE_NOT_ASSIGNED` identified inactivity, and enabling only the new workspace immediately restored owner workspace activation. Creation and enablement were executed separately in that diagnosis; the final combined script is a local correction whose complete fresh rerun remains untested. Do not rerun ADD_WORKSPACE against an existing workspace to repair activation; inspect and enable that specifically authorized workspace instead.

Create an app end user privately through APEX Administration Services, or use this block in the **ADMIN Database Actions Worksheet**. Confirm the fresh workspace name first, select BEGIN through END without the final slash, and choose **Run Statement**. Enter and submit the password yourself in the private `KCV_APEX_PASSWORD` bind dialog:

```sql
BEGIN
  APEX_UTIL.SET_SECURITY_GROUP_ID(APEX_UTIL.FIND_SECURITY_GROUP_ID('KCV_V2_FRESH'));
  APEX_UTIL.CREATE_USER(p_user_name=>'KCV_FRESH_USER',p_web_password=>:KCV_APEX_PASSWORD,
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
apex validate -input apex/application -workspace KCV_V2_FRESH
apex import -input apex/application -workspace KCV_V2_FRESH -schema KCV_V2_FRESH -id 102 -alias KCV-FRESH-EXPLORER -name "Knowledge Context Explorer"
```

Use `102` only after checking it is unused; choose another unused ID if necessary. Import can replace an existing selected application, so do not select 100 or 101. In this rehearsal, explicit ADMIN import created app102 with alias KCV-FRESH-EXPLORER, the fresh parsing schema/workspace, eight pages and seven static assets. The validation command passed with the existing `regionBody` deprecation warning. Inspect the output and installed target rather than relying only on SQLcl's process exit code. See [APEXlang authoring](apexlang-development.md) for engine export and receipt requirements.

The earlier owner-proxy import/activation failure is retained in the validation record. The cause was workspace inactivity, confirmed through the public APEX error message. After ENABLE_WORKSPACE, `APEX_UTIL.SET_WORKSPACE` succeeded in the same true-owner proxy identity. NO AUTHENTICATION and proxy access required no change. The actual app import in this rehearsal used direct ADMIN with explicit targets; successful owner workspace activation does not itself constitute a separate owner-import test.

Switch back to `KCV_V2_FRESH_OWNER` for database-side checks and verify USER/CURRENT_SCHEMA again. A true-owner parse passed for 19 page processes, 6 reports and 4 lists of values; the native Close Window process was intentionally skipped. After workspace enablement, the separate native APEX_SESSION harness also passed identity pinning, two-account isolation, owned-context relogin, conversation attachments, trace/history and archive checks. These server-side harness results are distinct from the authenticated browser journey below, which tests the end user's actual login and UI.

The alternate Worksheet installer is a separate acceptance route. Generate it with explicit target arguments rather than the KCV_LAB defaults:

```bash
python scripts/build_apex_worksheet.py --mode new --workspace KCV_V2_FRESH --schema KCV_V2_FRESH --alias KCV-FRESH-EXPLORER --output work/fresh/20_install_apex.sql
```

Open that installer in the intended owner's Worksheet, select the complete outer `DECLARE` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. Supply any prompted target binds. The installer allocates a new application ID. Choose either native APEXlang import or the new-app installer for a deployment; do not run both and accidentally create two apps. Generated-wrapper execution is not proven by a native APEXlang import.

## 11. Test the fresh experience and record its limits

Sign in to the new application using its new workspace account. Follow the [My Contexts manual review](my-contexts-manual-test.md): create or copy a draft, review/apply, start a conversation, ask a real question, inspect Sources and Answer lineage, record an observation, refine deliberately and reopen the saved conversation. Check that retrieval has APPLICATION origin before model dispatch, citations match supplied passages and earlier evidence remains unchanged. Exercise the sample route separately.

The native [personal journey](../integration-test/verify_personal_journey.sql), [sample regression](../integration-test/verify_sample_journey_regression.sql) and [grounded continuation](../integration-test/verify_grounded_continuation.sql) are among 15 test scripts locally updated to allow the explicit KCV_V2_FRESH owner. Published commit `bcabe1c` does not contain that allowlist addition and rejects this new owner. The local change keeps the original isolation checks and fixture-scoped cleanup; it does not authorize arbitrary schemas or establish a test pass. Run the tests through KCV_V2_FRESH_OWNER with their documented prerequisites. Do not run them against a preserved owner to obtain a pass. Native APEX harnesses additionally need the new application ID and their own synthetic test accounts, supplied through the named binds; the end-user browser account alone does not satisfy a two-account test.

Never run `verify_my_contexts_identity_lifecycle.sql` unchanged for this target: it explicitly modifies accounts in KCV_V2_TEST and is excluded from the fresh test selection. Local service mocks and the legacy teardown scripts are also excluded.

Compare the preserved installations' counts and application identities with the preflight record. Retain only non-sensitive acceptance facts publicly: code/data hashes, tool/database versions, checkpoints, counts, actual pass/fail results and limitations. Do not publish endpoints, wallet/service details, credentials, screenshots of login/bind screens, personal drafts or raw model transcripts.

A fresh schema/app test does not validate new-database provisioning, initial Java enablement, every model response, Worksheet transport or release promotion. Record each route separately and leave release unchanged until its own acceptance and explicit promotion.
