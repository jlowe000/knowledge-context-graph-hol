# Bind setup to an imported application

This is the **2.1.0 dev candidate** path for an installer using SQLcl or an owner SQL Worksheet. Native acceptance is pending. The published 2.0.0 application does not require this step.

After the ordered schema installation and matching application import, run [03_bind_deployment_owner.sql](../sql/install/03_bind_deployment_owner.sql) as the authenticated project owner. An approved proxy connection whose database user is that owner is supported by the identity checks. ADMIN changing `CURRENT_SCHEMA` is rejected. Do not run the maintained template in `sql/schema`; it deliberately stops without the generated verifier.

Supply these two nonsecret binds:

| Bind | Value |
| --- | --- |
| `KCV_APPLICATION_ID` | The application ID returned by your import |
| `KCV_WORKSPACE` | The exact upper-case workspace mapped to the same owner |

In Worksheet, select the generated script from `DECLARE` through its final `END;`, excluding the final slash, and use **Run Statement**. In SQLcl, declare and assign the two binds before running the file. Keep this operation separate from a transaction containing other work.

The script verifies the complete schema contract and the native application/workspace mapping. It refuses active or unresolved answers, context publication, deletion or setup work. An unfinished operation must be completed or recovered through its supported path first.

Expected output is `KCV_DEPLOYMENT_BINDING=READY_FOR_SETUP`. Both setup and application maintenance are enabled in one transaction. A repeat against the exact same binding returns `KCV_DEPLOYMENT_BINDING=ALREADY_VERIFIED` and preserves the current maintenance state. A different application or workspace is rejected; this script does not reassign an existing installation.

Next, inspect readiness as the same owner:

```sql
SELECT KCV_DEPLOY.STATUS_JSON FROM dual;
```

Complete only the reported missing setup actions. The fixed owner API provides `ENSURE_NETWORK`, `CONFIGURE_PROFILE`, `REGISTER_RUNTIME`, `LOAD_DATASET`, `TEST_MODEL` and `ENABLE_LEARNING`; each mutation requires a new bounded request token for an explicit action. `CONFIGURE_PROFILE` selects an already prepared credential local to this owner; it never accepts a key or password. `LOAD_DATASET` loads the packaged public commit and manifest pin. `TEST_MODEL` makes a real model request and records whether the current profile succeeded. Existing resources are verified rather than reset.

After all required checks pass, explicitly call `ENABLE_LEARNING`. Existing SQL-first runtime setup alone does not record the new model-test receipt or clear the setup gate. Reusing a completed enable token cannot clear maintenance subsequently enabled by another action. Review a failed request in `STATUS_JSON` before retrying with a new token; do not automatically repeat model calls.

The [APEX-led setup guide](apex-led-deployment.md) describes the alternative workspace-administrator UI. An ordinary app-only learner cannot run setup. Learners can use the application after readiness has been verified and learning enabled; they need no database or OCI login.
