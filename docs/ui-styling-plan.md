# EPIC-02: styling and layout

Status: implemented and deployed, 19 November 2026; cloud browser acceptance passed. Selected design: Traditional workspace, Iris.  Parent: [implementation epics](implementation-epics.md). Layout samples are conceptual interactive wireframes with sample content, not screenshots of the live app or official Oracle components.

## Can Redwood be applied?

Yes, through APEX Universal Theme. Oracle's APEX 26.1 documentation lists Redwood Light, Vita and Iris styles. Redwood Light provides a spacious Fusion-like appearance; Oracle describes Iris as Redwood-aligned and built on Vita. The deployed database currently has APEX 26.1.6, so evaluate those installed styles rather than requiring a different application framework.

Recommended starting point: **Traditional workspace with Iris**, retaining Redwood Light as a comparison if closer Fusion styling is preferred. Confirm the actual subscribed theme version and available styles in the installed application. APEX runtime version alone does not prove its theme subscription is current. This is alignment through APEX, not a claim to implement every Fusion Redwood component or interaction.

The current shell uses Universal Theme, but most app content sits inside a static region with custom colors, typography, rounded panels and controls. Merely switching the shell's theme style will not make that custom content consistent. Replace overlapping overrides with supported region templates, native controls and theme variables. Retain custom code for the response/evidence graph where it adds value; scope it and inherit the selected theme.

References checked 19 November 2026:

- [APEX 26.1 theme styles](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/theme-styles.html)
- [Universal Theme design system](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/universal-theme-design-system.html)
- [Oracle APEX: Iris and Redwood alignment](https://blogs.oracle.com/apex/universal-theme-evolves-with-the-new-iris-theme-style-smarter-templates-and-modern-ux-capabilities)

## Layout candidates

| Candidate | Composition | Strength | Trade-off |
| --- | --- | --- | --- |
| **Traditional workspace — recommended** | Persistent app navigation; scenario header; Conversation, Evidence and Context views. Observation capture is a task available within the same workspace. | Familiar enterprise layout; separates dense content without a long page; makes evidence a first-class destination. | Learners switch views to compare some information. Preserve draft and view state. |
| **Guided journey** | A task sequence: Understand → Explore → Refine → Reflect. Each step presents the relevant controls and expected result. | Strong first-run HOL experience and facilitator-led demonstrations. | Less efficient for experienced users who move repeatedly between tasks. Permit revisiting steps without restarting or forcing validation. |
| **Conversation workspace** | Conventional conversation list/navigation on the left, chat in the main area, context/evidence inspector beside it. | Familiar chat pattern, with supporting context near the answer. | Three columns need a wide screen; inspector must become a drawer or separate view on smaller screens. No claim of cross-login history unless separately implemented. |

All candidates include the same answer-specific **How was this answer built?** popup from EPIC-01. Choosing a different layout does not change the retrieval policy, graph model or allowed refinements.

## Stories and deliverables

### E2.1 — Review the design

Produce three wireframes using the same Alex question and source IDs. Let the reviewer switch designs, inspect conversation/evidence/context and open a sample explanation. Include sample states for objective-only refinement versus topic removal. Clearly mark sample content and do not connect wireframes to real credentials or inference services.

Review tasks:

1. Find Alex's current objective and ask a question.
2. Find why S02 is connected and identify a supporting page.
3. Open the explanation for a particular answer and distinguish it from the current-context view.
4. Find how to refine focus and inspect the effect of removing Graph capabilities.
5. Find where to record an observation and next step.

Assess discoverability, reading effort, clarity of current versus historical state and ease of returning to the conversation. Select one layout and theme direction before production CSS work. Sample interaction states are demonstrations, not saved data or validation results.

### E2.2 — Design foundation

- Inventory the app's subscribed Universal Theme version, available styles, templates and current overrides in an isolated app copy.
- Compare Iris and Redwood Light using the same populated page; adopt one named style and document it. Preserve the existing app for rollback.
- Use the theme for navigation, headings, spacing, inputs, buttons, dialog and status treatment. Prefer established APEX patterns over a bespoke application shell.
- Replace hard-coded colors in the custom region and SVG with theme-derived variables; provide explicit selected/focus/error states with text or shape in addition to color.
- Set a compact/readable content hierarchy. Model JSON should be progressively disclosed where appropriate; source assessment, caveats and next question remain readable prose/list content. Keep raw output available for inspection without presenting it as the primary reading experience.

### E2.3 — Workspace and interactions

- Implement the selected arrangement using page/region navigation appropriate to APEX. A tab/view switch must preserve unsent text, selected response and pending refinement.
- Keep scenario selection and active objective visible. Put detailed context editing behind a clear Refine context action; preserve preview/apply semantics.
- Give evidence its own discoverable space: graph, selected relationship explanation, source passages and public page links. Label it **Current context evidence**.
- Use consistent source/topic selection across graph and passage list. Provide a textual path alternative and an explicit empty state.
- Keep observation capture reachable without forcing an experiment or a linear completion gate. Distinguish source checks, discussions, votes and practical tests.
- Style the response explanation as a historical, answer-specific view labelled with the recorded revision. It must not overwrite the current-context evidence panel.
- Retain source scope/availability caveats and asynchronous status/error feedback. Avoid decorative confidence scores, false progress percentages and claims that a source was newly discovered merely because it entered the capped packet.

### E2.4 — Accessibility, packaging and acceptance

- Check wide desktop, approximately 768px tablet and 375px phone, plus 200% browser zoom. Navigation and inspectors should reflow; reading should not require page-wide horizontal scrolling. Offer a readable graph alternative at narrow widths.
- Exercise keyboard order, labelled inputs, dialog focus/close/return, contrast and status announcements. Native theme support helps but does not replace testing the custom graph and content.
- Run the existing start → question → objective refinement → topic removal → follow-up → observation journey, plus the historical popup checks from EPIC-01.
- Regenerate APEXlang and the engine-generated SQL export. Verify the DOMContentLoaded startup fix remains. Record exact theme/style and app versions in validation documentation.
- Update the UI walkthrough and facilitator screenshots to match the selected layout; do not present conceptual wireframes as deployment evidence.

## Boundaries and decisions

This epic changes presentation and navigation. It does not add graph editing, new retrieval ranking, automatic model training, cross-login conversation history or external services. Existing session ownership remains unchanged. Any new model-backed action or persistence capability suggested by design review needs an explicit story and data contract rather than being implied by a mockup.

Decisions for review: preferred layout; Iris versus Redwood Light appearance; whether evidence should be a dedicated view or a persistent inspector; how much guidance first-time learners need. The recommendation is a traditional workspace with evidence as a dedicated view and a short optional first-run guide.
