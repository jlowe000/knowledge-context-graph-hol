# Branches and release control

| Branch | Audience | Contents |
| --- | --- | --- |
| `dev` | People building their own adaptation, contributors and maintainers | DEV-led experience: source/model/ontology/retrieval/UI changes, preparation/build tools, tests, a publishable summary package for native acceptance and a build-your-own journey |
| `release` | App users and technical learners deploying or understanding the supplied collection | Curated v2.1.0 APEX-led and OCI / DBA-led SQL-first clean/upgrade paths, app-use and developer-learning journeys, SQL APIs, model/ontology, prepared dataset and app |

The distinction is the intended learning outcome, not simply tooling or developer skill level. Release teaches using and understanding this supplied collection; dev teaches adapting its content, model and implementation into your own version. An app user can start in a hosted deployment without provisioning resources. A developer can study/query the collection on release without changing its build pipeline. See [build your own](build-your-own.md) for the adaptation journey.

The branches share an initial history. `release` is a curated distribution tree, not a merge target for every development file. Tools remain public and accessible by selecting `dev`. A branch does not restrict who can use already public code.

The [three experiences](deployment-experiences.md) use these same two branches. The curated v2.1.0 package has passed all four prepared-environment routes in the [current record](../db/verification/release-v2.1-paths-validation.json). On 28 November 2026 the user authorised local dev and release commits; push and tag creation remain separate. Dev retains the DEV-led adaptation experience. The [APEX-led implementation plan](apex-led-deployment-plan.md) and [earlier acceptance review](apex-led-acceptance-review.md) retain their historical implementation scope. Generate Supporting Objects from the same migration definitions and preserve one application/schema contract. No third branch is required.

The published v2.0.0 SQL-first clean/migration results remain in their [historical record](../db/verification/release-v2-paths-validation.json). Current v2.1.0 templates under release-docs/ add APEX-led clean/upgrade guides and the SQL-first v2.0.0-to-v2.1.0 path; their [four-route record](../db/verification/release-v2.1-paths-validation.json) reports four scoped passes with no pending runtime checks. A v1 installation uses the pinned published v2.0.0 bridge first. A pass for one execution route does not certify the others.

## Maintainer promotion

1. Work on dev; maintain implementation/tests and the separate app-use, developer-learning and deployment templates under release-docs/.
2. Obtain the matching native SQL export/receipt and APEXlang ZIP/receipt, plus its reviewed canonical Supporting Objects directory. Follow [the packaging plan](apex-led-release-packaging-plan.md); v2.1.0 build_release requires explicit --apexlang-zip, --apexlang-receipt and --apexlang-canonical inputs. Use a new output directory and keep the source snapshot unchanged during generation.
3. Run contributor/package checks and inspect manifests, public summaries, loaders and consumer instructions. Keep PDFs, extracted bodies, private runtime data, credentials and ignored work excluded. The default build may record dirty inputs and pending acceptance; it remains an unpromoted candidate.
4. If public dataset bytes changed, publish reviewed dev data/caller together only when the user authorises the commit/push, then test the full immutable commit and matching manifest hash. If bytes are unchanged, retain the verified existing public pin. A local build or branch head is not a substitute for an available pinned dataset. Leave release unchanged during testing.
5. Rehearse all four curated-package routes independently on authorised isolated targets: APEX-led clean and populated published-v2.0.0 upgrade; SQL-first clean and populated published-v2.0.0 upgrade. Include actual transport, generated 03 binding where required, setup model test, explicit enablement, learner evidence/persistence and preserved-work comparison. Record exact runtime/artifact hashes and pending limits in db/verification/release-v2.1-paths-validation.json.
6. Complete the current acceptance record only from observed results. Older r13 or v2.0.0 records retain their historical scope. Runtime changes need affected checks against the changed package. A successful local build, native export or push is not route acceptance.
7. After acceptance and explicit publication approval, commit reviewed dev inputs and build with --prepare-publication plus the same three explicit APEXlang inputs into a new directory. For v2.1.0 the builder requires clean committed dev, four passed routes without pending checks, publication_approved, exact accepted runtime/route hashes and both native UI versions matching VERSION. It records prepared_for_publication but does not push, tag or run database tests. The historical --accepted-release-commit gate is for v2.0 publication-only corrections; v2.1 rejects that option.
8. Only when authorised, update the dedicated release checkout from the reviewed package, preserving its learner experience rather than merging the dev tree. Inspect the full staged file list, manifest/provenance, validation and licences before committing. Push/tag and remote branch settings require their own authorisation; the builder performs none of them.

Do not merge dev wholesale into release or merge release's distribution-file removals wholesale into dev. Port individual fixes on dev and regenerate. A release manifest hashes payload bytes; it is not a signature or a substitute for native acceptance. Keep a reviewed recovery path before changing a published distribution.

## Product versions and Git tags

Use **major.minor.patch**, with public annotated tags named `vMAJOR.MINOR.PATCH`. The published baseline is **v1.0.0**; My Contexts was delivered as **v2.0.0**. The current **v2.1.0** candidate adds APEX-led deployment and shared readiness gates. This project's policy explicitly permits a major increment for significant functional uplift as well as backward incompatibility; version numbers are not a substitute for compatibility notes.

| Increment | When to use it | Example |
| --- | --- | --- |
| Major | A backward-incompatible API, stored-data, behaviour or deployment contract; or a significant functional uplift that changes what users can do. Reset minor and patch to zero. | `v1.0.0` to `v2.0.0` for durable personal contexts and conversations. |
| Minor | A backward-compatible feature or meaningful extension within the current experience. Reset patch to zero. | `v2.0.0` to `v2.1.0` for an additional compatible learning capability. |
| Patch | Backward-compatible defect fixes, documentation corrections or maintenance with no new functional contract. | `v2.0.0` to `v2.0.1` for a corrected error message or installer defect. |

Classify each release by its highest-impact change. Routine source corrections can be patch changes; meaningful additional content coverage can be minor. A change to retrieval/data semantics must be assessed for compatibility rather than classified from the number of source files changed. Source editions, dataset hashes, schema migration IDs and APEX platform versions remain separately versioned.

My Contexts qualifies for `v2.0.0` because the user can maintain personal contexts and multiple durable conversations across sign-ins, beyond the supplied sample journeys. Native APEXlang authoring and Liquibase on dev accompany that uplift. The major number does not require us to break the existing HOL: retain its sample APIs/flows where feasible and provide tested, data-preserving upgrades. Document actual compatibility and unsupported downgrade paths separately.

### Baseline and tag targets

Public remote refs were checked on 24 November 2026. No tags were returned. At that check:

| Record | Commit | Planned role |
| --- | --- | --- |
| Published `release` | `83e3ecb64f417f6ef388df43ab9b102dddab2b71` | Exact target for the retrospective `v1.0.0` baseline tag. |
| Published `dev` | `cb4608c8b594d73e3908a63561cc963d386e52f8` | Corresponding development baseline; retain this source SHA in baseline provenance. |
| Subsequent `v2.0.0` release | `9597607c8cdd07b47893a92959bec9cb8f166829` | Published My Contexts release tagged on 25 November 2026; separate from the earlier baseline observation. |

On 24 November 2026, annotated tag `v1.0.0` was created and pushed. Its tag object is `aa60df23294503f2f0bb38c69a76c5ec6707e1fd` and its peeled commit was verified as `83e3ecb64f417f6ef388df43ab9b102dddab2b71`. The release branch stayed on that commit at that checkpoint. The later `v2.0.0` tag identifies the release commit above. Current v2.1.0 local promotion approval does not authorise a new remote tag. Recheck remote tags before any separately authorised tagging operation and reject an existing name pointing to a different commit. Historical labels do not assert that new tests have run.

Git tags identify commits across the repository, not separate branch-local versions. `vX.Y.Z` identifies the curated **release** commit. Record the exact accepted **dev** source SHA in the release manifest/validation provenance instead of trying to apply the same tag to two different commits. Dev contributors can check out that source SHA to recover the matching tools and authoring sources.

Use annotated, immutable tags. Never move or force-push a published version tag; publish the next appropriate version for a correction. Work in progress is identified by its full commit SHA and marked as an unreleased target version. If candidate tags become useful, use distinct prerelease names such as `v2.0.0-rc.1`; these do not claim final acceptance.

### Historical v2.0.0 implementation and publication sequence

The sequence below records the v1-to-v2.0.0 release process. Use [Maintainer promotion](#maintainer-promotion) and the four-route record for current v2.1.0 preparation; do not recreate the existing v2.0.0 tag.

1. Record/tag the exact existing baseline when executing the tagging work. Creating or pushing tags is a separate Git operation; editing this policy does neither.
2. Implement version metadata in the dev source/build: one maintained product version, release notes, manifest source SHA, migration compatibility range and app artifact hash. Keep build/acceptance status explicit so `2.0.0` in candidate metadata cannot imply a published release.
3. Accept the dev implementation, generate the learner distribution and independently accept its fresh Worksheet installation and supported upgrade from `v1.0.0`. Confirm the same-ID APEX upgrade preserves owned contexts/history. Record the exact source/data/app hashes and supported compatibility.
4. Produce the reviewed release commit and verify its tree matches the accepted candidate. Create the annotated `v2.0.0` tag against that exact commit with upgrade/release notes, then publish the branch/tag through the normal controlled Git workflow.
5. Continue pinning the GitHub dataset loader to a full 40-character commit SHA plus the manifest hash. A convenient version tag does not replace the loader's existing integrity/reproducibility contract.

The GitHub importer and expanded summary dataset passed the [recorded native SQL acceptance](../references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`, including the four supplied verification scripts and two-session lock exclusion. A subsequent [GenAI and signed-in APEX acceptance](../references/expanded-ui-validation.json) passed with the regenerated app export and corrected citation parser, identified by artifact hashes. Interrupted loading, a fresh learner deployment and execution from a promoted release commit remain separate checks. These results do not automatically promote or push release.
