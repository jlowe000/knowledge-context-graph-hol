# Changes

## 2.0.0 — unreleased

My Contexts is being implemented and validated on dev. The candidate adds a persistent, owner-scoped draft library, explicit graph preview/apply, saved personal conversations and bounded model continuation, with directly authored native APEXlang pages and migration artifacts. The full v2 experience is not accepted or published yet.

- Introduce major.minor.patch product versions and immutable release tags.
- Begin migration-managed personal-context storage and native page authoring.
- Add reviewed personal context revisions, pinned evidence, explicit conversation adoption, paginated history and recovery for interrupted operations.
- Separate topic/collection evidence selection from background/objective interpretation; observations do not automatically change the source graph.
- Preserve the existing sample conversation/evidence implementation during this first increment.
- Require native database and authenticated app acceptance before release promotion.
- Validate the draft increment on isolated ADB Serverless, including account lifecycle isolation, native APEXlang import, same-ID app updates and migration fresh/upgrade/recovery paths. See `references/my-contexts-c2-validation.json` for the exact coverage and remaining work.
- Retrieve and record current evidence before the grounded model request, including after provider-history expiry. Preserve earlier messages and traces; distinguish application retrieval from agent tool calls in the explanation graph.
- Validate independent APEX expiry continuation with six passages and three matched citations. A separate native model response contained malformed JSON, which retains an explicit warning rather than inferred citation matches. See `references/my-contexts-c3-validation.json` for current coverage and remaining fresh-deployment/Worksheet checks.
- Remove obsolete authoring snapshots and one-off local transformation tools, clarify historical v1 guidance, and expand private-file exclusions. Record the publication-file and local-history privacy audit in `docs/publication-security-review.md`.

Compatibility and upgrade instructions will be finalized against the accepted build. The major version reflects the planned functional uplift; it does not authorize removal of existing data or imply an untested downgrade is supported.

## 1.0.0 — baseline tagged 24 November 2026

The existing published release is tagged at `83e3ecb64f417f6ef388df43ab9b102dddab2b71`. Its corresponding dev source baseline is `cb4608c8b594d73e3908a63561cc963d386e52f8`.

This is a retrospective label for the published collection, supplied learner scenarios, APEX conversation/evidence experience and SQL Worksheet deployment. Tagging does not assert new acceptance testing.
