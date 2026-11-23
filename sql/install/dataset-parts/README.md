# Load the dataset in SQL Worksheet

This folder contains 6 ordered SQL files. Each file is at most 2,000,000 bytes and ends between complete SQL or PL/SQL units.

1. Sign in to Database Actions SQL Worksheet as `KCV_LAB` after completing the schema setup.
2. Open `001.sql`, paste or load its complete contents, and choose **Run Script (F5)**.
3. Check Script Output for errors, then run each remaining numbered file in order. Keep the same database user; the batch state is stored in the database.
4. The final part checks completeness and switches the active graph only after successful loading.

Run only one dataset load at a time. If any part reports an error, stop. Resolve the error and rerun all parts starting with `001.sql`; do not resume halfway through the sequence. Successful batches commit. The previous active graph remains active until the final completeness check passes.

The complete `../10_load_dataset.sql` remains available for clients such as SQLcl. Choose either the complete script or the numbered files for a load, not both.

`manifest.json` records order, byte sizes, hashes and SQL-unit ranges. Packaging verification does not establish successful execution on an Autonomous Database.

Contains attributed editorial summaries, not extracted source text.
