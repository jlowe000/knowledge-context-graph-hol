# Prepare Your Working Environment

## Introduction

Prepare the files that will be copied into your new database. This lab runs in an Oracle Linux terminal and does not change any database.

Estimated Lab Time: 20–30 minutes, excluding software installation and download delays; planning estimate.

### Objectives

In this lab, you will:

- Locate the project root and a supported Python interpreter.
- Create an isolated Python environment.
- Generate dataset and application-installation SQL files.

### Prerequisites

You have the project files, an Oracle Linux terminal, internet access to the public sources/Python packages, and permission to install or use Python 3.11+.

## Task 1: Open the correct folder

1. Open your Oracle Linux terminal. Change to the folder where you extracted this standalone project. Replace the path below with the actual folder; do not paste it into SQL Worksheet.

   ```bash
   <copy>
   cd /path/to/knowledge-context-graph-hol
   pwd
   ls README.md scripts sql apex
   </copy>
   ```

2. Check that README.md and the three directories are listed. Do not use the whole upstream spatial-graph repository for this installation.

**Expected outcome:** your terminal is at this project's root. Every terminal command in this route assumes that working directory.

**Reading this in GitHub?** `<copy>` and `</copy>` are LiveLabs copy markers. Copy only the commands between them. The LiveLabs renderer uses them for its copy button; they are not shell or SQL commands.

## Task 2: Check Python and create the environment

1. Check the default interpreter:

   ```bash
   <copy>
   python3.12 --version
   </copy>
   ```

2. If it is missing, ask your Oracle Linux administrator to install a supported Python 3.11+ with pip/venv. If Python 3.11 is already installed instead, select it before running the remaining commands:

   ```bash
   <copy>
   export KCV_PYTHON=python3.11
   </copy>
   ```

3. Run the setup script:

   ```bash
   <copy>
   bash scripts/bootstrap.sh
   </copy>
   ```

**Expected outcome:** the terminal ends with `Environment ready. No database has been modified.` A `.venv` directory contains this project's Python packages. If it reports the wrong operating system or missing Python, fix that prerequisite before continuing. No SQL client, wallet or OCI CLI configuration is needed for this route.

## Task 3: Generate the files

1. Run:

   ```bash
   <copy>
   bash scripts/build_artifacts.sh
   .venv/bin/python scripts/build_apex_worksheet.py
   </copy>
   ```

2. Check that the outputs exist:

   ```bash
   <copy>
   ls generated/build-report.json
   ls work/worksheet/10_load_dataset.sql
   ls work/worksheet/20_install_apex.sql
   </copy>
   ```

3. Make both SQL files accessible on the computer running your browser. If your terminal is on a remote Linux machine, download them through your approved file-transfer client; a Linux path is not an upload into ADB. Ask your facilitator for help with that transfer if needed.

**Expected outcome:** `10_load_dataset.sql` contains your verified public passages and graph data. `20_install_apex.sql` installs the supplied app into the default KCV_KNOWLEDGE workspace/KCV_LAB schema later. Do not execute either yet. They contain no passwords and stay in ignored `work/` because the loader contains presentation text.

The shared loading lab defaults to the [public GitHub summary dataset](../../docs/github-dataset-load.md). Publish its candidate on dev and use the full dev commit SHA for native acceptance before promotion to release. Your generated dataset SQL is the local authoring alternative for testing extracted passages; it is not the content published for ordinary release learners. Choose the intended dataset before loading a fresh lab schema. The GitHub route requires a published commit containing `data/load/manifest.json` and its matching short caller.

If a source is unavailable or its edition hash differs, stop and report the source ID/error. Do not turn off hash checks or invent replacement content. A successful build is not a database test.

Continue to [Create the database](../provision-database/provision-database.md).

## Learn More

- [Source identity and artifact details](../02_sources_and_passages.md)
- [Need help?](../need-help/need-help.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
