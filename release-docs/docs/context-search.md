# Search your saved contexts

In **My Contexts**, search a title, phrase or description of what you want to learn. Results belong to the signed-in account and respect All/Draft/Active/Archived. **Saved objective** shows up to 240 normalized characters, ending in `...` if truncated; **Why it matched** distinguishes title, saved-information and similar-meaning matches. A missing objective stays blank.

Search uses the latest saved title/details, including question, objective, background, unknowns, constraints and topics. It excludes conversation transcripts, observations and old revisions. Unsaved edits are not searchable. Clearing the query restores recently updated contexts without generating a query embedding.

## Meaning, wording and privacy

Text matches combine with optional embeddings from `KCV_CONTEXT_MINILM`, running inside Oracle Database. Saving/copying/applying refreshes private derived chunks. Search sends no context text to an external embedding or chat service. Asking a conversation question is separate and sends its context/evidence to the configured model service.

The model is an English short-text encoder. Other-language text matching remains available; multilingual semantic quality is not promised. Chunking covers the saved details, but a similar result is not evidence of business value. Public source retrieval remains the separate topic/graph join described in [architecture](architecture.md).

| Notice | Meaning |
| --- | --- |
| Hybrid search | Text and current local embeddings are available. |
| Partial semantic coverage | Some current chunks lack embeddings; text matches remain available. |
| Keyword matches only | The local model/query embedding is unavailable. |

Search ordering is recomputed for each request. Unchanged results paginate consistently; concurrent edits can reorder them. A still-owned context that no longer matches the cursor query resets the page with a notice. Foreign, deleting or deleted context IDs remain unavailable. The app computes search once per page request and reuses its response for display/pagination.

## Worksheet setup

This is a deployment/maintenance task, not something each app user performs. The ordered schema installation or migration must already be verified. Use the same owner chosen in [installation](installation-paths.md). Model weights are obtained separately and are not distributed in the repo; see [attribution](../third-party/context-search-model/README.md).

1. As **ADMIN**, run the block in [11_context_search_grants.sql](../sql/admin/11_context_search_grants.sql) with **Run Statement**, excluding its slash. Supply `KCV_SCHEMA`. Expect `KCV_CONTEXT_SEARCH_GRANTS_READY` for the intended owner. It grants CREATE MINING MODEL and execution of DBMS_VECTOR to this owner; it does not grant arbitrary network access.
2. Obtain the direct augmented `all_MiniLM_L12_v2.onnx` location from [Oracle's model instructions](https://blogs.oracle.com/machinelearning/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai). Use the augmented ONNX file, not a ZIP or generic model export. Keep access-bearing download URLs out of Git, screenshots and logs.
3. Sign into the **owner's Worksheet**, not ADMIN. In [22_setup_context_search.sql](../sql/extensions/22_setup_context_search.sql), run the complete setup PL/SQL block with Run Statement, excluding its trailing slash; enter the URL privately for `KCV_MODEL_URI`. Wait for success before running its separate coverage SELECT.
4. Expect `CONTEXT_SEARCH_MODEL_READY=384` and `CONTEXT_SEARCH_BACKFILL=COMPLETE; inspect coverage below`. Inspect counts by embedding_status. READY counts chunks, not contexts. No rows is valid before any personal contexts have been saved.

The script verifies newly downloaded bytes against its pinned SHA-256 and checks 384-dimensional output. A mismatch requires artifact review, not bypassing the check. An existing model is retained and dimension-tested; the script does not certify its original bytes or replace it automatically. Backfill commits private derived data; use a session without unrelated uncommitted work.

## Check the result

Save a synthetic context with a meaningful objective. Try its exact title, objective wording and a related description; inspect match reason and coverage. Verify filters and clear the query. When testing isolation, use separate app accounts, not two browser tabs sharing a login.

If setup fails, retain the error code privately and check the intended owner, grants, supported artifact, checksum and HTTPS reachability. Model download authentication is distinct from chat IAM. Re-run only the corrected setup after review; do not recreate the public collection or chat credential. Without a usable local model, keyword search remains the supported fallback.

The derived chunks are private runtime data and are not included in public dataset loading or publication. Permanent context deletion removes them through the schema relationship. Review [validation status](scenario-validation.md) for which deployment and browser cases were actually exercised.
