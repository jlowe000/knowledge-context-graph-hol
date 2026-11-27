# APEX-led clean installation

**v2.1.0: this package's prepared-environment clean core path passed.** Actual App Builder/Supporting Objects installation, guided setup, a learner answer and saved-evidence reopening passed within the recorded scope. Public administrator preparation and first Java enablement/restart were not established by this rehearsal. See [validation](scenario-validation.md). Use this path for an empty project schema and new app. An existing published v2.0.0 app uses [APEX-led upgrade](apex-led-upgrade.md).

## Before opening App Builder

The facilitator completes [administrator preparation](apex-led-administrator-preparation.md): ADB capabilities, Java, owner grants/quota, mapped workspace, installer/learner accounts, OCI model access and import prerequisites. The ZIP cannot provision OCI or grant itself database privileges.

Have the reviewed `apex/kcv-explorer.apx.zip` and package manifest. Keep it intact; a GitHub source archive or SQL bundle is not this installer. No Python, SQLcl, wallet or local Java is required by the workspace installer.

## 1. Import the new application

1. Enter the intended workspace's **App Builder**. Confirm the parsing schema is the new empty project owner.
2. Choose **Import**, select `apex/kcv-explorer.apx.zip` and choose **Application, Page or Component Export**. Do not unzip/edit it.
3. Choose **Auto Assign New Application ID**, unless an administrator reserved an unused ID for this workspace. Record the assigned ID/alias privately.
4. Complete the app-definition import, then the separate **Supporting Objects** step. Choose **Install** once.
5. Wait for its result and inspect prerequisite/schema checks. Supporting Objects creates the ordered backend, compiles/verifies it and binds it to this app/workspace.

Expected outcome: app and backend installation succeed for the intended owner. No credential, personal graph or learner answer is restored from the ZIP. App-definition import alone is insufficient.

Do not also run the SQL-first fresh installer. On failure/timeout, use [recovery](deployment-recovery.md) before another submission; do not delete objects or receipts to make a partial target appear clean.

## 2. Complete setup

Run the app and sign in with its authorised **workspace-administrator account**. This native APEX account may differ from the database login used to reach Builder. A learner account cannot invoke Deployment setup.

Follow [guided setup](deployment-setup.md#apex-guided-setup): network, owner-local credential, profile/test, conversation components and pinned public collection. Credential creation is optional when the facilitator already prepared it.

Expected outcome: six READY checks, then explicit **Enable learning**, then **Ready for learners**. Refresh readiness does not call a model or automatically retry failed work.

## 3. Verify the learner handoff

Sign out of the installer account. With an individual app-only account:

1. Open Sample Contexts and copy one into My Contexts. Check fictional identity fields are cleared; enter a non-sensitive learning purpose.
2. Save, review and apply it. Ask one bounded question and inspect Sources and Answer lineage for evidence/limits.
3. Sign out/in and reopen the same context, conversation and answer without asking again.
4. Verify a separate learner cannot see this library or enter setup; record any checks not performed.

These are package acceptance steps, not automatic results of import. Record actual outcomes in [v2.1 validation](../db/verification/release-v2.1-paths-validation.json). Share the app URL privately; learners need no OCI, database or Builder login. Continue with [My Contexts](../labs/my-contexts/my-contexts.md).
