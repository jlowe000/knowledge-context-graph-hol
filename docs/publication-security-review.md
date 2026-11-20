# Public repository credential review

Reviewed 19 November 2026. Scope: the standalone project's Git publication candidates (`git ls-files --cached --others --exclude-standard`), not its parent research repository or ignored working directories. Nothing was committed or published during this review.

**Result: no private keys, actual passwords, API tokens or other credential values were found in the publication candidates.**

- Scanned 155 files (including seven binary images) for private-key material, common provider-token signatures, JWTs, credential-bearing URLs, suspicious credential assignments, OCI resource identifiers and the known private database host. Assignment matches were reviewed: they are bind variables, environment lookups or explicit placeholders.
- Checked the supplied APEX export, including 743 hex literals decoded in memory. Its password field and login process reference runtime input; they do not embed a password or stored OCI credential. Application/workspace IDs and schema names are deployment metadata, not authentication secrets.
- Visually reviewed both application screenshots. They show public source information, fictional learner context and generic lab account/revision identifiers; no credential or private endpoint is visible. No EXIF/XMP or PNG text metadata markers were found in the seven images.
- The optional environment example contains placeholders only. SQL uses private bind inputs for database/APEX passwords and the OCI signing key. The credential name `OCI_USER_CRED` is a reference, not its secret contents.
- Confirmed `.env`, private `config/*.env`, working/generated Worksheet SQL, virtual environments and wallet/key formats are excluded. Expanded exclusions for additional key, wallet and environment-file formats. `config/example.env` remains intentionally included.
- Git had zero commits, no staged files and no configured remote at review time, so there was no committed history to inspect for previously removed secrets.

This records a review of the current snapshot, not a guarantee about future edits or files added with `git add --force`. Ignored `work/` content and local credentials must stay outside publication. Repeat the check against the final staged changes before the first public push, including any new screenshots, exports or configuration files.
