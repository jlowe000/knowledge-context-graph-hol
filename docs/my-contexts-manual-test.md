# My Contexts: manual candidate review

This walkthrough covers EPIC-03. The historical [journey record](../references/my-contexts-c3-validation.json) and [R4 execution record](../db/verification/c3-r4-validation.json) retain the earlier browser expiry/follow-up pass and separate strict native failure caused by malformed model JSON. The newer [fresh deployment record](../db/verification/fresh-dev-validation.json) records successful schema installation/repeat, dataset loading, native APEX checks and all three strict model requests, including provider-expiry continuation. That fresh app also passed the personal/sample browser journeys and scoped preservation checks; these results do not replace the historical failure. Generated Worksheet installer execution remains unverified. Other rows below remain review scenarios unless the relevant record marks them tested. Learning-loop assessment and Explorer evaluation remain separate future epics.

Sign in with your own app account. Use a synthetic idea during review and avoid confidential organisational information. Keep passwords, private endpoints, account details and personal context text out of screenshots and public issues. A working GenAI profile is required for chat answers. Saving/searching contexts may use a separate local embedding model inside the database; it sends no context text to an external embedding or chat service. Viewing saved history and browsing with an empty search do not generate embeddings.

**My Contexts** lists work owned by this signed-in account in this application. Shared fictional templates are under **Sample Contexts**; **Save as my draft** creates an owned copy without changing the template. A shared app login shares its contexts, so account-isolation checks require different application accounts.

The [lifecycle UI record](../db/verification/context-lifecycle-validation.json) covers the current native import, a disposable Draft archive/unarchive round trip and the Archived/Active/All filters. It does not claim a new Active round trip or two-account browser test.

## Core journey

On **My Contexts**, the introductory guidance appears immediately below **Your saved learning contexts**. The search fields follow, with **Search** on the left below them. Results show up to **10 contexts per page**; **Next contexts** and **Start of list** appear below the report when available.

On the context overview (page 13), **Edit Draft**, **Archive** (or **Unarchive**) and **Duplicate** are on the left; **Review and Apply** and **My Contexts** are on the right. Conversation actions sit with **Saved conversations**. **Delete Context** is at the bottom left of the page and opens the separate deletion review.

| Step | Action | Expected result |
| --- | --- | --- |
| 1 | Open **My Contexts**. Create a context named **Project information learning path**, leaving the other fields blank. Save it. | A private draft appears in your library. An uncertain objective is allowed. Saving may generate local search embeddings; it does not publish a graph revision or make a chat/GenAI request. |
| 2 | Reopen the draft and request a preview before supplying enough information. | Validation explains the missing information and retains your edits. An incomplete draft remains saved and editable. |
| 3 | Enter **Which approaches could help me find relevant project information?** as the question. Enter a learning purpose and keep objective clarity as emerging/uncertain. Select **Semantic retrieval** and **Ontology**, if those labels are offered by the pinned collection. | Topic choices come from the available collection. Background, objectives and explicit constraints remain distinct fields. The draft can be saved before activation. |
| 4 | Preview the context. Read the before/after values, selected collection and topic explanation. Cancel once, then preview again. | Preview shows what would change. Cancelling does not publish a ready revision. The current ready context, if any, remains usable. |
| 5 | Explicitly apply the reviewed preview. | A ready context revision is published. The overview identifies the current ready revision and collection. Source knowledge remains unchanged. |
| 6 | Start a conversation from this context. Ask **What should I explore first, and what evidence supports that suggestion?** | The conversation is linked to this context and pinned revision. A successful answer distinguishes evidence from proposed relevance and may identify missing information. Unsupported claims should not become accepted facts. |
| 7 | Open that answer's explanation. Inspect the Sources graph and Answer lineage. | The explanation uses the saved context, actual returned passages and citation matches for that answer. New R4 questions show **Application evidence retrieval** before the team/model request; this is distinct from an agent tool call. Topics/collection explain evidence selection; background/objectives/constraints explain interpretation. The graph does not prove that the suggested next step will work. |
| 8 | Record a short observation, such as **I reviewed the linked material; I still need to distinguish discovery from document approval.** Add a next question if useful. | The observation is saved against the conversation revision. It does not automatically edit the context or publish assertions into the source graph. |
| 9 | Return to the editor. Change the objective/background while keeping the same collection and topics. Preview and apply. | The edited framing is visible in the new revision. Under the unchanged retrieval policy, evidence selection remains based on the same topics/collection. Model wording may differ. |
| 10 | Reopen the earlier conversation. Inspect its revision before asking again. | It retains its pinned revision and shows that a newer ready revision exists. An explicit adoption action is required to use the newer head. |
| 11 | Adopt the newer ready revision, then ask a follow-up. Open the new answer's explanation. | The conversation records the revision boundary and selected context. The application retrieves and records evidence for this question before requesting the answer. The answer uses that current framing instead of inferring the current focus solely from older answers. Previous turns and explanations remain attached to their original revisions. |
| 12 | Refine the context again, removing one topic. Review and apply the change, then explicitly use that revision in a conversation. | Topic removal is a change in learning focus. It does not become a technical prohibition or delete public sources. Some sources may remain relevant through another selected topic. |
| 13 | Reopen the explanation for the first answer. | Its original evidence, context and lineage remain intact rather than being recomputed from the latest graph. |
| 14 | Sign out, sign in again and reopen the context and conversation. | Owned context, turns and observations remain available. Reopening does not silently adopt a new revision. If provider state has expired, the next question recreates it using bounded continuation while retaining application history. Failed or uncertain operations require explicit recovery. |
| 15 | Archive the context, then use **My Contexts → Status: Archived → Search** to find it. Open its history, then choose **Unarchive**. Return to **All** in the library if needed. | Archived work remains readable and blocks changes/new questions. Unarchive returns the previous Draft or Active state and preserves revisions, conversations, observations and evidence. It does not undo permanent deletion. |
| 16 | Duplicate the context. Also try **Save as my draft** on a fictional sample. | A duplicate starts as a draft without copied conversation history. A sample copy clears fictional identity/background/constraints and retains suggestions for personal review. The original sample is unchanged. |

## Additional checks

### Search saved context information

The [R7 validation record](../db/verification/context-search-validation.json) records native search regressions and browser semantic/title matches, status filtering and clearing the query. Other rows below remain review scenarios unless that record explicitly marks them tested; see [context search](context-search.md) for setup.

| Situation | Expected behaviour |
| --- | --- |
| Search an exact title, a term only in the saved objective, then a related phrase | Owned results can use title/detail matches and available local semantic matches. The objective preview and **Why it matched** help distinguish them. No chat answer or conversation is created. |
| Save an objective longer than 240 characters | Its library preview uses the first 237 normalized characters followed by `...`; opening the context retains the full saved objective. A blank objective stays blank. |
| Change the saved title/objective and search again | Current text replaces the old search representation. Stale vectors do not contribute semantic results. Unsaved edits and conversation transcripts are not searched. |
| Search with literal punctuation or a valid long multibyte query | Input is not interpreted as SQL, wildcard or regular-expression operators; accepted queries up to 200 characters remain valid. |
| Paginate unchanged results, then alter a matching context | Unchanged results paginate in ranked order. Concurrent edits can reorder results; a still-owned available anchor that stops matching resets to the first page with a notice. Unavailable/deleting/foreign anchors are rejected. |
| Semantic coverage is unavailable or partial in a controlled test | The page shows keyword-only or partial coverage explicitly. It does not silently send the query or saved details to an external model. |

### Delete an owned context

Deletion is an R5 dev addition; the earlier fresh-deployment and navigation records do not certify it. The [deletion validation record](../db/verification/context-delete-validation.json) records successful native deletion checks and browser review/Cancel; permanent-delete browser confirmation remains pending. The rows below remain review scenarios wherever that record does not mark them tested. Use disposable synthetic contexts.

Open **Delete context** from an owned context's overview. The review identifies the context and counts its revisions, conversations, turns, responses, evidence and observations. **Cancel** returns to My Contexts without starting deletion. **Delete permanently** is irreversible; use **Archive** instead when you need to retain and restore the work.

| Situation | Expected behaviour |
| --- | --- |
| Review and cancel | The context and its saved work remain available. |
| Confirm deletion of a disposable context | Its owned saved work, personal graph overlays and associated Select AI conversations captured for cleanup are removed. It disappears from My Contexts. Public sources, the shared knowledge collection and independent copied contexts remain. |
| The context changes after the review | The stale confirmation is rejected. Review the current state before confirming again. |
| Cleanup is interrupted | **Deletion unfinished** leads back to the deletion page. The context is unavailable for normal reads and changes; **Retry deletion** resumes cleanup. Returning to My Contexts does not undo a deletion already started. |
| Reopen an old context/conversation link or replay an earlier save after deletion | Deleted content is not returned or recreated. A different account cannot inspect or delete the private context. |

Deletion concerns the application's owned content and the explicitly associated resources it can remove. It does not promise erasure of service audit records, backups or provider retention outside this application.

### Other regression checks

The [25 November sample navigation record](../db/verification/sample-navigation-validation.json) covers the menu and unsaved-change regressions below separately from the earlier fresh-deployment acceptance.

| Situation | Expected behaviour |
| --- | --- |
| Open **Sample Contexts** from **My Contexts**, then return through the menu without editing; repeat the round trip | Alex is the explicit initial sample. Both menu directions and repeated entry work without an unsaved-change warning. |
| Edit **Name for your context** on Sample Contexts, then select My Contexts in the menu | The normal unsaved-change warning still appears. Cancel leaving, restore the name to its original value, and try again: navigation succeeds without a warning. |
| Edit the sample-copy name, then choose **Explore the samples** | The deliberate Explore action opens the sample workspace without saving the copy form. Its button-specific behavior must not disable the page's genuine-edit warning for ordinary menu navigation. |
| Two browser tabs preview the same draft; one applies first | The other preview is rejected as stale. It must be reviewed again against current state. |
| Two conversations use the same context | Each keeps its own revision until explicit adoption. Advancing the context head must not rewrite an answer already in progress against an earlier revision. |
| A later collection is available | Collection adoption is deliberate. Topic eligibility is checked again; historical answers retain the old collection/evidence. |
| Another signed-in account opens a copied private context/conversation link | Access is denied without disclosing the other account's content. |
| More than one page of contexts, conversations, revisions, turns or observations exists | Next/older controls preserve ordering and do not repeat or skip records. |
| A request fails or its model submission has an uncertain outcome | The operation status explains the condition. Explicit recovery does not silently resubmit an uncertain model request or overwrite finished work. |
| A synthetic conversation's provider history expires after several turns | A maintainer may remove only that synthetic provider conversation to exercise expiry. The same application conversation retains its turns and revision; the next question recreates provider state with bounded continuation and retrieves new scoped evidence before dispatch. The explanation shows the new application retrieval and citation matches. Expiring the provider state must not remove application history. |
| Evidence preparation fails before a model request | A controlled maintainer test should receive `ORA-20174`, with a failed attempt, no model dispatch timestamp and no new assistant answer. Saved work remains available. Review the failure and deliberately submit a new attempt when ready; replaying the same failed token must not dispatch a model call. Do not disrupt a learner's live collection to force this case. |
| An explanation predates the origin field | Its original evidence remains available. The UI identifies a historical event with an unrecorded trigger; it must not relabel it as a newly observed application or agent event. |
| A historical response from the earlier agent-tool retrieval flow lacks a successful evidence-tool call, or records a failed tool call | **Exploration incomplete** is visible and the unsupported model text is initially collapsed. Its explanation shows the missing/failed retrieval rather than invented graph support. Reopening the conversation retains the warning. No automatic retry occurs; deliberately asking again is a separate action. Use an already captured incomplete response or a controlled maintainer test; do not disable a live learner's tools merely to force this case. Current questions retrieve application evidence before model dispatch; use the evidence-preparation failure check above for that flow. |
| The question is not supported by the selected passages | The response identifies the evidence gap. A public link or graph connection alone is not evidence for an unsupported claim. |
| Alex, Sam and Casey sample journeys | They remain available separately from personal contexts, including the original evidence/refinement/observation experience. |

Record the step, action, expected result, actual result and whether the problem repeats. Use synthetic text when reporting a failure. Include the candidate version and validation-record identifier so an issue can be tied to the tested implementation; do not paste connection definitions, credentials or private transcripts.
