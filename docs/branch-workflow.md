# Branches and release control

| Branch | Audience | Contents |
| --- | --- | --- |
| `dev` | People building their own adaptation, contributors and maintainers | Source/model/ontology/retrieval/UI changes, preparation/build tools, tests, a publishable summary package for native acceptance and a build-your-own journey |
| `release` | App users and developers learning the knowledge collection | Separate app-use and developer-learning journeys, optional sample deployment, SQL APIs, model/ontology, prepared dataset and app |

The distinction is the intended learning outcome, not simply tooling or developer skill level. Release teaches using and understanding this supplied collection; dev teaches adapting its content, model and implementation into your own version. An app user can start in a hosted deployment without provisioning resources. A developer can study/query the collection on release without changing its build pipeline. See [build your own](build-your-own.md) for the adaptation journey.

The branches share an initial history. `release` is a curated distribution tree, not a merge target for every development file. Tools remain public and accessible by selecting `dev`. A branch does not restrict who can use already public code.

## Maintainer promotion

1. Work on `dev`; update SQL, UI sources, tests and the common labs. Maintain the app-use, developer-learning and optional deployment routes in `release-docs/`.
2. Run the contributor checks and build the summary-only `data/load/` package plus `sql/install/10_load_github.sql` in dev, as described in [development setup](development.md#publish-and-test-the-github-dataset-on-dev). Build a separate release candidate to inspect its learning routes, but do not publish release yet.
3. Inspect the manifests, summaries, loader and publication candidates. Keep source documents, extracted passages, `work/`, credentials and private audit details excluded. Verify that app users can start without cloud/database setup, developers can trace the collection through SQL/APEX, and adaptation/build instructions stay on dev.
4. Commit and push the reviewed **dev** candidate. Use its full 40-character commit SHA and matching manifest hash for the real GitHub load on the approved temporary ADB Serverless instance. A local package or branch name cannot substitute for that pinned public commit. Leave release unchanged during acceptance.
5. Run the native import, graph checks, GitHub acceptance script and relevant model/app flows. Record the tested code/data commit, manifest hash, database/application versions and actual results. If a fix is needed, change and retest dev with its new full commit SHA. A successful push or local test suite does not prove native operation.
6. After dev acceptance passes, build the reviewed release distribution and update a dedicated `release` checkout with that package. Remove only files tracked in that release checkout before copying the new package, so removed distribution files cannot linger. Do not copy the development tree or private `work/` files wholesale. Inspect `git status`, the staged diff, manifest and validation record before committing.
7. Push release only after that acceptance and distribution review. Set `release` as the repository's default branch in GitHub, retain `dev` for contributors, and configure branch rules/review requirements to control updates. Learners pin the resulting release commit. These are remote settings; local branches do not enforce them. No remote, push or branch protection is created by the package builder.

Do not merge `dev` wholesale into `release`: it restores developer files. Do not merge the release's file-removal commit wholesale into `dev`: it removes the tools. Port individual fixes on dev and regenerate the distribution. Branch names are case-sensitive.

The release manifest hashes all payload files except itself. Compare those hashes when preparing a release; the manifest is not a signature or a substitute for native acceptance. Use version tags only after the desired acceptance checks pass.

The new GitHub importer and expanded summary dataset currently retain pending native acceptance. Publishing their dev candidate makes that testing possible; it is not a claim that they have passed.
