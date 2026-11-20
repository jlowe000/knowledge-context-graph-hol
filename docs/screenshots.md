# Screenshot checklist for the beginner HOL

Screenshots support a decision or confirm a result. They do not replace the numbered steps, copyable commands or expected outcomes. Use real product screens, meaningful alternative text and a caption beside the task they explain. Keep labels consistent with the Console/APEX version used for capture.

Two application screenshots from the validated lab are included in [Explore Evidence](../labs/explore-evidence/explore-evidence.md). The remaining setup images below are a **capture plan**, not evidence that a new empty instance was provisioned for this documentation review. Do not add broken placeholder image links to learner pages.

| ID | Lab/task | Capture and useful callout | Learner question answered | State |
| --- | --- | --- | --- | --- |
| S01 | Create database / Task 1 | Provisioning form: Serverless, 26ai, workload; exclude password fields and personal tenancy details | Have I selected the right kind of database? | Capture on clean run |
| S02 | Create database / Task 1 | Details page: Available and Database actions → SQL; keep private identifiers/URLs outside the frame | Is it ready, and where do I click next? | Capture on clean run |
| S03 | Create database / Tasks 2–3 | Worksheet editor, Run Statement, Run Script and result tabs; visible ADMIN role | Where do I paste code and read the result? | Capture on clean run |
| S04 | Configure database / Task 1 | JAVAVM VALID query output and successful runtime query | Has Java finished installing? | Capture on clean run |
| S05 | Configure database / Task 2 | Empty password bind dialog with the field name and submit control; no entered values | Where do I enter a value without editing a script? | Capture on clean run |
| S06 | Configure database / Task 3 | KCV_LAB user menu and SELECT USER result | Am I using the right account? | Capture on clean run |
| S07 | Configure database / Tasks 4–5 | Non-secret profile-setting variable names; successful greeting result; no key/OCID/account details | What must I configure, and did model access work? | Capture on clean run |
| S08 | Load knowledge / Tasks 1 and 3 | Native graph PASS messages, not just “procedure completed” | Did evidence retrieval actually work? | Capture on clean run |
| S09 | Deploy application / Task 3 | Successful import and generated application ID | Which result tells me installation completed? | Capture on clean run |
| S10 | Deploy application / Task 4 | Empty app sign-in fields and a separate workspace landing view | Is this the app login rather than Database Actions? | Capture on clean run |
| S11 | Explore evidence / Task 1 | Learner selector, four workspace views, first question/answer | Where does the learner start? | Capture current app |
| S12 | Explore evidence / Task 2 | Sources graph with selected topic/source and page nodes | Why was this source connected? | Included: sources-graph.jpg |
| S13 | Explore evidence / Task 3 | Answer lineage with captured tool output and matched citations | How was this response supported? | Included: answer-lineage.jpg |
| S14 | Explore evidence / Task 4 | Preview/apply control and current-versus-historical selection after removing a topic | What changed, and what stayed preserved? | Capture current app |
| S15 | Explore evidence / Task 5 | Observation fields plus saved confirmation, using fictional sample text | How do I record learning and continue? | Capture current app |

The included screenshots show the earlier extracted-passage dataset. This release loads editorial summaries with different citation IDs and wording. Use the images to locate controls; they do not demonstrate native acceptance of this changed dataset.

## Capture procedure

1. Rehearse the beginner route on a new approved database. Capture each screen immediately after the corresponding task reaches its expected outcome.
2. Use an empty credential-entry dialog when illustrating binds. Never take an image while a private key, password or token is visible. Avoid private endpoints, live session URLs, tenancy identifiers and personal names in the frame. Do not put secrets into a screenshot and rely on an annotation to conceal them later.
3. Show enough surrounding UI to identify the page and account role. Keep the text legible at normal viewing width; use a focused crop only where it preserves the relevant context. The supplied real screenshots are around standard desktop width and contain public/fictional content only.
4. Place images under the relevant lab's `images/` folder with descriptive lowercase filenames. Use relative Markdown links and alternative text describing the control/result, not “screenshot.”
5. Add callout numbers only where they clarify a choice; pair them with written steps. Do not create images of code as the only runnable instructions.
6. Record capture date, APEX/Console context and what was verified in the validation record. Label conceptual wireframes separately; they are not installation screenshots.

The included images were captured on 19 November 2026 from APEX 26.1.6. Turn IDs and graph revision names are example values, not inputs for another installation. A fresh-instance screenshot set and first-time-learner rehearsal remain outstanding.
