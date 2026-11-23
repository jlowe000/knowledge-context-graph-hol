# Development environment — dev branch

Use dev when building your own adaptation of the collection or contributing implementation changes. Start with [Build your own version](build-your-own.md) for the learning journey, then use this page for its environment and build commands. Release has separate experiences for end users and developers learning the supplied collection; neither requires this authoring setup. This page is not shipped on release.

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

The build uses attributed editorial summaries from the original presentations and the admitted expanded research, not private files or original PDF text. It generates a separate graph, summary IDs/hashes, a GitHub JSON load package and short caller, fallback SQL, an APEX Worksheet installer, learner documentation and a hashed file manifest. The package manifest records its exact counts. No PDF downloads or database connection are required for this release build. Release documentation overrides live under `release-docs/`; common labs are adapted in the packaging step.

Run `.venv/bin/python -m unittest discover -s tests -v`, `python scripts/sync_doc_snippets.py --check` and `python scripts/build_apex.py --check` before promotion. Inspect `work/release-package/README.md` and `release-manifest.json`. The release dataset requires its own native graph/model/browser acceptance; original-passage validation cannot be claimed for changed summaries.

See [branch workflow](branch-workflow.md) for promotion. Optional direct-driver setup (`scripts/setup_serverless.sh`) does not replace the learner SQL walkthrough.

## Publish and test the GitHub dataset on dev

The dev branch includes the public summary package used to test the actual download path before release. Generate it from the project root in Oracle Linux:

```bash
.venv/bin/python scripts/build_github_dataset.py --output data/load --loader sql/install/10_load_github.sql
```

On a Windows development host, use `.venv/Scripts/python.exe` for the same command. The helper builds attributed summaries; it does not publish the raw extracted passages in `work/`. Review `data/load/manifest.json`, its JSON parts and the caller together. Their counts describe the summary package, while the normal dev `generated/build-report.json` can describe a larger extracted-passage authoring build.

After local validation and publication review, commit and push **dev**. Copy that full 40-character dev commit SHA into the generated caller and run it through the [GitHub load guide](github-dataset-load.md) on the approved temporary ADB Serverless instance. The caller's manifest hash is already filled in. Keep release unchanged while proving this candidate.

Native acceptance includes installing/compiling the importer, loading the pinned data, running `integration-test/verify_worksheet.sql`, `verify_scenario_native.sql`, `verify_source_packet_scope.sql` and `verify_github_dataset.sql`, then checking the relevant real model and signed-in application/evidence flows. Record outcomes against the tested commit and manifest hash; do not convert pending checks into passes based on local packaging tests. If a change is needed, publish a new dev commit and repeat the affected checks before promotion.

The GitHub path and expanded summaries passed [native SQL acceptance](../references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`, including the four scripts above and two-session lock exclusion. Model inference, APEX browser acceptance for this dataset and interrupted-load behaviour remain untested in that run. Keep these limits separate from the native passes when reviewing promotion; see [branch workflow](branch-workflow.md#maintainer-promotion).

For an explicitly requested reset of the dedicated disposable cloud lab, follow [dev reset and retest](dev-reset-and-retest.md). It verifies a project-free checkpoint and retains the one-way JAVAVM installation before rebuilding.

## Refresh the public research catalogue

The supplied catalogue is self-contained; the original research implementation is not a runtime or learner dependency. Maintainers with a research report can run:

```bash
.venv/bin/python scripts/import_public_research.py --report /path/to/download-report-data.json --audit-dir /path/outside-repo/public-access-audit
.venv/bin/python -m kcv.cli build
```

The importer uses records/references and the [public-source policy](../references/public-source-policy.json). The policy records the approved Oracle GitHub API, Helidon raw/repository and AI World session URL scopes. Matching references are classified **manually marked as public**, overriding earlier classification holds within those scopes. Forbidden destinations remain excluded, including redirect targets. Actual anonymous GET results are retained independently; manual classification does not manufacture an HTTP success or a content inspection.

Catalogue intake records bibliographic metadata and controlled facets. The separate [content pipeline](content-pipeline.md) now retrieves and chunks readable admitted content into ignored local files, then packages attributed editorial paraphrases for release. Authentication is never used. A matching reference whose body cannot be retrieved remains catalogue-only with its actual access result and, where applicable, a catalogue-metadata hash. No passage is inferred from a successful landing-page check alone.

The audit directory must be outside this repository. Its `public-release-conflicts.json` retains `conflicts`, `manually_marked_public` and `to_be_reviewed` arrays; unresolved records outside approved rules stay in the review array. Do not copy this private review artifact into either branch. `--resume` reuses successful checks; `--reuse-results` rebuilds metadata from saved outcomes without claiming a new verification date. Stable IDs are retained, changed hashes increment versions, and retired IDs are reserved. The public rules classify references; they do not transfer source copyright or licences.

After source review, rebuild the original passages if the curated PDF set changed, run tests, then build a new release directory. No new source body is silently converted into model evidence. See [catalogue learning steps](public-research-catalog.md).

Public classification also applies the catalogue-title condition for YouTube. Industry and third-party items outside approved scopes remain in the private `to_be_reviewed` array and are excluded from the generated graph/loader. The [catalogue guide](public-research-catalog.md#publisher-and-video-review-scope) describes the rule precedence and scope.
