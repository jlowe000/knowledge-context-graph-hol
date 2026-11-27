# Recover an incomplete deployment

Use this for an unexpected prerequisite, import, setup or verification failure. The v2.1.0 prepared-environment route passes and earlier recovery tests do not establish every interruption mode. Preserve the target and error history.

## First response

1. Stop dependent steps. Record step name and safe error code; keep live endpoints, private model configuration, credentials and raw logs out of public reports.
2. Use **Refresh readiness** in setup, or this owner-Worksheet statement:

```sql
SELECT KCV_DEPLOY.STATUS_JSON FROM dual;
```

3. Have the facilitator check actual activity, exact receipts and physical postconditions before retrying. Browser timeout or a stale RUNNING row does not prove work stopped.
4. Select recovery matching the installed state/package. Do not edit receipt phases/hashes, reset accounts, drop graphs or run a clean installer over a partial schema.

| Observation | Next step |
| --- | --- |
| Supporting Objects or physical verification failed | Preserve the failed step; select matching ordered recovery with the maintainer |
| Work remains active or admission is busy | Wait and inspect; do not launch a second copy |
| Credential already exists | Retain it and review ownership/use privately; the app does not replace it |
| Credential creation may have succeeded before journal/cleanup failure | Inspect the name and receipt before retrying; never automatically drop/recreate it |
| Model authorization error | Check identity/key/fingerprint, IAM, region/model and compartment privately; do not rebuild schema |
| Public download/hash failure | Keep the active collection and failed receipt; correct the intended pin/access before an explicit retry |
| Six checks READY, learning paused | Choose Enable learning deliberately |
| Missing context after a bare context-overview sign-in | Open My Contexts and select the context; automatic redirect is not implemented |

A new action click or SQL request token means a new operation, including a potentially billable model test. Refreshing status and replaying an already completed token are different operations. Do not turn refresh into automatic inference retry.

## Worksheet application import or bind-prompt delay

During rehearsal, one client crash and delayed bind prompts were observed; their root cause was not established. This is not evidence of a bind-variable defect. The original Run Statement installers remain valid. A delayed prompt or failed browser action does not tell you whether the database import started or completed.

Before another submission, inspect the owner, exact target app, current activity and available installation/readiness status. In the owner's Worksheet, this query helps identify existing applications:

```sql
SELECT application_id, application_name, alias, pages
FROM apex_applications
WHERE owner=USER;
```

Check the expected app version and physical postconditions as well; an app row alone does not prove the whole step succeeded. Preserve the existing app ID. Never blindly repeat a fresh application's allocator or use it to overwrite an existing app. For an upgrade, retain the original target and confirm the first attempt has finished before deciding whether any matching retry is needed. Keep the original error and execution evidence.

If inspection establishes that an application submission needs retrying, the optional [clean F5 wrapper](../sql/install/20_install_apex_script.sql) or [upgrade F5 wrapper](../sql/install/20_upgrade_apex_script.sql) changes only the execution form. Edit its labelled non-secret target placeholders explicitly: `l_schema`, `l_workspace` and `l_alias`, plus the existing numeric `l_existing_app_id` for upgrade. Run the complete file with **F5**, including its final slash. The owner, alias and full-schema guards remain; SQLcl is not required. Follow the corresponding [clean](fresh-serverless-deployment.md#choose-the-application-execution-form) or [upgrade](migrate-to-v2.1.md#3-replace-the-same-app-and-establish-binding) instructions, and retain the separate owner-binding step.

Changing the application submission form is not a reason to repeat completed schema installation/upgrade, reload the dataset, recreate runtime registrations or replace credentials. Do not change a receipt or delete an existing app to make a different form run.

## Protect recoverability

DDL/native operations can commit independently. Browser Back, Sign Out and one ROLLBACK do not undo installation. Preserve app identity, graph data, revisions, history, evidence, credentials and accounts. Keep JAVAVM enabled.

Keep the old application definition and an appropriate restorable database recovery plan before upgrade. SQL/APEXlang app exports do not back up learner rows, graphs, credentials or accounts. [Cleanup](cleanup.md) follows a separate retirement decision; a newer successful test does not make existing data disposable.

Owner-assisted recovery is recorded separately from an uninterrupted App Builder success. Keep original failures and final verification. Broader DDL/mid-graph interruptions and platform audit/request-log protection remain outside the bounded earlier r13 results.
