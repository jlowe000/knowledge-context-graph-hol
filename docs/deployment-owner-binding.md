# Bind setup to an imported application

This is the **2.1.0** path for an installer using SQLcl or an owner SQL Worksheet. The [four-route record](../db/verification/release-v2.1-paths-validation.json) records successful binding in both curated SQL-first routes. Clean schema/app installation and binding used Worksheet, while its successful model test and enablement used genuine-owner SQLcl; the SQL-first upgrade completed its retained-model test and enablement in Worksheet. This is not a separate direct DEV-led Liquibase/native-import acceptance claim. The published 2.0.0 application does not require this step.

After the ordered schema installation and matching application import, run [03_bind_deployment_owner.sql](../sql/install/03_bind_deployment_owner.sql) as the authenticated project owner. An approved proxy connection whose database user is that owner is supported by the identity checks. ADMIN changing `CURRENT_SCHEMA` is rejected. Do not run the maintained template in `sql/schema`; it deliberately stops without the generated verifier.

Supply these two nonsecret binds:

| Bind | Value |
| --- | --- |
| `KCV_APPLICATION_ID` | The application ID returned by your import |
| `KCV_WORKSPACE` | The exact upper-case workspace mapped to the same owner |

In Worksheet, select the generated script from `DECLARE` through its final `END;`, excluding the final slash, and use **Run Statement**. In SQLcl, declare and assign the two binds before running the file. Keep this operation separate from a transaction containing other work.

The script verifies the complete schema contract and the native application/workspace mapping. It refuses active or unresolved answers, context publication, deletion or setup work. An unfinished operation must be completed or recovered through its supported path first.

Expected output is `KCV_DEPLOYMENT_BINDING=READY_FOR_SETUP`. Both setup and application maintenance are enabled in one transaction. A repeat against the exact same binding returns `KCV_DEPLOYMENT_BINDING=ALREADY_VERIFIED` and preserves the current maintenance state. A different application or workspace is rejected; this script does not reassign an existing installation.

## Continue in the installed app

After binding, open the runtime app and sign in using a **native APEX workspace-administrator** account such as KCV_INSTALLER. Use [account preparation](../release-docs/docs/apex-led-administrator-preparation.md#3-create-the-workspace-and-accounts) if it does not exist; do not grant setup rights to the app-only learner. The runtime APEX password is separate from the database/SQLcl connection.

Follow [Deployment setup](../release-docs/docs/deployment-setup.md#apex-guided-setup) for the owner-private network, credential creation/selection, model configuration/test, conversation registration, public collection and explicit learner enablement. Import and binding require no pre-created model profile. The app configures/registers KCV_GENAI; do not run manual profile scripts as duplicate work.

For an existing installation, retain correct resources and complete only missing readiness. All six checks READY still requires **Enable learning**. Reusing a completed enable token cannot clear maintenance subsequently enabled by another action. Review failures before retrying; never automatically repeat model calls.

## Optional owner diagnostics or headless setup

The shared owner API remains available for deliberately chosen non-UI work. Inspect status without making a model call:

```sql
SELECT KCV_DEPLOY.STATUS_JSON FROM dual;
```

The bounded API provides ENSURE_NETWORK, CONFIGURE_PROFILE, REGISTER_RUNTIME, LOAD_DATASET, TEST_MODEL and ENABLE_LEARNING. Each mutation requires a new request token for an explicit action. See [owner readiness examples](../release-docs/docs/deployment-setup.md#sql-first-final-readiness). These are alternatives to completed app actions, not mandatory follow-up calls. Keep private key entry in its approved private interface and never put credential values into a saved script or tool call.
