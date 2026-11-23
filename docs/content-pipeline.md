# Build the public research content

This maintainer workflow runs on `dev`. Release learners load the prepared dataset directly from GitHub using a short SQL call and do not need Python, original-source downloads or the original research application. The public catalogue is the input boundary: items still awaiting review are not ingested.

## 1. Retrieve and extract the admitted sources

Use the configured Python environment on Oracle Linux:

```bash
.venv/bin/python scripts/ingest_public_content.py --refresh-editions --workers 8
```

Windows maintainers can use `.venv/Scripts/python.exe`. The optional `--report /path/to/download-report-data.json` can reuse research files only when their bytes match a previously verified public source hash. It is not a runtime or installation dependency. `--audit-dir` must point outside the Git repository if the private access checkpoint is to be updated.

The ingester uses anonymous HTTPS without cookies or credentials, checks destinations and redirects, and retains source editions by hash. `--refresh-editions` adopts newly retrieved, validated editions with an incremented version; it does not relabel a failed fetch as verified. Previously authored summaries must then be rechecked against their new basis.

PDF text retains actual pages. HTML retains sections, and text repository files retain line ranges. GitHub API base64 and embedded file content are decoded as source content; file-preview controls alone are not file content. No OCR or video transcript is inferred. Images, archives, script-only pages and failures retain explicit coverage gaps.

Outputs are local and ignored by Git:

- `work/catalog-passages.json`: full extracted chunks, with overlapping text, source hash and locators.
- `work/research-content/ingestion-report.json`: one outcome per attempted source.
- `work/research-content/summary-inputs.json`: sampled passages for editorial work; automated selection still needs inspection for covers, surveys and navigation.
- `work/research-content/bodies/`: hash-addressed source responses.

Do not publish these bodies or the extracted-passage SQL under `work/worksheet/`. The small `sql/install/10_load_github.sql` caller and summary-only `data/load/` package are separate publication artifacts. Even publicly hosted sample code can contain links or identifiers that should not be reproduced in the package.

## 2. Prepare release paraphrases

Read actual passages and write concise original prose. Summarize the identified content, preserve its qualifications, and distinguish vendor statements, fictional scenarios and measured outcomes. If an automatically selected passage is a footer or menu, choose a substantive passage instead; never generate a capability claim from its title alone.

The checked-in `data/public-content-summaries.json` records the resulting paraphrases, selected locator, source-edition hash and basis-passage hashes. Its review status explicitly says AI-assisted and not independently fact checked. These are not accepted Claim nodes. A licence or reference index can be described as such without pretending it contains a product implementation.

The maintainer helper accepts JSON maps of source ID to original prose and optional maps of source ID to basis-passage IDs:

```bash
.venv/bin/python scripts/assemble_content_summaries.py --parts work/editorial-part.json --overrides work/editorial-basis.json
```

It validates provenance and generates the public coverage record. It does not write summaries automatically or publish the original passages. The public record includes statuses and counts without private audit URLs.

## 3. Generate and validate artifacts

```bash
.venv/bin/python -m kcv.cli prepare
.venv/bin/python -m kcv.cli build
.venv/bin/python -m kcv.cli worksheet
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python scripts/build_release.py --output work/release-content-build
```

Run the original `fetch` step before `prepare` if the nine PDF editions are not already cached. Choose a new release output directory; the builder refuses to overwrite an existing one. Graph generation combines the original passages with the added research chunks and validates edition, locator and text hashes. The RDF contains provenance rather than full extracted bodies. Release substitutes the attributed summaries and packages a SQL-only installation path.

The release build also writes `data/load/manifest.json`, bounded JSON parts for sources/passages/contexts/triples and `sql/install/10_load_github.sql`. The short caller contains the generated manifest hash; learners supply the full published commit SHA. Only attributed summary data belongs in this public load package. The importer fetches data, validates it and uses installed database code; it never runs SQL downloaded from GitHub.

For native acceptance, generate the same publishable summary package directly in the dev checkout:

```bash
.venv/bin/python scripts/build_github_dataset.py --output data/load --loader sql/install/10_load_github.sql
```

Review and commit the complete `data/load/` directory and its matching short caller together with the implementation changes on **dev**. Keep `work/`, original documents, full extracted passages and private audit files excluded. Push dev, then use that full dev commit SHA in the [GitHub load guide](github-dataset-load.md). A package in a local build directory has no usable public Raw URL; do not pin a prior commit that predates the generated files.

Keep release unchanged while testing this candidate on the approved temporary ADB Serverless instance. Record the pinned commit, manifest hash, native load and graph checks, model/browser results and failures. Promote the reviewed package only after the dev acceptance passes, following [branch workflow](branch-workflow.md). Building artifacts does not publish, commit or push them.

The local Worksheet loader remains available for authoring tests and environments that cannot fetch GitHub. It emits guarded, bounded PL/SQL batches with progress messages, plus numbered files under `work/worksheet/dataset-parts/`. Run those files in order, or use the complete loader in a suitable client. Successful batches commit; an error blocks later activation. Run one loader at a time. Resolve an error and restart from the first part rather than skipping a failed block. Generation and local tests do not establish native ADB compilation or deployment of the new GitHub importer.

## 4. Deploy deliberately

For a new database, follow [fresh Serverless deployment](fresh-serverless-deployment.md). For an existing lab, follow [content locator upgrade](content-ingestion-upgrade.md). The current engine-produced application export includes the non-PDF evidence JavaScript and versioned assets; importing it does not require a separate static-file replacement. Historical conversations retain their saved evidence; create a new conversation for the new active graph.
