# EPIC-01: “How was this answer built?”

Status: implemented and deployed, 19 November 2026. Native Serverless tool capture passed (COMPLETED, one actual tool call, parsed citations); local historical/security/component/UI checks passed. Cloud browser acceptance passed as KCV_USER. See [upgrade and operations](epics-upgrade.md).

This entire feature is one epic in the [implementation plan](implementation-epics.md). Its phases are stories within EPIC-01. The related [styling and layout epic](ui-styling-plan.md) defines the app-wide visual treatment and navigation.

## Purpose and scope

Add a button to each assistant response that opens a read-only popup explaining the question, context, graph connections and evidence that supported that particular response. The learner should be able to distinguish what the application recorded, what the model cited, and what remains uncertain.

The popup uses saved execution records. Opening it makes no model call and does not query today's graph to reconstruct yesterday's evidence. It explains observable processing and inputs, not private model reasoning. Source knowledge remains curated; graph maintenance and training are outside scope.

## Current implementation and gaps

| Area | Current behaviour | Required change |
| --- | --- | --- |
| `KCV_SCENARIO.ASK` | Stores user and assistant turns with the revision selected before RUN_TEAM. There is no explicit request/response pairing or execution record. | Allocate an execution ID and pair the turns with its recorded revision, conversation and outcome. |
| Evidence tool | Queries the active scenario's graph and returns context, bindings and passages. | Correlate tool calls to the execution; persist the exact successful tool response before returning it. |
| APEX callback | Re-queries current evidence after actions and sends the latest 20 turns as role/body only. | Include turn IDs, revision IDs and trace availability; add an authorized per-response trace action. |
| UI | Shows current graph/source cards below the conversation. | Retain this current-context view; add a historical popup bound to an individual assistant turn. |
| Historical responses | Have revision IDs and sometimes model-written citations/paths, but no independently captured tool payload. | Show a clear unavailable/partial explanation; never manufacture a complete historical trace. |

Important distinction: a model's echoed graph paths are output to inspect, not the authoritative execution log. A pre-run evidence query is also insufficient proof of what an agent tool actually returned.

## Learner experience

1. A completed assistant turn gains **How was this answer built?** underneath it.
2. Clicking it opens an accessible modal headed **How this answer was built**, with the answer's timestamp and a short historical-context notice when its revision differs from the active scenario.
3. The learner can inspect the following sections without leaving the conversation:

| Section | Content | Expected understanding |
| --- | --- | --- |
| **Question and context** | Original question, selected intent, person, objective, active topics and revision at submission. | “This was the situation this answer addressed.” |
| **Recorded process** | Application submission, RUN_TEAM start/end, recorded tool calls and outcome, with elapsed times where captured. Distinguish configured routing from observed calls. | “These steps were observed; the application is not displaying hidden reasoning.” |
| **How the graph helped** | Small graph using captured context → topic ← source bindings; selecting a source/topic highlights its paths and evidence cards. Include a readable text equivalent. | “This relationship explains why this material was retrieved.” |
| **Evidence returned to the agent** | Exact saved passages, source titles/versions, PDF page links, retrieval rules and caps. Label matched citations separately from supplied-but-not-cited passages. | “This evidence was available through the tool; these passage IDs appeared in the answer.” |
| **Limits and open questions** | Recorded retrieval bounds; separately labelled model-stated limitations/next question; any citation or trace gaps. | “Connected evidence does not establish suitability, truth or observed value.” |

4. Closing the modal returns focus to the triggering button and preserves the transcript scroll position and any unsent question.
5. Older untraced turns show **Saved process details are unavailable for this earlier response**. They may show the retained revision/question where a reliable pairing exists, but must not label current evidence as historical evidence.

Use plain language by default. Put execution IDs, graph names, technical timings and machine-readable payloads in optional details. Keep raw prompts, credentials and database diagnostics out of the default learner view.

## Data design

Use an additive, versioned migration with installation prechecks and a clear second-run result. Do not recreate existing tables or alter the curated base graph.

| Record | Proposed contents |
| --- | --- |
| `KCV_RESPONSE_RUNS` | Execution ID; scenario session; user turn ID; assistant turn ID when available; pinned revision/base/overlay/conversation IDs; requested mode; context/question snapshot; prior relevant history turn IDs; status; start/end times; trace schema version; application retrieval-policy version; configuration fingerprint where reliably available; citation validation result. |
| `KCV_RESPONSE_TOOL_CALLS` | Execution ID and sequence; allow-listed tool identity; start/end/status; exact application tool-input/output snapshots; safe error code when failed. Store successful response JSON as a CLOB with JSON validation. |
| Session execution lease | An active execution ID/lease on the scenario session, claimed atomically. Release on success or failure; document recovery after a terminated request. |

Keep immutable snapshots of source titles, version/hash metadata, URLs and exact passages with the captured evidence payload or its associated source metadata. A later source-table update must not silently relabel an older answer. Record how many calls/payloads were captured and expose truncation if a configured size bound is reached; never silently present a partial log as complete.

Store only allow-listed application data. Do not dump entire AI profiles, OCI credentials, signing keys, provider headers, hidden prompts or unrestricted framework logs. A configured profile/model label is metadata, not proof of every internal model invocation. Conversation history may influence an answer: retain the conversation ID and application-visible prior turn IDs, and state that this feature is not a full provider prompt archive or exact replay facility.

## Execution capture and consistency

1. **Claim the scenario execution.** Authenticate using the existing owner + APEX application + APEX session boundary. Atomically reject overlapping asks or refinement applies for the same scenario while an answer is running. Browser button locking alone is insufficient across tabs or Worksheet clients.
2. **Pin the request.** Save the question, context revision, graph identities, conversation ID and requested mode; insert the user turn with RETURNING turn_id. Commit the run record before the external model request, consistent with the current durable user-turn behaviour.
3. **Pass an execution ID.** Include it in the original JSON sent to RUN_TEAM. Require wrappers to validate that it belongs to the caller's active scenario and pinned revision. Never trust a model-supplied execution ID without these checks.
4. **Capture actual tool results.** Add a traced entry point for the evidence wrapper that resolves the pinned execution revision rather than the mutable active revision. Persist exactly the JSON returned by each tool call before returning it. Keep the existing untraced current-context evidence API for the page's lower graph so normal rendering does not create false agent-call events.
5. **Handle both intents.** The evidence worker captures returned evidence. The refinement planner captures its actual proposal tool result. A planner-only response may legitimately have no graph-evidence retrieval; the popup must say so. Preserve the rule that planning cannot apply a change.
6. **Finalize the response.** Insert the assistant turn, pair it to the run, save the final status and citation checks, and release the lease. Do not rely on client timestamps or model-written process descriptions. Preserve the current ASK return type so Worksheet callers continue to work.
7. **Handle incomplete execution honestly.** On model/tool failure, keep a failed run and safe diagnostic status without inventing an assistant answer. No tool call, repeated calls, malformed output and missing correlation must be visible as trace limitations. A successful RUN_TEAM return with no captured tool call is not a verified evidence-backed execution.

Use a short persisted lease rather than a row lock across the remote model call. Exercise cleanup and failure transactions explicitly: logging must survive the framework's actual execution behaviour. If tool-side correlation cannot be proven in the live environment, mark the trace incomplete and resolve that before claiming feature acceptance.

## Citation handling

- Capture the raw answer unchanged. Parse structured citations defensively, including fenced JSON where returned; plain text must still display normally.
- Match explicit citation IDs against the union of captured evidence tool outputs for that execution. Mark matches as **Cited in this answer** and other supplied passages as **Returned, not explicitly cited**.
- Unknown IDs appear as **Citation not found in captured evidence** and must not generate a fabricated source link or graph path.
- Missing or unparseable citation metadata means **Citation matching unavailable**, not “no evidence used.”
- A matched citation establishes traceability to a supplied passage, not that every associated claim is supported. Claim-level entailment checking is outside the first release.

## Backend and UI changes

| Area/file | Planned work |
| --- | --- |
| New `sql/extensions/06_response_provenance.sql` | Add run/tool-call storage, execution-lease support and lookup indexes; include private-schema installation checks and migration verification. Keep new-run records distinguishable from legacy turns. |
| `sql/extensions/02_scenario_api.sql` | Add execution capture and authorized trace retrieval; refactor evidence selection to support a pinned revision; guard ASK/APPLY concurrency and finalize failures safely. |
| `sql/extensions/03_scenario_agents.sql` | Add execution-ID propagation/validation in traced wrappers and instructions. Check which registration objects require updating on an already-installed team; provide an explicit upgrade path rather than assuming CREATE can overwrite them. |
| `sql/extensions/05_apex_api.sql` | Return stable turn/revision IDs and trace availability; expose an allow-listed `trace` action requiring both owned scenario session and its assistant turn ID. Return only that response's saved trace. Avoid rebuilding the full current packet/transcript for a trace-only request. |
| `apex/region.html`, `explorer.js`, `explorer.css` | Add per-answer buttons, on-demand loading, dialog, scoped graph/evidence highlighting, loading/error/legacy states and responsive styling. Reuse graph rendering through a supplied host element rather than hard-coded IDs. Render all source/model text safely. |
| APEX build/export | Rebuild APEXlang, validate/import in the isolated workspace and regenerate the engine-produced SQL export. The saved export must contain the feature, not only the editable JS. |
| Documentation | Extend UI walkthrough with expected popup outcomes, explain historical versus current evidence, migration order and record-retention/cleanup procedure. Retain short runnable SQL inline where under ten lines. |

A trace fetch must not replace the main page's current context, refresh its graph, alter the pending refinement, send a question or make an AI call. Use response-specific DOM IDs, disable background interaction while the dialog is open, support Escape, and provide keyboard-operable graph selections and a text/list equivalent. On small screens, use a full-width modal with a scrollable body.

## First release and later enhancement

**First release:** durable capture, historical per-response modal, visible graph/evidence linkage, citation matching, clear limits and legacy fallback. This is the minimum complete feature; snapshot accuracy and ownership are not optional follow-up work.

**Later enhancement:** compare two saved responses. Diff their contexts, selected paths and evidence IDs. Explain objective-only versus topic changes and selection caps. Do not label a source as globally ineligible merely because it left the bounded packet. Defer response export, source-graph editing and a general agent-debugging console.

## Implementation sequence and acceptance

| Stage | Work | Completion evidence |
| --- | --- | --- |
| **1. Storage and correlation** | Migration, paired runs, pinned request state, tool capture and lease lifecycle. | A real question produces a paired run and captured tool payload; failure/no-call cases remain explicitly incomplete. Existing Worksheet ASK calls still work. |
| **2. Historical API** | Authorized per-turn retrieval and safe citation matching. | Fetching an earlier response after refinement returns its original paths/passages/labels. Other sessions cannot access it by guessing IDs. |
| **3. Popup experience** | Dialog, graph/source interaction, cited versus supplied evidence and legacy states. | A learner can explain why one source was selected, open its page, and close the popup without losing their place or draft. |
| **4. Verification and packaging** | Focused component/native/browser checks, export rebuild and documentation. | The acceptance cases below pass with recorded mock/native distinctions. No new external service is introduced. |
| **5. Temporary Serverless upgrade** | Preflight/export current app for rollback, install migration/packages, update registrations, import the corrected app into its intended existing ID. | Repeat the Alex before/after flow and historical-popup checks on the actual ADB/OCI model. App import may require the user to sign in again. Keep private URLs and credentials outside tracked files. |

Verification must cover:

1. **Original answer survives refinement:** answer A uses S02/S03/S06; after removing Graph capabilities, answer B uses the revised packet with S08. Opening A still shows A's saved inputs; opening B shows B's. Compare actual IDs, not hard-coded model wording.
2. **Actual tool capture:** tool payload equals the stored payload; repeated calls are retained; a no-call answer has no invented evidence event. Ordinary current-page evidence retrieval is excluded from the trace.
3. **Citations and rendering:** cited/supplied/unknown IDs; fenced/plain/malformed responses; Unicode; long passages; HTML-like source text; only approved public URLs become links.
4. **Identity and concurrency:** cross-session and cross-owner access rejected, even for the same username in a different APEX session; simultaneous ASK/APPLY rejected or safely serialized; interrupted calls leave inspectable status and a recoverable lease.
5. **Failures and legacy:** model failure, tool failure, missing metadata and pre-feature turns produce clear states without fabricated history. Failure logging does not roll back successful earlier turns.
6. **Popup behaviour:** mouse and keyboard, focus return, Escape, narrow screen, error/retry, draft preservation, reopening without an AI call and no mutation of the current context. Ensure the existing DOMContentLoaded startup fix remains in the generated export.
7. **Native validation:** local mocks can verify persistence and guards but cannot establish real RUN_TEAM tool correlation. Validate that boundary and the saved payloads on the temporary Serverless instance.

## Completion definition

For each new response, the learner can inspect the recorded question/context, actual tool-returned graph paths and passages, matched citations and trace limits from an authorized popup. The record remains accurate after later refinements. The normal conversation, refinement and observation journey still works. The published artifacts and documentation match the tested app.

Related: [UI walkthrough](ui-walkthrough.md), [scenario validation](scenario-validation.md), [APEX app](../apex/README.md), [Serverless deployment](serverless-apex-deployment.md).
