# My Contexts API: v2.0.0 C3 candidate

The C3/R4 source implements the personal journey alongside the existing sample route. R4 migration, grounded-task registration, native APEX import and the independent browser expiry/follow-up have passed. Native initial/adopted answers and the retrieval-failure test passed; a separate strict native expiry answer failed JSON/citation parsing despite successful retrieval. Full model-suite and fresh-route acceptance are not claimed; see the [R4 record](../db/verification/c3-r4-validation.json). Capabilities describe permitted actions, not a promise that every input is valid or every generated answer is correct.

## Storage and identity

`KCV_PERSONAL_CONTEXTS` stores the owned draft and ready-head reference separately from the public dataset. `KCV_CONTEXT_REQUESTS` stores transactional draft/lifecycle receipts. `KCV_PERSONAL_OPERATIONS` journals graph publication, model boundaries and other personal actions; `KCV_CONTEXT_ATTACHMENTS` authorizes a durable conversation in the current authenticated session. Personal revisions, turns, observations, receipts and attachments are runtime records, never public dataset/export supporting data.

`KCV_ACCESS` derives APEX ownership from the workspace, application and native APEX account ID. The authentication scheme's post-login callback `KCV_ACCESS.CAPTURE_IDENTITY` pins that account ID in the protected, application-scoped `KCV_AUTH_ACCOUNT_ID` item. Every read/write requires the pin to match the current native account ID. Missing or mismatched pins fail closed; reads never populate the item. A stale session therefore cannot become a newly created account that reused the same username. Existing sessions must sign out/in after this authentication change.

A display name or client-supplied field is never ownership. The current authentication scheme must remain Oracle APEX Accounts for this implementation; a different scheme needs a deliberate identity adapter. The [APEX user-ID API](https://docs.oracle.com/en/database/oracle/apex/24.2/aeapi/GET_USER_ID-Function.html) operates specifically on the native account repository. The native lifecycle acceptance also exercises rename, deletion/recreation and old-session replay; actual browser sign-in remains a separate acceptance layer.

The lab-owner SQL Worksheet uses a separate database-principal scope. Its drafts do not become APEX-user drafts. A shared application login remains one identity. A database administrator retains normal access to database records.

## Call contract

The following `KCV_PERSONAL_CONTEXT_API` functions return CLOB JSON. Read functions can be used by native reports through `JSON_TABLE`. Mutations run from PL/SQL form processes and commit their own work; do not invoke them in a SQL `SELECT` or combine them with unrelated uncommitted work. Journey operations below include procedures and a start function returning a conversation ID.

| Function | Inputs | Output |
| --- | --- | --- |
| `list_contexts` | Optional status, literal title search, owner-checked cursor ID and limit 1–50 | `contexts` summaries and nullable `next_cursor`; newest updated rows first |
| `get_context` | Owned context ID | Summary, draft, ready context when present, `has_unapplied_changes`, selected topics, pinned base graph, provenance and actual capabilities |
| `topic_options` | Optional owned context ID; omitted uses the current collection | Eligible topic labels and base graph, using relational metadata only |
| `save_draft` | Context ID or null for create, title, body, expected draft version and request token | Saved context; version increments on update |
| `duplicate_context` | Owned source ID, new title and request token | New draft, copy provenance; no copied conversations/history |
| `copy_sample` | Available sample ID, title and request token | New draft with question/purpose/topics as suggestions; identity, constraints and background omitted |
| `archive_context`, `restore_context` | Owned ID, expected version and request token | Updated lifecycle; restore returns the prior Draft or Active state |

Draft body allows `question`, `objective_clarity`, `objective`, `person`, `role`, `organisation`, `known_situation`, `learning_purpose`, `time_horizon`, `unknowns`, `constraints` and `topic_preferences`. Clarity is `unknown`, `emerging` or `defined`; constraints and unknowns are arrays of single-line text, at most 20 entries of 500 characters each. Embedded CR/LF is rejected so the native one-item-per-line editor preserves item boundaries. Topic preferences map exact eligible labels to weights 1–10; weights are not retrieval rankings. `selected_topics` is a presentation projection of the saved preferences, not an extra graph lookup. The total submitted body is limited to **16,000 UTF-8 bytes**, with smaller per-field character limits enforced by the API. The exact byte check converts a temporary CLOB/BLOB; it does not approximate the size by truncating a string. This bounds native editor buffers for multibyte input. A draft can be incomplete and does not invoke a model.

An Active context's pending draft is stored separately from its ready revision. Saving an incomplete edit does not disable ready work or change a conversation. Applying a reviewed complete draft creates a new immutable revision and advances the context head. Public graph data and original answer records are untouched.

## Publication and durable conversations

`KCV_PERSONAL_JOURNEY` supplies these operations. Every personal ID is checked against the authenticated owner; opening a saved conversation also creates an attachment for this application session. Reopening is read-only with respect to the selected revision and does not run the model.

| Operation | Contract and result |
| --- | --- |
| `preview(context, version, session?, collection?, body?)` | Validates a complete candidate with a question and at least one eligible topic. Returns a ten-minute preview containing token, before/after values, expected draft/head, collections and notice. Optional `body` supports resolving topics when changing collections without first replacing the saved draft. |
| `get_preview(context, token)` | Reads the owned saved preview. It does not publish or refresh its lifetime. |
| `apply_preview(context, token)` | Verifies the reviewed draft/head and optional conversation revision, builds/verifies an RDF overlay, then atomically publishes the ready revision. Replaying an applied token returns that revision. Returns status/revision and model-refresh status when an initiating conversation was supplied. |
| `start_conversation(context, token)` | Requires an Active context. Creates a durable conversation pinned to the ready head and returns its session ID as `VARCHAR2`. A replay returns the same conversation. |
| `open_conversation(session)` | Owner-checks and attaches the saved conversation to this authenticated session. Does not silently adopt the latest head. |
| `adopt_head(session, expected_revision, token, expected_head)` | Explicitly moves this conversation to the head the user reviewed. Both pinned revision and target head must still match. Earlier turns remain unchanged. |
| `collections(context)`, `collection_topics(context, collection)` | Returns ready collection options and the selected collection's eligible topic vocabulary. |
| `conversations(context, before?)` | Array of up to 20 conversations, newest first; use the last session ID as the next cursor. |
| `history(session, before?)` | Up to 20 earlier turns, returned in chronological order; use the lowest displayed turn ID as the next cursor. |
| `observations(session, before?)` | Up to 20 observations, newest first; use the lowest displayed observation ID as the next cursor. |
| `revisions(context, before?)` | Up to 50 revisions, newest first; use the last revision ID as the next cursor. |
| `operations(context)` | Inspect unfinished publication/model operations and running/uncertain answers. It does not perform recovery. |
| `recover_operation(context, token)` | Explicitly abandons an interrupted journal operation only after acquiring the worker locks. It neither publishes an orphan graph nor deletes provider state. |
| `recover_response(session, execution)` | Explicitly abandons the matching interrupted answer, releases its lease and marks model state for refresh. It does not cancel or resubmit the provider request. |

The current native UI publishes from the overview without an initiating conversation. Therefore **all existing conversations remain pinned** after Apply; use **Use the latest ready revision** in a conversation to adopt explicitly. Changing collection/topics requires **Refresh preview for selected collection and topics**, inspection of the new before/after values, then **Apply reviewed context**. A stale preview is rejected.

`KCV_SCENARIO.ASK(session, message, mode, token)` handles personal answers and preserves the explicit sample route. `OBSERVE(session, method, observation, next_step, token)` saves a revision-linked observation. The personal editor uses the full preview/apply API; legacy sample `STAGE_CHANGE`/`APPLY_CHANGE` rejects personal sessions. `KCV_APEX.DISPATCH` validates an attached session before conversation actions and routes history, observations, evidence and answer traces through the same authorization boundary.

## Evidence and model continuation

Topics and the pinned collection select evidence by topic union. Weights do not rank retrieval. Question, objective, identity/background, unknowns and explicit constraints frame the answer; they do not become extra graph filters. State/evidence packets separate `selection_context` and `interpretation_context`. A response trace keeps the captured context, source metadata, actual retrieval output and citation matches for that answer, even after refinement or a collection update.

For `question`, application code retrieves and durably records evidence against the execution's pinned revision before calling the model. It passes that exact `evidence_packet` to `KCV_GROUNDED_TEAM`, whose answer task has no tools and interprets the supplied packet. Retrieval therefore does not depend on the model choosing a tool, including after provider-history expiry or revision adoption. `propose_change` retains `KCV_EXPLORER_TEAM`; earlier teams remain available. Each request also includes the server-pinned `current_context`, `context_revision` and learning-focus semantics. That learner-supplied frame takes precedence over historical continuation or model memory; it is not verified source evidence.

After installing the migrated v2 code and configuring the model profile, a fresh owner runs [03_scenario_agents.sql](../sql/extensions/03_scenario_agents.sql) once to register the scenario teams. An owner with existing scenario registrations instead runs [16_refresh_grounded_answers.sql](../sql/extensions/16_refresh_grounded_answers.sql) after the R4 migration. That repeatable upgrade creates or refreshes the grounded task and creates its team if absent, preserving conversations and earlier teams. When run before any QA registration, it reports that registration is deferred; the later fresh registration remains required. Do not repeat the fresh `CREATE_*` registration script over existing agents. The earlier script 15 configures the R3 route and does not install the R4 grounded task.

`COMPLETED` requires a successful expected event with the correct origin: `EVIDENCE` from `APPLICATION` for a question, or `PROPOSAL` from `AGENT` for a proposed change, with no unsuccessful recorded events. A returned model message without that support remains `INCOMPLETE`, preserving its raw text for inspection. The app displays **Exploration incomplete** and initially collapses that text, including when the conversation is reopened. There is no automatic inference retry. This execution check does not establish that every generated claim is correct; citations, qualifications and relevance still need review.

`KCV_RESPONSE_TOOL_CALLS.CALL_ORIGIN` distinguishes new `APPLICATION` retrieval events from `AGENT` tool calls. Existing rows receive `LEGACY`; the trace JSON omits `origin` for those rows instead of inventing a trigger for historical evidence. The lineage view labels them as historical events with an unrecorded trigger. `KCV_RESPONSE_RUNS.MODEL_STARTED_AT` records the boundary immediately before model dispatch and is included in trace JSON only when present. It does not prove that a remote provider received or completed the request. Existing answer/context/evidence records are retained.

Model conversations use seven-day retention. `ensure_model` checks actual registered model state before a personal answer and creates a replacement when needed. The application transcript remains durable. The supplied continuation is bounded to the newest eight turns, at most 1,500 characters per turn and 8,000 characters in total; it records truncation and historical revision flags. This exact payload is captured with the response. It does not describe or recreate hidden provider history. `KCV_MODEL_BOUNDARIES` records replacements; reopening a page alone does not create a model call.

The learning loop and evaluation of the Explorer remain separate future epics. Observations here are user-reported records; they do not automatically change context, validate source truth or publish into the knowledge graph.

## Retry and error behavior

Draft/library mutations use 16–80 character safe tokens. Personal journey actions and personal ask/observe use 16–40 character safe tokens; use a fresh 32-character token per distinct action for either API. Allowed characters are letters, digits, underscores and hyphens. Replaying a completed action with the same payload returns its recorded result; changing the payload with that token fails. Do not manufacture a new token merely to bypass an uncertain request.

If evidence preparation fails before model dispatch, the attempt is recorded as `FAILED`, its execution lease is released, and `ORA-20174` reports that no model request was made. The saved conversation remains available; no assistant answer is invented. After reviewing the failure, the user may deliberately submit a new attempt with a new token. Replaying the failed token returns the recorded failure rather than issuing another model request. This differs from a submitted request with an uncertain outcome, which still requires explicit recovery before another action.

Zero-wait advisory locks bound contention. Ordinary draft mutations commit the change and receipt together. RDF/model operations have durable journal phases because platform calls can commit; publication changes the ready pointer only after graph verification and version checks. Archive refuses pending answers and unfinished build/publication work. Archived contexts remain readable and reject new writes until restored.

A personal model failure after submission is **uncertain**, because the provider may have processed it even if the result was lost. The answer lease remains until explicit recovery; the browser only refreshes status after an error and never automatically retries the model call. Review unfinished operations from the context overview, abandon only an interrupted operation, then deliberately start a new action. Recovery cannot acquire a live worker's lock. Completed historical evidence is retained.

List cursors are reauthorized on every call. A changing library can move rows between pages; it is not a frozen snapshot.

| Oracle error | Stable prefix | Meaning |
| --- | --- | --- |
| `-20174` | Failed attempt message | Evidence preparation failed before dispatch, or a failed request token was replayed; review the failure and deliberately start a new attempt. No automatic retry occurs. |
| `-20240` | `NOT_AUTHENTICATED` | Sign-in/native account or the lab-owner Worksheet is required |
| `-20241` | `CONTEXT_UNAVAILABLE` | Generic missing/unowned context, including cursor and copy targets |
| `-20242` | `STALE_VERSION` | Reload before editing or changing lifecycle |
| `-20243` | `CONTEXT_ARCHIVED` | Read-only until restored |
| `-20244` | `VALIDATION_ERROR` | Invalid input, shape, status, length or request token |
| `-20245` | `REQUEST_TOKEN_REUSED` | Same token was supplied for different action/content |
| `-20246` | `OPERATION_IN_PROGRESS` | Another worker holds the lock or an earlier operation needs review; do not blindly resubmit |
| `-20247` | `INVALID_TOPIC` | Label is not an eligible topic in the pinned collection |

Native page processes display safe validation errors. Do not expose owner IDs or private backtraces in user-facing messages. Personal-conversation routes reuse this authorization model while retaining the original sample-session rules.

## Validation

The R4 native schema upgrade, grounded-task registration, APEXlang validation/import and 29 component parse checks passed. The independent browser expiry/follow-up and fail-before-dispatch test passed; initial/adopted native answers passed while the strict native expiry answer failed JSON/citation parsing. See the [R4 record](../db/verification/c3-r4-validation.json) for the retained failure and remaining coverage. `integration-test/verify_personal_journey.sql` is the isolated native journey harness; the [manual candidate review](my-contexts-manual-test.md) covers the corresponding UI outcomes. Neither a test file nor an earlier candidate record establishes a current pass.


`integration-test/verify_my_contexts.sql` is an executable native SQL test restricted to an isolated test schema. It covers draft creation/editing, idempotent replay, changed-token rejection, stale edits, input allowlisting, duplication, pagination, archive/restore, foreign-owner filtering and absence of graph/model side effects. It does not substitute for actual APEX authentication, rename/recreation or browser acceptance. Record compilation and native results separately from source checks.

`integration-test/verify_my_contexts_apex.sql` uses two existing native accounts and `APEX_SESSION.CREATE_SESSION` in the isolated test app to exercise the stable principal and cross-session/cross-account API rules. The privileged harness explicitly calls the post-authentication capture procedure after creating each new session; an HTTP user cannot call it directly. It accepts only app ID/account-name binds, never passwords. This is a server-side identity harness; actual browser login/relogin remains separate. Both native scripts remove only their own synthetic records after success.

`integration-test/verify_my_contexts_identity_lifecycle.sql` is an optional ADMIN-only test restricted to the disposable `KCV_V2_TEST` workspace and `KCV_V2_A` account. It renames and deletes/recreates that test account with an unprinted database-generated password, proves access continuity after rename and isolation after recreation, and attempts old-session replay. It must never be run against a learner account. The separate browser test account is untouched.

`integration-test/verify_my_contexts_samples.sql` additionally requires the public sample dataset in that isolated schema. It tests Alex/Sam/Casey copies, visible topic suggestions, cleared fictional assumptions, replay behavior and unchanged source JSON. The empty-schema draft test does not establish sample-copy acceptance.

The three `integration-test/verify_my_contexts_contention_*.sql` scripts exercise two independent SQLcl sessions, rather than reentrant locking in one session. Bind the same fresh `v2_cross_` plus 32-hex-character token as `KCV_TEST_REQUEST_TOKEN` in both sessions. Start `hold` in session A, run `busy` in session B after `HOLD_READY`, and run `replay` after `HOLD_RELEASED`. Session A holds the synthetic request lock for 30 seconds. Session B must return `OPERATION_IN_PROGRESS` within two seconds and leave no receipt or draft; after release, the request must succeed and replay exactly one draft. The final script removes that fixture. Use only an isolated test schema.
