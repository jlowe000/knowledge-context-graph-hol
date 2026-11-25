# Reconcile an interrupted migration receipt

These are facilitator recovery scripts, not installation steps. Diagnose the failed migration first. Run only its matching file as the project schema owner after the intended physical objects are complete. The script verifies exact postconditions and hashes before reconciling a receipt. It does not rerun missing DDL or clear a live migration lock. Never manually mark a migration complete, reset checksums, or run all recovery files. Then retry the failed installation part and finish the normal verification.
