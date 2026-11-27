# Name, replace and retire a dev build

Use this guide with [fresh dev deployment](fresh-dev-deployment.md). It covers installations built from `dev` using Oracle Linux/Bash, local SQLcl, Liquibase and native APEXlang. Release has its own SQL-first installation and migration instructions. Managing a dev build does not commit, push or promote release.

## Naming and identity

Name the database schema and APEX workspace identically: **`KCV_V<major>_<build>`**.

| Identity | First build example | Replacement example |
| --- | --- | --- |
| Schema and workspace | `KCV_V2_001` | `KCV_V2_002` |
| SQLcl owner connection | `KCV_V2_001_OWNER` | `KCV_V2_002_OWNER` |
| Application alias | `KCV-V2-001` | `KCV-V2-002` |
| Application ID | An unused ID, recorded separately | A different unused ID |
| APEX end user | `KCV_USER` in workspace `KCV_V2_001` | A separately created `KCV_USER` in workspace `KCV_V2_002` |
| Administrative connection | Existing private ADMIN alias, for example `KCV_V2_ADMIN` | Retain the same ADMIN alias |

The major comes from the product version: `2.0.0` uses `V2`. The build is an allocation sequence per major version on the target database, starting at `001`, padded to at least three digits. Allocate the next unused number and retain a record of retired numbers; do not reuse them. A new installation of the same product version or Git commit still receives a new build number. A future major version starts its own sequence, such as `KCV_V3_001`.

Keep product version, Git commit and deployment build separate. An in-place patch/minor upgrade retains the deployed schema/workspace and records the new code and migration checkpoint. The bootstrap accepts uppercase `KCV_` identifiers of 5–30 characters; it does not enforce this narrower convention or equality of the workspace and schema. Supply both names explicitly and identically.

The dev owner has **NO AUTHENTICATION**. Its private owner connection uses `ADMIN[build_owner]` proxy syntax; `CURRENT_SCHEMA` alone does not establish that identity. `KCV_USER` is an APEX app-only account, not a database login or a workspace developer. Reusing that username across workspaces creates separate accounts with independently entered passwords.

## Choose the lifecycle operation

| Intent | Route | What happens to saved work? |
| --- | --- | --- |
| Install a first build | [Fresh dev deployment](fresh-dev-deployment.md) | New collection and empty personal library |
| Upgrade the existing build | [Migration-managed upgrade](database-migrations.md#upgrade-an-existing-migration-managed-development-installation) and same-ID APEX import | Preserve existing identities and verify runtime data before/after |
| Replace with a separate build | Create and validate the next build, then retire the old one below | New personal library; retain or deliberately migrate old work separately |
| Retire without replacement | Exact-target retirement after an explicit saved-work/recovery decision | Old application access ends; recovery depends on retained material |

Retirement removes an installation. It is not a Liquibase rollback: Oracle DDL and native service APIs can commit independently, and schema changes do not have an automatic reverse migration here.

## Saved work and replacement

My Contexts ownership includes the workspace ID, application ID and stable APEX account ID. Giving the new workspace another `KCV_USER` does **not** transfer its contexts, conversations or historical evidence. The public dataset loader supplies source knowledge and fictional samples, not personal runtime data. A fresh installation is therefore not a data migration.

If the existing learning history must remain available, prefer an in-place migration or keep the old build until a supported transfer is separately designed and tested. Do not copy personal tables and replace usernames or ownership IDs: attachments, revisions, graph overlays and evidence must remain consistent with authorization. This repository does not provide a cross-workspace personal-data migration command.

Before retirement, record whether old data is disposable, retained privately for recovery, or must be transferred before removal. Code in Git and an APEX application export do not back up all learner data. A content recovery archive should cover the relational data and schema metadata, native RDF graphs, application definitions and any additional local assets needed to reconstruct the build. Preserve source version and runtime configuration requirements without exporting credential values or APEX password data.

Verify exported row/triple counts, file completeness and checksums. State the limits: a verified content archive is not a rehearsed full database restore. Recreating identities, foreign-key/identity-column ordering, native models and private credentials requires its own recovery procedure. If restoration is required, establish and test that procedure before deleting the only working copy. Keep archives and raw acceptance logs outside published files, with an explicit retention decision.

## Replace a build

1. **Record the current build.** Privately record its exact owner, workspace, app ID/alias, source commit, product version, migration checkpoint, public dataset commit/hash and SQLcl owner alias. Record counts/digests for the existing data and app identity. Keep wallet paths, endpoints, service names and secrets out of public records.
2. **Allocate the replacement.** For example, preserve `KCV_V2_001` and allocate `KCV_V2_002`. Check that its owner/workspace/alias are unused and select a different unused application ID. Do not overwrite the current owner connection or app to make a target available.
3. **Deploy independently.** Follow [all fresh-deployment steps](fresh-dev-deployment.md) with the new target names. Create the owner/grants, save the new proxy connection and apply Liquibase. Create/enable the workspace with a native installer-admin and separate app-only learners, import the APEXlang app, then establish owner binding. Configure its own network, credential/profile, model test, runtime registrations and public collection through Deployment setup. Optional local semantic search remains a separate owner/admin task. Keep account passwords private.
4. **Validate the replacement.** Check the schema verifier, zero invalid project objects, a READY public graph, source/passage counts, owner-local model access and local embedding dimensions. Use exact-owner test adapters where required; historical integration-test guards are not generic build allowlists. Run the personal/sample browser flow, evidence views, explicit revision adoption, a follow-up and saved-work reopening. Record what passed and what remains untested.
5. **Check the old build is preserved.** Compare its data/app baseline after installation and tests. Resolve any unexplained difference before continuing. A working replacement must not depend on the old schema's credential, profile, graph or packages.
6. **Switch usage deliberately.** Give users the new app location and accounts; explain its new personal-data boundary. Keep the old installation until acceptance and the saved-work decision are complete. Before destructive retirement, returning to the old app is possible, but new work written in the replacement is separate and must not be silently discarded.
7. **Retire the old build.** Follow the exact-target sequence below. Protect the new build with a fresh before/after baseline once its validation activity is idle.

## Retire an exact build

There is **no generic numbered-build teardown command checked into this repository**. The successful consolidation used a privately reviewed runbook tied to its exact inventory. Prepare and review a runbook for the owner/workspace/app actually being retired. The legacy `scripts/sql/90–93` reset/teardown files target the original `KCV_LAB` setup and do not cover the current v2 resource set; do not run them or adapt them by simple name replacement.

### 1. Preflight and recovery checkpoint

Use direct ADMIN for the cross-schema inventory. Verify the retired and retained identities separately, including workspace-to-schema mappings and the app's parsing schema. A workspace with additional applications, schemas or accounts needs a deliberate scope decision. Review dependencies, outside grants/synonyms, proxy relationships, model/profile references and other consumers before removal.

Inventory the exact owner-native teams, agents, tasks, tools, conversations, profiles, credentials, mining models, scheduler jobs and RDF networks/models. A name prefix alone is insufficient evidence of ownership or permission to delete. Native APIs can create supervisor tasks, disabled scheduler jobs and RDF grants/result types; review their exact identities and relationships rather than declaring every extra object safe.

Complete the saved-work/recovery checkpoint. Record the retained build's data counts/digests and application identity with no active writes. Record JAVAVM as VALID. If a required catalog cannot be read, resolve access with the administrator; a failed query is not proof that a resource is absent.

### 2. Quiesce the old app

In the exact old workspace context, use the supported APEX application-status API to make only the old app unavailable, recording its previous status. Allow active requests to finish; close old owner SQLcl sessions. Check running jobs, model requests, conversation mutation leases, graph/dataset loads, context publication journals and pending deletions. Do not infer that a disabled job or an expired browser session means all work is idle.

A saved unapplied preview is distinct from a partially completed publication. Stop for unresolved or uncertain operations and review their journals. Do not kill sessions, delete journal rows or fabricate completion to get past a check. Quiescing the APEX app alone does not prevent another SQL client from writing; keep the old owner out of use throughout retirement.

### 3. Remove owner-native runtime resources

Use the **actual old owner context** for owner-native catalogs and APIs. A verified owner connection works; an administrator may instead use a separately reviewed, exact-owner definer-rights helper with direct privileges and strict caller/target guards. Changing ADMIN's CURRENT_SCHEMA is not equivalent. Never grant new access to the retained build's credentials for cleanup.

Execute each stage sequentially, using the reviewed inventory and verifying its postconditions:

| Order | Supported operation | Required result before proceeding |
| --- | --- | --- |
| 1 | `DBMS_CLOUD_AI_AGENT.DROP_TEAM` for exact old teams | Teams gone and associated jobs no longer present/running |
| 2 | `DROP_AGENT`, then remaining `DROP_TASK` and `DROP_TOOL` | Exact old agents/tasks/tools gone, including reviewed supervisor-generated tasks |
| 3 | `DBMS_CLOUD_AI.DROP_CONVERSATION` | Old provider conversation resources removed |
| 4 | `DBMS_CLOUD_AI.DROP_PROFILE`, then `DBMS_CLOUD.DROP_CREDENTIAL` | Old owner-local profile/credential removed; replacement remains independent |
| 5 | `DBMS_VECTOR.DROP_ONNX_MODEL` for the exact old local model, if present | Old search model removed |
| 6 | `SEM_APIS.DROP_SEM_NETWORK` with the **old owner** and exact `KCV_NET`, after reviewing every model it contains | Old network and its models removed; replacement's same-named network retained |

Re-query resources after native API calls: dropping a team/agent may also remove generated resources. The documented `force` option on [Select AI Agent drop operations](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-ai-agent-package.html) tolerates absence; it is not permission to ignore other failures. Stop if native cleanup leaves unexpected resources or fails. Do not jump to DROP USER as a workaround.

### 4. Remove the exact app, workspace, route and schema

Return to direct ADMIN after native cleanup succeeds. Recheck the protected replacement and JAVAVM, then perform these steps in order:

1. Remove the exact old app with `APEX_INSTANCE_ADMIN.REMOVE_APPLICATION(p_application_id=>...)`.
2. Remove only the old workspace with `REMOVE_WORKSPACE`, explicitly setting `p_drop_users=>'N'` and `p_drop_tablespaces=>'N'`. This keeps database-user removal separate and protects shared tablespaces. See [Oracle's parameter definitions](https://docs.oracle.com/en/database/oracle/apex/26.1/aeapi/REMOVE_WORKSPACE-Procedure.html). The retired workspace's application accounts cease to be available; the new workspace's separate accounts remain.
3. If the old schema has an ORDS route, remove it using `ORDS_ADMIN.DROP_REST_FOR_SCHEMA(p_schema=>...)` and verify it is gone through the supported administrative view. A schema-only dev owner may have no route. Do not write ORDS metadata tables directly; see the [ORDS administration API](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/26.1/orddg/oracle-rest-data-services-administration-pl-sql-package-reference.html).
4. Confirm no old-owner sessions remain, revoke only its `CONNECT THROUGH ADMIN` relationship, then drop **that exact old schema** with CASCADE.

Do not alter JAVAVM, the shared DATA tablespace, the database instance, unrelated resources, or external OCI API keys/IAM policies used by the replacement. Removing an old stored database credential does not require revoking the external OCI signing key.

DDL and native operations may already be committed if a later stage fails. Record the last successful stage and inspect the remaining resources. Continue only with a reviewed recovery action for the actual state; do not replay the entire teardown blindly or replace a failed helper without inspection.

### 5. Verify and retain the retirement record

Verify the exact old schema/objects, app, workspace/mappings, routes and proxy relationships are absent. Verify the replacement's owner/workspace/app, app-only users, schema checkpoint, public data, native graph and local model are healthy. Compare the protected data/app baseline, verify zero invalid project objects and JAVAVM VALID, then test a small model request using the replacement's own profile. Record any comparison exclusions rather than claiming a whole-database restore or preservation test.

Retain a private record of target identities, source/data hashes, backup locations, retirement results and the final retained build. Publish only sanitized acceptance facts. Keep the recovery archive until the agreed retention period ends.

## Clean up local work areas and saved connections

Database retirement and local cleanup are separate actions. First inventory the local areas, distinguish recoverable generated output from unique recovery evidence, and choose exact deletion targets. Check `git status` and tracked-file membership before deleting anything. On Windows, resolve the absolute path and confirm it remains inside the intended workspace before any recursive removal. Do not delete all of `work/` just because it is ignored by Git.

| Local area | Cleanup rule |
| --- | --- |
| Superseded generated release candidates, previews, Worksheet transport files and temporary export staging | Can be removed after the relevant committed inputs and exact tested/promoted package evidence are retained |
| Old build runners and populated installation SQL | Retire once no longer needed; they can target deleted owners or contain private configuration. Keep the sanitized procedure and useful acceptance results |
| Recovery archives, app exports and before/after ledgers | Retain privately under the recovery/retention decision; a reproducible code build cannot recreate personal runtime history |
| Research originals, extraction outputs and provenance | Review against research/reproducibility needs separately; do not treat them as disposable deployment output |
| Java/SQLcl caches and Python environments | Keep versions used by the active launcher/workflow; remove obsolete caches only after confirming they are unused and can be restored |
| Wallets, saved connections, local credential files and authentication screenshots | Review privately. Keep shared wallet/service material needed by the current owner or ADMIN; do not inspect or publish secret contents as an inventory technique |

Use SQLcl's connection manager from the **same OS account and Oracle Linux/WSL environment** where the aliases were saved. List names without opening connection definitions:

```sql
connmgr list -flat
```

After confirming `KCV_V2_001` has been retired and `KCV_V2_002` is the retained build, remove only the obsolete saved connection:

```sql
connmgr delete -conn KCV_V2_001_OWNER
connmgr list -flat
```

These commands were checked against local SQLcl 26.3 connection-manager help. Confirm `help connmgr` for a different client version. Keep `KCV_V2_002_OWNER` and the shared ADMIN alias. Avoid folder deletion or `-force`: they can remove other saved connections. Removing a saved connection removes its local saved settings/credential entry; it does not drop the database user, change the ADMIN password, revoke an OCI key or remove a wallet still used by another alias. A connection saved under Windows is separate from the Linux user's connection store.

## Validation scope

On 25 November 2026, a numbered build from dev commit `32e111f6340ab97beb0720dc867e7c2ab8ab46ae` completed fresh native installation and browser acceptance before five older project installations were retired. Private recovery material was verified before removal. All five retirements passed, the new build's 28 persistent-table count/hash digests and app identity matched before/after, and JAVAVM remained VALID. The final owner-local GenAI request passed. The data remained at 834 sources, 762 passages and three samples, with a READY native graph and 384-dimensional local search model.

This establishes the reviewed deployment/retirement procedure, not a reusable generic teardown script or a tested full archive restore. Raw vector values, transient provider history, full native graph hashes and complete APEX source were outside that 28-table digest comparison. Native initial/adoption/provider-expiry model checks and scoped browser navigation/publication/evidence/adoption/follow-up/search/reopening passed. This particular browser run did not repeat sign-out/sign-in, two-account isolation or permanent deletion. The [separate SQL-first clean/migration rehearsal](../db/verification/release-v2-paths-validation.json) records its own wider persistence checks. These are existing-database tests; provisioning and Java enablement were not repeated.
