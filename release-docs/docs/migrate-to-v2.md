# Migrate an existing installation to v2

**v2 candidate documentation; not yet promoted to release.** The SQL-first candidate passed a published-v1 migration through Database Actions in an isolated schema on an existing temporary ADB Serverless database, retaining the application ID and recorded legacy work. See the [release-path validation record](../db/verification/release-v2-paths-validation.json) for the exact scope and limits. Candidate02 supplied the tested executable SQL; its APEX installer instruction was corrected to **Run Statement**, with no import-body change. Use [installation paths](installation-paths.md) to distinguish this route from a clean installation.

This route preserves the project schema, public collection, stored model credential/profile, workspace, application accounts and **existing application ID**. It does not tear down data, change JAVAVM or recreate credentials. A customized or unrecognized installation needs a reviewed migration path first.

## 1. Prepare and identify the target

For complete SQL files, use Worksheet **Open File / upload SQL** to load the intended file into its editor, then run it in the mode stated below. Confirm the file is complete. Do not paste a filename as SQL or split a large block by hand; use the documented execution mode and stop if a file is rejected or truncated.

Have the administrator arrange a maintenance window and a restorable recovery plan. Export the existing APEX application privately and retain the matching old release. Stop new app requests and let active work finish. Record the existing owner, workspace, app ID/alias, version, graph identities and counts of contexts, conversations, turns and observations; keep environment details and content out of public reports. Before the maintenance window, review/export any legacy sample-chat material you need through its currently authorized session.

Obtain the [complete matching package](installation-paths.md#use-a-complete-matching-package), including `sql/install/20_upgrade_apex.sql`. Do not proceed with a partial package or substitute `20_install_apex.sql`.

Sign into the actual project owner's SQL Worksheet, normally KCV_LAB. Run this with **Run Statement**:

```sql
SELECT USER FROM dual;
```

Confirm the expected owner. Do not use ADMIN with `ALTER SESSION SET CURRENT_SCHEMA`. Run this separate read-only check:

```sql
SELECT table_name FROM user_tables
WHERE table_name='KCV_SCHEMA_MIGRATIONS';
```

No row means the installation has no migration registry; it does **not** prove compatibility with v1. A row means receipts exist; it does **not** prove that the physical schema matches them.

## 2. Select the verified starting path

| Starting state | Action as the project owner |
| --- | --- |
| Existing v1, without receipts | Run [00_complete_v1_optional.sql](../sql/install/00_complete_v1_optional.sql) with **Run Script (F5)**, then [00_adopt_schema_baseline.sql](../sql/install/00_adopt_schema_baseline.sql). Continue only after both guards succeed. |
| Existing migration-managed installation at a supported, complete checkpoint | Skip adoption. Have the maintainer confirm its recorded checkpoint/source matches the package's supported chain; the upgrade's opening checks must also pass. |
| Partial/failed installation, unknown version or customized objects | Stop. Retain the error/receipt and obtain the matching recovery or reviewed migration procedure. Do not mark it complete or guess a baseline. |

The published v1 beginner route may omit the optional domain-extraction table/function. The completion helper verifies all required v1 objects first, verifies any existing optional objects, and creates only the missing supported optional objects. Expect `KCV_V1_REQUIRED_CONTRACTS=PASS` and `KCV_V1_OPTIONAL_COMPLETION=PASS`; objects_created is 2 for the normal guided v1 installation or 0 when both optional objects already exist. A complete matching v1 installation is unchanged. The helper rejects an existing migration registry; migration-managed installations skip it as well as adoption. It replaces no customized program, creates no migration receipts and makes no model request. Unknown differences still stop.

Adoption then records verified existing objects; it is not fresh installation or a dataset load. A failed comparison must be resolved before upgrading. Do not edit expected hashes, fabricate receipts or rerun raw table/package initialization to bypass it.

## 3. Upgrade and verify static objects

Follow the [schema-parts guide](../sql/install/schema-parts/README.md), running each **upgrade** part with F5 in the manifest order. The combined [01_upgrade_schema.sql](../sql/install/01_upgrade_schema.sql) is an alternative for a suitable transport; choose one form. Then run [02_verify_schema.sql](../sql/install/02_verify_schema.sql) separately. Check every result for errors before continuing. The upgrade stops at its first failed step, but earlier DDL may already be committed; do not assume that a rollback restores the old version.

Expected: **96 COMPLETE project receipts**, `2.0.0-c3-r7-ready`, zero invalid project objects, matching program-source verification and all **16 required package specification/body objects**. Compare the recorded existing-work counts with the pre-upgrade baseline. New operational tables may be empty; later search setup intentionally creates derived rows. Do not expect a Liquibase ledger from this Worksheet route.

Run this short checkpoint query with Run Statement as an additional check; it does not replace the complete verifier:

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.0.0-c3-r7-ready';
```

Expected: one row, product version `2.0.0`, phase `COMPLETE`.

## 4. Refresh runtime registrations and search

As the owner, run [16_refresh_grounded_answers.sql](../sql/extensions/16_refresh_grounded_answers.sql) with F5. Expect `Grounded answers ready`: the application retrieves evidence before the answer task. Existing proposal teams and saved conversations remain. A **deferred** result means model/agent prerequisites are absent; diagnose them instead of blindly rerunning fresh agent creation or recreating a working credential.

For semantic library search, ADMIN runs [11_context_search_grants.sql](../sql/admin/11_context_search_grants.sql), supplying the existing owner name for `KCV_SCHEMA`. As the owner, open [22_setup_context_search.sql](../sql/extensions/22_setup_context_search.sql), select its complete setup block without the slash and use **Run Statement**. Supply the direct augmented ONNX URI privately. The same block loads or verifies the model, checks its dimensions, backfills and commits; require `CONTEXT_SEARCH_MODEL_READY=384` and `CONTEXT_SEARCH_BACKFILL=COMPLETE` before running the separate coverage query. Obtain the supported artifact from the [Oracle model instructions](https://blogs.oracle.com/machinelearning/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai); do not substitute a ZIP or bypass the pinned checksum.

Expected: the existing model is retained or the pinned model loads, backfill completes and coverage is visible. `READY` counts chunks, not contexts; empty coverage is valid before personal contexts exist. Backfill commits derived data, so use a session without unrelated uncommitted work. Without a usable model, the app explicitly uses keyword search; do not report semantic search as accepted. This setup is separate from chat credentials and does not send saved context text to an external embedding service.

Keep the existing public dataset for this migration. Loading another published collection is an optional, separate [GitHub dataset operation](github-dataset-load.md), not a prerequisite to upgrading the application. Existing conversations retain their pinned collection and revision; do not delete old graph data to make them follow a new collection.

## 5. Upgrade the same application and check the experience

Confirm the supplied `sql/install/20_upgrade_apex.sql` targets the existing workspace, parsing schema and alias. In the owner's Worksheet, select the complete outer `DECLARE` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. Supply the target binds and the **existing app ID** in `KCV_APPLICATION_ID`. F5 does not open these bind prompts. Its guards must pass. The reported application ID must match the recorded one. Keep the same app accounts; installation must not create a replacement identity to bypass an access error.

The migration does not turn shared fictional contexts or legacy sample conversations into personal My Contexts work. It preserves v1 stored rows, evidence and RDF without widening access. Legacy sample conversations remain bound to their original browser session; a new sign-in may not reopen them. Retaining the app ID does not remove that boundary. Review/export needed legacy material before the maintenance window. New v2 personal conversations deliberately created under My Contexts are the durable, account-owned reopening path.

Sign in again if the import expires the app session. Verify preserved v1 records/evidence and unchanged application identity through the authorized migration checks; do not treat legacy chat reopening after logout as a promised outcome. Confirm a new personal context can be saved, reviewed and used, then reopen that personal conversation after a fresh sign-in. Check Sample Contexts, explicit adoption of a revised context, search/status filters and archive/unarchive. Use only a disposable context for permanent-delete acceptance. Current native deletion and browser review/Cancel results do not establish that final confirmation test.

Compare preserved work and record the exact installed package, verification results and outstanding checks before reopening access. If a check fails, keep the app in maintenance and use the prepared recovery plan. Restoring only an old APEX export is not a complete reversal of database changes. The [validation guide](scenario-validation.md) should identify the accepted scope; a successful import alone is not release acceptance.
