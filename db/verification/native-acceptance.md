# Native migration acceptance record template

Status: pending. Fill results only after execution against a deliberately isolated project schema. Keep connection details, runtime records and raw logs outside Git. A successful local generator test is not a native pass.

Record the source commit or working-tree hashes, `VERSION`, manifest SHA-256, generated SQL hashes, SQLcl/Liquibase versions, database/APEX versions, and whether the target is local component testing or ADB Serverless. Do not publish endpoint, account, wallet or credential details.

| Check | Expected result | Actual result |
| --- | --- | --- |
| `environment.sql` as dedicated owner | Required grants and length semantics; ADMIN rejected. | Pending |
| `lb validate -changelog-file db/changelog.xml` | Changelog accepted by the pinned SQLcl/Liquibase runner. | Pending |
| Fresh root `lb update` | 36 baseline, twelve C2 and twenty-one active C3/r1/r2 receipts complete; all expected programs VALID and no `USER_ERRORS`. | Pending |
| Second root update | No pending changes; complete verifier still passes. | Pending |
| Existing v1 adoption | Structural/source checks pass before recording only baseline receipts. | Pending |
| Adopted installation update | Baseline wrappers verify/no-op and Liquibase records them normally; only pending C2/C3 DDL/programs installed. | Pending |
| Existing C2 installation update | Original 48 receipts/wrapper checksums unchanged; 21 new active steps complete; existing runtime rows retained. | Pending |
| Legacy NULL request-token probe | Multiple existing NULL-token responses survive indexing; duplicate non-NULL per-session requests are rejected; reserved probe removed. | Pending |
| Worksheet fresh install | Same postconditions and payload digests as Liquibase. | Pending |
| Worksheet baseline adoption/upgrade | Same final schema without fabricated Liquibase ledger rows. | Pending |
| Worksheet installation subsequently opened through Liquibase | Verified wrappers no-op; superseded historical steps require exact successor proof; pending migrations remain pending until executed. | Pending |
| Partially completed successor | Old Worksheet and final checks reject drift; corrective changes resume deliberately. | Pending |
| Existing Liquibase history after appending correction | Applied checksums remain valid without clearing or rewriting ledger rows. | Pending |
| Wrong source/table definition | Verification rejects mismatch rather than inferring compatibility from object names. | Pending |
| Invalid package in isolated probe | Package error detected; migration does not receive COMPLETE; later changes stop. | Pending |
| Interrupted operation in isolated probe | RUNNING/FAILED receipt visible; blind rerun rejected. | Pending |
| Physically complete interrupted operation | Matching recovery verifies postconditions and digest under the migration lock, then reconciles. | Pending |
| Physically incomplete operation | Recovery fails and keeps incomplete state. | Pending |
| Second migration runner while first holds lock | Clear exclusion; no unrecorded concurrent DDL. | Pending |
| Modified published-payload fixture | Builder/hash validation and Liquibase checksum protection reject it. | Pending |
| Existing sample data/evidence | Counts and recorded evidence unchanged by additive upgrade. | Pending |

For failure probes, prepare a separate disposable fixture migration/schema instead of corrupting the accepted candidate or existing lab. Do not weaken the real manifest, turn off error checking, clear checksums, release a live lock, or insert a successful receipt manually. Record the actual observed Oracle errors and recovery actions privately, then summarize without private identifiers.

The C3 candidate changes existing package contracts and adds columns to chat/response tables. Record the application maintenance interval, successor-aware baseline gate and preserved runtime row counts before native acceptance. This table is a reusable template; the separate C2 record remains historical evidence, not a C3 pass.

The initial C3 candidate failed after fourteen steps. Replacement acceptance must also prove that all 62 completed wrappers remain unchanged, the exact retired FAILED receipt remains unchanged, and no retired ID enters Liquibase history. Fresh schemas have no retired receipts. See `../retired/2.0.0-c3-initial/retirement.json`.
