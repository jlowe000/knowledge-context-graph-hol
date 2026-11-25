# Development environment — dev branch

Use dev when building your own adaptation of the collection or contributing implementation changes. Start with [Build your own version](build-your-own.md) for the learning journey, then use this page for its environment and build commands. Release has separate experiences for end users and developers learning the supplied collection; neither requires this authoring setup. This page is not shipped on release.

## v2.0.0 work in progress

Current R7 adds local hybrid search over owned saved contexts and objective previews. Its [native upgrade/repeat, search regressions and scoped browser checks passed](../db/verification/context-search-validation.json). Use the R7 migration checkpoint before importing the nine-page app and follow the separate [model setup](context-search.md). The [R5 deletion record](../db/verification/context-delete-validation.json) retains successful native tests and browser review/Cancel, with permanent-delete browser confirmation still pending.

The `v1.0.0` tag retains the original baseline. Current numbered-build [fresh deployment and retirement](dev-build-lifecycle.md#validation-scope) passed with native model/browser checks and protected-data comparisons. The separate [SQL-first clean and migration rehearsals](../db/verification/release-v2-paths-validation.json) also passed within their recorded scope. Earlier [fresh](../db/verification/fresh-dev-validation.json) and [R4](../db/verification/c3-r4-validation.json) records remain historical evidence. The learning loop and Explorer evaluation remain separate future epics.

Use the [implementation plan](my-contexts-implementation-plan.md), [context API contract](my-contexts-api.md), [migration workflow](database-migrations.md) and [APEXlang authoring guide](apexlang-development.md) for the new development route. The [private SQLcl connection guide](dev-connection-setup.md) prepares isolated native tests without sharing credentials. SQLcl/Liquibase manages new database development; native pages are maintained directly in `.apx` files. Existing Python utilities continue to prepare content and generate/check artifacts.

For a separate fresh deployment, use [Fresh v2 dev deployment](fresh-dev-deployment.md). Name the owner and workspace `KCV_V<major>_<build>`, such as `KCV_V2_001`, and use a build-specific owner connection. The [build lifecycle](dev-build-lifecycle.md) covers in-place upgrades, independent replacement builds, private recovery material, exact-target retirement and local cleanup. `KCV_USER` is scoped to its APEX workspace; reusing the username does not transfer personal contexts to another build.

The v2 release builder and app installer require a matching native engine import/export receipt and reject missing or stale source/export hashes. The current [receipt](../apex/export-validation.json) identifies the tested R7 source; offline compiler and local unit-test results alone cannot supply it. Deployment acceptance and release promotion are separate decisions. Updating dev deployment documentation leaves release unchanged.

After installing the development app through the [v2 deployment sequence](../apex/README.md#deploy-the-v2-dev-candidate), use the [personal journey walkthrough](my-contexts-draft-walkthrough.md) and [manual candidate review](my-contexts-manual-test.md) to exercise drafts, activation, saved conversations, refinement and evidence. Use migrations for the schema; the older raw-schema beginner and upgrade guides apply to a published v1 checkout.

The [C3 validation record](../references/my-contexts-c3-validation.json) separates current native, model and browser evidence from outstanding checks. The earlier [C2 validation record](../references/my-contexts-c2-validation.json) remains the historical record for the draft library, including account recreation and draft reopening; it does not certify the later personal journey.

## Requirements

- Oracle Linux/Bash and Python 3.11+ (default python3.12).
- Git and internet access to the pinned public PDFs and Python package index.
- For native testing: a separate approved ADB Serverless 26ai instance with Java/RDF, Select AI and compatible APEX; use the documented private credentials.
- For v2 schema/UI development: local Java and SQLcl/Liquibase with APEXlang tooling. The [Bash launcher](dev-connection-setup.md) reuses compatible installations or downloads missing Java/SQLcl; no container is required. Earlier native acceptance used SQLcl 26.2.1.209.2118 with Java 21.0.12.1 on Oracle Linux 8.10. Verify the actual tool versions and target APEX compatibility before import. Do not hand-edit the generated SQL export.

## Script conventions

All shell launchers use Bash: invoke them as `bash scripts/<name>.sh` from the repository root in Oracle Linux. The same convention applies on a laptop and an OCI host. The SQLcl launcher additionally supports Git Bash on Windows for a native local client, documented in [private connection setup](dev-connection-setup.md). This does not change the Oracle Linux requirement for the full authoring pipeline. There is no PowerShell launcher to maintain alongside it.

| Script | Purpose |
| --- | --- |
| `scripts/check_environment.sh` | Check the Oracle Linux/Bash and Python prerequisites. |
| `scripts/bootstrap.sh` | Prepare the Python build environment. |
| `scripts/build_artifacts.sh` | Build and check the authoring data/artifacts. |
| `scripts/open_dev_sqlcl.sh` | Prepare missing local Java/SQLcl and open SQLcl without logging in; use it for the dev Liquibase/APEXlang workflow. |
| `scripts/setup_serverless.sh` | Legacy direct-driver helper; v2 schema creation is blocked in favour of migrations. |

Python `.py` files remain build/data utilities called from this Bash environment. Database objects and operations remain SQL/PLSQL. The release learner route remains SQL Worksheet and requires none of these shell launchers.

## Set up and check the original-source pipeline

1. Check out `dev`: `git switch dev`.
2. Run `bash scripts/bootstrap.sh`.
3. Run `bash scripts/build_artifacts.sh`. This verifies source hashes, extracts selected PDF text, builds RDF and runs checks.
4. Generate candidate app installers with `python scripts/build_apex_worksheet.py --mode new` or `--mode upgrade`, using the target options described in the [APEXlang guide](apexlang-development.md). A matching current-source engine receipt is required before generation; the resulting wrappers still need deployment testing. To reproduce the published v1 deployment, use the tagged baseline.
5. Keep `work/`, `.venv/`, local configuration and credentials ignored. Original PDFs and extracted text never belong in a public commit.

The `kcv/` package implements preparation and optional direct-database automation. `scripts/` contains developer/build utilities. `tests/` and `integration-test/` contain checks; mocks may be installed only in the isolated test schema. Learner database operations remain SQL/PLSQL.

## Build the SQL-first release

Run `.venv/bin/python scripts/build_release.py --output work/release-package` from the project root. Use a new output directory each time; the tool refuses to delete or overwrite an existing directory.

For publication-only corrections to an accepted package, commit the reviewed dev changes and use `--prepare-publication --accepted-release-commit FULL_ACCEPTED_RELEASE_COMMIT` with a new output directory. This records clean committed provenance, checks the same-version clean/migration acceptance record and rejects runtime changes against that accepted commit's manifest. It does not push, tag or rerun native tests. Follow [maintainer promotion](branch-workflow.md#maintainer-promotion) before updating release; historical records keep their original scope.

The build uses attributed editorial summaries from the original presentations and the admitted expanded research, not private files or original PDF text. It generates a separate graph, summary IDs/hashes, a GitHub JSON load package and short caller, fallback SQL, an APEX Worksheet installer, learner documentation and a hashed file manifest. The package manifest records its exact counts. No PDF downloads or database connection are required for this release build. Release documentation overrides live under `release-docs/`; common labs are adapted in the packaging step.

Run `.venv/bin/python -m unittest discover -s tests -v`, `python scripts/sync_doc_snippets.py --check` and `python scripts/build_apex.py --check` before promotion. Inspect `work/release-package/README.md` and `release-manifest.json`. The release dataset requires its own native graph/model/browser acceptance; original-passage validation cannot be claimed for changed summaries.

See [branch workflow](branch-workflow.md) for promotion. Optional direct-driver setup (`scripts/setup_serverless.sh`) is retained for legacy diagnostics/bootstrap and rejects raw schema creation on v2. Use the migration guide for v2 schema changes; do not mix old raw initialization scripts with migration-managed objects.

## Publish and test the GitHub dataset on dev

The dev branch includes the public summary package used to test the actual download path before release. Generate it from the project root in Oracle Linux:

```bash
.venv/bin/python scripts/build_github_dataset.py --output data/load --loader sql/install/10_load_github.sql
```

On a Windows development host, use `.venv/Scripts/python.exe` for the same command. The helper builds attributed summaries; it does not publish the raw extracted passages in `work/`. Review `data/load/manifest.json`, its JSON parts and the caller together. Their counts describe the summary package, while the normal dev `generated/build-report.json` can describe a larger extracted-passage authoring build.

After local validation and publication review, commit and push **dev**. Copy that full 40-character dev commit SHA into the generated caller and run it through the [GitHub load guide](github-dataset-load.md) on the approved temporary ADB Serverless instance. The caller's manifest hash is already filled in. Keep release unchanged while proving this candidate.

For current dev acceptance, follow the [migration workflow](database-migrations.md), load the pinned data, and run `integration-test/verify_worksheet.sql`, `verify_sample_journey_regression.sql` and `verify_personal_journey.sql` in the isolated test schema. The latter two remove only their own synthetic fixtures. Do not use the legacy `verify_scenario_native.sql` against a schema whose conversations must be preserved. Dataset changes also need `verify_source_packet_scope.sql` and `verify_github_dataset.sql`; review each script's prerequisites before execution. Model/expiry checks and signed-in application/evidence flows are separate acceptance steps in the [manual review](my-contexts-manual-test.md). Record outcomes against the tested commit or artifact hashes and manifest hash; local packaging tests do not establish native acceptance. Repeat affected checks after changes before promotion.

Historical v1 acceptance: the GitHub path and expanded summaries passed [native SQL acceptance](../references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`, including that record's dataset/scenario tests and two-session lock exclusion. A later [real-model and APEX browser acceptance](../references/expanded-ui-validation.json) passed using the updated app export and citation parser, identified by artifact hashes. These records do not establish fresh v2 deployment or execution from a promoted v2 release. See the current candidate status above and [branch workflow](branch-workflow.md#maintainer-promotion).

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
