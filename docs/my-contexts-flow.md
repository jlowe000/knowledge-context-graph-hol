# My Contexts: create, use and revisit a learning context

Status: R4 dev candidate, 24 November 2026. Native upgrade, APEXlang import/export and the independent browser expiry/follow-up passed, including preserved history and evidence retrieved before model dispatch. The separate strict native expiry test returned malformed model JSON, so model-suite acceptance remains partial. Fresh deployment and generated Worksheet installer execution remain unverified. See the [current acceptance record](../references/my-contexts-c3-validation.json) and [R4 verification](../db/verification/c3-r4-validation.json). The published release remains the v1 baseline.

The [implementation plan](my-contexts-implementation-plan.md) defines EPIC-03. Dev uses directly authored APEXlang and SQLcl/Liquibase-managed schema changes; release retains its SQL Worksheet route. The [manual candidate review](my-contexts-manual-test.md) gives the actions and expected results for testing the completed source journey.

## Purpose

Use the public knowledge collection for your own engagement or learning question. Start without a settled objective, inspect connected evidence, record what you learn and return to the same work after signing in again. A context describes a situation; it is not a universal profile of everything a person knows. One account may own several contexts, each with several conversations.

The journey is **My Contexts → Create or copy → Save draft → Review and apply → Start or reopen a conversation → Inspect evidence → Record observations or refine → Return later**. A source check, discussion, vote or practical activity may inform a next step. This candidate does not prescribe an experiment.

## Screen journey and expected outcomes

| Step | Screen and action | Expected outcome |
| --- | --- | --- |
| 1 | Open **My Contexts**, then **Create context**, **Use a sample** or an existing context. | The library contains this account's owned contexts in this application, with title, clarity, lifecycle and update information. Search and status filters operate on that owned list. |
| 2 | Enter a context name and choose **Save draft**. | A name alone is enough. No RDF overlay, model conversation or answer is created. |
| 3 | Use **Edit draft** to enter a starting question, purpose, objective clarity, optional background, unknowns, constraints and topics. Save. | The complete draft is retained separately from any ready revision. Topic removal means a change of learning focus, not a technical prohibition. |
| 4 | From the overview choose **Review and apply draft**. Read the before/after comparison. | A valid preview needs a question and at least one eligible topic. Defined clarity also requires objective text. Cancel leaves ready work unchanged. |
| 5 | If changing collection or topics, select the collection's eligible topics and choose **Refresh preview for selected collection and topics**. Inspect the new comparison, then **Apply reviewed context**. | A private immutable context revision becomes ready. The reviewed draft/head must still match. Shared public source knowledge is unchanged. |
| 6 | Choose **Start a new conversation**, or open a saved conversation. | A new conversation starts on the ready head. An existing conversation retains its pinned revision and attaches only after ownership validation. Opening it does not ask the model a question. |
| 7 | Ask a question, then open **How was this answer built?** | The answer explanation shows its captured context, application-retrieved evidence, Sources graph, Answer lineage and citation matches. Viewing it makes no model call. |
| 8 | Save an observation with a method, finding and optional next step. | It belongs to the conversation revision where it was recorded. It does not automatically refine the context or establish that a source claim is true. |
| 9 | Return to the full editor, save changes, review and apply. In the conversation choose **Use the latest ready revision** when wanted. | Applying advances the context head; all existing conversations remain pinned until explicit adoption. Earlier turns and explanations retain their original revision and evidence. |
| 10 | Sign out, sign in again, reopen the context and saved conversation. | Saved work remains available to the same account in the same application. The app retains history independently of replaceable model state. |

Conversation and observation history have **Load earlier** controls. The overview has **Older conversations** and **Older revisions**, with controls to return to the newest page. The library supports title search and Draft, Active and Archived filtering. These are bounded pages, not frozen snapshots; edits can change library ordering.

## Draft, ready revision and conversation

A draft may remain incomplete. An Active context can also have an incomplete edited draft while its ready revision stays usable. The overview distinguishes the saved draft from the ready revision. A preview does not apply itself, and an ordinary chat suggestion does not persist a change.

Activation requires a starting question and at least one topic with eligible evidence in the selected collection. A fully defined objective is optional. If clarity is explicitly **Defined**, objective text is required. Identity, role, organisation, known situation, purpose, horizon, unknowns and explicit constraints are user-supplied framing; none is inferred from a topic choice.

The native editor supports up to 20 exact eligible topic labels. Weights already present in a draft are retained; newly selected topics use weight 1. Weights do not rank retrieval. Unknowns and constraints use one item per line, and the complete draft is limited to 16,000 UTF-8 bytes.

A collection update is deliberate: use the review dialog's collection selector, resolve its topic choices, refresh and inspect the preview, then apply. A disjoint topic vocabulary cannot be adopted without choosing valid topics. Existing conversations and historical answers retain their old collection until a new revision is explicitly selected for future questions.

**Use a sample** copies question, purpose and topic suggestions from Alex, Sam or Casey into an owned draft. It clears fictional identity, background, objective, unknowns and constraints. **Explore the samples** opens the separate fictional journey. **Duplicate** creates another draft from the owned context without copying conversations, observations or answer records.

## What the graph and explanation establish

| Record or input | Responsibility |
| --- | --- |
| Personal context | Durable owner, application scope, title, lifecycle, draft and ready-head pointer. |
| Context revision | Immutable context JSON, topics, parent revision and pinned collection/RDF overlay. |
| Conversation | Durable discussion pinned to one revision; adoption requires both the current revision and reviewed target head still to match. |
| Selected topics and collection | Explicit topic-union evidence selection using the existing bounded policy; weights do not rank results. |
| Question, objectives and background | Frame interpretation of returned evidence; they do not add independent graph filters. |
| Answer explanation | Captured question/context, source metadata, actual tool outputs and citation matches from that answer. It does not reveal private model reasoning or prove a suggested next step will succeed. |
| Observation | User-reported method, finding and next step, linked to the original conversation revision. |

Changing the objective while keeping collection/topics unchanged does not promise different evidence. The model's wording and proposed relevance may change. Removing a topic does not delete a source, and a source may remain connected through another topic. Old explanations are read from saved evidence rather than recomputed against the latest context.

## Ownership, continuation and recovery

Personal ownership uses the workspace/application and stable native APEX account ID. The authentication callback pins that identity for the current session. Opening a saved conversation checks the owner and attaches it to the new session; each later request checks that attachment. URLs and browser storage are navigation aids, never authority. The original sample route retains its separate application/session ownership checks.

A shared `KCV_USER` login is one identity. Distinct people require distinct native application accounts. A context's optional display person does not determine ownership, and a database administrator retains normal access to database records.

Model conversations have seven-day retention. Before a personal answer the runtime checks actual registered model state and creates a replacement when needed. The bounded continuation contains at most the newest eight application turns, 1,500 characters per turn and 8,000 characters overall, with truncation and historical-revision flags. It is captured with the response and does not claim to restore hidden provider history. Full saved application history remains pageable.

If a submitted model request fails, its result may be uncertain. The browser refreshes status without automatically resubmitting. Use **Context overview and saved conversations** to inspect unfinished operations. **Abandon interrupted operation** requires an explicit confirmation and server-side checks that no worker still holds the operation lock. It does not cancel provider processing, publish incomplete work or retry an answer. A later new request is deliberate.

Archive makes a context read-only and refuses to proceed while answers or build/publication work remain unfinished. Archived conversations and evidence remain readable; Restore returns the previous Draft or Active lifecycle. Archive is not deletion.

Personal context, conversations, observations and operational records remain runtime data. They are excluded from the public sample dataset, generated dataset SQL and release manifests. Asking a question supplies context to the configured model service; keeping it out of GitHub does not mean no model service receives it.

## Implementation and acceptance

| Source | Role |
| --- | --- |
| [Personal objects](../sql/extensions/10_my_contexts_objects.sql), [journey objects](../sql/extensions/13_personal_journey_objects.sql) | Additive personal storage, receipts, attachments and operation/model-boundary records. |
| [Access API](../sql/extensions/11_context_access.sql) | Stable principal, owner/session checks and eligible topic vocabulary. |
| [Draft API](../sql/extensions/12_my_contexts_api.sql) | Library, validated full drafts, copy/duplicate and archive/restore. |
| [Journey API](../sql/extensions/14_personal_journey.sql) | Preview/publication, saved conversations, adoption, history and explicit recovery. |
| [Scenario API](../sql/extensions/02_scenario_api.sql), [response provenance](../sql/extensions/06_response_provenance.sql) | Questions, pinned graph retrieval, observations and captured answer evidence. |
| [APEXlang source](../apex/application/), [dispatcher](../sql/extensions/05_apex_api.sql), [workspace JS](../apex/explorer.js) | Native library/editor/review/overview and specialized authenticated conversation/evidence UI. |

The detailed [API contract](my-contexts-api.md), [migration guide](database-migrations.md) and [APEXlang guide](apexlang-development.md) explain development. Complete isolated native upgrade/fresh tests, actual model checks, two-account isolation, history/expiry/concurrency checks, signed-in browser acceptance and original HOL regression before acceptance. Preserve existing work; an upgrade must not tear down the shared lab to make tests pass.

The learning-loop workflow and evaluation of the Explorer are **two separate future epics**. This candidate contains observation capture and explicit refinement, but no activity planning/assessment workflow, automatic publication, evaluation telemetry or knowledge-value score. Shared contexts, invitations, public context publication, source ingestion, ontology editing and vector ranking are also outside EPIC-03.

No release promotion follows automatically from source implementation or metadata validation. Engine import/export acceptance and publication-boundary checks must precede a separate promotion decision.
