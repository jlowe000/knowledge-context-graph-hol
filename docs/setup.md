# Setup using Database Actions → SQL Worksheet

**Legacy v1 technical reference.** Follow this raw SQL setup only from the matching published release or `v1.0.0` checkout. Current dev uses [database migrations](database-migrations.md) and [APEXlang authoring](apexlang-development.md); do not run raw v1 initialization over migration-managed objects.

**New to ADB or deploying a fresh instance? Start with the [beginner walkthrough](fresh-serverless-deployment.md).** This page is the compact technical reference; it does not replace that ordered route.

Database work is performed in SQL Worksheet. No laptop database driver, wallet, direct SQL*Net connection or database password in shell configuration is required for this route. The Python database CLI remains optional automation.

Oracle Linux/Bash and Python 3.11+ are used to generate artifacts. ADB Serverless 26ai is the database target. OCI provisioning, IAM, database restart and termination remain OCI control-plane actions, not SQL Worksheet operations.

## Generate artifacts locally

```bash
bash scripts/bootstrap.sh
bash scripts/build_artifacts.sh
```

This creates RDF/previews and **work/worksheet/10_load_dataset.sql**. The SQL load file contains the selected public-source passages and stays ignored by Git. Keep it local rather than republishing presentation text.

The generated loader needs no substitution values. If Worksheet prompts for substitutions, cancel it and open the latest regenerated loader. The exporter represents source-text ampersands with `CHR(38)` so they are preserved without triggering client substitution. Do not enter replacement values for source text.

Open SQL files using Worksheet's file controls or paste the content. Use **Run Script (F5)** for slash-delimited scripts. For a bind-variable PL/SQL block, select through END; without the final slash and use **Run Statement**. Inspect results after each step.

## ADMIN worksheet

1. Run `sql/admin/00_readiness.sql`. Java must become VALID before the native RDF steps.
2. If Java is absent and the database-wide change is intended, run `sql/admin/01_enable_java.sql`; restart the Serverless instance in OCI and wait for installation to finish. Oracle documents that Java cannot be disabled afterwards. This is not automatic setup.
3. Open [01_create_user_worksheet.sql](../sql/admin/01_create_user_worksheet.sql), copy the block from `DECLARE` through `END;` into the ADMIN Worksheet, and use **Run Statement** (exclude the final `/`). Supply the private KCV_LAB_PASSWORD bind value when prompted. Do not save it into a script or send it in chat. Existing users cause a stop rather than a reset.
4. Open [02_grants.sql](../sql/admin/02_grants.sql), paste the whole script into the ADMIN Worksheet, and use **Run Script (F5)** for own-object creation and direct package grants. It grants neither DBA nor ANY privileges nor DBMS_CLOUD_ADMIN to the learner. Exact native RDF privileges still require the functional probe.
5. Run [04_enable_database_actions.sql](../sql/admin/04_enable_database_actions.sql) as ADMIN with **Run Script (F5)** to enable the lab user's authenticated Database Actions route. A copyable version is below.

Java reference: [Oracle setup](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-oracle-java.html). User/RDF reference: [RDF quick start](https://docs.oracle.com/en/database/oracle/oracle-database/26/rdfrm/quick-start-using-rdf-data-oracle-autonomous-ai-database.html).

### Copyable administrator steps

**Check Java status:**

<!-- include-sql: sql/admin/00_java_status.sql -->

```sql
SELECT status, version FROM dba_registry WHERE comp_id='JAVAVM'
/
```

[Script: 00_java_status.sql](../sql/admin/00_java_status.sql)

<!-- /include-sql -->

**Request Java enablement only if absent and intended; restart through OCI afterwards:**

<!-- include-sql: sql/admin/01_enable_java.sql -->

```sql
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_FEATURE(feature_name=>'JAVAVM');
END;
/
```

[Script: 01_enable_java.sql](../sql/admin/01_enable_java.sql)

<!-- /include-sql -->

**After restart, verify the runtime:**

<!-- include-sql: sql/queries/00_java_runtime.sql -->

```sql
SELECT dbms_java.get_jdk_version AS java_version FROM dual
/
```

[Script: 00_java_runtime.sql](../sql/queries/00_java_runtime.sql)

<!-- /include-sql -->

**Enable the authenticated lab-user Database Actions route after creating the user:**

<!-- include-sql: sql/admin/04_enable_database_actions.sql -->

```sql
BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(p_enabled=>TRUE,p_schema=>'KCV_LAB',
    p_url_mapping_type=>'BASE_PATH',p_url_mapping_pattern=>'kcv_lab',p_auto_rest_auth=>TRUE);
END;
/
```

[Script: 04_enable_database_actions.sql](../sql/admin/04_enable_database_actions.sql)

<!-- /include-sql -->

## OCI model authentication

Choose one of the two paths in [OCI Generative AI authentication](authentication.md):

- **User API signing key:** use your existing OCI user permissions and create `OCI_USER_CRED` as KCV_LAB. No dynamic group or resource-principal enablement is required. This is the example configuration's default.
- **Resource principal:** configure a dynamic group matching this ADB and an inference policy in OCI IAM, then enable the lab user's resource principal. The linked guide includes the matching rule and policy examples. Set the profile credential to `OCI$RESOURCE_PRINCIPAL`.

IAM policies are separate from database grants. Creating a stored credential does not grant OCI model access.

It is valid to create the credential and AI profile before the lab tables. Follow this sequence if checking GenAI access first: create the credential → run `05_profile_worksheet.sql` → optionally run `00_test_genai.sql` → create the lab objects → run `06_register_profile.sql`. The registration step is the first authentication-related step that needs `KCV_SETTINGS`.

No model key, user password or private target URL is bundled. Confirm networking and credential access for the chosen environment. See [Select AI examples](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/select-ai-examples.html).

**Resource-principal path only: enable use for the lab user after OCI IAM is configured (ADMIN). Skip this for user credentials:**

<!-- include-sql: sql/admin/03_resource_principal.sql -->

```sql
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_RESOURCE_PRINCIPAL(username=>'KCV_LAB');
END;
/
```

[Script: 03_resource_principal.sql](../sql/admin/03_resource_principal.sql)

<!-- /include-sql -->

## KCV_LAB worksheet

Sign in to Database Actions as **KCV_LAB**, using the schema route (for example `/ords/kcv_lab/_sdw/?nav=worksheet`) or the database's sign-in flow. Use a separate tab/session as needed. Ordinary lab work must not run as ADMIN.

Run in order:

| Script | Purpose |
| --- | --- |
| `sql/schema/01_objects.sql` | Lab tables, source/context identity and revision tracking |
| `sql/schema/02_network.sql` | KCV_NET owned by the lab user |
| `sql/schema/03_tools.sql` | Deterministic read-only packet functions |
| `sql/schema/06_dataset_import.sql` | Public GitHub dataset importer and persistent load log |
| `sql/schema/00_user_credential_worksheet.sql` | User-key path only: create OCI_USER_CRED using private bind values; see authentication guide |
| `sql/schema/05_profile_worksheet.sql` | Set model/region/compartment and chosen credential, then create KCV_GENAI |
| `sql/schema/06_register_profile.sql` | After table/profile creation, register KCV_GENAI for lab extraction and agents |
| `sql/queries/00_test_genai.sql` | Optional billable greeting call to verify authentication and model access |
| Short `KCV_DATASET.LOAD_GITHUB` call | Load the public summaries and RDF from a pinned dev candidate or promoted release commit; see [GitHub dataset guide](github-dataset-load.md) |
| `sql/queries/01_inspect.sql` | Inspect data and actual graph-derived evidence |
| `integration-test/verify_worksheet.sql` | Assert context and native evidence behaviour without a model call |

Initial schema/network setup is not a blanket rerunnable migration. Inspect USER_OBJECTS/USER_ERRORS after failures. Existing profiles/objects are not silently replaced. The load script checks identity/hashes and activates a graph only after success; identical graph hashes reuse ready snapshots. Prior graphs and contexts remain historical records.

For a local authoring dataset instead of the public summaries, use `work/worksheet/dataset-parts/README.md` and its numbered SQL, or `work/worksheet/10_load_dataset.sql` in a suitable client. Keep extracted content local and choose one dataset/load method for a fresh schema. The GitHub path requires the importer package and current ADMIN grants, but no GitHub credentials. Test the dev candidate before promoting the package to release.

Profile creation and the greeting test can also be done before creating lab tables. `05_profile_worksheet.sql` has no KCV table dependency; return to `06_register_profile.sql` after `01_objects.sql` before extraction or agents. Do not rerun schema creation over tables that already exist.

### Copyable RDF network creation

Run once as **KCV_LAB**, after schema setup:

<!-- include-sql: sql/schema/02_network.sql -->

```sql
BEGIN
  SEM_APIS.CREATE_RDF_NETWORK('DATA',network_owner=>USER,network_name=>'KCV_NET');
END;
/
```

[Script: 02_network.sql](../sql/schema/02_network.sql)

<!-- /include-sql -->

## Optional extension: extraction and review

For the main walkthrough, continue directly to [context and relevance agents](../labs/05_context_and_agents.md). The following claim-curation workflow is optional and is not a prerequisite for agent setup or graph retrieval.

Run `sql/queries/03_extract_candidates.sql` in KCV_LAB Worksheet. It invokes the model and returns a JSON cell. Save/copy the raw JSON value into a local file (not a CSV-quoted wrapper), then:

```bash
.venv/bin/python -m kcv.cli import-candidates --file work/worksheet-response.json
```

Review with the local `review` command from Lab 4. After decisions, regenerate:

```bash
.venv/bin/python -m kcv.cli build
.venv/bin/python -m kcv.cli worksheet
```

Run the new load script in Worksheet. Quote validation does not replace semantic review.

## Agents, feedback and inference

- Run `sql/schema/04_agents.sql` once to register the native team.
- Run individual statements from `sql/queries/04_run_agents.sql` to invoke the model-backed workers.
- Enter an actual observer/observation in `sql/queries/05_record_feedback.sql`; inspect with `02_feedback.sql`.
- Use `sql/queries/06_inference.sql` for the optional native OWL2RL step.

Model calls and native SQL remain pending validation until actually run. See [validation](validation.md). `requirements-db.txt` and Python DB commands are optional test automation only. Object Storage, an APEX app, separate graph/vector services and WMS metadata are not required. See [cleanup](cleanup.md) for retiring temporary resources deliberately.
