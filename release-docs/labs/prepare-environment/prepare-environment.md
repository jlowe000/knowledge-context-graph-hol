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

   - [10_load_github.sql](../../sql/install/10_load_github.sql)
   - [20_install_apex.sql](../../sql/install/20_install_apex.sql)

2. Open them in a plain-text editor to confirm you can read them. Do not execute them yet. Keep the files on the browser computer; a local file is not already uploaded to ADB.

3. Read the [dataset explanation](../../docs/release-dataset.md). The short dataset call downloads the public research catalogue, attributed editorial summaries, contexts and graph data directly from GitHub. Original research pages remain accessible through their source links; they are not downloaded during installation.

4. Follow [Choose a published version](../../docs/github-dataset-load.md#choose-a-published-version) to identify the full release commit SHA containing `data/load/manifest.json` and the matching caller. The manifest hash is supplied in the caller; you will replace only its commit placeholder. If the package exists only locally and is not yet on GitHub, it must be published before the database can fetch it.

**Expected outcome:** the short dataset call and application installer are ready for later tasks, and you can identify the published dataset commit. No local build or download of presentation text is required. If files are missing, obtain a complete release archive; do not substitute another learner's private working files. The larger `10_load_dataset.sql` and numbered SQL parts remain a fallback described in the GitHub load guide.

## Task 3: Understand copyable examples

1. This workshop uses LiveLabs code blocks with `<copy>` and `</copy>` markers. In a plain repository view, copy only the content between those markers. The markers themselves are not SQL commands.

2. For long linked SQL files, open the local file in a plain-text editor and copy the complete contents. Later labs explain when to use Run Script versus Run Statement. Never save entered passwords or API signing keys into a file.

**Expected outcome:** you can find both supplied installers and copy commands without copying Markdown or page HTML. Continue to [Create the database](../provision-database/provision-database.md).

## Learn More

- [SQL catalogue](../../docs/sql-catalogue.md)
- [Need help?](../need-help/need-help.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
