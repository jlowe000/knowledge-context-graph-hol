# Database migrations on dev

Status: v2.0.0 C3 R7 dev candidate, not an accepted release. The [context-search record](../db/verification/context-search-validation.json) records the native upgrade to 96 COMPLETE project receipts / 97 Liquibase changesets, zero invalid objects and successful search regression tests. Scoped browser search/filter checks passed; the matching engine export is identified by its [receipt](../apex/export-validation.json). Fresh R7 installation remains unverified. The [deletion record](../db/verification/context-delete-validation.json) retains its R5 native results and pending permanent-delete browser confirmation; the [fresh deployment record](../db/verification/fresh-dev-validation.json) describes the preceding R4 installation. Generated Worksheet installer execution remains unverified; historical records and release remain unchanged.

The [24 November native migration record](../db/verification/native-validation.json) records successful SQLcl/Liquibase execution on isolated Serverless schemas: all 48 project migrations, fresh and verified-v1 upgrade routes, repeat updates, exact schema/program checks, concurrent-runner exclusion and failure/recovery probes. Generated Worksheet SQL also passed fresh/adoption/upgrade/repeat and subsequent Liquibase-entry tests through SQLcl. The Database Actions browser upload/copy transport has not been tested for these v2 bundles. The initial timestamp-index verification correction and later append-only identity correction are recorded explicitly; this is not full-v2 or release acceptance.

The accepted R2 chain contains 69 project receipts and 70 Liquibase changesets including the registry bootstrap. The initial native attempt completed fourteen C3 steps, then failed to compile the scenario body. Its unaccepted four-entry suffix is explicitly retired and retained as audit evidence. Five new r1 steps replace that suffix and add a separate model-reset audit correction. All 62 already completed payloads, postconditions and execution wrappers remain unchanged. The r1 update and independent repeat passed native source/schema checks, preserved the retired failure audit and passed the isolated legacy-request index fixture. Runtime observation testing then required two additional r2 steps. R2 then passed native update, an independent Liquibase no-op repeat and the generated Worksheet upgrade rerun through SQLcl, with exact unchanged receipts and zero invalid project objects. Fresh installation, v1 adoption/upgrade and Database Actions browser transport remain pending for this increment; the C2 acceptance record does not certify those new routes.

R3 appends three replacement package bodies and a new readiness checkpoint, giving **73 active project migrations and 74 Liquibase changesets**. It preserves every R2 payload, postcondition and execution wrapper. The [R3 validation record](../db/verification/c3-r3-validation.json) retains that candidate's native/browser evidence and expiry-continuation limitation. R4 appends seven steps, giving **80 active project migrations and 81 Liquibase changesets**, while preserving all 73 preceding migrations and their wrappers. The separate grounded-task registration below remains required; a schema checkpoint alone does not configure model routing.

Use SQLcl's Liquibase integration for developer schema changes. The [local Bash setup](dev-connection-setup.md) reuses Java/SQLcl or downloads missing tools without a container. Earlier Oracle Linux native acceptance used SQLcl 26.2.1.209.2118 and Java 21.0.12.1; its database checks are recorded separately from local tool startup. Run migrations as the dedicated project schema owner, never ADMIN. ADMIN is used only for separately reviewed bootstrap/grants. Keep credentials, saved connections, wallets, generated test data and private logs outside Git.

## What is managed

| Artifact | Responsibility |
| --- | --- |
| `db/manifest.json` | Explicit dependency order, immutable payload/verification hashes, baseline identity and target product version. |
| `db/baseline/contract.json` | Public v1 table/column/constraint and program inventory anchored to the recorded dev commit. |
| `db/baseline/payloads/` | Frozen v1 static schema/program source, not a dump of a live instance. |
| `db/changes/` | Frozen baseline additions and C2/C3/r1/r2/r3/r4/r5 payloads with exact postconditions. |
| `db/retired/` | Hashed evidence for an unaccepted failed candidate, excluded from the active execution chain. |
| `db/generated/` | Generated one-unit migration wrappers used by Liquibase. |
| `db/changelog.xml` | Ordered baseline and feature changelogs. |
| `db/baseline/adopt.sql` | Verify an existing v1 installation before recording baseline receipts. |
| `db/recovery/` | Per-step reconciliation that succeeds only after physical postconditions are satisfied. |
| `sql/install/*schema*.sql` | Generated fresh, adoption, upgrade and verification scripts for Worksheet acceptance. |

These scripts manage static project objects. They do not create users, enable Java, create credentials/profiles, copy content, register agents, create model conversations or create personal RDF overlays. Fresh setup still needs the documented prerequisites, RDF network, profile registration, dataset loading and deliberate agent setup. Existing setup retains these objects. Never run old raw `CREATE TABLE` scripts after the generated schema installer.

After applying R4 to an existing configured app, run [16_refresh_grounded_answers.sql](../sql/extensions/16_refresh_grounded_answers.sql) as the lab owner. This repeatable runtime step creates or refreshes the grounded answer task with no tools and creates `KCV_GROUNDED_TEAM` if absent. The application supplies evidence retrieved before dispatch; proposed context changes retain their existing route. It preserves existing teams and conversations. On a fresh schema without the QA agent it explicitly defers registration: first configure a working model profile, then run the initial [03_scenario_agents.sql](../sql/extensions/03_scenario_agents.sql). Do not rerun initial agent creation on an already registered installation. Script 15 remains the historical R3 route and does not install the R4 grounded task.

`KCV_SCHEMA_MIGRATIONS` records the expected payload/postcondition digest, product version, phase and completion for each step. It is separate from Liquibase's `DATABASECHANGELOG` and lock. Completed receipts are not trusted without postcondition checks. Oracle DDL commits independently; the wrappers make interrupted work visible rather than claiming a transactional rollback of the schema.

## Check the local artifacts first

From the dev repository in Oracle Linux:

```bash
python scripts/build_database_installers.py --check
python -m unittest discover -s tests -p test_migrations.py -v
```

Use the repository's Python environment if dependencies are not on your path. These commands verify hashes, current-source consistency, ordered dependencies, exact SQL payload preservation and the generated artifacts. They make no database connection. `VERSION` supplies the maintained product version; the manifest's target must match it.

## Fresh isolated schema

Use the [complete fresh dev deployment route](fresh-dev-deployment.md) for parameterized ADMIN bootstrap, a separate owner connection, runtime configuration, dataset loading and a new APEX app. It identifies local bootstrap/documentation/APEX fixes added after the published R4 commit and records scoped fresh acceptance with the remaining route limitations. Connect SQLcl to the dedicated schema and work from the repository root. The commands below were exercised with the SQLcl/Liquibase versions recorded above; validate them again when changing runner versions.

Before the Liquibase commands, use SQLcl `cd /path/to/knowledge-context-graph-hol` with your actual repository path. A previously executed script under `work/` can change relative-path resolution; do not assume a shell working directory or script header left Liquibase at the repository root.

```sql
lb validate -changelog-file db/changelog.xml
lb status -changelog-file db/changelog.xml
lb update -changelog-file db/changelog.xml
@sql/install/02_verify_schema.sql
```

Expected result: 36 static v1 baseline steps, twelve C2 steps and forty-eight active C3/r1/r2/r3/r4/r5/r6/r7 steps: 96 project receipts and 97 Liquibase changesets including bootstrap. The final marker is `2.0.0-c3-r7-ready`, with valid package objects and complete postconditions. A second `lb update` should report no pending changes; rerun the verification SQL to check the physical schema/program state. The marker denotes the installed schema contract, not browser/model or release acceptance.

No credentials or environment-specific source rows are part of the baseline. Its built-in `SCHEMA_VERSION = 1` setting is retained for compatibility; the full migration receipts identify later objects. Do not infer the complete schema version from that old setting alone.

## Upgrade an existing migration-managed development installation

Preserve the existing schema, application ID, public collection and personal runtime rows. Connect as the project schema owner using the private SQLcl setup. `ALTER SESSION SET CURRENT_SCHEMA` does not establish an owner session and is rejected by the migration runner.

1. Put the target application into a maintenance window and wait for active requests to finish. Setting a database flag alone cannot stop an already running application request. Keep the original separate HOL application available.
2. Record counts of existing contexts, conversations, turns and observations without exporting their contents. Record the current migration checkpoint and application identity.
3. Run the same `lb validate`, `lb status`, `lb update` and verification commands shown above. Do not recreate users, repeat raw table initialization, re-adopt an already recorded baseline or reset migration checksums.
4. Confirm 96 active COMPLETE project receipts, the `2.0.0-c3-r7-ready` marker, no invalid project objects and unchanged existing runtime row counts. Run `integration-test/verify_migration_legacy_requests.sql` in the isolated test schema; it uses and removes its own reserved probe table.
5. Run `sql/extensions/16_refresh_grounded_answers.sql` for the existing configured app. Confirm its ready message; a deferred message means initial model/agent setup is still needed.
6. Import the compatible native APEXlang application using the same application ID, complete the personal-journey and existing sample checks, then reopen the application. Verify a follow-up question records evidence for that answer and any incomplete response is visibly labelled. Keep any unresolved native/model/browser checks explicit in the candidate record.

On the development installation that encountered the initial compile error, one additional original FAILED receipt remains as audit evidence. The new checkpoint does not convert it to COMPLETE.

R4 adds `CALL_ORIGIN` with a `LEGACY` default to retained retrieval events and nullable `MODEL_STARTED_AT` to response runs. New events use `APPLICATION` or `AGENT`; old trace JSON omits the new origin and missing timestamp. The final checkpoint recompiles dependent package bodies and functions and checks their exact source. These changes do not rerun historical answers.

R5 adds an empty deletion journal and resource manifest, the `KCV_CONTEXT_DELETE` package, and replacement access/context/journey bodies. Normal access is fenced once deletion starts; cleanup can resume after an interruption. The schema migration itself deletes no context, conversation or graph.

R6 adds private derived search chunks, `KCV_CONTEXT_SEARCH`, and save/apply refresh hooks. Its native long-multibyte-query test exposed `ORA-12733`; R7 supersedes the search body with fixed-pattern normalization and literal token matching, and adds the final readiness checkpoint. Earlier applied payloads remain immutable. Apply the complete chain before importing the current app: the APEX installer checks R7 readiness and all sixteen required package specification/body objects. Model privileges, loading and backfill are separate runtime steps in [context search setup](context-search.md).

The C3 table changes add nullable fields to existing chat and response records. The response request-token index uses a conditional expression so legacy responses with NULL tokens remain valid; only non-NULL per-conversation request tokens are unique. New attachments, operation journals and model-boundary tables start empty. Package specifications precede dependent bodies, and the final step recompiles the fixed project function inventory before verifying the complete source contract. These migrations do not backfill personal identities, publish contexts or create model conversations.

## Adopt an existing v1 Worksheet installation

Use an isolated copy/test installation for initial native acceptance. The baseline verifies expected columns, datatypes, nullability, defaults, identity columns, keys, foreign keys, check constraints, indexes and installed program text. Full-line comments and blank lines are ignored in program comparison; substantive source differences are rejected. The current baseline assumes BYTE semantics for unspecified VARCHAR2 lengths and preserves explicitly declared CHAR semantics in new fields.

```sql
@db/baseline/adopt.sql
lb validate -changelog-file db/changelog.xml
lb update -changelog-file db/changelog.xml
@sql/install/02_verify_schema.sql
```

Adoption first verifies the existing baseline, then creates the project receipt registry and records only the verified v1 steps. The normal Liquibase update executes those verified wrappers as no-ops and records its own ledger before applying new steps. This avoids manually fabricating Liquibase rows or blanket `changelog-sync`. Do not bypass a failed adoption by changing expected hashes or synchronizing pending feature changes.

If the actual v1 deployment differs, stop and inspect the specific object named by the verifier. A package's valid status alone does not prove it matches the baseline. Resolve a legitimate supported variant through a reviewed baseline contract or upgrade path, rather than weakening the check to object existence.

## Independent Worksheet acceptance

The release learner route remains Database Actions SQL Worksheet. These are candidate generated scripts for testing on dev; this work has not promoted them to release.

| Entry path | Ordered scripts |
| --- | --- |
| Empty project schema | `sql/install/00_install_schema.sql`, then `02_verify_schema.sql`. |
| Existing verified v1 schema | `sql/install/00_adopt_schema_baseline.sql`, then `01_upgrade_schema.sql`, then `02_verify_schema.sql`. |
| Existing migration-managed dev schema | `sql/install/01_upgrade_schema.sql`, then `02_verify_schema.sql`; preserve existing receipts. |

Use Run Script and check the result after each file. The install/upgrade bundle has one outer PL/SQL block that stops on the first error, even if Worksheet normally continues later script blocks. It executes the same immutable SQL payloads and postconditions as Liquibase. Superseded steps are handled by the verified-history rules below. This does not undo DDL already committed; failed steps remain recorded. Literal ampersands are encoded to prevent substitution prompts without changing the executed SQL text.

The final check is short enough to run directly:

```sql
SELECT migration_id,product_version,phase
FROM kcv_schema_migrations
WHERE migration_id='2.0.0-c3-r7-ready';
```

Expected: one `2.0.0` row with `COMPLETE`. This is a necessary schema checkpoint, not proof of browser, ownership, model or full-v2 acceptance. The complete verifier and native My Contexts/deletion/search tests remain required. The [search record](../db/verification/context-search-validation.json) describes R7's tested scope; the [fresh deployment](../db/verification/fresh-dev-validation.json), [R4](../db/verification/c3-r4-validation.json) and [R3](../db/verification/c3-r3-validation.json) records describe preceding checkpoints.

## Adding a migration

1. Edit the maintained SQL source, review the change and choose a new ordered migration ID. Never change a published payload or reuse its ID for different SQL.
2. Freeze one executable SQL/PLSQL unit into `db/changes/<version>/`. For packages, install all required specifications before dependent bodies. Freeze explicit postconditions with it.
3. Add its manifest row with SHA-256 hashes, source/unit provenance and dependencies. Candidate source files must match their latest frozen payloads. Do not reference a mutable package source file from an already-published changeset.
4. Run `python scripts/build_database_installers.py` to regenerate wrappers, changelogs, recovery and Worksheet scripts; then run the check/tests above.
5. Apply it through SQLcl to an isolated native target. Check compilation, fresh/upgrade paths, rerun behavior and failure recovery. Keep the result separate from local tests.

New migrations that alter an earlier table/program must define which earlier postconditions they supersede at the new schema head. The C2 identity correction demonstrates this: it appends a new access specification, body, dependent-body compilation and `2.0.0-c2-identity-ready` checkpoint. The original access SQL, receipts and Liquibase checksums remain unchanged. The strict v1 verifier still describes the v1 baseline; it is not a generic verifier for arbitrary future schema states.

A manifest `supersedes` relationship replaces an earlier *current-state postcondition*, never its recorded history. The final verifier requires both the historical receipt and the exact successor digest/COMPLETE receipt, then checks the successor's actual program text and VALID status. Worksheet skips an old wrapper only after the same proof. If the successor is incomplete, the old physical contract must still pass; an interrupted specification/body replacement therefore fails closed and needs deliberate recovery before normal replay.

C3 also supersedes full baseline table/program contracts. Its additive column checks retain the entire earlier table contract, including original columns, keys and constraints. The Worksheet upgrade's opening gate verifies the newest completed successor when one exists, and the original contract otherwise; it always requires the original baseline receipt. This supports both a first upgrade and a completed-upgrade rerun without prematurely accepting pending work. Raw-v1 adoption intentionally remains a strict v1 check.

When an installation made through Worksheet later enters Liquibase, old `sqlFile` content is still immutable. A `sqlCheck` precondition on each superseded change can mark that historical entry as ran **only** after verifying its exact historical receipt, a COMPLETE successor with matching digest and the successor's physical postconditions. Missing successors use normal execution; failed verification HALTs. This is not blanket `changelog-sync` and does not mark pending feature work complete. The runner's ledger remains separate from the project receipts. See the [Liquibase precondition contract](https://docs.liquibase.com/oss/user-guide-4-33/what-are-preconditions).

## Failure and recovery

Inspect the specific step before proceeding. The original known retired C3 failure remains visible in this query after successful replacement; inspect the retirement record and run the full verifier to distinguish it from a new active failure:

```sql
SELECT migration_id,phase,error_code
FROM kcv_schema_migrations
WHERE phase<>'COMPLETE';
```

The shared `DBMS_LOCK` migration lock survives DDL commits and prevents another cooperating runner from entering the same step concurrently. A Liquibase lock alone is not an application maintenance gate. Later upgrades that change active runtime objects must also block/drain application writes as defined in the implementation plan.

An invalid package, a missing prerequisite or a partially installed object cannot receive a successful receipt. Investigate and fix the actual cause through a reviewed procedure. For physically complete work whose receipt was interrupted, the matching `db/recovery/<migration-id>.sql` requires the actual schema-owner session, acquires the same lock and verifies the exact postconditions and digest before reconciling it. It does not rerun DDL, clear a live lock or create a missing object. If postconditions are not met, recovery fails; do not mark the step complete manually.

### Retired initial C3 candidate

The first native C3 attempt failed at `2.0.0-c3-015-kcv_scenario-package-body` with ORA-24344 because `PRIOR` was used as a PL/SQL identifier. The [retirement record](../db/retired/2.0.0-c3-initial/retirement.json) preserves the original manifest and hashes of the applied prefix and unaccepted suffix. The replacement changesets have new IDs; the original failed receipt, error and timestamps are never modified. The unexecuted old suffix is excluded from both active Liquibase and Worksheet routes.

The guard accepts either no retired receipts (fresh installation), or the exact original failed digest, product version, FAILED phase, error code and empty completion timestamp. The other retired entries must be absent. If a Liquibase ledger exists, none of the retired IDs may have a row there. Unexpected states halt; this is not a general rule for ignoring failed migrations.

For the affected installation, keep the application in maintenance and run the normal active changelog update. Its next pending step is `2.0.0-c3-r1-001-kcv_scenario-package-body`, dependent on the already complete C3 step fourteen. The Worksheet install/upgrade bundles have an additional narrow preflight: only the verified retired failure triggers the reviewed replacement suffix before the ordinary baseline gate. This repairs invalidated package bodies before checking their current contracts. Fresh installations do not enter that branch. Both routes finish with the same source, receipt and retirement checks.

The separate `2.0.0-c3-r1-004-kcv_personal_journey-package-body` correction records a model-reset error on an already applied adoption operation. It supersedes the current-state check of the original C3 step fourteen while retaining that step's exact completed history. Neither correction publishes contexts or changes existing conversation data.

The r1 migration chain subsequently passed native upgrade, no-op replay, exact source/schema verification and the legacy request-index fixture. Runtime testing identified ORA-40573 while saving a personal observation: a JSON object method was evaluated directly by the SQL INSERT. `2.0.0-c3-r2-001-kcv_scenario-package-body` instead materializes the CLOB in PL/SQL before inserting it. The new r2 readiness checkpoint verifies that corrected body. These are ordinary additive migrations; all 67 applied r1 migrations remain active and unchanged. The Worksheet retirement preflight uses verified successor checks, so a completed r2 installation can rerun without comparing its current body to obsolete r1 source.

Record invalid-package, changed-checksum and interrupted-DDL tests before native acceptance. Preserve existing application data during fallback; there is no automatic destructive rollback. JAVAVM remains enabled.

See [SQLcl Liquibase commands](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/liquibase.html) and the [My Contexts implementation plan](my-contexts-implementation-plan.md).
