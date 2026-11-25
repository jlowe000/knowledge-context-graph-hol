# Branches and release control

| Branch | Audience | Contents |
| --- | --- | --- |
| `dev` | People building their own adaptation, contributors and maintainers | Source/model/ontology/retrieval/UI changes, preparation/build tools, tests, a publishable summary package for native acceptance and a build-your-own journey |
| `release` | App users and developers learning the knowledge collection | Separate app-use and developer-learning journeys, optional sample deployment, SQL APIs, model/ontology, prepared dataset and app |

The distinction is the intended learning outcome, not simply tooling or developer skill level. Release teaches using and understanding this supplied collection; dev teaches adapting its content, model and implementation into your own version. An app user can start in a hosted deployment without provisioning resources. A developer can study/query the collection on release without changing its build pipeline. See [build your own](build-your-own.md) for the adaptation journey.

The branches share an initial history. `release` is a curated distribution tree, not a merge target for every development file. Tools remain public and accessible by selecting `dev`. A branch does not restrict who can use already public code.

The v2 release must present two installation paths: **clean installation** into an empty project schema, and **migration** of an existing supported installation. Maintain their selector and separate guides in `release-docs/docs/installation-paths.md`, `fresh-serverless-deployment.md` and `migrate-to-v2.md`. Both paths use supplied Database Actions SQL, with no learner dependency on Liquibase or SQLcl. Migration retains the existing schema, workspace, application ID, credentials, graphs and history. Record fresh installation and migration acceptance independently; a pass for one does not certify the other.

## Maintainer promotion

1. Work on `dev`; update SQL, UI sources, tests and the common labs. Maintain the app-use, developer-learning and optional deployment routes in `release-docs/`.
2. Run the contributor checks and build the summary-only `data/load/` package plus `sql/install/10_load_github.sql` in dev, as described in [development setup](development.md#publish-and-test-the-github-dataset-on-dev). Build a separate release candidate to inspect its learning routes, but do not publish release yet.
3. Inspect the manifests, summaries, loader and publication candidates. Keep source documents, extracted passages, `work/`, credentials and private audit details excluded. Verify that app users can start without cloud/database setup, developers can trace the collection through SQL/APEX, and adaptation/build instructions stay on dev.
4. Commit and push the reviewed **dev** candidate. Use its full 40-character commit SHA and matching manifest hash for the real GitHub load on the approved temporary ADB Serverless instance. A local package or branch name cannot substitute for that pinned public commit. Leave release unchanged during acceptance.
5. Run the native import, graph checks, GitHub acceptance script and relevant model/app flows. Record the tested code/data commit, manifest hash, database/application versions and actual results. If a fix is needed, change and retest dev with its new full commit SHA. A successful push or local test suite does not prove native operation.
6. After dev acceptance passes, build the reviewed release distribution. Rehearse its clean and supported migration paths independently through Database Actions, including ordered parts, runtime setup and same-ID APEX upgrade. Record exact source/package/data hashes, preserved existing work and actual browser coverage in `db/verification/release-v2-paths-validation.json`. Only then update a dedicated `release` checkout with the accepted package. Remove only files tracked in that release checkout before copying the new package, so removed distribution files cannot linger. Do not copy the development tree or private `work/` files wholesale. Inspect `git status`, the staged diff, manifest and validation record before committing.
7. For publication-only corrections to an accepted package, commit the reviewed dev inputs first, then run `python scripts/build_release.py --prepare-publication --accepted-release-commit FULL_ACCEPTED_RELEASE_COMMIT --output work/release-publication` using a new output folder. Supply the full 40-character local release commit containing the accepted package; it need not already be pushed. This requires a clean dev tree and a same-version record with passed clean/migration routes and no pending route checks. The builder compares every non-document payload hash with that commit's manifest, allowing only regenerated publication metadata and the exact reviewed GitHub caller header correction. It records the comparison and `prepared_for_publication` status without claiming a push, tag or new native test. The default build remains a candidate. Changed runtime requires new relevant acceptance and a new reviewed package baseline; an older passing record alone is insufficient. Preserve historical validation records unchanged. Review the documentation/comment-only differences and every manifest hash, then commit the curated release tree.
8. Push release only after that acceptance and distribution review and when publication is authorized. Set `release` as the repository's default branch in GitHub, retain `dev` for contributors, and configure branch rules/review requirements to control updates. Learners pin the resulting release commit. These are remote settings; local branches do not enforce them. No remote, push, tag or branch protection is created by the package builder.

Do not merge `dev` wholesale into `release`: it restores developer files. Do not merge the release's file-removal commit wholesale into `dev`: it removes the tools. Port individual fixes on dev and regenerate the distribution. Branch names are case-sensitive.

The release manifest hashes all payload files except itself. Compare those hashes when preparing a release; the manifest is not a signature or a substitute for native acceptance. New version tags follow the acceptance gates below; the initial baseline tag identifies the already-published state without asserting new testing.

## Product versions and Git tags

Use **major.minor.patch**, with public annotated tags named `vMAJOR.MINOR.PATCH`. The agreed baseline is **v1.0.0** and the planned My Contexts delivery is **v2.0.0**. This project's policy explicitly permits a major increment for significant functional uplift as well as backward incompatibility; version numbers are not a substitute for compatibility notes.

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
| Future accepted release | Not yet created | Target for `v2.0.0` after the My Contexts implementation and learner acceptance gates pass. |

On 24 November 2026, annotated tag `v1.0.0` was created and pushed. Its tag object is `aa60df23294503f2f0bb38c69a76c5ec6707e1fd` and its peeled commit was verified as `83e3ecb64f417f6ef388df43ab9b102dddab2b71`. The release branch stayed on that commit. `v2.0.0` remains a future target. Recheck remote tags before creating new ones and reject an existing name pointing to a different commit. The baseline label describes the already-published implementation and its existing validation record; it does not assert that new tests have run.

Git tags identify commits across the repository, not separate branch-local versions. `vX.Y.Z` identifies the curated **release** commit. Record the exact accepted **dev** source SHA in the release manifest/validation provenance instead of trying to apply the same tag to two different commits. Dev contributors can check out that source SHA to recover the matching tools and authoring sources.

Use annotated, immutable tags. Never move or force-push a published version tag; publish the next appropriate version for a correction. Work in progress is identified by its full commit SHA and marked as an unreleased target version. If candidate tags become useful, use distinct prerelease names such as `v2.0.0-rc.1`; these do not claim final acceptance.

### Implementation and publication sequence

1. Record/tag the exact existing baseline when executing the tagging work. Creating or pushing tags is a separate Git operation; editing this policy does neither.
2. Implement version metadata in the dev source/build: one maintained product version, release notes, manifest source SHA, migration compatibility range and app artifact hash. Keep build/acceptance status explicit so `2.0.0` in candidate metadata cannot imply a published release.
3. Accept the dev implementation, generate the learner distribution and independently accept its fresh Worksheet installation and supported upgrade from `v1.0.0`. Confirm the same-ID APEX upgrade preserves owned contexts/history. Record the exact source/data/app hashes and supported compatibility.
4. Produce the reviewed release commit and verify its tree matches the accepted candidate. Create the annotated `v2.0.0` tag against that exact commit with upgrade/release notes, then publish the branch/tag through the normal controlled Git workflow.
5. Continue pinning the GitHub dataset loader to a full 40-character commit SHA plus the manifest hash. A convenient version tag does not replace the loader's existing integrity/reproducibility contract.

The GitHub importer and expanded summary dataset passed the [recorded native SQL acceptance](../references/github-dataset-validation.json) on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`, including the four supplied verification scripts and two-session lock exclusion. A subsequent [GenAI and signed-in APEX acceptance](../references/expanded-ui-validation.json) passed with the regenerated app export and corrected citation parser, identified by artifact hashes. Interrupted loading, a fresh learner deployment and execution from a promoted release commit remain separate checks. These results do not automatically promote or push release.
