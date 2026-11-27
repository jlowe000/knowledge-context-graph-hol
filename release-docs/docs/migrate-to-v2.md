# Historical bridge from v1 to published v2.0.0

This page identifies the **already tested v1 → v2.0.0 SQL-first bridge**, not a direct v1 → v2.1.0 installer. The [historical release-path record](../db/verification/release-v2-paths-validation.json) retains its exact candidate02 Worksheet/browser scope and limitations. Keep that record unchanged.

Use the complete [published v2.0.0 package](https://github.com/jlowe000/knowledge-context-graph-hol/releases/tag/v2.0.0) and its [matching migration guide](https://github.com/jlowe000/knowledge-context-graph-hol/blob/v2.0.0/docs/migrate-to-v2.md). Do not run this checkout's v2.1.0 schema files while following the older guide.

The published bridge verifies required v1 objects, completes only supported missing optional objects, adopts the verified baseline, applies the v2.0.0 migrations and upgrades the same application ID. It preserves stored rows, evidence and RDF without widening access. Unknown/customised schemas still stop for review.

Its resulting verified checkpoint is `2.0.0-c3-r7-ready` with 96 COMPLETE project receipts. A registry row or count alone does not replace its physical/program verifier. The historical acceptance does not certify new-database provisioning or every isolation/deletion case.

Legacy sample chats remain browser-session-bound; preserving the app ID does not make them account-owned. Export needed legacy material privately before the maintenance window. New My Contexts conversations deliberately created under v2 use durable account ownership.

After that complete bridge and its checks, choose the separate **v2.0.0 → v2.1.0** route: [APEX-led upgrade](apex-led-upgrade.md) or [SQL-first upgrade](migrate-to-v2.1.md). Both prepared-environment rehearsals passed within the scopes in [v2.1 validation](../db/verification/release-v2.1-paths-validation.json). The older bridge is not evidence that a direct v1-to-v2.1 path works.
