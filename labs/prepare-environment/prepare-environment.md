# Prepare the Release Files

## Introduction

Get the supplied SQL and documentation onto the computer running your browser. This release is prebuilt: no Oracle Linux terminal, Python, wallet or local database software is required.

Estimated Lab Time: 5–10 minutes; planning estimate.

### Objectives

In this lab, you will:

- Confirm you downloaded the release branch.
- Locate the short GitHub dataset call and application installation SQL.
- Understand how to copy code into Worksheet.

### Prerequisites

A browser, a plain-text editor, the complete release download supplied by your facilitator or repository owner, and access to an approved OCI tenancy for the next lab.

## Task 1: Obtain the correct branch

1. On the repository page, select **release** in the branch selector before downloading/extracting the project. If your facilitator supplied a ZIP, confirm it is the SQL-first release.

2. Open README.md at the extracted project root. It should identify the release branch and state that no Python is needed. If it describes installing Python or building source artifacts, you have the dev branch.

**Expected outcome:** you have the complete release files locally. You do not need Git installed to use an extracted release ZIP.

## Task 2: Locate the SQL installers

1. Open the `sql/install/` directory. Confirm these supplied files exist:

   - [Schema-parts guide and manifest](../../sql/install/schema-parts/README.md), with separate fresh and upgrade files
   - [00_complete_v1_optional.sql](../../sql/install/00_complete_v1_optional.sql) for supported v1 completion
   - [00_adopt_schema_baseline.sql](../../sql/install/00_adopt_schema_baseline.sql) and [02_verify_schema.sql](../../sql/install/02_verify_schema.sql)
   - [20_upgrade_apex.sql](../../sql/install/20_upgrade_apex.sql) for an existing app
   - [10_load_github.sql](../../sql/install/10_load_github.sql)
   - [20_install_apex.sql](../../sql/install/20_install_apex.sql)

2. Open them in a plain-text editor to confirm you can read them. Do not execute them yet. Keep the files on the browser computer; a local file is not already uploaded to ADB.

3. Read the [dataset explanation](../../docs/release-dataset.md). The short dataset call downloads the public research catalogue, attributed editorial summaries, contexts and graph data directly from GitHub. Original research pages remain accessible through their source links; they are not downloaded during installation.

4. Follow [Choose a published version](../../docs/github-dataset-load.md#choose-a-published-version) to identify the full release commit SHA containing `data/load/manifest.json` and the matching caller. The manifest hash is supplied in the caller; you will replace only its commit placeholder. The selected dataset commit must already be public. A documented earlier commit may be used when its dataset bytes/hash are unchanged; local code packaging does not publish data.

**Expected outcome:** the short dataset call and application installer are ready for later tasks, and you can identify the published dataset commit. No local build or download of presentation text is required. If files are missing, obtain a complete release archive; do not substitute another learner's private working files. The larger `10_load_dataset.sql` and numbered SQL parts remain a fallback described in the GitHub load guide.

## Task 3: Understand copyable examples

1. Packaged GitHub SQL code blocks are ready to copy; LiveLabs authoring markers are removed during packaging. Copy SQL only, not Markdown fences or page HTML.

2. For long installers/parts, use the SQL Worksheet **Open File / upload SQL** control to load the selected local file into the editor. Confirm you loaded the complete intended file, then use its documented execution mode. Ordered schema parts use **Run Script (F5)**; the APEX installers use **Run Statement**, selecting the complete outer `DECLARE` through the final `END;`, excluding the final slash, for their target binds. Uploading a file into the editor does not execute it or make other local files available to the database. The actual Worksheet transport is part of candidate acceptance; if a file is rejected or truncated, stop and report it rather than splitting a PL/SQL block.

3. Short inline examples may be copied directly. Private-bind setup blocks use Run Statement as directed, excluding their slash. Never save entered passwords or signing keys into a file.

**Expected outcome:** you can find both supplied installers and copy commands without copying Markdown or page HTML. Choose [clean installation or migration](../../docs/installation-paths.md) before continuing; a clean path can use an approved existing database with an empty project schema.

## Learn More

- [SQL catalogue](../../docs/sql-catalogue.md)
- [Need help?](../need-help/need-help.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
