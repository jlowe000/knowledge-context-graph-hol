# UI walkthrough: from a broad interest to a useful next step

Use Knowledge Context Explorer to explore a curated collection of public knowledge, understand why it connects to a person's situation, and refine what to explore next. Allow approximately 15–20 minutes, including time to read the evidence. Model responses may take a minute or longer.

The starting knowledge graph is already curated. This walkthrough changes the learner's context, not the source documents or their assertions. Knowledge-graph maintenance is a separate activity outside this journey.

**Experience:** start with a person → ask a question → inspect connected evidence → clarify the objective → narrow or broaden the focus → compare → capture learning → choose the next step.

## Before you start

Open the application URL supplied by the facilitator and sign in with an APEX application account. In the deployed example, this is KCV_USER. Use the application's password, which is separate from database and OCI credentials. No SQL Worksheet or App Builder access is needed for this walkthrough.

Alex, Sam and Casey are fictional people. Use Alex for the main journey below. Start a new conversation if you want to repeat it from the supplied baseline; an existing conversation may already have refinements applied.

## Workspace navigation

The traditional workspace has Conversation, Evidence, Context and Observations views. Your draft question stays in place while switching views. Current understanding stays visible. Use **Context** for refinement controls, **Evidence** for current graph/source cards, and **Observations** to capture learning.

For each assistant turn, **How was this answer built?** opens a read-only explanation. Sources shows captured graph connections and full passages; Answer lineage shows the recorded question, context, tool calls, answer and citation references. Select nodes for detail. Overview includes recorded timestamps. Limits explains capture/retrieval boundaries. The popup belongs to that answer's revision even after later refinements; older pre-feature answers show an unavailable notice. Close or press Escape to return to the triggering answer without losing your draft. It does not make a model call.

## Main journey: Alex needs to find project information

| Step | What to do in the UI | Expected outcome and what to notice |
| --- | --- | --- |
| **1. Start with a person** | Under **Learner scenario**, select **Alex · engineering information discovery**, then click **Start a new conversation**. | **Current understanding** shows Alex's role, emerging objective and learning purpose. **Where context meets content** shows connections to topics and sources, with public source cards below. Starting retrieves the curated context and graph evidence; it does not require a model answer. |
| **2. Ask an initial question** | Leave **Conversation intent** as **Explore and ask about content**. Paste the first question below into **Your question or new thought**, then click **Explore this question**. | The status shows that exploration is running and controls are temporarily disabled. When ready, the conversation contains your question and an answer grounded in the returned evidence. Look for citations, proposed relevance, limitations and a next question. Exact wording and ordering can vary. Asking alone does not persist a context change. |
| **3. Inspect the connections and detail** | Read **Where context meets content**. In **Evidence**, open **Exact graph paths** if you want to inspect the relationships. Under **Public sources behind this conversation**, open at least one PDF page link and compare its wording with the answer. | You can trace a connection from Alex's context through a topic to a source, its version and an evidence passage. The PDF link identifies the supporting page. Decide whether the source supports the explanation and whether its scope or availability caveats matter. A topic connection explains selection; it does not establish suitability or business value. |
| **4. Preview a clearer objective** | Open **Context** → **Refine the stored context**. Under **What would you like to refine?**, choose **Clarify the objective**. Paste the objective below into **Objective**, then click **Preview refinement**. | A structured preview shows the proposed SET_OBJECTIVE change. The stored context and active graph have not changed. Read it before proceeding. |
| **5. Apply the objective** | Click **Apply this refinement**. Check **Current understanding**. Optionally expand **Context and graph identifiers** to compare the revision with the previous one. | The objective becomes defined and a new context revision is active. The prior revision is retained. Because the topics have not changed, the source set should remain the same for this baseline. More precise wording alone does not imply different graph matches. |
| **6. Preview a narrower focus** | In **Context** → **Refine the stored context**, choose **Remove an area of focus**, select **Graph capabilities** under **Topic**, and click **Preview refinement**. | The preview specifies REMOVE_TOPIC and Graph capabilities. This removes an interest from Alex's context when applied; it does not delete a source or assert that graph capabilities lack value. Nothing changes until you apply it. |
| **7. Apply and compare the connections** | Click **Apply this refinement**. Compare the graph and source cards with step 3. | A further revision becomes active. In the validated dataset, the Graph capabilities path and S06 disappear from this retrieval, while S08 appears alongside S02 and S03. This is a change in the bounded evidence selection, not a measured improvement. |
| **8. Ask with the refined context** | Paste the follow-up question below into **Your question or new thought**, keeping **Explore and ask about content**, and click **Explore this question**. | The new answer should use the narrower objective and current evidence. In the validated run, it discussed S02, S08 and S03, preserved the Coming Soon qualification, and explained what remained unproven. Earlier answers remain historical turns; use the new answer and current graph for the comparison. |
| **9. Capture what you learned** | Open **Observations** → **Capture what you learned**. Choose a method under **How did you check your understanding?** Complete **What did you observe?** and **Next question, idea or step**, then click **Save observation**. | The status confirms **Observation saved against this context revision.** Record something you actually observed through a source check, discussion, dot vote, practical test or another approach. This creates a learning record; it does not certify a source, retrain the model or automatically apply another refinement. |
| **10. Continue deliberately** | Use the recorded next question to continue the conversation. If it calls for another context change, preview and apply that change using the refinement controls. Alternatively, finish with a concrete reading, conversation or validation action. | The learner leaves with a clearer need, traceable supporting material, identified uncertainties and a next step. A useful outcome can be a better question; it need not be a deployment or an experiment. |

### Copyable question for step 2

```text
Which sources could help Alex find existing project information, and what do they not establish?
```

### Copyable objective for step 4

```text
Find existing project information across documents; approval and workflow are out of scope.
```

### Copyable follow-up for step 8

```text
With the objective now limited to finding existing information and Graph capabilities removed, which returned sources should Alex explore first, and what remains unproven?
```

### A useful observation for step 9

Write your own observation. Describe what you checked, what you found and what remains uncertain. For example, if you checked a source's availability wording, record the page and qualification you found, then identify the current product information you would need next. If you used a dot vote, record the priorities expressed; agreement is not proof of factual accuracy.

The current UI confirms that the observation was saved; it does not provide an observation-history panel. Revision-linked observations and audit history are available through the documented [Worksheet audit queries](../labs/07_original_workshop_scenarios.md).

## How to interpret the comparison

The evidence packet is limited to six passages, at most two locators per source, using explicit topic membership and deterministic ordering. Other eligible sources may therefore exist outside the displayed packet. S08 entering the packet after S06 leaves does not mean it was newly added to the knowledge collection. This flow does not use vector similarity or topic weights to rank sources.

Refining the context supplies updated context to subsequent model responses. It does not train the model. Saving an observation records feedback for learning and later review; it does not automatically rewrite the context or curated knowledge.

## Optional ways to explore further

| Option | UI action | Expected outcome |
| --- | --- | --- |
| **Broaden again** | Choose **Add an area to explore**, select **Graph capabilities**, preview and apply. | A new revision restores the topic. With the supplied unchanged baseline data, the original topic-based selection should return. Earlier revisions and observations remain. |
| **Ask for a suggested refinement** | Set **Conversation intent** to **Suggest a context refinement** and ask for an area to explore. Click **Explore this question**. | The agent proposes a change. It does not apply it. If appropriate, choose the corresponding objective/topic change in **Refine the stored context**, preview and apply it yourself. |
| **Try Sam** | Select **Sam · evidence and traceability** and click **Start a new conversation**. Ask which concepts and evidence support an answer, and what they do not establish about document approval. | A different starting context highlights different connections. Source traceability does not itself prove that a document is approved. |
| **Try Casey** | Select **Casey · connected healthcare** and click **Start a new conversation**. Ask how clinical care connects to enterprise operations and what can be concluded about availability in your region. | Inspect S10 PDF pages 3 and 10 together. The answer should preserve scope and availability limitations rather than assume regional availability. |

The **Where do I start?**, **Why these sources?** and **What next?** buttons populate the question box. Click **Explore this question** to send the selected question.

## Explore the expanded research with Casey

Use this optional journey to compare an original presentation with added research and a public webpage. It uses the same preview/apply controls and does not alter the source collection.

1. Select **Casey · connected healthcare** and click **Start a new conversation**. Check the current context before making a change.
2. Open **Context**, choose **Add an area to explore**, select **Healthcare** and click **Preview refinement**. Read the proposed ADD_TOPIC operation, then click **Apply this refinement**.
3. Open **Evidence**. In the expanded-data browser check, six passages were returned across **S10**, **R0046**, **R0528**, **R0546** (Community Health Systems presentation) and **R0691** (Community Health Systems customer webpage). The answer cited S10, R0546 and R0691. Distinguish evidence returned to the model from evidence explicitly cited in its answer. This bounded packet is not every matching healthcare source; it can differ with the installed dataset or later refinements.
4. Return to **Conversation**, keep **Explore and ask about content**, and submit:

   ```text
   Using the returned summaries, how do clinical care and enterprise operations connect? Which benefits are reported or projected, and what does this material establish about availability in Australia? Cite the exact passages and identify what remains uncertain.
   ```

5. Open **How was this answer built?** and select the new source and passage nodes. Check **Sources**, then **Answer lineage**. R0691 is a webpage: its evidence should show a recorded section label and a public link, not a made-up PDF page. Its section is labelled **Solution and results: Standardized processes with cloud applications**. PDF evidence retains its actual page or supporting-page links.
6. Compare the answer with the full saved summaries. R0546 and R0691 distinguish reported operational changes from expected savings. S10 preserves the country/region and prospective-US qualification. The supplied evidence does not establish Australian availability or prove that projected savings have been realised. The answer should preserve those limits and describe editorial summaries as summaries, not source quotations.
7. Save an observation describing the source detail you checked and the next information you would seek. Use a new question or preview/apply another refinement to continue.

**Expected outcome:** the graph connects Casey's added topic to newly supplied research, the explanation identifies the evidence actually returned for that answer, and public page links make the supporting context inspectable. A public URL, matching topic or citation does not certify a claim. The packet remains limited to six passages and two locators per source; its order is deterministic rather than semantic relevance ranking.

## When something looks unexpected

- **The objective changed but the sources did not:** expected when topic membership is unchanged. Compare the focus of the next answer as well as the paths.
- **The answer differs from this walkthrough:** inspect the actual evidence and limitations. Model prose varies; the source IDs above describe the supplied dataset and validated run, not a fixed answer template.
- **A preview has expired or no longer matches the current revision:** preview the intended change again. Tokens are revision-bound and expire after ten minutes.
- **The app is still exploring:** wait for the status to return to Ready or show an error. Avoid submitting duplicate model requests. If it fails, retain the displayed error for diagnosis.
- **The login expired:** sign in again and start a new conversation. An old Worksheet or APEX session ID cannot be transferred into the new authenticated session.

## Relationship to the original HOL

The original workshop's chatbot journey asks questions, checks a stored graph fact, performs a guarded change, asks again and restores the fact. This adaptation retains the inspect/change/compare learning pattern while refining a person's context over curated source knowledge. Source-graph maintenance, ingestion, ontology editing and optional inference are separate exercises.

See the [adapted SQL scenarios](../labs/07_original_workshop_scenarios.md), [original workshop comparison](upstream-comparison.md) and [validation record](scenario-validation.md). The main Alex UI flow was first exercised on the temporary ADB Serverless instance on 18 November 2026. The expanded summary dataset's Alex refinement/history and Casey added-research journeys passed [real-model and signed-in browser acceptance](../references/expanded-ui-validation.json) on 23 November. Optional branches are not all claimed as live tests.
