# Branches and release control

| Branch | Audience | Contents |
| --- | --- | --- |
| `dev` | Contributors and maintainers | Full source, Python preparation/build utilities, tests, optional tools, release packaging and contributor setup |
| `release` | Learners and application users | SQL/PLSQL, prebuilt APEX installers, attributed summary dataset and learner documentation; no Python/shell tooling |

The branches share an initial history. `release` is a curated distribution tree, not a merge target for every development file. Tools remain public and accessible by selecting `dev`. A branch does not restrict who can use already public code.

## Maintainer promotion

1. Work on `dev`; update SQL, UI sources, tests and the common labs. Maintain learner-only wording in `release-docs/`.
2. Run the contributor checks and build a new package as described in [development setup](development.md).
3. Inspect its file manifest, source summaries, generated SQL and complete beginner path. Scan publication candidates for credentials and inspect screenshots.
4. Update a dedicated `release` checkout with the package. Remove only files tracked in that release checkout before copying the new package, so files removed from the distribution cannot linger. Do not copy the development tree or private `work/` files wholesale.
5. Inspect `git status` and `git diff --cached` in that checkout; run native SQL checks and the app flow on an approved fresh test database. Commit the reviewed release snapshot. Record target versions and results in its validation document.
6. Push only when ready. Set `release` as the repository's default branch in GitHub, retain `dev` for contributors, and configure branch rules/review requirements to control updates. These are remote settings; local branches do not enforce them. No remote, push or branch protection is created by the package builder.

Do not merge `dev` wholesale into `release`: it restores developer files. Do not merge the release's file-removal commit wholesale into `dev`: it removes the tools. Port individual fixes on dev and regenerate the distribution. Branch names are case-sensitive.

The release manifest hashes all payload files except itself. Compare those hashes when preparing a release; the manifest is not a signature or a substitute for native acceptance. Use version tags only after the desired acceptance checks pass.
