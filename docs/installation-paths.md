# Choose an installation path

**v2.1.0: all four prepared-environment deployment routes passed within their recorded scopes.** The [v2.1 validation record](../db/verification/release-v2.1-paths-validation.json) identifies the exact artifacts, execution forms, learner checks and bounded protected-build comparison. SQL-first clean acceptance used Worksheet plus genuine-owner SQLcl; combined schema-file transport remains unverified. Earlier r13 and [published v2.0.0 SQL-first tests](../db/verification/release-v2-paths-validation.json) remain separate evidence.

If you already have an app URL and individual login, go to [My Contexts](../labs/my-contexts/my-contexts.md). Installation is a facilitator task, not a requirement for every learner.

## Choose the experience and starting state

| Experience | Empty project schema | Existing published v2.0.0 installation |
| --- | --- | --- |
| **APEX-led** | [New application ZIP](apex-led-installation.md), Supporting Objects **Install**, then guided setup | [Replace the same application](apex-led-upgrade.md), Supporting Objects **Upgrade**, then readiness |
| **OCI / DBA-led** | [SQL-first clean installation](fresh-serverless-deployment.md) through Worksheet | [SQL-first v2.0.0 to v2.1.0 upgrade](migrate-to-v2.1.md), preserving the app ID |
| **DEV-led** | [Dev deployment environment](https://github.com/jlowe000/knowledge-context-graph-hol/blob/dev/docs/fresh-dev-deployment.md) for your adaptation | Dev's immutable migration/development workflow |

The package targets an **empty schema** or the **verified published v2.0.0 baseline**. These are the starting states used for the four passed rehearsals. Check the path record and its limits before using the package for a workshop.

For v1, use the [historical bridge to published v2.0.0](migrate-to-v2.md), then choose the v2.0.0 to v2.1.0 path. Direct v1 to this package has not been established by the earlier v1-to-v2 test. Unknown, customised or partially failed schemas require review; do not guess a checkpoint.

Clean means a new empty project schema, possibly on an approved existing database. It does not mean deleting an installation. Upgrades preserve the owner, workspace, app ID, accounts, collection, credentials, contexts, conversations and evidence.

## Use one matching package

Record the package version, source commit and artifact hashes privately. Use matching schema, app, setup and dataset files. A GitHub source-code ZIP is not the APEXlang application ZIP.

| Artifact | Purpose |
| --- | --- |
| `apex/kcv-explorer.apx.zip` | App Builder import with guarded Supporting Objects clean/upgrade scripts |
| `apex/kcv-explorer.sql` | Standard SQL app definition; import alone does not install the backend or complete readiness |
| `sql/install/schema-parts/README.md` | SQL-first ordered fresh/upgrade parts |
| `sql/install/00_install_schema.sql` / `01_upgrade_schema.sql` | Combined alternatives to the corresponding schema parts |
| `sql/install/02_verify_schema.sql` | Full receipt, physical-object and program-source verification |
| `sql/install/20_install_apex.sql` / `20_upgrade_apex.sql` | SQL-first new-ID / existing-ID app installation |
| `sql/install/03_bind_deployment_owner.sql` | SQL-first binding after app import |
| Dataset manifest/caller and validation records | Identify public content and tested artifacts/routes |

Stop if required files are absent. Do not substitute the new-app installer for an upgrade, mix branches or treat the Supporting Objects status label as full physical verification.

The current target has **121 COMPLETE project migrations**, checkpoint `2.1.0-apl-r4-ready`, valid matching program source and no invalid project objects. Use the full verifier; a receipt count alone is insufficient. Worksheet installation does not need a Liquibase ledger.

## Common readiness and handoff

Both experiences finish at [deployment readiness](deployment-setup.md). Its six checks are Database objects, Graph network, Model profile, Model connection test, Conversation components and Public collection. All six READY does not enable learners automatically: **Enable learning** is explicit. A manual greeting does not record the setup API's model-test result.

Use one method per installation/loading step. Supporting Objects performs its own owner binding. SQL-first import requires the separate generated **03 binding** step; skipping it leaves the app gated even when the model and collection work.

## Preserve work and recover deliberately

Before upgrading, arrange a restorable backup/recovery plan and maintenance window. Keep the old app definition and privately record identities and work counts. An application export does not back up learner rows, native graphs, credentials or accounts.

For the first v2.0.0 upgrade, stop learner traffic and let requests finish before changing code. New admission locks cannot coordinate an old-version request retroactively. Keep JAVAVM enabled. DDL/native operations may commit independently; browser cancellation or one rollback does not reverse an upgrade.

At a failure or timeout, stop dependent steps and use [recovery](deployment-recovery.md). Preserve receipts and codes; do not clear history, reset accounts, overwrite credentials or delete graphs to make checks pass.
