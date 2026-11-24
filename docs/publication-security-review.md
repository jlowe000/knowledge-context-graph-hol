# Public repository privacy and credential review

Reviewed 24 November 2026 against the uncommitted v2 dev candidate. Scope: every existing tracked or untracked file eligible for an ordinary Git add (`git ls-files --cached --others --exclude-standard`), plus all blobs reachable from the local Git refs. The parent research repository and ignored private working directories are outside the public-file scan. No commit, push, history rewrite or release promotion was performed.

**Result: no live credentials, private keys, private database endpoints or real internal source URLs were found in the reviewed publication files or reachable history.** This is a bounded review of the current snapshot, not a guarantee about all possible secrets or future edits.

## Coverage and reviewed matches

- The initial scan covered 647 publication candidates, approximately 73 MB, including seven binary images. After cleanup, the final scan covered all 646 remaining publication candidates. All matches were reviewed as described below.
- Local history contained 20 reachable commits and 403 unique blobs, approximately 77 MB uncompressed. No remote refresh, dangling-object scan or external service audit was performed.
- Pattern checks covered private-key material, common provider tokens, JWTs, credential-bearing URLs, credential literals, private OCI resource identifiers, private database hosts, internal source URLs, local user paths and known synthetic runtime markers. Matches were reported privately by path/rule/line, without printing values.
- Credential-looking assignments were explicit placeholders. SharePoint, OneDrive, Seismic and URL-credential matches were fabricated rejection-test fixtures in `tests/`, not real source links or credentials. These tests remain to prevent private URLs from becoming publishable content.
- Runtime-shaped hexadecimal matches in the application SQL exports were embedded image bytes. The current native export's seven embedded assets match the reviewed authored files. Neither the export nor the publication data includes the private browser test conversation.
- The two lab screenshots were visually reviewed: they contain public source information, a fictional learner, a generic lab account name and synthetic revision identifiers. No password, credential dialog, private endpoint or browser address bar is visible. They illustrate the earlier v1 interface and are labelled accordingly in dev guidance.
- No EXIF/XMP or PNG text-metadata markers were found in the seven images. The other five images are the attributed application icons.
- Public author/source attribution, generic workspace/schema/application identifiers, sample learner names and references such as `OCI_USER_CRED` are intentional. A credential's name is not its secret value. APEX login components obtain passwords at runtime; they do not embed them.

## Private local files stay private

Local wallet material, private connection configuration, test logs, extracted research and deployment helpers are intentionally retained outside publication. They are not certified as safe to share. No tracked file was found under `work/`, the wallet directory, `.sqlcl/` or `.dbtools/`.

The ignore rules were checked for `work/`, `.sqlcl/`, `.dbtools/`, logs, wallet directories and wallet ZIPs, private environment files, key formats, `tnsnames.ora`, `sqlnet.ora`, `ojdbc.properties` and generated private artifacts. Required public SQL installers, `db/generated/`, `data/load/`, the native APEX export and `config/example.env` remain visible to Git.

The detailed audit output and one-off scanning helpers remain under ignored `work/repository-audit/`; only this value-free review is intended for publication. An ignored directory can still be exposed by a forced add, filesystem archive or manual upload. Share a reviewed Git checkout or explicit release package, not a ZIP of the entire local project folder.

Repeat the review against final staged changes before publication, especially after adding screenshots, exports, configuration or new data. See [the cleanup review](repository-cleanup.md) for retained artifacts and [the candidate validation](../references/my-contexts-c3-validation.json) for functional test limits.
