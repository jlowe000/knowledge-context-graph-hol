# APEX-led upgrade from v2.0.0 to v2.1.0

**v2.1.0: this package's prepared-environment upgrade core path passed.** Same-app replacement/Supporting Objects upgrade, measured preservation, readiness and historical evidence reopening are recorded in its [artifact-specific result](../db/verification/release-v2.1-paths-validation.json). Start from the verified published v2.0.0 schema and existing app. For v1 use the [published v2.0.0 bridge](migrate-to-v2.md). Unknown or partial schemas need review.

## 1. Prepare the existing installation

Arrange a maintenance window and restorable recovery plan. Preserve owner, workspace, app ID/alias, learner accounts, credential/profile, public collection and private context/history graphs. Keep the old app export and package privately; an app export is not a full database backup.

Stop learner traffic and let work finish before replacing v2.0.0 code. New admission locks do not protect an already-running old request. Verify the published checkpoint and physical/program contracts. Add only missing required grants/prerequisites; do not create a replacement owner/workspace or reset accounts.

Confirm the installer can reach App Builder with the [APEXlang import prerequisites](apex-led-administrator-preparation.md). Privately record a preservation baseline and a saved answer whose Sources and Answer lineage can be reopened afterward.

## 2. Replace the same application

1. Import the matching `apex/kcv-explorer.apx.zip` in the existing workspace.
2. Select the **existing application ID**, alias and parsing schema. Verify the target and choose **Replace Application** once; do not auto-assign a new app.
3. After definition import, choose **Supporting Objects → Upgrade** once. It verifies the baseline, applies ordered additions, compiles/verifies and binds the backend.
4. Read the complete result. Definition replacement alone is not database upgrade completion.

A timeout does not establish that database work stopped. Use [recovery](deployment-recovery.md) before resubmission. Expected outcome: the same identities now use the v2.1.0 contract. No dataset reload, credential recreation or personal-revision republishing is part of this upgrade.

## 3. Review readiness and enable learners

Sign into the running app as the authorised workspace administrator; import may expire its earlier session. Follow [setup](deployment-setup.md), completing only missing checks. Keep ready credentials, profile, network, registrations and collection.

If Model connection test is PENDING, confirm the profile and use **Test model connection once**. If already READY, upgrading alone is no reason for another call. Do not click Save configuration or Load collection merely to repeat setup.

Six READY checks still require explicit **Enable learning**. Record that maintenance-state change separately from preserved data. No manual 03 binding is needed after a successful guarded Supporting Objects upgrade.

## 4. Verify preserved work

Sign in as the original learner and reopen the original context, conversation, answer, Sources and Answer lineage. Confirm its pinned revision/collection without asking a new question. Compare saved work and graph/evidence with the baseline. A new sign-in may add a session attachment; report the observed allowance rather than claiming every row is unchanged.

Check normal navigation and setup restrictions. An explicit optional-model keyword-fallback banner is valid; it does not require replacing chat credentials. Keep learners out if required checks fail. Record the exact package, preservation and limits in [v2.1 validation](../db/verification/release-v2.1-paths-validation.json).
