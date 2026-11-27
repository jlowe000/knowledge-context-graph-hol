# Need Help?

## Introduction

Find the failing step before repeating setup. Earlier successful tasks usually remain in place; resetting the schema or recreating the database can hide the original problem.

Estimated Lab Time: as needed.

### Objectives

In this lab, you will:

- Identify the account, location and failing operation.
- Apply the next appropriate check.
- Gather a useful, non-secret support request.

### Prerequisites

You have the name of the lab/task you were attempting and its exact displayed error or unexpected result.

## Task 1: Locate the problem

1. Check where you are: OCI Console, SQL Worksheet or the finished app. Confirm the account name; ADMIN, KCV_LAB, KCV_USER and your OCI login have different purposes.

2. Use the matching row below. Stop at the first failing task rather than running all remaining scripts.

   | What you see | What to check next |
   | --- | --- |
   | Console cannot create the database | Region, compartment, resource limits, permission and approved service offering with your OCI administrator |
   | Database Actions does not open | Correct database host and required network/VPN access; private endpoint access differs from a public endpoint |
   | Only Navigator is visible | Widen the browser or collapse Navigator to expose the editor |
   | Login rejected | Correct login screen and account/password; do not automatically reset another account |
   | No rows for JAVAVM | Java is not installed; follow the ADMIN enable/restart task |
   | JAVAVM LOADING | Installation is still running; wait and check again |
   | Table/view does not exist | USER result, preceding creation step and compile errors; KCV_SETTINGS is created before profile registration |
   | Object already exists | An earlier attempt created it; inspect progress instead of dropping everything |
   | Model call returns JSON/API error | Exact supported model name/region, profile attributes, credential owner and effective OCI inference permission |
   | Loader asks for substitutions | Cancel; obtain an unchanged release loader; do not enter guessed substitution values |
   | App import fails | Workspace exists, KCV_LAB parsing schema, compatible APEX version and complete generated installer |
   | KCV_USER cannot access App Builder | Expected: it is an app end user. Use the Worksheet deployment route or an administrator-provided developer account |
   | Popup says earlier response unavailable | Expected for a pre-feature answer; ask a new question after trace capture is installed |
   | Popup has no recorded evidence | Inspect recorded tool status; proposals/no-call runs are not proof of graph retrieval |
   | Model request appears slow | Wait/read its status; do not start duplicate inference calls merely to monitor it |
   | “Another answer or refinement is running” persists | Ask the schema administrator to inspect the specific run/lease; never clear all leases while a real request may still run |

**Expected outcome:** you have narrowed the issue to one prerequisite/task and a specific next check.

## v2 checkpoints

| Symptom | Check before retrying |
| --- | --- |
| Schema part fails or receipt differs | Keep the failed step/error; stop dependent setup. Do not clear receipts or rerun raw DDL. Use the selected clean/migration route. |
| App import rejects readiness or target | Verify the matching v2.1 contract and actual schema/workspace/alias. SQL-first also requires generated 03 binding; an upgrade retains the original app ID. |
| Workspace is unavailable after creation | Verify mapping and explicit enablement; an ADD_WORKSPACE call alone is insufficient. |
| Search shows Keyword only or Partial | Inspect local model setup/coverage, separately from chat profile/IAM. |
| A saved context is missing | Check the app account, application and status filter. Sharing an account is not separate-user isolation. |
| An answer is Incomplete | Read its explanation/status. Do not treat text alone as successful evidence-backed completion. |
| Deletion unfinished | Open the dedicated review and explicitly retry after diagnosis; ordinary access is fenced. |

## Task 2: Gather safe diagnostics

1. For a database problem, run these read-only checks as the intended database user:

   ```sql
   SELECT USER AS signed_in_as FROM dual;
   SELECT version_no AS apex_version FROM apex_release;
   SELECT name,type,line,text FROM user_errors ORDER BY name,sequence;
   ```

2. Record the lab/task, script filename, Run Statement versus Run Script, error code/line, expected outcome and what happened instead. For model errors, include the model name and region, but no credential or private key.

3. If adding a screenshot, show the relevant control/result and account role. Keep passwords, entered secret bind values, private keys, authentication tokens, personal account details and private connection URLs out of the image. Do not post live session URLs in a public issue.

**Expected outcome:** a facilitator or administrator can reproduce the failing step without receiving your secrets. See [authentication troubleshooting](../../docs/authentication.md#json-syntax-error-when-exercising-the-profile) and [deployment recovery](../../docs/deployment-recovery.md) where relevant.

## Task 3: Resume from the last successful checkpoint

1. After resolving the cause, rerun the failing check and confirm its expected outcome. Initial CREATE TABLE/network/team scripts should not all be rerun against existing objects.

2. Return to the [beginner route](../../docs/fresh-serverless-deployment.md) and continue with the next task. Record any undocumented correction for the workshop author.

**Expected outcome:** progress continues without losing earlier source data, context history or evidence records.

## Learn More

- [Validation scope and tested behaviour](../../docs/scenario-validation.md)
- [Temporary-resource cleanup](../../docs/cleanup.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
