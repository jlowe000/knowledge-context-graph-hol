# Ordered schema installation parts

Choose **fresh** for an empty project schema. Choose **upgrade** only when starting from the verified published v2.0 baseline with valid migration receipts. A v1 installation must first follow the pinned published v2.0 bridge; direct v1-to-v2.1 acceptance is not claimed. Do not run both routes.

Within the chosen route, select **one execution form**: upload the complete [combined clean installer](../00_install_schema.sql) or [combined upgrade installer](../01_upgrade_schema.sql), as appropriate, or use the corresponding numbered parts below. Both forms contain the same ordered canonical steps; the combined file keeps them in one outer failure-stop block. Use Worksheet **Open File** to load the entire SQL file and **Run Script (F5)** as the actual project owner. Combined files reduce file handling, but their size and actual Worksheet execution must be checked for the specific release; generation is not transport acceptance.

If an upload is rejected **before execution**, the other form remains an option. Once migrations have started, or execution is uncertain, inspect receipts and the recovery guidance before changing forms or retrying. Do not run the other form as an extra installation.

Open each numbered `.sql` file in the chosen directory in order. Run its complete contents with SQL Worksheet **Run Script (F5)** as the project schema owner. Stop on any error. Each file is one outer PL/SQL block so later steps in that file do not execute after a failure. DDL can already have committed: inspect the receipt and use the documented recovery process before retrying. The last part performs full schema verification.

`manifest.json` records exact order, step IDs, file sizes, SHA-256 hashes and success markers. The grouping target is one MiB, not a hard ceiling. Complete verification/migration blocks larger than that remain intact. Generation alone does not establish browser upload limits or native execution acceptance. See the release validation record.
