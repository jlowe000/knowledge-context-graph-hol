# Reset the dedicated temporary lab and retest — dev only

This is an explicit destructive development workflow, not a normal installation or upgrade. Use it only when the owner has requested deletion of this project's disposable database artifacts. It deletes conversations, observations and private deployment backups together with the schema. Inspect the inventory first; stop if this workspace/schema has been reused for unrelated work.

The goal is a **project-free checkpoint**, followed by a new installation from dev. This does not factory-reset the managed service or remove unrelated schemas, service audit/history, Oracle-managed objects or other applications. JAVAVM remains enabled and VALID: Oracle Java enablement is one way. No Java removal, database termination, external API-key revocation or IAM policy change is part of these scripts.

## Inventory and teardown

Run each complete file separately in ADMIN Database Actions SQL Worksheet with F5. Read the final output before proceeding. The reset utilities are under `scripts/sql/` so they stay on dev and are excluded from the SQL-first release package.

1. [90_inventory.sql](../scripts/sql/90_inventory.sql): inspect the project owner, workspace, application, sessions and Java. Confirm KCV_LAB and KCV_KNOWLEDGE are dedicated to this lab. Resolve any running jobs/users first. Check for unexpected project objects outside KCV_LAB before proceeding.
2. [91_teardown_runtime.sql](../scripts/sql/91_teardown_runtime.sql): installs and invokes a temporary definer-rights helper in KCV_LAB. Removes the two known lab teams, their agents/tasks/tools, lab-owner conversations, KCV_GENAI, the stored OCI_USER_CRED and the schema-private KCV_NET network/graphs. It refuses running jobs or an unexpected non-Oracle team. It uses supported APIs rather than directly deleting service metadata.
3. Continue **only** after its final PASS. [92_teardown_admin.sql](../scripts/sql/92_teardown_admin.sql) checks the runtime completion marker and workspace ownership, removes the project app and workspace/accounts, removes REST metadata and drops the dedicated KCV_LAB schema. This also removes tables, audit/trace data, backups, the temporary helper and residual owner objects. It does not drop a tablespace.
4. [93_verify_clean.sql](../scripts/sql/93_verify_clean.sql): asserts the owner, project objects, workspace, application and model profile are absent, while JAVAVM is still VALID. Retain the PASS as a checkpoint before rebuilding.

These are scoped reset scripts, not generic cleanup tools. Do not run them in a shared or unrelated schema. They intentionally stop on unexpected errors. Their `force` arguments handle absent named AI objects, not arbitrary exceptions. Do not suppress a failure and continue with later files. A partially completed reset requires inspection of the failed stage, not broad deletion of Oracle metadata.

## Rebuild and test

1. On dev, regenerate and verify the original public-source artifacts using [contributor setup](development.md). The dev dataset contains extracted passages; release's editorial summaries are a separate distribution and need their own acceptance run.
2. In ADMIN, recheck Java readiness and **skip enablement when VALID**. Recreate KCV_LAB through its private bind dialog, apply the documented grants and enable Database Actions. The user enters/submits the new password privately.
3. Sign into KCV_LAB, install base objects/network/tools, then recreate the OCI credential through private bind input. A stored signing key was deleted by teardown; it is never exported for automatic reuse. Use the existing external user API key only if still appropriate. Keep model/profile environment settings local and ignored.
4. Create/register/test the profile, load the regenerated dataset, and run both native verification scripts. Install scenario objects, provenance, API, explorer agent registration and APEX API in documented dependency order.
5. As ADMIN recreate the APEX workspace and app end user with private password input. As KCV_LAB install the regenerated Worksheet APEX installer, recording the newly allocated app ID.
6. Test real model answers, sources/lineage, topic refinement, historical persistence after reload, an observation and Casey's two scope pages. Record actual outputs and failures in validation. Do not count mocked/component results as cloud passes.

The full installation order and expected results remain in the [beginner walkthrough](fresh-serverless-deployment.md). A successful rebuild in an existing Java-enabled instance is not evidence that provisioning and first-time Java enablement were repeated.

After native scenario verification, [verify_rebuild_model.sql](../integration-test/verify_rebuild_model.sql) provides an additional development acceptance check. It makes **two billable real model calls**, creates its own fictional Alex session, checks recorded tool evidence and explicit citation matches, removes a topic, checks S06-to-S08 evidence selection, compares the unchanged historical trace and saves the observed technical test outcome. It must run as KCV_LAB on real Serverless, never through local service mocks. Inspect the actual answer wording separately: matching citations is traceability, not factual correctness or measured business value.
