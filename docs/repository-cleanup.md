# Dev repository cleanup review

Reviewed 24 November 2026 against the uncommitted v2 My Contexts candidate. This is a repository housekeeping record, not a database teardown or release promotion. The running application and the linked release worktree were not changed.

## Removed

| Item | Reason |
| --- | --- |
| `apex/region.html` | Obsolete HTML snapshot. APEXlang pages under `apex/application/` are authoritative and the asset helper no longer reads this file. The authoring test still creates its own obsolete fixture to prove that it cannot overwrite a page. |
| `db/changes/2.0.0-c3/table-contracts.json` | Unreferenced scratch snapshot. Its five contracts duplicate the JSON already embedded in the immutable C3 table verification scripts. It is outside the active and retired migration hash records. |
| Seven ignored one-off scripts under `work/` | Old UI string-rewriting helpers and dated release-promotion helpers are superseded by maintained APEXlang sources and the current build scripts. |
| Four ignored download staging directories and four Python cache directories | Removed approximately 681 MB of downloaded Java/SQLcl archives, checksums and bytecode. Installed tools and saved connections were retained. Tests may recreate ignored bytecode caches. |

The removed one-off scripts were `build_epics_ui.py`, `ui-author-c3.py`, `ui-assets-c3.py`, `ui-collection-c3.py`, `ui-operations-c3.py`, `promote_content_release.py` and `promote_github_release.py`, all under ignored `work/`.

## Retained deliberately

- **Migration history:** every active payload, verifier, generated wrapper and recovery script, plus the explicitly retired C3 suffix. Their hashes and order are part of upgrade verification. Do not remove them simply because a later migration supersedes their implementation. See [database migrations](database-migrations.md).
- **Historical validation:** C2, C3 and R1–R4 records document different checks and failures. They are evidence, not alternative current setup instructions.
- **Runtime registration:** refresh script 16 is required for current grounded answers. Script 15 records the earlier R3 route; script 09 remains part of the v1 lab/release material. Old refresh scripts are not additional steps in the current R4 setup.
- **Build tools and integration tests:** the maintained Python and Bash tools still build data, SQL installers, deployment packages or test distinct behaviour. No maintained PowerShell scripts remain.
- **APEX artifacts:** editable JS/CSS and their synchronized static-file copies are both required. The native SQL export and its validation receipt support SQL Worksheet deployment.
- **Public generated data:** `generated/`, `data/load/` and `db/generated/` contain versioned deliverables, not disposable caches. Do not ignore these directories wholesale.
- **Release learning templates:** `release-docs/` remains input to packaging the separate SQL-first learning experience. It does not mean v2 has been promoted to release.
- **Private local material:** research downloads, extracted passages, reviewed export stages, migration baselines, test evidence and connection material remain ignored. No bulk deletion of `work/`, wallets or saved connections was performed.

## Documentation and ignore rules

Current dev instructions point to the R4 migration/APEXlang route and scoped personal/sample regression checks. Older v1 lab instructions, plans and screenshots are identified as historical where appropriate. Their existence must not be taken as fresh-v2 deployment acceptance; the [candidate record](../references/my-contexts-c3-validation.json) lists outstanding checks.

The ignore rules now cover SQLcl `.sqlcl/` and `.dbtools/` directories, logs, wallet ZIPs with either initial case, wallet directories, `tnsnames.ora`, `sqlnet.ora` and `ojdbc.properties`. Existing exclusions for `work/`, private environment files, keys and generated private artifacts remain. Required SQL, public datasets and `config/example.env` were checked to remain visible to Git.

For the publication-file and history privacy audit, see [the security review](publication-security-review.md). Ignore rules protect ordinary Git adds; they do not make private local files public-safe or prevent an explicit forced add.

## Verification

The 29 migration tests and 10 APEX authoring tests passed after removal. All 80 migration payloads and generated installers still passed integrity checks; APEX asset/source checks, 38 documentation snippets, local document links and diff whitespace checks also passed. The privacy scan covered all 646 resulting publication candidates and 20 reachable local Git commits. No database changes, commits or pushes were made during cleanup.
