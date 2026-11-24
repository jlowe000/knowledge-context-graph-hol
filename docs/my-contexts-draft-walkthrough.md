# Start a personal context on dev

This walkthrough covers the current R7 My Contexts dev candidate; [native search and scoped browser checks passed](../db/verification/context-search-validation.json) for the new local search and objective preview. The [lifecycle UI record](../db/verification/context-lifecycle-validation.json) covers the native import and scoped Draft archive/unarchive and status-filter browser checks. The separate [R5 deletion record](../db/verification/context-delete-validation.json) records native tests and browser review/Cancel, with permanent-delete confirmation still pending. The preceding [R4 fresh deployment](../db/verification/fresh-dev-validation.json) and historical [journey record](../references/my-contexts-c3-validation.json) retain their own acceptance scope and earlier model-format failure. Generated Worksheet installer execution remains unverified. Use this walkthrough after the candidate migrations and native app are installed in an isolated development environment. It does not describe the published v1 app. The [complete manual review](my-contexts-manual-test.md) continues through answers, evidence, refinement and reopening.

Use a separate APEX application account for each person. **My Contexts** is the entry to work owned by your signed-in account in this application; the optional person name inside a context does not control ownership. A shared login is one identity and shares its saved contexts. Database/OCI credentials are separate from the application login. Use synthetic information while evaluating this development build.

## Create your own starting point

1. Sign in and open **My Contexts**. The library should contain only this account's saved contexts in this application.
2. Choose **Create context**. Enter a name, such as **Finding the next useful thing to learn**, and choose **Save draft**. A name alone is sufficient. The overview should show the saved name, **Draft** status and **Not sure yet** objective clarity.
3. Choose **Edit draft**. Add a starting question, for example **How could connected sources help me choose what to learn next?** Set objective clarity to **Emerging** if that describes your position. Add only the background and constraints you actually know.
4. Enter unknowns and explicit constraints one per line. Each entry can contain up to 500 characters; the complete saved draft is limited to 16,000 UTF-8 bytes. Choose **Save draft** and check the overview. An invalid submission should display an error and retain the text you entered so it can be corrected.

Saving a draft may refresh private search embeddings using the model inside the database. It makes no chat/GenAI request, creates no conversation and does not change the shared RDF graph. A learning interest is separate from a technical constraint. Drafts may remain incomplete while you work out what matters.

## Start from suggestions in a sample

**Sample Contexts** contains the shared fictional templates. They become your own context only when you choose **Save as my draft**; exploring a sample does not add it to your personal library.

1. Return to **My Contexts**, then choose **Use a sample**.
2. Select Alex, Sam or Casey and give the new context your own name. Choose **Save as my draft**.
3. Review the copied question, learning purpose and topic suggestions. The fictional person's identity, role, organisation, background, objective, unknowns and constraints must not become your facts. The original public sample remains unchanged.
4. Edit your own question and background. Review the **Topics to explore (up to 20)** topic choices, save, and inspect the overview. Topic options come from the pinned collection; suggestions are not accepted personal facts until you review and apply the draft.

On **Sample Contexts**, **Explore the samples** opens the fictional learner journey and leaves the copy form without saving its edits. Choose **Save as my draft** first if you want to keep those suggestions as a personal draft. The sample conversation uses its fictional context, not your saved personal draft.

## Return to and manage your drafts

| Action | Expected result |
| --- | --- |
| Enter a title, phrase or natural-language description in **Search your contexts**, then choose **Search** | Only matching owned contexts appear, ranked using title/saved details and available local embeddings. Inspect the saved objective preview, **Why it matched** and the coverage notice. Clearing the query returns to recent contexts. |
| Select **All**, **Draft**, **Active** or **Archived**, then choose **Search** | The filter applies to the owned results and starts from the first page. |
| **Next contexts** | The next bounded set appears when more than 20 contexts match. **Start of list** returns to the first set. |
| **Duplicate** | A separate draft is created with a new identifier and copied context fields. It is not a new conversation or learning event. |
| **Archive** | The draft remains readable; edit and archive actions are unavailable. |
| **Unarchive** | Returns to the previous Draft or Active state, retaining revisions, conversations, observations and evidence. It does not create a new graph or ask the model a question. |
| Sign out, sign in again and reopen | The saved context is still available to the same account in the same application. |
| Sign in as a different account | The first account's contexts are absent. A copied context URL must not grant access. |

The list reflects current activity; it is not a frozen snapshot. A context edited while you traverse results can move in the ordering. Refresh the search to see the current list.

The objective preview shows up to 240 characters, ending in `...` when longer; a missing objective stays blank. Search uses saved context information, not conversation transcripts, and makes no chat request. A keyword-only or partial-coverage notice explains unavailable semantic matches. See [context search](context-search.md) for setup and the current validation limits.

To bring back archived work, open **My Contexts**, set **Status** to **Archived**, choose **Search**, open the context and choose **Unarchive**. Return to the library and select **All** if the Archived filter is still selected. Archive is reversible; a permanently deleted context cannot be unarchived. The API operation remains named `restore_context`.

## Review and start exploring

1. Enter a starting question and select at least one eligible topic. If you select **Defined** objective clarity, enter objective text too. Save the draft.
2. On the overview choose **Review and Apply**. Read the before/after values. Cancelling does not publish a ready revision.
3. To change the collection or topic choices, select the target collection's topics and choose **Refresh preview for selected collection and topics**. Read the refreshed comparison before choosing **Apply reviewed context**.
4. Choose **Start a new conversation** from the overview. Ask a question and open that answer's **How was this answer built?** explanation. The explanation records the selected context and actual returned source evidence.
5. After later draft refinements are reviewed and applied, an existing conversation still uses its previous revision. Select **Use the latest ready revision** deliberately before asking with the new context.

Topics and the collection select evidence; objective and background frame the answer. Earlier explanations keep their captured evidence. Observations and ordinary chat do not automatically publish a context change. Continue with the [manual candidate review](my-contexts-manual-test.md) for saved observations, paging, archive/unarchive, interrupted-operation recovery and sign-in/reopening checks.

The [API contract](my-contexts-api.md) documents the actual operations and bounded model continuation. Learning-loop planning/assessment and evaluation of the Explorer remain separate future epics. Do not treat a saved draft or a metadata validation pass as acceptance of the full v2 feature.
