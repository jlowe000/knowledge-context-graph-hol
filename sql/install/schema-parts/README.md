# Ordered schema installation parts

Choose **fresh** for an empty project schema. Choose **upgrade** only after the existing v1 schema has passed the documented optional-baseline completion and `../00_adopt_schema_baseline.sql` checks, or when it already has valid migration receipts. Do not run both routes.

Open each numbered `.sql` file in the chosen directory in order. Run its complete contents with SQL Worksheet **Run Script (F5)** as the project schema owner. Stop on any error. Each file is one outer PL/SQL block so later steps in that file do not execute after a failure. DDL can already have committed: inspect the receipt and use the documented recovery process before retrying. The last part performs full schema verification. Do not also run the combined installer.

`manifest.json` records exact order, step IDs, file sizes, SHA-256 hashes and success markers. The grouping target is one MiB, not a hard ceiling. Complete verification/migration blocks larger than that remain intact. Generation alone does not establish browser upload limits or native execution acceptance. See the release validation record.
