# Knowledge Context Explorer: implementation epics

Implementation update: 19 November 2026. Both epics are built and deployed to the temporary Serverless app. Native tool capture and local regression/UI checks passed; authenticated cloud browser acceptance passed as KCV_USER. Traditional workspace with Iris is the selected layout. Stories below remain within their parent epic.

| Epic | Outcome | Detailed plan |
| --- | --- | --- |
| **EPIC-01 — Explain each answer through recorded context and evidence** | A learner can open an answer-specific popup and inspect its actual context, graph connections, tool-returned passages and citation matches, even after subsequent refinement. | [Response provenance plan](response-provenance-plan.md) |
| **EPIC-02 — A coherent Oracle-style learning workspace** | A familiar, accessible APEX layout makes the conversation, evidence and context easier to navigate, using a supported Universal Theme style with restrained custom styling. | [Styling and layout plan](ui-styling-plan.md) |

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
