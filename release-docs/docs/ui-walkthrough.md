# Use the collection with your own context or a sample

Use your individual application login. No OCI Console or SQL access is needed for this journey. A shared login shares the same personal library; it does not isolate the people using it.

## Choose the starting point

| Start | Action | Expected outcome |
| --- | --- | --- |
| My own question | My Contexts → Create context | A named owned draft, even before the objective is clear |
| A starting suggestion | Sample Contexts → Save as my draft | An owned draft copied from sample suggestions, with fictional personal framing cleared |
| A guided fictional example | Sample Contexts → Explore the samples | The separate Alex/Sam/Casey experience |

The [My Contexts lab](../labs/my-contexts/my-contexts.md) gives the full personal journey. The [sample lab](../labs/explore-evidence/explore-evidence.md) demonstrates a bounded topic refinement. Samples remain shared templates; personal drafts, revisions, conversations and observations are runtime data excluded from the public dataset.

## Personal journey and expected outcomes

| Step | Action | Expected outcome |
| --- | --- | --- |
| Save | Enter a name and save; add question, objective clarity, background and topics when ready | The draft persists; local search embeddings may refresh, but no answer/ready revision is created |
| Review | Review and Apply; inspect before/after and cancel once | No change is applied until explicit confirmation; incomplete drafts explain what is missing |
| Apply | Apply the reviewed context | An immutable private revision becomes ready; public facts are unchanged |
| Converse | Start or reopen a conversation, ask, then inspect How was this answer built? | Evidence is captured before model dispatch; citation matches link to supplied summaries |
| Refine | Edit/save/review/apply, then choose Use the latest ready revision in the existing conversation | The conversation changes only on explicit adoption; older answers keep old context/evidence |
| Record | Save an observation and possible next step | A revision-linked learning record, not automatic fact acceptance or model training |
| Return | Sign out/in, search the library and reopen | The same app account can continue its saved work |

Search matches titles and saved details, optionally by local semantic similarity. Read Saved objective, Why it matched and coverage notices. All/Draft/Active/Archived filters remain owner-scoped. The [search guide](context-search.md) explains keyword fallback and why this differs from public knowledge retrieval.

Archive is reversible: choose Archived, open the context and Unarchive. Delete Context is permanent and has a separate review/retry flow; only test it on disposable work. See [acceptance status](scenario-validation.md), which distinguishes native deletion from the final browser confirmation.

## Explain one answer

Open How was this answer built? for the response you want to inspect. Sources shows the selected topics, content, versions and actual returned passages. Answer lineage shows the saved context, pinned graph, **Application evidence retrieval**, model dispatch and stored response. New retrieval happens before the answer task, not at the model's discretion.

The graph records observable relationships; it is not hidden model reasoning. Cited evidence is distinct from material returned but not cited. Opening the explanation makes no model request. Historical answers can show their earlier revision/legacy event representation. An unavailable or incomplete trace must be labelled, not presented as proof of a successful answer.

Summaries are attributed editorial text with original source links. A matched citation establishes traceability, not factual correctness or observed business value. Follow the source and retain roadmap/region qualifications.

## Explore the expanded research with Casey

In Sample Contexts, choose Casey and Explore the samples. Ask which evidence is relevant to the fictional healthcare context and what availability limits remain. Inspect S10's overview and qualification alongside other returned sources. The supplied packet is capped; it is not an exhaustive search of all 834 references.

Change a sample topic using its preview/apply controls, ask again and reopen the original explanation. Topic removal narrows learning focus rather than prohibiting technology. Clarifying only an objective can change interpretation while leaving selected sources unchanged. These sample controls are distinct from the personal full-context editor and explicit conversation adoption.

The original workshop's inspect/change/compare pattern is retained; ontology editing, ingestion, the broader learning loop and Explorer evaluation are separate work. Continue with [developer learning](../labs/understand-collection/understand-collection.md) to inspect the implementation.
