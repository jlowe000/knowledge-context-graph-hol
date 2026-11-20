# Release dataset and attribution

The release loads 17 author-written editorial summaries attributed to pages of nine real public presentations, with three explicitly fictional learner contexts. Source metadata is in [public-sources.json](../data/public-sources.json); summaries and their original public page links are in [release-summaries.json](../data/release-summaries.json). The included [SQL loader](../sql/install/10_load_dataset.sql) installs this data without Python or downloading PDFs.

## What the hashes and citations mean

- The source version SHA-256 identifies the pinned original PDF edition reviewed during source preparation. Installing release SQL does not download or reverify that PDF.
- A summary's text hash identifies the editorial text, not the original slide text.
- IDs contain `summary` and are separate from original extraction IDs. Text is prefixed “Editorial summary, not a quotation”. Metadata identifies `attributed_editorial_summary` and the original page locator.
- Review examples and summaries are not automatically accepted extracted Claim nodes. There are no accepted extracted claims in the release baseline.
- The app retrieves and cites these summaries. A match proves traceability to the supplied summary; it does not prove that a paraphrase is complete, that a feature is generally available or that the source meets a particular business need.

The dev branch retains the original PDF download/hash verification and extraction pipeline. Changing between original-passage and summary datasets is a data change, not a simple app upgrade. Use a fresh lab schema/database for this release; do not replace the baseline underneath existing conversations. Previously saved response traces retain their historical payloads.

Source/topic membership, source IDs and context relationships are preserved, so the same Alex/Casey exercises apply. Wording and citation IDs differ from earlier screenshots and original-passage model answers. The summary dataset needs its own native SQL and model/browser acceptance; see [validation](scenario-validation.md).
