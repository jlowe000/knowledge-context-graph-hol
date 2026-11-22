# Knowledge Context Explorer — APEX chatbot

Application icons use Font APEX from the Oracle APEX team. See [attribution](../third-party/font-apex/README.md) and the [retained licence](../third-party/font-apex/LICENSE.txt). Include these files and [NOTICE](../NOTICE.md) when distributing the SQL export separately.

**First deployment:** follow the [fresh Serverless walkthrough](../docs/fresh-serverless-deployment.md). **Existing explorer:** follow the [upgrade guide](../docs/epics-upgrade.md). The installation details below assume the base database objects, dataset and working model profile already exist.

An authenticated APEX app for the extended knowledge/context scenarios. It uses the database's existing GenAI profile and the new KCV_EXPLORER_TEAM. There is no OpenAI/OCI key in browser code and no separate APEX Generative AI service configuration is required.

## What the app does

- Start with Alex, Sam or Casey, each explicitly fictional.
- Ask questions or request a proposed refinement, using a registered database conversation.
- Inspect source-page links and a visual of actual returned context/topic/content edges.
- Preview a structured objective/topic edit, then explicitly apply it. Removal does not delete a public source; it removes an interest from a new context revision.
- Compare the resulting graph paths and recommendations. Earlier revisions and turns remain available in the database.
- Record a source check, discussion, dot vote, practical test or another observation, plus the next question/step.

The UI displays model output as text, never as executable HTML. Public links are restricted to HTTPS static.rainfocus.com source pages. Scenario access is checked against APP_USER, APP_ID and APP_SESSION on the server. This is a public-sample lab, not a production multi-tenant knowledge portal.

## Install through APEX App Builder

For the user's temporary ADB Serverless instance, follow the [Serverless workspace and deployment sequence](../docs/serverless-apex-deployment.md). A local test workspace is not needed on that route.

1. Complete [scenario setup](../docs/scenario-setup.md), including `05_apex_api.sql`, as KCV_LAB. Retain the existing working credential/profile/base graph. Never install the files under `integration-test/mocks/` in KCV_LAB.
2. Confirm the target APEX version:

```sql
SELECT version_no FROM apex_release;
```

The SQL export was generated and test-imported on **APEX 26.1.5** with SQLcl 26.2.1. Use APEX 26.1 or later; import into older APEX is not claimed. The complete backend remains usable from Worksheet if the UI version differs.

3. Open APEX Administration Services and create a workspace using the **existing database schema KCV_LAB**, or have the workspace administrator map KCV_LAB to an existing suitable workspace. This is APEX workspace administration, not the ORDS Database Actions route. Do not create a new empty database schema and accidentally use it as the parsing schema.
4. Sign in to that workspace as an APEX developer. In App Builder select **Import**, upload [kcv-explorer.sql](kcv-explorer.sql), choose Application/Page/Component Export, UTF-8, and continue.
5. On installation, select **KCV_LAB** as Parsing Schema and choose a **new available application ID**. Do not overwrite an unrelated application. The export's default workspace/schema/application IDs belong to the isolated local test; remap them in the wizard. These are not required target values.
6. Install and run. Authentication is **Oracle APEX Accounts**. Use an APEX account permitted to run apps in this workspace; a database/OCI login is not automatically an APEX application account. Create or manage those accounts through the workspace administration UI. No test password or workspace account is included in the export.
7. Choose Alex and click **Start a new conversation**. Current understanding, graph connections and public source cards should appear without making a model call. An error at this point is a database/graph setup error; inspect its reported message before sending a model request.
8. Ask a question. Then follow [the scenarios](../labs/07_original_workshop_scenarios.md). One scenario session belongs to the signed-in APEX session; after logout or an expired login, start a new one. The UI restores a scenario only within the same browser/APEX session.

Oracle references: [importing application exports](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/importing-export-files.html), [installation remapping](https://docs.oracle.com/en/database/oracle/apex/26.1/aeadm/installing-an-application.html).

## First user journey

For the complete UI instructions, copyable prompts and expected outcome at every step, follow the [UI walkthrough: from a broad interest to a useful next step](../docs/ui-walkthrough.md).

1. **Start:** CTX01 / Alex. Ask: “Which sources could help me find existing project information, and why?”
2. **Inspect:** Follow a source link and open Exact graph paths. Compare the model's explanation to the returned topic joins.
3. **Refine:** Open Refine the stored context → Clarify the objective. Enter “Find existing project information across documents; approval and workflow are out of scope.” Preview, inspect and apply.
4. **Compare:** The objective and revision change; topics and eligible sources may remain the same. Ask again to compare the explanation.
5. **Change focus:** Remove Graph capabilities from the scenario's topics. Preview/apply, then inspect the changed paths and ask again. This is the before/after counterpart to the original HOL's guarded graph-change exercise.
6. **Validate understanding:** Discuss the results, check a source, record differing priorities with a dot vote or try a practical test. Capture what you actually observed and what it suggests exploring next. Do not enter a predetermined successful result.

## Files and rebuilding

| File | Purpose |
| --- | --- |
| `kcv-explorer.sql` | APEX-engine-generated application export; import through App Builder |
| `region.html`, `explorer.css`, `explorer.js` | Editable UI source, with no build/runtime npm dependencies |
| `application/` | Standalone APEXlang application source with Universal Theme and APEX Accounts login |
| `../sql/extensions/05_apex_api.sql` | Server-side authenticated AJAX process adapter |

To rebuild the APEXlang page after editing assets:

```bash
python scripts/build_apex.py
```

For optional SQLcl authoring, connect to the intended database privately and run the following, replacing the workspace and choosing a free application ID. Importing updates the selected application if it already exists, so inspect the target first:

```text
apex validate -input apex/application -workspace YOUR_WORKSPACE
apex import -input apex/application -workspace YOUR_WORKSPACE -schema KCV_LAB -id YOUR_NEW_ID -alias KCV-EXPLORER -name "Knowledge Context Explorer"
apex export -applicationid YOUR_NEW_ID -exptype SQL -dir work/apex-export
```

The published SQL export must be regenerated after an asset change; changing the source files alone does not change the already exported app. The generated export is not a handwritten imitation of APEX internal import APIs.

## Local test status and deployment limit

The app imported successfully into a separate local KCV_HOL_TEST workspace. Packages compiled and component tests passed using explicit native/model service mocks. An APEX-session callback test returned context, source metadata and graph paths. Those local results do not validate native RDF/model operations in that container. Separately, the app was rebuilt on temporary Serverless APEX 26.1.6 and passed the signed-in real-model/evidence/refinement/observation browser journey on 23 November. See [validation](../docs/scenario-validation.md) for the exact checks and remaining limits.

## Cleanup

Export any scenario observations/transcripts you need. Remove only this app using App Builder and its dedicated lab workspace if no other apps use it. Context overlays, domain proposals and inference graphs are database objects and are not removed by deleting the APEX app. Inspect their recorded names before explicitly retiring them; see [cleanup](../docs/cleanup.md).

## Planned response explanation feature

See the [two-epic implementation plan](../docs/implementation-epics.md): EPIC-01 covers per-response process/evidence popups, and EPIC-02 covers Oracle-style presentation and layout. Both are now implemented and deployed to the temporary Serverless app; see the validation record for actual checks and limits.

## Response explanations and workspace upgrade

The traditional workspace uses Iris with Conversation, Evidence, Context and Observations views. Each assistant response can open Sources and Answer lineage graphs based on its saved execution. Pre-feature turns show a legacy notice. Follow the [upgrade sequence](../docs/epics-upgrade.md) before importing the new export. Application CSS/JavaScript are now retained as editable assets and generated application static files by `build_apex.py`.
