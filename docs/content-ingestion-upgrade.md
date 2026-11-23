# Use evidence from pages, PDFs and repositories

The expanded dataset includes non-PDF evidence. PDF page numbers remain real page numbers; other passages carry a `locator_kind` and `locator_label`. The runtime uses selected inspected locations, returning up to two locators per source and six passages in total. Sources used in the original lessons take priority, followed by catalogue IDs. This is a bounded topic join, not exhaustive document reading or a semantic ranking. Summaries spanning multiple locations include separate links to each supporting location. Additional catalogue sources may fill unused slots, including in the healthcare scenario; the S10 overview and qualification must remain present.

## Existing database

As KCV_LAB in Database Actions Worksheet, run [08_content_locators.sql](../sql/extensions/08_content_locators.sql) with F5 before loading the new dataset. It permits a null PDF page for non-PDF evidence and retains existing records. Fresh installations already use the updated table definition and can skip this migration.

```sql
DECLARE nullable_flag VARCHAR2(1);
BEGIN
 SELECT nullable INTO nullable_flag FROM user_tab_columns
  WHERE table_name='KCV_PASSAGES' AND column_name='PDF_PAGE';
 IF nullable_flag='N' THEN EXECUTE IMMEDIATE 'ALTER TABLE kcv_passages MODIFY (pdf_page NULL)'; END IF;
END;
/
```

Run [03_tools.sql](../sql/schema/03_tools.sql), [06_response_provenance.sql](../sql/extensions/06_response_provenance.sql), [02_scenario_api.sql](../sql/extensions/02_scenario_api.sql) and [05_apex_api.sql](../sql/extensions/05_apex_api.sql) in that order, using F5 for each complete file. The provenance script is rerunnable and preserves captured responses; it installs the corrected parser for explicit citation strings and objects. The source packet now returns only passages linked to the active graph. Earlier versions could include historical extracted passages sharing a source edition with the current summaries. Existing function signatures and historical rows are retained; do not delete old evidence to avoid these issues.

Do not recreate credentials or agent registrations. Load the new dataset using the [GitHub load guide](github-dataset-load.md) or the documented local alternative. Existing conversations keep their pinned graph; start a new conversation to use the newly active graph.

```sql
SELECT name,line,text FROM user_errors
WHERE name LIKE 'KCV%' ORDER BY name,sequence;
```

Expected outcome: no compilation errors. After loading the data, run [verify_source_packet_scope.sql](../integration-test/verify_source_packet_scope.sql) alone with F5. It inserts a temporary passage outside the active graph, checks that the source packet excludes it and that every returned passage belongs to that graph, then rolls back its fixture. Expect `PASS: source packet returns only active graph evidence; fixture rolled back`.

Run this source-scope check alongside [verify_github_dataset.sql](../integration-test/verify_github_dataset.sql) and the native scenario check before considering the upgrade validated. These SQL checks make no model calls. Installing the files alone does not establish a native pass.

## Update the application

The supplied [engine-generated SQL export](../apex/kcv-explorer.sql) has been regenerated with the non-PDF display changes and versioned application assets. For a new app, import that export using the normal [APEX installation steps](../apex/README.md). No separate JavaScript upload is required.

For an existing app, back up its current export, verify its workspace, parsing schema and application ID, then import the current export into that same lab application. Retain the backend objects, credentials and dataset. An application import can expire the current app login; sign in again and start a new conversation to use the newly active graph. Do not overwrite an unrelated application.

### Manual fallback for an older installed export

Use the steps below only when retaining an older app export that still renders PDF-only labels. They update the display file without replacing the full application. This fallback does not install backend changes or replace the current export as the normal deployment path.

This requires an APEX workspace developer or administrator account in **KCV_KNOWLEDGE**. **KCV_USER** is intentionally an end-user account and cannot perform it. Ask your workspace administrator to carry out these steps if you only have app access.

1. Open App Builder and select this lab's application. Open **Shared Components → Static Application Files**.
2. Locate `explorer.js` and download a backup. Select that file and delete only it.
3. Choose **Create File**, leave Directory empty, upload the supplied [explorer.js](../apex/explorer.js), and create it under the same name. Its reference must be `#APP_FILES#explorer.js`.
4. Open page **1 / Home** in Page Designer. Select the page node; under **JavaScript → File URLs**, replace only the explorer.js entry with `#APP_FILES#explorer.js?v=content-locators-v2`. Save. The changed query suffix prevents reuse of the old cached asset.
5. Run the app, start a new conversation and open **Evidence**. PDF cards retain their page labels. When a non-PDF passage is selected, it shows its recorded locator and opens the approved public source. The content-kind label distinguishes extracted text from editorial summaries.

These file-management operations follow Oracle's [APEX 26.1 static application file instructions](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/managing-static-application-files-in-the-database.html). Keep the backup until this check passes. If you use the fallback, export your updated application through App Builder to retain the change for your own future deployments.

## Validation boundary

The JavaScript helper tests cover permitted publishers, blocked/private and credential-bearing links, and real non-PDF labels. APEXlang asset synchronisation and JavaScript syntax checks run locally. On 23 November 2026, the updated source tools, scenario and APEX backend packages compiled without errors on ADB Serverless; the summary dataset load, source-scope regression and native graph/scenario checks passed at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`. See the [native validation record](../references/github-dataset-validation.json). That run made no GenAI inference calls or APEX browser tests. Subsequent [real-model and signed-in APEX acceptance](../references/expanded-ui-validation.json) passed with the regenerated export and citation parser `4-explicit-citation-ids`. The check covered historical explanations, refinement, new research, non-PDF public links and observation capture.
