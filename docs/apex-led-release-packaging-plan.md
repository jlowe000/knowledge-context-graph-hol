# Package the v2.1.0 deployment experiences

**Current status: all four curated-package runtime routes passed on prepared environments within their recorded scopes. SQL-first clean learner persistence and bounded reviewer checks passed; the SQL-first upgrade preserved the existing work and reopened its original answer and evidence. The protected-build comparison and 78 local tests passed.** The candidate package has been checked against the accepted runtime inventory. On 28 November 2026, the user authorised committing dev and promoting the validated package into a local release commit. Regeneration must use clean committed dev inputs and preserve the accepted runtime hashes. Push and tag creation remain unauthorised; local package provenance records the resulting source commit and validation.

The authored application now declares 2.1.0. Its native application-only import and SQL/APEXlang exports passed with 11 pages and 16 maintained assets. Supporting Objects execution was disabled for that export rehearsal. Subsequent actual App Builder rehearsals of this candidate passed clean installation and a populated published-v2.0.0 upgrade, including the canonical 121-step contract, guided readiness and saved-answer evidence. These prepared-environment results do not establish positive execution of the public administrator preparation templates, new-database provisioning or first Java enablement/restart. Earlier r13 evidence retains its separate historical scope.

## Inputs and artifact boundaries

| Input | Requirement |
| --- | --- |
| VERSION and maintained apex/application source | Matching reviewed product version and source hash |
| apex/kcv-explorer.sql plus [SQL export receipt](../apex/export-validation.json) | Genuine native definition-only export; do not hand-edit generated SQL |
| Reviewed native APEXlang ZIP plus [ZIP receipt](../apex/apexlang-export-validation.json) | Exact archive bytes, native validation/provenance, source and canonical-manifest hashes |
| Reviewed canonical Supporting Objects directory | Local input matching the receipt and frozen migration chain; not distributed as a work directory |
| Public dataset and release-docs templates | Attributed summaries, approved pins and separate learner/deployment experiences |
| [Four-route record](../db/verification/release-v2.1-paths-validation.json) | Four scoped runtime passes and exact evidence; accepted runtime inventory verified against the candidate package |

The builder receives the ZIP and canonical directory explicitly; it does not search ignored work folders for whichever candidate is newest. Example paths below are placeholders for your reviewed local artifacts, not a command to synthesize a receipt or regenerate a different canonical tree.

## Build an unpromoted candidate

Run in the documented Oracle Linux/Bash development environment, using a new output directory:

```bash
.venv/bin/python scripts/build_release.py \
--output work/release-package-candidate \
--apexlang-zip work/reviewed-apex/kcv-explorer.apx.zip \
--apexlang-receipt apex/apexlang-export-validation.json \
--apexlang-canonical work/reviewed-apex/supporting
```

A candidate may use an uncommitted source snapshot and a pending route record; provenance records that state and labels the result unpromoted. Inputs must remain unchanged during generation. The builder refuses an existing output directory and rejects stale export/receipt/source/canonical relationships. Packaging neither connects to the database nor establishes deployment acceptance.

The output includes the exact APEXlang ZIP, definition-only SQL app export, SQL-first clean/upgrade parts and wrappers, generated owner binding, neutral preparation scripts, public summary data and consumer documentation. It excludes dev proxy bootstraps, development skills/tools and local private work. The historical v1 helpers are excluded: v1 first uses its pinned published v2.0.0 bridge, then the candidate v2.0.0-to-v2.1.0 path.

Inspect release-provenance.json, release-manifest.json, dataset pin/hash and the produced README. Run the focused release/package regression suites and link/privacy checks. A finite scan is not a universal secret-absence guarantee.

## Test four paths independently

| Route | Starting point | Required result | Current status |
| --- | --- | --- | --- |
| APEX-led clean | New prepared empty owner/workspace | Actual ZIP import and Supporting Objects Install, private guided setup, real learner evidence and persistence | Passed, prepared-environment core scope |
| APEX-led upgrade | Populated published v2.0.0 app | Same-ID replacement/Supporting Objects Upgrade, exact preserved-work scope, readiness and historical evidence reopen | Passed, prepared-environment core scope |
| SQL-first clean | New password-enabled owner/Worksheet | Complete schema transport, new SQL app import, generated 03 binding, setup model test, explicit enablement and learner checks | Passed, prepared-environment mixed-transport and bounded reviewer scope |
| SQL-first upgrade | Populated published v2.0.0 app | Ordered upgrade and same app ID, binding/readiness, preserved graph/context/history and reopening | Passed, prepared-environment core scope |

The clean APEX-led rehearsal retained 27 bounded answer/evidence observer records across a new sign-in. The upgrade immediately preserved 44 rowsets and six metrics, including all 96 published-v2 receipts, then retained 23 earlier answer/evidence records on reopening. These are the measured scopes, not universal row, attachment or provider-billing comparisons. The record pins the tested runtime and evidence hashes. Combined SQL installer transport remains unverified.

SQL-first clean installation completed the ordered schema parts, standalone verifier, app import and owner binding in Worksheet. After a private credential correction, the successful model test and explicit enablement used genuine-owner SQLcl; this is not an all-Worksheet completion claim. The first personal question, Sources and lineage passed, and 31 bounded answer/evidence records remained identical after a new sign-in and stored-answer reopening. Navigation and explicit keyword fallback passed. The separate reviewer began with an empty All-contexts list, saw only their own sample copy, found no result for the other learner's context and one for their own, navigated Sample Contexts to My Contexts, and was denied direct Deployment setup access. These browser checks do not establish universal account/API isolation or semantic-vector search. The record retains the exact literal-input installer variant.

The SQL-first upgrade completed its ordered schema parts and standalone verifier in Worksheet, then used the optional F5 wrapper for same-ID application replacement and the separate owner binding. Native verification confirmed 121 receipts, 28 program hashes and 11 app pages. Before readiness, 44 original rowsets and six metrics matched, including all 96 published receipt rows and two native graphs with 30,150 triples. The retained-model test and explicit enablement passed in Worksheet. The original learner reopened the saved answer, Sources and lineage; 23 original observer records remained unchanged, with four additional assertions confirming one response request, one model-start marker, two turns and one tool event. All five citations still matched supplied evidence. Transport execution/derivation records are reviewed attestations; the builder independently checks packaged/source hashes but does not reopen private execution evidence.

The protected-build comparison passed across seven existing installations with 302 exact marker lines and no allowed differences. It retains the original observers' bounded scope, including their attachment checks, and is not a full database backup or universal preservation claim. All 78 local worksheet, authoring, release, portable-preparation and catalogue tests passed. Follow the four-route record for subsequent progress and exact artifact relationships.

Record exact runtime/artifact hashes and actual outcomes in the four-route record. Preserve existing apps/data and JAVAVM. An APEXlang validation pass, a SQLcl export or an older package's success is not a substitute for any of these routes. New provisioning/first Java activation and broader platform/audit limits remain explicit.

## Prepare publication only after acceptance and approval

The default build remains a candidate. For v2.1.0, --prepare-publication additionally requires:

- A clean, committed dev source snapshot.
- The version-specific record marked passed, all four named routes passed with no pending checks, and explicit publication_approved.
- Exact agreement with the accepted runtime inventory and each route's recorded artifact hashes.
- Both native application's declared versions matching VERSION.

Use the same explicit ZIP/receipt/canonical flags with --prepare-publication and a new output directory. Do not use --accepted-release-commit for v2.1.0: that is the separate historical v2.0 publication-correction gate and is rejected here.

Changed runtime requires affected deployment acceptance against the changed artifacts; documentation-only regeneration still needs manifest/provenance review. Keep the [v2.0 record](../db/verification/release-v2-paths-validation.json) and [earlier r13 evidence](../db/verification/apex-led-candidate-validation.json) unchanged in historical scope. Publication packaging is local; it does not update release, push, tag or grant approval. Follow [branch promotion](branch-workflow.md#maintainer-promotion) only within the user's explicit authorisation.
