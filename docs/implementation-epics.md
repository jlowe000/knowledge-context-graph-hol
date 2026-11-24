# Knowledge Context Explorer: implementation epics

Implementation update: 24 November 2026. EPIC-01 and EPIC-02 remain deployed; Traditional workspace with Iris is the selected layout. EPIC-03 now has the R4 application-retrieval path. Native schema/import checks, initial/adopted answers and the negative retrieval test passed. An independent authenticated browser test continued the saved conversation after actual provider expiry with pre-model evidence, matched citations and unchanged historical hashes. A separate strict native expiry answer returned malformed JSON despite successful retrieval, so full model-suite acceptance remains partial. The matching R4 engine export/receipt and generated wrappers are prepared; fresh deployment and Worksheet execution remain unverified. See the [R4 record](../db/verification/c3-r4-validation.json) and [journey record](../references/my-contexts-c3-validation.json). EPIC-04 and EPIC-05 remain separate future work outside this delivery. Stories remain within their parent epic.

| Epic | Outcome | Detailed plan |
| --- | --- | --- |
| **EPIC-01 — Explain each answer through recorded context and evidence** | A learner can open an answer-specific popup and inspect its actual context, graph connections, tool-returned passages and citation matches, even after subsequent refinement. | [Response provenance plan](response-provenance-plan.md) |
| **EPIC-02 — A coherent Oracle-style learning workspace** | A familiar, accessible APEX layout makes the conversation, evidence and context easier to navigate, using a supported Universal Theme style with restrained custom styling. | [Styling and layout plan](ui-styling-plan.md) |
| **EPIC-03 — My Contexts** | People create, refine and reopen their own contexts and conversations, with durable ownership and original answer evidence. Dev uses native APEXlang authoring and Liquibase-managed database migrations; release retains prepared Worksheet deployment. | [Implementation plan](my-contexts-implementation-plan.md) |
| **EPIC-04 — A deliberate learning loop (future)** | People connect knowledge to a theoretical or practical activity, record observations with evidence, then assess and refine their context using explicit judgement. | Future scope below; not part of My Contexts delivery. |
| **EPIC-05 — Evaluate the Explorer (future)** | Evaluate whether the Explorer helps a defined process reach an acceptable, justified next step or refinement with the least necessary time, effort and cost. | Future scope below; not part of My Contexts delivery. |

## EPIC-01 — Explain each answer through recorded context and evidence

Keep the entire [existing feature plan](response-provenance-plan.md) as one epic. Its storage, actual tool capture, authorization, API, popup, tests, export and deployment stages are implementation stories, not separate epics.

- **E1.1 Capture:** additive migration, paired turns/runs, immutable input/tool snapshots and execution correlation.
- **E1.2 Retrieve:** authorized historical trace endpoint, safe citation matching and legacy/failure behaviour.
- **E1.3 Explain:** per-response button, accessible popup, graph/evidence highlighting and plain-language boundaries.
- **E1.4 Validate and deliver:** component/native/browser acceptance, regenerated export, upgrade steps and walkthrough.

**Acceptance:** an earlier answer still shows its original evidence after context changes; actual tool returns are distinguished from model statements; trace access respects the existing APEX identity/session boundary; opening the explanation makes no model call or context change. See the detailed plan for complete tests. Comparing two saved responses is a possible later story within this epic, not a third epic.

## EPIC-02 — A coherent Oracle-style learning workspace

- **E2.1 Review the design:** compare Traditional workspace, Guided journey and Conversation workspace wireframes with the same Alex scenario and explanation popup. Select a layout based on learner tasks.
- **E2.2 Apply the design foundation:** inspect installed Universal Theme styles, choose Iris or Redwood Light, reduce hard-coded custom CSS and align content with theme tokens/components.
- **E2.3 Restructure the experience:** implement navigation, context editing, source exploration, response layout and observation capture without changing their underlying meaning.
- **E2.4 Integrate and deliver:** style the EPIC-01 popup consistently, test responsive/keyboard behaviour, regenerate the APEX export and update screenshots/documentation.

**Acceptance:** all current learner actions remain available; current scenario evidence and historical response evidence are clearly labelled; important graph/source controls are findable; the chosen style applies consistently across login, app shell, content and popup; the app works at narrow widths and with keyboard navigation. Visual styling must not imply that recorded opinions or connected topics prove factual correctness.

## Sequence and dependencies

Design review can proceed while E1.1/E1.2 are implemented. Choose the layout and theme before finalizing the popup chrome and page composition. E2.3 may ship with a disabled/unavailable explanation state until EPIC-01 is ready; it must not simulate provenance as a production feature. Complete integrated regression and a single coordinated APEX export/import after both epics are ready to minimize repeated sign-ins.

No new database service, external frontend framework or model provider is required by either epic. The existing ADB Serverless/APEX architecture remains the baseline. Build first in an isolated application/workspace; retain the working app export for rollback. Deployment and actual acceptance are recorded separately from these plans.

## EPIC-03 — My Contexts (v2.0.0 in development)

The [My Contexts flow](my-contexts-flow.md) describes personal context creation, saved conversations, refinement and authorized reopening after sign-in. The [detailed dev implementation plan](my-contexts-implementation-plan.md) defines eight stories, concrete storage/API/page contracts, four parallel work lanes, native APEXlang authoring, SQLcl/Liquibase migrations, separate fresh/install-upgrade paths, SQL-first learner delivery and acceptance checkpoints. The persistent-draft increment is deployed and validated in the isolated test app; see its [C2 acceptance record](../references/my-contexts-c2-validation.json). The current work completes activation, personal conversations, explicit refinement, continuation and native-page integration for a manually testable dev candidate. NVIDIA Auto Ontology is excluded. No v2 release promotion has occurred. Private runtime contexts remain separate from the public sample dataset.

## EPIC-04 — A deliberate learning loop (future)

Keep this separate from the current My Contexts implementation. Its proposed flow is context → relevant knowledge → theoretical or practical activity → observations with evidence → assess/refine → updated context. An activity may be discussion, validation, a consensus vote, analysis or an experiment; it should not automatically be called an experiment.

Future stories cover selecting an activity and expected learning, linking observations to supporting evidence, reviewing what changed or remains uncertain, and making an explicit decision about the next thought or step. User judgement stays visible. Recording an observation or receiving a model recommendation never automatically publishes a context revision or changes source knowledge. Existing observation capture and explicit context refinement remain in EPIC-03; activity planning, assessed learning cycles and their additional workflow belong here.

## EPIC-05 — Evaluate the Explorer (future)

Evaluate the Explorer itself and the defined process of using it. First establish a task, baseline and an acceptable outcome, such as a justified next step or a useful context refinement. Then assess quality against those criteria alongside time, effort, model cost, reliability and qualitative friction. The aim is an effective process that reaches the acceptable outcome with the least necessary cost.

Future stories cover evaluation tasks and baselines, evidence-backed judgements of the resulting next step/refinement, bounded operational measurements and participant feedback. Do not turn this into a score for the business value of knowledge, claim downstream business outcomes from interaction counts, or add evaluation telemetry to the current My Contexts delivery. Evaluation findings may inform later product improvements through a separate review.
