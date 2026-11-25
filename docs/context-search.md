# Search your saved contexts

Status: R7 development candidate. [Native upgrade/repeat, search regressions and scoped browser checks passed](../db/verification/context-search-validation.json). R6 introduced the derived search data; its long multibyte token test exposed `ORA-12733`. R7 corrects that matching path and marks truncated objective previews. Model loading and schema/application installation are separate steps. Fresh R7 and generated Worksheet execution remain unverified; the published release is unchanged.

## What is searched

In **My Contexts**, enter a title, phrase or natural-language description in **Search your contexts**, choose a status if useful, then choose **Search**. Results belong to your signed-in application account. Each row shows its saved objective preview and why it matched. An empty query returns the usual most-recently-updated list; it does not ask a model to invent a starting point.

Search uses the latest **saved draft title and context details**, including the question, objective, background, role/organisation, learning purpose, unknowns, constraints and selected topics. Unsaved form edits are not searchable. Conversation transcripts, answer evidence, observations and earlier revisions are not added to this search document. Finding a context does not apply its draft, change its graph revision or ask a conversation question.

The project combines text matching with semantic similarity computed by a model inside Oracle Database. This is a way to find your saved work, not evidence that a context or suggested action has greater business value. Status and account ownership apply before ranking. Shared samples remain separate until **Save as my draft** creates an owned context.

## How results are selected

The canonical document contains labelled saved fields and sorted topic labels. It is split into 480-character segments with 64 characters of overlap. Text matching checks the current saved representation; semantic matching uses only chunks whose content hash and model key match it. The best matching chunk supplies each context's cosine similarity, with a minimum threshold of 0.30. Exact title and title-phrase matches have priority, then reciprocal-rank fusion combines the text and semantic rankings with a constant of 60. Update time and context ID break ties. These are current retrieval choices, not relevance guarantees.

Saving, copying, duplicating or applying a context refreshes its derived search rows in the same application transaction. Unchanged content and model reuse current chunks. Archiving changes visibility through the status filter without embedding the same text again. Contexts being permanently deleted are excluded from search; unfinished deletion remains accessible through its dedicated library status/retry flow.

A populated search is evaluated once per page request, including at most one local query embedding. The page reuses that response for results, the next cursor and the visible search notice. Another explicit search or pagination action evaluates the current saved state again. Pagination follows the current ranked context ID; concurrent edits can reorder results. If a still-owned, available anchor no longer matches the query/filter, the page returns to the first results and explains the reset. Deleted, deleting or other-account cursor IDs are rejected. Clearing the query returns to recency browsing.

| Search notice | Meaning |
| --- | --- |
| Hybrid search | Both text and current local embeddings are available. |
| Partial semantic coverage | Text search covers the saved representation, but some contexts/chunks lack current embeddings. |
| Keyword matches only | The local model/query embedding is unavailable; results use text matching. |

The row's **Why it matched** label distinguishes title, saved-information and similar-meaning matches. Its objective preview normalizes whitespace and is capped at 240 characters: a longer objective shows its first 237 characters followed by `...`. A missing objective remains blank; the app does not invent or summarize it with AI.

## Local model and privacy boundary

`KCV_CONTEXT_MINILM` is the project-local name for a 384-dimensional model loaded from Oracle's augmented `all-MiniLM-L12-v2` ONNX distribution. Oracle supplies a pipeline that includes the preprocessing and postprocessing needed to accept text in the database. [Oracle model preparation and loading guidance](https://blogs.oracle.com/machinelearning/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai).

The search path embeds the query and saved context text **inside the database**. It does not send that text to an external embedding endpoint, call a chat/GenAI team or use the existing OCI inference credential. The one-time model download brings model bytes into the database; it does not upload a context. Asking a question in the separate conversation workspace still uses its configured model service.

Search chunks, text, vectors and errors are private, rebuildable runtime data. Treat them with the same access controls as the context they represent; vectors are not a promise of anonymisation. They are excluded from the public knowledge dataset and application supporting-data export. Permanent context deletion also removes its search rows; archiving retains them so the Archived filter can find the context.

The base model is an English sentence and short-paragraph encoder with an input-length limit. The implementation splits the saved representation into overlapping segments to cover longer drafts; similarity is still approximate and needs evaluation for your terminology and language. See the [model card](https://huggingface.co/sentence-transformers/all-MiniLM-L12-v2) and [external-model attribution](../third-party/context-search-model/README.md). No ONNX file or model weights are distributed in this repository.

## Configure the model after schema installation

Use the current dev migrations to install the search table/package before this runtime step. Do not run raw `CREATE TABLE` files over an existing installation. Use the [private local SQLcl setup](dev-connection-setup.md); the launcher disables SQLcl history. Model setup does not alter the existing GenAI profile, credential or registered scenario teams.

### 1. Grant the named owner permission as ADMIN

In a direct ADMIN session, supply the existing build owner, such as `KCV_V2_001`, and run [11_context_search_grants.sql](../sql/admin/11_context_search_grants.sql). Use the new owner's name for a replacement build; see [build naming](dev-build-lifecycle.md#naming-and-identity).

```sql
VARIABLE KCV_SCHEMA VARCHAR2(30)
EXEC :KCV_SCHEMA := 'KCV_V2_001';
@sql/admin/11_context_search_grants.sql
```

Expected: `KCV_CONTEXT_SEARCH_GRANTS_READY` The script grants `CREATE MINING MODEL` and execution of `SYS.DBMS_VECTOR` to that schema. It does not create a model, directory, external credential or network ACL. Existing owner prerequisites still include its permitted `DBMS_CLOUD` use.

### 2. Obtain the augmented model location privately

Follow Oracle's [prebuilt model instructions](https://blogs.oracle.com/machinelearning/use-our-prebuilt-onnx-model-now-available-for-embedding-generation-in-oracle-database-23ai) to obtain the direct HTTPS location of **`all_MiniLM_L12_v2.onnx`**. Use the augmented model, not a generic unprepared ONNX export or the ZIP archive itself. Retain and review the notices accompanying the chosen download.

The setup pins newly downloaded bytes to SHA-256:

```text
3929907d138051f818619fce3ba054185f748f2739d7a4dbc26e2502dd2499ea
```

Keep a populated download URI in the private session or ignored local work only, especially if it is an Object Storage pre-authenticated request. Do not add it to documentation, source, screenshots or public execution logs. The repository links to the official instructions rather than embedding an access-bearing download URL.

### 3. Load and verify as the project owner

Connect with the saved **owner** alias, not ADMIN or an APEX page session. Set the non-published URI bind, then invoke [22_setup_context_search.sql](../sql/extensions/22_setup_context_search.sql). Replace the placeholder below privately:

```sql
WHENEVER SQLERROR EXIT SQL.SQLCODE
VARIABLE KCV_MODEL_URI VARCHAR2(4000)
EXEC :KCV_MODEL_URI := '<direct augmented .onnx HTTPS URL>';
@sql/extensions/22_setup_context_search.sql
```

The script downloads into a BLOB, verifies the checksum and calls `DBMS_VECTOR.LOAD_ONNX_MODEL` when the named model is absent. That supported BLOB overload accepts a model without separate external initializer files. [LOAD_ONNX_MODEL reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/load_onnx_model-procedure.html).

If the model already exists, setup retains it and checks its output dimensions; it does **not** certify the original bytes of an existing model or replace it automatically. A checksum mismatch on a new download requires review of the artifact and pin, not bypassing the check. Model changes must be deliberate and followed by rebuilding derived search data.

Expected: `CONTEXT_SEARCH_MODEL_READY=384`, then `CONTEXT_SEARCH_BACKFILL=COMPLETE; inspect coverage below`, followed by chunk counts grouped by embedding status. `READY` rows have an embedding; `KEYWORD` rows retain text matching without one. No rows is valid when no personal contexts exist yet. A backfill-complete message alone does not mean every chunk has semantic coverage; inspect the counts. The fail-fast SQLcl setting prevents a failed model setup from continuing into the later blocks.

### 4. Check the experience with synthetic information

Save two disposable contexts with different titles and objectives. Search for an exact title, a term found only in saved details and a related phrase. Check the objective preview and match explanation. Try a status filter, clear the query, then reopen a result. Confirm that searching creates no conversation or answer. Test account isolation with separate app accounts, not two people sharing one login. Record actual results separately; these are suggested checks, not a report that they have passed.

## Maintenance and incomplete semantic coverage

The owner can rerun setup to retain the installed model and rebuild missing/stale search material. Backfill is explicit maintenance across that schema's contexts, including APEX-owned contexts; it returns coverage counts rather than context text. It must run through the owner connection outside APEX and refuses to proceed when a context is busy. Keep uncommitted unrelated work out of the setup session because the backfill step commits its derived rows.

The search page reports when it can provide only keyword results or partial semantic coverage. A missing/unavailable local model must not silently become an external model call. Do not treat the similarity score as a probability that the context is relevant; review the saved objective and context before reopening it.

For a setup failure, inspect the error code and the model/checksum or access prerequisite involved. The grants script is not a blanket network-access configuration; downloading still requires the chosen HTTPS location to be reachable under the database's network policy. Keep model URIs and private context text out of shared diagnostics.
