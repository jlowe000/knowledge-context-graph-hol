# Contributor setup — dev branch

Use `dev` to change code, prepare public-source content, build the application and run tests. This document is not shipped on `release`. Learners use the separate release README and labs without installing Python.

## Requirements

- Oracle Linux/Bash and Python 3.11+ (default python3.12).
- Git and internet access to the pinned public PDFs and Python package index.
- For native testing: a separate approved ADB Serverless 26ai instance with Java/RDF, Select AI and compatible APEX; use the documented private credentials.
- APEX/SQLcl tooling is needed only when regenerating an engine-generated application export. Do not hand-edit the generated SQL export.

## Set up and check the original-source pipeline

1. Check out `dev`: `git switch dev`.
2. Run `bash scripts/bootstrap.sh`.
3. Run `bash scripts/build_artifacts.sh`. This verifies source hashes, extracts selected PDF text, builds RDF and runs checks.
4. Run `.venv/bin/python scripts/build_apex_worksheet.py` if testing the original-passage Worksheet installation.
5. Keep `work/`, `.venv/`, local configuration and credentials ignored. Original PDFs and extracted text never belong in a public commit.

The `kcv/` package implements preparation and optional direct-database automation. `scripts/` contains developer/build utilities. `tests/` and `integration-test/` contain checks; mocks may be installed only in the isolated test schema. Learner database operations remain SQL/PLSQL.

## Build the SQL-first release

Run `.venv/bin/python scripts/build_release.py --output work/release-package` from the project root. Use a new output directory each time; the tool refuses to delete or overwrite an existing directory.

The build uses the 17 existing attributed editorial paraphrases, not private files or original PDF text. It generates a separate graph, summary IDs/hashes, a ready-to-run dataset loader, an APEX Worksheet installer, learner-only documentation and a hashed file manifest. No PDF downloads or database connection are required for this release build. Release documentation overrides live under `release-docs/`; common labs are adapted in the packaging step.

Run `.venv/bin/python -m unittest discover -s tests -v`, `python scripts/sync_doc_snippets.py --check` and `python scripts/build_apex.py --check` before promotion. Inspect `work/release-package/README.md` and `release-manifest.json`. The release dataset requires its own native graph/model/browser acceptance; original-passage validation cannot be claimed for changed summaries.

See [branch workflow](branch-workflow.md) for promotion. Optional direct-driver setup (`scripts/setup_serverless.sh`) does not replace the learner SQL walkthrough.

For an explicitly requested reset of the dedicated disposable cloud lab, follow [dev reset and retest](dev-reset-and-retest.md). It verifies a project-free checkpoint and retains the one-way JAVAVM installation before rebuilding.
