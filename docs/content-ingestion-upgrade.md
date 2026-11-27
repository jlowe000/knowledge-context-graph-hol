# Upgrade the application or public collection

For an existing installation, use the [version-aware installation selector](installation-paths.md). Published v2.0.0 uses the v2.1.0 upgrade; v1 first uses the pinned published v2.0.0 bridge. The old package-by-package sequence is historical, not a direct v1-to-v2.1 recipe. Keep schema/app upgrade separate from an optional public-collection update.

## Keep application and collection updates separate

An application migration can keep the installed public collection. It preserves source versions, graph snapshots, saved conversations and their historical evidence. Do not reload data merely because app code changed.

If you deliberately want another published collection, first verify the upgraded schema, then use [GitHub dataset loading](github-dataset-load.md) with the chosen immutable commit and matching manifest hash. Activation occurs only after successful loading. Existing conversations retain their pinned collection/revision; a new personal revision and explicit adoption select changed knowledge for future questions. Do not delete old graphs to force adoption.

## What release evidence means

The release contains attributed editorial summaries, not original PDF extracts. PDF pages remain page locators; web/repository passages carry their actual locator kind/label. The bounded packet contains up to six passages and two locators per source version. Original lesson sources precede additional catalogue IDs. This is a topic relationship join, not an exhaustive reading or semantic ranking of public documents.

A title/reference without supplied text remains a discovery link, not evidence the model has read. Keep roadmap and regional qualifications when interpreting the packet. The [dataset guide](release-dataset.md) records coverage and source attribution.

## Verify after a deliberate update

Run the full schema verifier, public-source scope and scenario checks, then test the relevant app flows. For an authorized current conversation, open a historical explanation and confirm it retains its original context/evidence. Legacy v1 sample chats keep their original browser-session access restriction; migration preserves their records without converting them into durable My Contexts conversations. See the migration guide before relying on reopening them after logout. Ask a new question and inspect the application retrieval event before model dispatch. An objective change may affect interpretation without changing selected sources; removing a topic narrows learning focus rather than declaring a technical prohibition.

The app export already contains its runtime assets. Import the matched upgrade installer; do not manually replace one JavaScript file from another version. Preserve workspace, parsing schema, alias and application ID. A successful import is not evidence that all model, browser or migration cases passed; use [validation status](scenario-validation.md).
