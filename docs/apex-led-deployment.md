# Install through APEX

**Unpublished dev candidate: both prepared-environment core paths passed with coverage limits.** R13 passed clean ZIP installation, guided credential/profile setup, real learner evidence and new-sign-in persistence, plus a populated published-v2 same-application upgrade and historical evidence reopening. Reviewer isolation and the recorded credential/concurrency/recovery checks also passed. See the [current acceptance review](apex-led-acceptance-review.md) for exact scopes and retained historical evidence. New-database provisioning and first Java enablement/restart were not rehearsed; platform audit/request-log protection remains unproven.

The ZIP is unpublished and release is unchanged. The published v2.0.0 [SQL-first paths](../release-docs/docs/installation-paths.md) remain available. Optional semantic search is unconfigured in the tested environment; the actual learner UI showed an explicit keyword-fallback banner. The [validation record](../db/verification/apex-led-candidate-validation.json) records the finite privacy scans, known limitations and final preservation comparisons; the [maintainer guide](apex-led-package-development.md) retains earlier failure/recovery history.

This guide is for the workspace administrator installing the candidate. Someone using an already prepared app needs only its privately shared URL and an individual app login, without App Builder or model credentials.

## Before you import

The installation journey starts in OCI when you do not yet have a suitable database. Follow [administrator preparation](apex-led-administrator-preparation.md#start-from-your-current-position) in this order:

| Phase | Who performs it | Expected outcome |
| --- | --- | --- |
| Create or select ADB in OCI | OCI administrator/facilitator | Supported database is Available and its tools can be opened |
| Prepare database capabilities, schema and grants | Database ADMIN | Java and required APIs are ready; the intended owner has quota and grants |
| Create and enable the APEX workspace | APEX administrator | Workspace maps to that owner and the installer reaches App Builder |
| Prepare private model access and ZIP prerequisites | Facilitator | OCI key/IAM access and browser import prerequisites are ready; choose an existing credential or the candidate creation form |
| Import the application ZIP and complete setup | Workspace installer | Supporting Objects, runtime configuration, public collection and readiness checks succeed |
| Start learning | Individual application user | Sample Contexts, My Contexts and supporting evidence work |

If a facilitator has already prepared the environment, confirm its handoff and start at ZIP import. If you are upgrading an existing installation, preserve its owner, workspace, app identity and data; do not create a replacement environment as part of that upgrade.

Have your facilitator complete [administrator preparation](apex-led-administrator-preparation.md). You need a prepared ADB Serverless database, an enabled workspace mapped to the intended schema, an authorised workspace administrator account and the supplied APEXlang application ZIP. Agree the model name, OCI region, compartment and credential route with the facilitator. Only the explicitly labelled **Private key body** field in **Create a local OCI signing credential** accepts a key; profile fields, chat and other app fields never do. Use the reviewed package and have the facilitator check its recorded form tests and the deployment's logging controls before private entry.

App Builder's APEXlang import requires **ORDS 26.1.1 or later** and **at least one REST-enabled schema in the workspace**. The facilitator verifies these prerequisites before you import. [Oracle's browser-import requirements](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/importing-export-files.html) apply in addition to this application's database capabilities.

Your **App Builder sign-in** may use ADB database single sign-on, while **the running application** uses a native Oracle APEX account. Confirm the two entry points with your facilitator. A working app account alone does not establish Builder access; do not reuse or reset passwords to guess which account a screen expects.

Choose the path deliberately:

| Your starting point | Path | Expected result |
| --- | --- | --- |
| New, empty project schema | Clean installation into a new application | A separate empty personal library and the supplied public collection |
| Supported existing v2 installation | Verified upgrade of the same application ID, workspace and schema | Existing accounts, collection, contexts and history retained |
| Published v1 or an unknown/customised schema | Stop and follow the supported SQL-first migration or maintainer review | No guessed baseline or destructive fresh install |

For an upgrade, arrange a maintenance window and verified recovery preparation before replacing the application. Keep existing users out until readiness passes. Importing an old application export alone cannot undo database changes. The installer must independently verify the schema and receipts; an APEX Supporting Objects status flag is not sufficient.

For the first v2.0.0 → 2.1.0 upgrade, stop learner traffic and allow active work to finish before starting. The new write-admission lock protects new code; it cannot retroactively coordinate an already running v2.0.0 request. An idle check is an additional safeguard, not a substitute for this maintenance window.

## 1. Import the supplied application ZIP

1. Sign in to the intended workspace's **App Builder** and choose **Import**.
2. Upload the supplied **APEXlang application ZIP intact** and select **Application, Page or Component Export**. You do not unzip it, edit its contents or paste SQL into a Worksheet.
3. Check the parsing schema, workspace and application identity. For a **clean install**, choose **Auto Assign New Application ID** unless your facilitator has explicitly reserved an ID for this workspace. Record the assigned ID after import. For an **upgrade**, retain the agreed existing application ID and alias. When Builder identifies the existing application, check that target and choose **Replace Application** once; do not allocate a new application.
4. Complete the application-definition import, then its separate **Supporting Objects** step: **Install** for the clean path or **Upgrade** for the supported existing installation. Supporting Objects installs or upgrades the backend, compiles its packages and verifies the expected schema. Review the prerequisite checks and results; stop at the first failed prerequisite or schema check. Replacing the application definition alone does not complete the database upgrade.

Oracle documents [APEXlang application exports as ZIP files](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/exporting-an-application.html). Use the reviewed application package with its matching Supporting Objects definitions and assets; a GitHub source-download ZIP or an archive containing SQL scripts is not an interchangeable installer. The actual supplied ZIP must pass the browser import rehearsal before this route is accepted.

An ID absent from `APEX_APPLICATIONS` is not proof that it is available: APEX can reserve it for another workspace. If an explicit clean-install ID is rejected as reserved, use automatic allocation or ask your facilitator to confirm an appropriate reservation. Do not overwrite another application or change its reservation to make the import proceed.

Expected outcome: the application definition and ordered backend installation are complete, with the intended owner, compilation and version verified. Continue to guided configuration and the pinned public dataset load below. A successful ZIP import alone is not a ready learning environment. If Supporting Objects were omitted or failed, return to the application's Supporting Objects area to review the reported step; do not run raw schema files over a partially installed target.

## 2. Open Deployment setup

Run the app and sign in with the authorised workspace administrator account. **Deployment setup** is restricted to that role. A developer-only account or learner account does not receive setup permissions.

Before the backend is installed, the app shows a neutral installation handoff. After completing Supporting Objects, sign out and sign in again to establish the account identity. Learners see no credential choices or configuration details while installation is incomplete.

The setup page shows required checks and recent setup actions. **Refresh readiness** reads these results; it does not test a model, create a network or load data. Each new setup action pauses learning until you explicitly choose **Enable learning**. Plan any change to an existing live installation accordingly.

## 3. Complete the required checks

The **Required checks** report has six rows: **Database objects**, **Graph network**, **Model profile**, **Model connection test**, **Conversation components** and **Public collection**. Supporting Objects prepares the database-objects check. Credential creation is an optional prerequisite action, not a seventh readiness check.

All six rows can show **READY** while the banner still says **Learning is paused**. This is expected: choose **Enable learning** explicitly, then expect **Ready for learners** and **Open My Contexts**. Until then, keep learners out of the app.

| Action | What to do | Expected result |
| --- | --- | --- |
| **Prepare graph network** | Create or verify the installation's owner-private RDF network | Graph network becomes READY; an existing matching network is retained |
| **Create local OCI credential** — optional | Use the credential form below only if your facilitator has not already prepared a suitable owner-local credential | Fixed name `OCI_USER_CRED` is created once; no model call is made and an existing credential is never replaced |
| **Save model configuration** | Select the existing or newly created credential and enter the approved region, compartment OCID and model **name** | Model profile becomes READY; no chat request is made by saving |
| **Test model connection once** | If Model connection test is not READY, explicitly send the fixed test greeting using the current profile | Model connection test becomes READY; the response is not added to learner conversations |
| **Prepare conversation components** | Register or verify the supplied components | Conversation components become READY without replacing existing conversations |
| **Load approved public collection** | Fetch the package's pinned GitHub dataset | Manifest/content checks, graph construction and guarded activation complete; Public collection becomes READY |
| **Enable learning** | Use this after every required check is READY | Learning is enabled and the app-only accounts can enter My Contexts and Sample Contexts |

If both **Model profile** and **Model connection test** are already READY, retain them; an upgrade alone is not a reason to save the configuration again or send another model test. If the profile is READY but the connection check is PENDING, resolve any reported error and use **Test model connection once**. Changing the profile, or creating its credential, requires an explicit connection test.

Selecting a credential uses its stored database value without copying it. The **Configure model access** fields accept only the credential name, region, compartment and model name; never put a key or password there.

### Optional: create the owner-local credential

The form appears between **Prepare graph network** and **Configure model access**. Its r12 rehearsal passed private creation, scoped privacy checks and the subsequent explicit model connection test. Keeping a facilitator-prepared credential remains an alternative; this form never replaces one.

1. Confirm your facilitator has approved the OCI identity and inference permissions. Its public API signing key must already be registered for that user; the matching private key must be unencrypted. The form does not create an OCI user, register a public key or grant IAM permissions. See [model-access prerequisites](apex-led-administrator-preparation.md#prepare-private-model-access).
2. In **Create a local OCI signing credential**, enter the **OCI user OCID**, **OCI tenancy OCID**, **API key fingerprint** and matching **Private key body** privately. Paste only the base64 body, without PEM BEGIN/END markers or the `OCI_API_KEY` label. The submitted key field is limited to **4,000 bytes**, including whitespace; do not truncate a larger key to fit.
3. Choose **Create local OCI credential** once. The intended result is `OCI_USER_CRED` in this application's parsing schema. All four inputs are masked and designed to clear after submission or navigation. An existing credential is retained; replacement or repair belongs to the facilitator's separate private process.
4. Select `OCI_USER_CRED` under **Configure model access**, save the approved profile and choose **Test model connection once**. Creation alone does not verify the key, IAM permissions or model access, and leaves learning paused.

Keep the values out of URLs, screenshots, chat and copied diagnostics. Request-only fields are intended to avoid persistent APEX session state; this is not a guarantee about every platform's audit or request logging. The facilitator must review the deployment's logging controls and the recorded canary checks before real-key use.

An upgrade can keep its existing ready public collection. Loading data is a separate choice; it must not replace the active collection on a failed import or silently republish personal revisions. Public data comes from the package's approved full GitHub commit and manifest hash, not a branch head. The app export does not include private context data or downloaded research PDFs.

The optional local embedding model is separate from the conversational profile. Without it, My Contexts uses keyword search. Its owner-only [setup and verification](context-search.md) remains a facilitator task; a model-presence notice alone does not certify semantic-search quality. Native VECTOR support is still required by the schema.

## 4. If a step fails or is interrupted

Use **Refresh readiness** to inspect the step, recorded phase, error code and next action without rerunning it. Replaying the same recorded successful request is different from pressing an action button again: a new click of **Test model connection once** explicitly requests another model test. Opening or refreshing the page does not retry a failed test.

If another action is running, wait before retrying. Do not clear deployment receipts, change checksums, delete graphs or disable ownership checks to force progress. Give your facilitator only the safe error code and step name. Keep populated configuration, credentials, live URLs and private audit details out of screenshots or public reports.

A partially completed installation requires a facilitator to inspect its receipts and select a recovery that matches the exact installed state. The current candidate recognises one specific failed index-verification step. Its reviewed replacement ZIP was imported on the **same existing application**, followed by **Supporting Objects → Upgrade**. That request timed out and left a different step recorded as running. Investigation, matching per-step owner recovery and final verification subsequently passed. This is not a general way to treat an unknown partial schema as a supported v2 baseline.

After that recovery and the canonical r3 upgrade, the reviewed candidate-r7 ZIP was imported into the same application and its Supporting Objects Upgrade completed successfully. It retained the application identity and all 116 historical receipt rows, including the original failure. The only reported state difference was the installer's update timestamp. This verified operation does not make an unknown partial schema a supported baseline. Select recovery from the verified current state; do not clear receipts or rerun raw DDL. The later r9 fresh installation and scoped runtime checks passed separately, as recorded above. The later r12 credential flow and published-v2 structural upgrade passed within their recorded scopes; r13 also passed the scoped upgraded learner flow. Remaining gates are listed in the [acceptance review](apex-led-acceptance-review.md).

Expected outcome: either the step completes with verified postconditions, or the application remains safely paused with a specific recovery action. DDL and native graph operations can commit independently; browser Back, Cancel or Sign Out is not a rollback.

If the browser reports a gateway timeout, do not assume that database work stopped or restart the request. The facilitator must check active work, exact migration receipts and physical postconditions. A stale `RUNNING` receipt can be reconciled only with its matching recovery script after those checks pass, using the intended schema-owner session. Preserve failure history. An owner-assisted recovery is recorded separately from a successful end-to-end App Builder installation.

## 5. Hand the app to learners

Use an individual app-only account for each learner. Share the application URL privately and direct them to My Contexts or the [evidence walkthrough](ui-walkthrough.md). A shared login shares the same personal library; an account with the same name in another workspace is a different identity.

Before handoff, verify a real answer and its sources, save/refine a personal context, and confirm saved work reopens after a new sign-in. The installer should also verify a learner cannot invoke setup. These are acceptance tasks, not results established merely by following this draft guide.

This route does not provision ADB, grant database privileges, enable JAVAVM or create learner accounts automatically. It does not add the separate future learning-loop or Explorer-evaluation epics.


If signing in returns a missing-context error on a bare context-overview page, open **My Contexts** and select the saved context. This known navigation limitation has a working route; its automatic redirect is not implemented yet.
