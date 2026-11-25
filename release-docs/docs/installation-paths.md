# Choose an installation path

**Version 2.0.0 installation paths.** Both SQL Worksheet routes passed their scoped rehearsals in isolated project schemas on an existing temporary ADB Serverless database: a clean R7 installation and an upgrade from the published v1 release. The [release-path validation record](../db/verification/release-v2-paths-validation.json) records the tested candidate, preserved-work checks and browser scope. Candidate02 required the documented APEX **Run Statement** instruction correction; its executable import body was unchanged. These tests did not exercise provisioning of a new database. Each route used one app account; two-account browser isolation and final permanent-delete confirmation are outside this acceptance.

If you already have a working app URL and your own app login, use [the learning paths](learning-paths.md). Installing or migrating is an administrator task; it is not required for every learner.

## Identify what already exists

For complete SQL files, use Worksheet **Open File / upload SQL** to load the intended file into its editor, then run it in the mode stated below. Confirm the file is complete. Do not paste a filename as SQL or split a large block by hand; use the documented execution mode and stop if a file is rejected or truncated.

| Your situation | Choose | Result |
| --- | --- | --- |
| No project objects or application exist in the intended schema | [Clean installation](fresh-serverless-deployment.md) | A configured project schema, dataset, workspace and new app |
| An existing v1 project contains work you want to keep | [Migrate to v2](migrate-to-v2.md) | Verify/adopt the supported baseline, upgrade it and retain the existing app ID |
| An existing project already has migration receipts | [Migrate to v2](migrate-to-v2.md) | Verify a supported recorded checkpoint and upgrade without adopting again |
| You do not know the installed version, or the schema/app has been customized | Stop for a maintainer review | Identify a supported path before changing objects |

An empty project schema may be created on a suitable existing database. **Clean installation does not mean deleting the old installation.** If the intended schema or application already exists, do not run fresh-create scripts over it or drop it to make the installation succeed. Use a separately approved target or the migration path.

## Use a complete, matching package

Obtain one complete release archive. Record its version and commit privately. The schema scripts, application export, installer and dataset caller must come from that package; do not combine current dev files with older release instructions.

Use a complete package containing these matching artifacts:

| Artifact | Purpose |
| --- | --- |
| `sql/install/00_install_schema.sql` | Create the complete static schema in an empty project schema |
| `sql/install/00_complete_v1_optional.sql` | Verify v1 and complete only missing supported optional objects before adoption |
| `sql/install/00_adopt_schema_baseline.sql` | Verify and record a compatible existing v1 installation |
| `sql/install/01_upgrade_schema.sql` | Apply ordered additions to an adopted/migration-managed installation |
| `sql/install/02_verify_schema.sql` | Verify receipts, physical objects and installed program source |
| `sql/install/20_install_apex.sql` | Install a new app for the clean route |
| `sql/install/20_upgrade_apex.sql` | Upgrade the existing app while preserving its ID |
| Runtime setup scripts and their release instructions | Configure the RDF network, model access, agent registration and optional local search model as appropriate |
| Matching export/validation record and dataset manifest/caller | Identify the prepared app and optional public dataset load |

**Package verification is required:** confirm that both APEX installer modes and the generated schema-parts manifest are present. A dev-generated artifact alone does not prove that a downloadable release contains it. If a required artifact is absent, stop and obtain the completed package; do not use the new-app installer as an upgrade substitute.

The ordered schema parts use **Run Script (F5)**. Both `20_install_apex.sql` and `20_upgrade_apex.sql` use **Run Statement (Ctrl+Enter)**: select their complete outer `DECLARE` through the final `END;`, excluding the final slash, to open the target and application-ID bind prompts.

## What each route does

| Step | Clean installation | Migration |
| --- | --- | --- |
| Account and access | Create a password-enabled lab owner for Database Actions and grant the documented privileges | Retain the existing owner, credentials and permissions; add only required new grants |
| Static objects | Run the complete schema installer, then verifier | Verify/complete supported optional v1 objects and adopt only when needed; run upgrade, then verifier |
| Runtime configuration | Create the owner RDF network, credential/profile and fresh scenario registrations | Preserve existing configuration; refresh only the required registrations |
| Public collection | Load the pinned public dataset using the [GitHub caller](github-dataset-load.md) | Keep the installed collection unless a separate dataset update is intended |
| APEX | Create and enable the workspace; create individual app accounts; install a new app | Keep workspace, accounts and app ID; use the matching upgrade installer |
| Acceptance | Complete the app-user and developer-learning checks | Complete those checks and compare preserved work with the pre-upgrade baseline |

Both routes use **Database Actions → SQL Worksheet**. No Python, SQLcl, Liquibase client or APEXlang authoring environment is required for a learner installing the prepared release. ADMIN performs account/grant/workspace tasks; the actual project owner performs schema and runtime tasks. Changing `CURRENT_SCHEMA` while signed in as ADMIN is not an owner login.

For version 2.0.0, successful schema verification requires **96 COMPLETE project receipts**, `2.0.0-c3-r7-ready`, no invalid project objects and all **16 required package specification/body objects**. The 97-entry Liquibase ledger used in dev is not a requirement for a Worksheet installation. These checks establish the schema contract, not successful model answers or complete learner acceptance.

## Preserve work and plan recovery

Before migration, the administrator must have an appropriate restorable backup/recovery plan and a maintenance window. Keep the old application export and record schema/app identity and work counts without publishing personal content or credentials. Database DDL and some native graph/model operations commit independently; an error is not undone by a single `ROLLBACK`.

Stop at an unexpected object, failed verification, missing prerequisite or import error. Keep the error code and failed-step identity privately for diagnosis. Do not clear receipts, bypass hashes, recreate credentials, reset accounts or force a new app ID. Neither path tears down existing project data or disables JAVAVM; Java enablement is a separate, one-way prerequisite when it is not already enabled.

Continue with [clean installation](fresh-serverless-deployment.md) or [migration](migrate-to-v2.md). The [validation guide](scenario-validation.md) distinguishes recorded tests from outstanding acceptance.
