# Clean installation of the v2 sample

Use this path for an **empty project schema**, on a new or approved existing ADB Serverless database. For an existing project installation, use [Migration to v2](migrate-to-v2.md). The [installation selector](installation-paths.md) explains the difference.

**Candidate status:** the SQL-first clean route passed its scoped rehearsal in an isolated empty schema on an existing temporary Serverless database. See the [release-path record](../db/verification/release-v2-paths-validation.json). Candidate02 supplied the tested runtime; its APEX installer instruction was corrected to Run Statement without changing the import body. V2 remains unpromoted, and these tests do not establish provisioning of a new database. The linked labs use the ordered v2 installation; do not combine them with raw-object instructions from an older checkout.

If a facilitator has already supplied an app, start with [app use](../labs/explore-evidence/explore-evidence.md) or [developer learning](../labs/understand-collection/understand-collection.md). No installation is needed for those hosted experiences.

## Before starting

For complete SQL files, use Worksheet **Open File / upload SQL** to load the intended file into its editor, then run it in the mode stated below. Confirm the file is complete. Do not paste a filename as SQL or split a large block by hand; use the documented execution mode and stop if a file is rejected or truncated.

- Obtain a complete, versioned release package and its manifest. Use one version throughout; do not mix files from dev, v1 and v2.
- Have ADMIN access for platform checks, user/grants and workspace setup, and an approved OCI Generative AI identity for chat inference.
- Use a password-enabled lab owner with Database Actions access. The dev-only proxy/no-authentication connection workflow is not part of this route.
- Keep credentials and model-download access links in private browser prompts, outside source files, screenshots and shared logs.

Database work uses **Database Actions SQL Worksheet**. No local Java, wallet, SQLcl, Liquibase, Bash or Python is required. OCI provisioning, IAM and any required database restart remain administrator tasks.

## Installation sequence

Use **Run Script (F5)** for the ordered schema parts and other files explicitly marked for script execution. For bind-bearing setup blocks and the APEX installers, select the complete outer `DECLARE`/`BEGIN` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. This opens the required bind prompts, including nonsecret application targets. Read the result after every step; stop on an error rather than continuing into dependent setup.

| Step | Account | Action | Expected outcome |
| --- | --- | --- | --- |
| 1. Check the platform | ADMIN | Confirm the supported database/APEX versions and VALID JAVAVM. If Java is already enabled, leave it enabled. For a new database, complete the documented Java enablement/restart before proceeding. | Required database services are ready. Local laptop Java is not a substitute for database Java. |
| 2. Prepare the lab owner | ADMIN | Use the supplied user, grants and Database Actions scripts. Create a new project owner, or verify a separately provisioned owner is empty and complete only missing setup. Do not reset an existing project's user to make it appear empty. | A password-enabled owner can open its own Worksheet with the required quota and grants. |
| 3. Install the schema | Lab owner | Run the **fresh** files in the [schema-parts guide](../sql/install/schema-parts/README.md), then [02_verify_schema.sql](../sql/install/02_verify_schema.sql). Do not also run the old raw table/package creation sequence. | The ordered schema installation and full verification succeed. The R7 candidate has 96 COMPLETE project receipts and valid required packages. |
| 4. Configure runtime services | Lab owner | Create the owner-private RDF network using `sql/schema/02_network.sql`. Follow [model authentication](authentication.md), create the profile and register it after the settings table exists. Test a greeting. | The RDF network and this owner's model profile work. A different owner's successful model call is not sufficient. |
| 5. Load public knowledge | Lab owner | Follow [GitHub dataset loading](github-dataset-load.md) using the package's full published commit SHA and manifest hash. | The public summary dataset and graph are ready; load status reports success. No personal contexts are imported. |
| 6. Register conversation services | Lab owner | Run `sql/extensions/03_scenario_agents.sql` after the profile and schema are ready. | The required teams are registered, including `KCV_GROUNDED_TEAM` for answers using application-retrieved evidence. Do not recreate schema tables here. |
| 7. Enable semantic context search | ADMIN, then lab owner | Follow [Worksheet search setup](context-search.md#worksheet-setup): grant the required model privileges, load the separately obtained embedding model, verify it and backfill search data. | Search can use local embeddings. A new empty personal library may have no search rows; without the model, the app must explicitly report keyword-only matching. |
| 8. Create the APEX workspace and account | ADMIN | Use the release workspace bootstrap, including explicit workspace enablement, and create a separate app login privately. | The enabled workspace maps to this owner and the app account can authenticate. |
| 9. Install the app | Lab owner | Select the complete outer block in `sql/install/20_install_apex.sql`, excluding the final slash; use **Run Statement** and supply its target binds. Record the generated application ID and launch link. | A new application is installed against the verified schema. This installer allocates a new ID and is not the migration installer. |
| 10. Verify the experience | App user; lab owner for SQL checks | Sign in, explore a Sample Context, create a My Contexts draft, review/apply it, ask a question and inspect its evidence. Sign out/in and reopen the saved work. Run the supplied final verification. | Both learning routes work and private saved work survives a new sign-in. |

After signing in as the lab owner, confirm the account before running owner scripts:

```sql
SELECT USER FROM dual;
```

Expected: the chosen project schema, normally `KCV_LAB`, not ADMIN.

After the full schema verifier succeeds, this short query confirms the candidate checkpoint:

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.0.0-c3-r7-ready';
```

Expected: one row with product version `2.0.0` and phase `COMPLETE`. This checkpoint does not replace model, account-isolation or browser tests. A Worksheet installation does not need a Liquibase changelog count.

## Package acceptance before publication

The candidate02 clean rehearsal passed all 19 ordered schema parts through Worksheet upload/execution, including parts exceeding 2 MB, runtime setup, new-app import and scoped browser/persistence checks. Use a complete matching package with the corrected execution instructions, documented order and completion checks; do not split PL/SQL blocks yourself. The linked validation record retains the one-account browser scope and untested permanent-delete confirmation.

A failed installation can have committed DDL before the error. Retain the error and migration receipts, then use the supplied recovery instructions or facilitator support. Do not drop the user, graph or database to hide a failed step. Re-running verification is distinct from recreating credentials, networks or app accounts.

The route follows [LiveLabs authoring conventions](livelabs-authoring-alignment.md). See [validation](scenario-validation.md) for recorded scope and [the screenshot checklist](screenshots.md) for safe beginner captures. The final release must record clean installation and migration as separate acceptance results.
