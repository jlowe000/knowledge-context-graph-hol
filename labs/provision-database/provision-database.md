# Create the Serverless Database

## Introduction

Create a dedicated lab database and learn to open SQL Worksheet. If an administrator provides the database, they perform Task 1 and give you its Console details and ADMIN access privately.

Estimated Lab Time: 20 minutes plus provisioning time; planning estimate.

### Objectives

In this lab, you will:

- Identify the database configuration for this workshop.
- Open Database Actions as ADMIN.
- Distinguish script execution from statement execution.

### Prerequisites

You have an OCI account authorized to create a lab database or an administrator performing provisioning, an approved budget, and browser/network access to the database's built-in tools.

## Task 1: Provision the instance

**Where:** OCI Console. **Account:** your OCI user or cloud administrator.

1. In the Console, find **Oracle AI Database → Autonomous AI Database**. Choose the intended region/compartment and select **Create Autonomous AI Database**. Oracle's [provisioning instructions](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-provision.html) show the current form.

2. Use these workshop choices. Console labels and available shapes can vary.

   | Field | Workshop choice |
   | --- | --- |
   | Display name / database name | Recognizable lab names, for example KCV Lab / KCVLAB |
   | Deployment | Serverless |
   | Database version | 26ai |
   | Workload | Transaction Processing for this documented route |
   | Compute/storage | Small lab allocation approved by your administrator; review the Console cost estimate |
   | License | License Included for this example; follow your administrator's direction for another arrangement |
   | Network | Approved configuration reachable from your browser; private endpoints require the corresponding network access |
   | ADMIN password | Enter/store privately |

3. Create the database and wait for **Available**. Record its name, region and compartment privately. A Free/Developer offering is not claimed as a tested substitute for every required feature; confirm Java/RDF, Select AI Agent and APEX support for your chosen offering.

**Expected outcome:** the database details page shows Available. Provisioning did not create KCV_LAB or the application; those are later tasks.

## Task 2: Open SQL Worksheet

**Where:** database details page, then browser. **Account:** ADMIN.

1. Open **Database actions → SQL**. If only a launchpad is offered, open it and choose the **SQL** card. Sign in as ADMIN with the password from Task 1 if prompted. See [Oracle's Database Actions access instructions](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/connect-database-actions.html).

2. Find the editor, Run controls and the result panels below it. Widen the browser or collapse Navigator if only the object list is visible.

3. Paste this statement into the editor and choose **Run Statement** (Ctrl+Enter; Command+Enter on macOS):

   ```sql
   <copy>
   SELECT USER AS signed_in_as FROM dual;
   </copy>
   ```

**Expected outcome:** Query Result shows ADMIN. Keep this private URL; another person's lab URL is not your database. If it cannot open, check your endpoint/network with the administrator rather than recreating the database.

## Task 3: Learn the two Run controls

1. Use **Run Script (F5)** for the complete linked `.sql` scripts in this workshop. Read **Script Output** for created/compiled messages and errors. A success message followed by an Oracle error is not a passed task.

2. Use **Run Statement** for a selected single SQL statement, or a bind-variable block from BEGIN/DECLARE through END; **without the final slash**. A bind such as `:KCV_LAB_PASSWORD` opens an input dialog. The slash is a script delimiter, not part of the value.

3. To run a long linked script reliably, open its local `.sql` file in a plain-text editor, copy the whole file, click the Worksheet editor, select all, paste, then use F5. Do not copy GitHub page HTML, Markdown fences or `<copy>` tags. Run one task's script at a time.

**Expected outcome:** you know where to see results, where an error appears, and why secret bind values use Run Statement. Continue to [Configure database and model access](../configure-database/configure-database.md).

## Learn More

- Setup reference (technical reference on the dev branch: `docs/setup.md`)
- [Screenshot capture checklist](../../docs/screenshots.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
