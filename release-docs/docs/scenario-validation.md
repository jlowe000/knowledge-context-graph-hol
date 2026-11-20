# Release validation status

## Existing application evidence

The earlier original-passage version was deployed to the temporary ADB Serverless instance with APEX 26.1.6. Real model answers, native graph paths, context refinement, saved observations, per-response Sources/Answer lineage, historical persistence after reload and narrow-screen interaction were exercised. Detailed historical/component records remain on dev.

## Summary release

This distribution changes the evidence payload to 17 attributed editorial summaries with distinct IDs/hashes. It includes a prebuilt dataset loader and Worksheet APEX installer. Build checks verify the publication allowlist, relative documentation links, generated SQL, graph/source/context integrity, native-query selection against RDFLib and manifest hashes. These are local checks, not a native Oracle database or inference pass.

## Required native acceptance before a validated release tag

1. Follow the beginner route on a fresh approved ADB Serverless database using only release files.
2. As KCV_LAB run [verify_worksheet.sql](../integration-test/verify_worksheet.sql) and [verify_scenario_native.sql](../integration-test/verify_scenario_native.sql). Inspect PASS and USER_ERRORS. These native checks make no model inference request.
3. Deploy the supplied installer, sign in as KCV_USER and complete Alex's question, Sources and Answer lineage inspection, topic removal, another question and observation save. Check summary labels and IDs; answers must preserve roadmap/availability limits.
4. Reload and verify the historical answer retains its original evidence while the new answer uses the refined context. Check Casey retains both overview and regional disclaimer pages. Record actual versions and observed results.
5. Capture the remaining platform screenshots and have a first-time ADB learner complete the documented path. Review accessibility and a second user's isolation on the target separately.

No new cloud database or model call is implied by packaging this release. The optional OWL/extraction exercises are not part of the main acceptance result.
