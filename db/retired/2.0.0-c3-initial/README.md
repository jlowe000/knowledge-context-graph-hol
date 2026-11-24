# Retired, unaccepted C3 suffix

This directory records the first C3 candidate's failed native compilation. It is audit evidence, not an alternative installation route.

The update completed the original 48 project migrations and the first fourteen C3 migrations. `2.0.0-c3-015-kcv_scenario-package-body` then failed with ORA-24344: its local identifier `PRIOR` is reserved by Oracle. The remaining three entries were never executed. The corrected body uses `PRIOR_RUN`.

`manifest.json` preserves the exact initial candidate. `retirement.json` records its hash, the immutable 62-entry applied prefix, hashes of all applied wrappers including the bootstrap, and the four retired entries with their original payload, verifier, wrapper and recovery artifacts. Those artifacts remain at their original paths for comparison. **Do not execute the retired payloads, wrappers or recovery scripts.**

The active manifest installs distinct `2.0.0-c3-r1-*` replacements. Fresh installations never execute the defective body. On the affected development installation, the original failed receipt remains unchanged, including its error and timestamps; it is not marked complete. The exact known FAILED record is allowed as audit evidence, or it may be absent on a fresh installation. Any other retired receipt state or a Liquibase executed entry for a retired ID is rejected.

This retirement does not rewrite any of the 62 completed migrations, remove runtime rows, clear checksums, or certify the replacement. The separate C3 validation record states what has actually been tested.
