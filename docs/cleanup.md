# Cleanup and temporary resources

For an app user, Archive/Unarchive manages the library reversibly; Delete Context has a separate explicit permanent review and resumable cleanup. It removes the selected context's application records, private resources and derived search chunks, retaining minimal cleanup receipts. It does not remove public knowledge, independent copies or platform audit/backups. A schema/app migration is not cleanup and must preserve existing work.

The environment-retirement notes below are administrator tasks, outside normal installation and migration.

Local files: this release contains public metadata and attributed editorial summaries. Retain/export any personal lab observations you need before removing your local download. No original PDF downloads or Python environment are required for this branch.

The temporary ADB is a separately provisioned OCI resource. If it exists only for this exercise, review/export the evidence you need and terminate that exact instance through your normal OCI lifecycle process. Deletion/termination is not performed by any project script.

If preserving a shared database, have its administrator inspect and remove only the chosen project owner's agent team/tasks/tools, AI profile/credential as appropriate, RDF network/graphs and schema. KCV_LAB is only the default example; confirm the actual owner selected during setup. Verify ownership and dependencies first. The project intentionally has no blanket DROP USER CASCADE or automatic RDF-network purge. Remove any lab-only IAM dynamic group/policy additions only after confirming that nothing else uses them.

Oracle Java enablement is database-wide and Oracle documents that it cannot be disabled afterwards. Dropping lab objects does not reverse Java enablement. Keep all unrelated databases and applications intact.

The scenario extension adds KCV_O_… overlay graphs recorded in KCV_SCENARIO_REVISIONS, KCV_D_… proposed-relationship graphs in KCV_DOMAIN_RUNS, and optional KCV_W_… rule / KCV_I_… inference graphs printed by the bonus script. It also stores chat turns, staged changes, audits and observations in KCV_* scenario tables. Export anything needed before retiring this dedicated environment. Inspect exact graph ownership/names before removal, including any orphan left by a failed native DDL operation; do not purge by a broad prefix in a shared database.

Deleting the APEX application does not delete these database objects, model credentials or graph data. The isolated KCV_HOL_TEST schema/workspace/app used for component validation are separate from the project owner and from existing research applications. They use service mocks and must never be promoted to the cloud lab as its backend.

The response explanation feature also stores KCV_RESPONSE_RUNS and KCV_RESPONSE_TOOL_CALLS. These contain learner questions, context snapshots, actual evidence payloads and response links. Retain/export records before retiring this dedicated lab. Private deployment backups in KCV_DEPLOY_BACKUPS are administrator artifacts and are not part of a response trace. No automated purge is installed.
