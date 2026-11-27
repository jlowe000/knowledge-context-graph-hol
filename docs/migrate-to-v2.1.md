# SQL-first upgrade from v2.0.0 to v2.1.0

**v2.1.0: this prepared-environment SQL-first upgrade rehearsal passed.** Ordered Worksheet schema parts, same-ID app replacement, owner binding, readiness, measured preservation and historical answer/evidence reopening passed within the [recorded scope](../db/verification/release-v2.1-paths-validation.json). Start only from the verified published v2.0.0 checkpoint. For v1, use the [published v2.0.0 bridge](migrate-to-v2.md) first.

This upgrade preserves owner, workspace, application ID, accounts, stored model credential/profile, public collection and private graphs/history. It does not disable JAVAVM or create a replacement installation.

## 1. Prepare the baseline

Arrange a maintenance window and restorable recovery plan. Keep the old app export and versioned package privately. Stop learner traffic and let work finish; the new admission lock cannot protect old in-flight code. Record app/schema/workspace identity and relevant context/revision/conversation/evidence counts, plus a saved answer to reopen after upgrading.

Sign into the actual owner's Worksheet. ADMIN with a changed CURRENT_SCHEMA is not the owner. Verify the published package's physical/program contract; the checkpoint query alone is insufficient:

```sql
SELECT USER FROM dual;
```

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.0.0-c3-r7-ready';
```

The published baseline has 96 COMPLETE project receipts and that COMPLETE checkpoint. Skip v1 adoption/completion scripts: this installation already has a verified registry. Unknown hashes, custom objects or partial receipts require review. Do not fabricate receipts or bypass guards.

## 2. Upgrade and verify the backend

Choose **one execution form**: the complete [01_upgrade_schema.sql](../sql/install/01_upgrade_schema.sql) file or each numbered **upgrade** part in the [schema-parts guide](../sql/install/schema-parts/README.md). Both contain the same ordered canonical steps. Load complete files through Worksheet **Open File/upload SQL**, then use **Run Script (F5)**. The numbered parts were used in the accepted rehearsal. The combined file reduces file handling, but its large-file Worksheet transport remains unverified; it is not a preferred or accepted transport. Do not split PL/SQL blocks.

If upload is rejected before execution, the parts remain an alternative. Once migration starts—or a timeout leaves execution uncertain—inspect receipts and [recovery guidance](deployment-recovery.md) before switching forms or retrying. Do not run both as separate upgrades.

Run [02_verify_schema.sql](../sql/install/02_verify_schema.sql) separately. Expect 121 COMPLETE project migrations, `2.1.0-apl-r4-ready`, matching source/physical checks and no invalid project objects. Earlier DDL may already be committed on an error; stop dependent steps and use [recovery](deployment-recovery.md).

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.1.0-apl-r4-ready';
```

Expected: one COMPLETE row for version 2.1.0. This does not replace the full verifier, model test or learner evidence checks.

## 3. Replace the same app and establish binding

Choose one application execution form in the authenticated owner's Worksheet:

- **Bind prompts:** use [20_upgrade_apex.sql](../sql/install/20_upgrade_apex.sql). Select its complete outer DECLARE through final END, excluding the slash, and choose **Run Statement**. Supply the existing app ID and matching schema/workspace/alias.
- **Full-file F5:** open [20_upgrade_apex_script.sql](../sql/install/20_upgrade_apex_script.sql). In its labelled configuration block, replace the NULL values for `l_schema`, `l_workspace` and `l_alias` with the exact uppercase target names in single quotes; set `l_existing_app_id` to the existing positive numeric app ID. These values are non-secret. Leave credentials and model configuration out of the file. Run the complete file, including its final slash, with **Run Script (F5)**. No SQLcl is required.

Both forms retain the authenticated-owner, alias, existing-app and full-schema guards. Unfilled NULL targets in the script form fail before import. Use the upgrade wrapper, not either new-app allocator, and check the reported app ID is unchanged. The original bind form remains valid; the [validation record](../db/verification/release-v2.1-paths-validation.json) records which execution forms have actually passed native testing.

If execution is uncertain, check the existing app, activity and status using [recovery guidance](deployment-recovery.md#worksheet-application-import-or-bind-prompt-delay) before any retry. Switching the application SQL's submission form does not require repeating the completed schema upgrade, data load or conversation-component registration. Do not run both forms as separate upgrades.

This SQL app-definition route does not run a second Supporting Objects installation. Next run generated [03_bind_deployment_owner.sql](../sql/install/03_bind_deployment_owner.sql) as the owner with the actual app ID/workspace, using Run Statement for its complete block. Expect READY_FOR_SETUP or the exact-existing-binding ALREADY_VERIFIED result. See [binding and readiness](deployment-setup.md#sql-first-owner-binding).

## 4. Complete only missing readiness in the app

Preserve the existing network, credential/profile, collection and conversation registrations. Verify or create the separate native APEX workspace-administrator installer account using [account preparation](apex-led-administrator-preparation.md#3-create-the-workspace-and-accounts), without changing learner accounts.

After owner binding, sign into the **installed runtime app** as that installer and open [Deployment setup](deployment-setup.md#apex-guided-setup). Refresh readiness first. Retain a suitable existing credential; do not recreate it. Leave the existing model configuration and collection untouched when already correct. If the model connection test is not READY, explicitly use **Test model connection once**. A historical greeting from the older package is not this readiness receipt.

Use **Prepare conversation components** only when the required registration check is missing; review conflicting existing names rather than deleting them. Once all six checks are READY, choose **Enable learning** deliberately. Upgrading alone is not a reason to save profiles, repeat model calls or reload the collection.

The [owner SQL API](deployment-setup.md#sql-first-final-readiness) remains an optional headless/diagnostic alternative. Do not combine it with duplicate app actions. Optional local embedding search remains separate; without it the app labels keyword matching. Do not install/delete that model merely to force a test outcome.

The earlier SQL-first upgrade acceptance used its recorded owner-Worksheet readiness actions. The common-UI instructions reuse the existing setup contract but are not a newly observed end-to-end route result.

## 5. Verify preservation and reopen access

Sign in as the original learner, reopen the saved personal context/conversation/answer and inspect Sources and Answer lineage without asking again. Confirm its historical revision/collection. Compare baseline rows/graphs and report any observed new login attachment separately; do not conceal it as an exact unchanged-table claim.

Check My Contexts/Sample Contexts navigation and setup restrictions. Keep learners out if required checks fail. Old v1 sample conversations remain bound to their original browser session; the v2 personal-context path is the durable account-owned experience. No migration turns shared fictional samples into a user's personal context automatically.

Record the exact curated artifacts, preserved-work scope and actual route result. A successful import alone is not package acceptance, and restoring only an old app definition cannot reverse database changes.
