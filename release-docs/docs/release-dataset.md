# Release dataset and attribution

The release loads attributed editorial summaries of the original nine public presentations and selected content from the expanded research, with three explicitly fictional learner contexts. Source metadata is in [public-sources.json](../data/public-sources.json) and [public-catalog.json](../data/public-catalog.json); all installable summaries and source locators are in [release-summaries.json](../data/release-summaries.json). The preferred [GitHub loader](github-dataset-load.md) fetches this prepared data directly into ADB from a pinned public commit, without Python or original-source downloads. Exact counts and remaining gaps are recorded in the [build report](../generated/build-report.json) and [ingestion record](../references/content-ingestion-checks.json).

The [load manifest](../data/load/manifest.json) describes bounded JSON parts for sources, passages, contexts and RDF triples. [10_load_github.sql](../sql/install/10_load_github.sql) supplies the expected manifest hash; select the published commit containing that file and the matching data. ADB downloads data, not executable SQL. The existing [SQL dataset](../sql/install/10_load_dataset.sql) remains a fallback for environments without public GitHub access.

## What the hashes and citations mean

- The source version SHA-256 identifies the pinned retrieved source response where retrieval succeeded; catalogue-only metadata hashes are identified separately below. Installing the prepared dataset does not download or reverify the original source. The GitHub manifest and part hashes verify the packaged data bytes, a separate check.
- A summary's text hash identifies the editorial text, not the original slide text.
- IDs contain `summary` and are separate from original extraction IDs. Text is prefixed “Editorial summary, not a quotation”. Metadata identifies `attributed_editorial_summary` and an actual page, section or file-line locator. Non-PDF passages have a null PDF page.
- New research summaries are AI-assisted and not independently fact checked. Basis-passage IDs and hashes tie them to locally extracted content. They summarize selected passages, not the whole source; a short panel introduction cannot substitute for the panel discussion.
- Review examples and summaries are not automatically accepted extracted Claim nodes. There are no accepted extracted claims in the release baseline.
- The app retrieves and cites these summaries. A match proves traceability to the supplied summary; it does not prove that a paraphrase is complete, that a feature is generally available or that the source meets a particular business need.

The dev branch retains the original PDF download/hash verification and extraction pipeline. Changing between original-passage and summary datasets is a data change, not a simple app upgrade. Use a fresh lab schema/database for this release; do not replace the baseline underneath existing conversations. Previously saved response traces retain their historical payloads.

The retained source identities and context relationships preserve the Alex/Casey exercises. S05 and S07 are retained following explicit review of the template footers in those public event editions. Wording and citation IDs differ from earlier screenshots and original-passage model answers. The summary dataset needs its own native SQL and model/browser acceptance; see [validation](scenario-validation.md).

## Public research expansion — 23 November 2026

The prepared dataset includes all admitted references as source/version/topic/domain nodes. Sources with supplied summaries also connect to EvidencePassage nodes and can enter the chatbot's evidence packet. The [searchable catalogue](../generated/public-catalog.html) labels the coverage actually installed by this build. Catalogue-only entries have no invented passages and do not become answer evidence. The topic selector includes sources with supplied text, without claiming that extraction or summarization establishes truth.

The [public-source policy](../references/public-source-policy.json) records the approved Oracle and repository URL scopes and the YouTube title condition. Matching items carry `classification_status="manually marked as public"`. The [access audit](../references/public-access-checks.json) separately records actual anonymous HTTPS results and errors. Public accessibility, readable text extraction and supplied release summaries are separate observations. A failed retrieval is not presented as successful verification.

For metadata-only observations, `version.hash_basis="catalogue_metadata"` identifies the catalogue record, not source bytes. The original nine PDFs retain their 17 summaries, including the reviewed S05 and S07 editions. Images, archives, missing video transcripts, failed fetches and material without substantive readable content retain explicit gaps. Source documents, complete extracted text, embedded credentials and private review details are not bundled.

Other unresolved conflicts remain in a private `to_be_reviewed` array outside both Git worktrees. The private conflict report also preserves the original conflicts and the `manually_marked_public` decisions. No conflict-detail file is included in the release. Manual public classification does not grant copyright or licensing rights over the original material. Existing conversations retain their historical graph snapshots; use a fresh lab deployment for first native acceptance of the expanded dataset.

This expanded dataset has local graph, packaging, source-access and generated-SQL checks. Its GitHub package passed [native SQL acceptance on ADB Serverless](../references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`: 834 sources, 762 summaries, three contexts and 30,144 triples. Native source isolation, graph paths, refinement, retry and two-session exclusion passed. This run did not test GenAI inference, the APEX UI, interrupted loading, fallback SQL batches or execution from a release commit.

For non-PDF evidence cards, complete the [required APEX static-file update](content-ingestion-upgrade.md#required-application-file-update) after importing the supplied application. The source JavaScript is current; a new engine-produced export and live acceptance of this expanded release remain pending.

Public classification also applies the catalogue-title condition for YouTube. Industry and third-party items outside approved scopes remain in the private `to_be_reviewed` array and are excluded from the generated graph/loader. The [catalogue guide](public-research-catalog.md#publisher-and-video-review-scope) describes the rule precedence and scope.
