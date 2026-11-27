# Cleanup and temporary resources

Local files: `work/` contains source downloads, extracted text, runtime evidence, recovery material, build inputs and generated packages. Git exclusion does not make those files disposable. Follow the [dev build lifecycle](dev-build-lifecycle.md) and inventory exact paths before cleanup. Remove only reviewed obsolete outputs after confirming they are neither dependencies nor unique evidence. Do not delete `work/` wholesale.

Preserve the retained demo's artifacts and configuration requirements, current reviewed ZIP/native exports and canonical Supporting Objects inputs, verification receipts, verified backups, shared wallet, ADMIN/current-owner SQLcl connections, active local toolchain and research inputs. Do not copy private credentials or runtime material into Git. Remove obsolete saved owner aliases only after the corresponding database retirement is verified; a local alias deletion does not retire a schema.

For numbered `KCV_V<major>_<build>` installations, use the [exact-target retirement process](dev-build-lifecycle.md#retire-an-exact-build). Confirm which build is retained, capture recovery/preservation checks, and review every other schema/workspace/app before removal. The legacy `KCV_LAB` notes below are not a generic numbered-build teardown. These instructions do not assert that any current cleanup has completed.

The temporary ADB is a separately provisioned OCI resource. If it exists only for this exercise, review/export the evidence you need and terminate that exact instance through your normal OCI lifecycle process. Deletion/termination is not performed by any project script.

If preserving a shared database, have its administrator inspect and remove only the KCV_LAB-owned agent team/tasks/tools, AI profile/credential as appropriate, RDF network/graphs and schema. Verify ownership and dependencies first. The normal learner route has no automatic user deletion or RDF-network purge. Remove any lab-only IAM dynamic group/policy additions only after confirming that nothing else uses them.

On dev, the separate [explicit reset workflow](dev-reset-and-retest.md) supports an owner-requested teardown of the dedicated disposable KCV_LAB project. Its guarded ADMIN stage does drop that named user with CASCADE after supported runtime/graph/APEX cleanup. It is not an installer side effect or a generic shared-schema cleanup tool. JAVAVM remains enabled.

Oracle Java enablement is database-wide and Oracle documents that it cannot be disabled afterwards. Dropping lab objects does not reverse Java enablement. The optional local oaiw-adb instance and existing applications must remain intact.

The scenario extension adds KCV_O_… overlay graphs recorded in KCV_SCENARIO_REVISIONS, KCV_D_… proposed-relationship graphs in KCV_DOMAIN_RUNS, and optional KCV_W_… rule / KCV_I_… inference graphs printed by the bonus script. It also stores chat turns, staged changes, audits and observations in KCV_* scenario tables. Export anything needed before retiring this dedicated environment. Inspect exact graph ownership/names before removal, including any orphan left by a failed native DDL operation; do not purge by a broad prefix in a shared database.

Deleting the APEX application does not delete these database objects, model credentials or graph data. The isolated KCV_HOL_TEST schema/workspace/app used for component validation are separate from KCV_LAB and from existing research applications. They use service mocks and must never be promoted to the cloud lab as its backend.

The response explanation feature also stores KCV_RESPONSE_RUNS and KCV_RESPONSE_TOOL_CALLS. These contain learner questions, context snapshots, actual evidence payloads and response links. Retain/export records before retiring this dedicated lab. Private deployment backups in KCV_DEPLOY_BACKUPS are administrator artifacts and are not part of a response trace. No automated purge is installed.
