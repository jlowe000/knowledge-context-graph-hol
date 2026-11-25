# APEXlang development on dev

The v2 application is authored directly under `apex/application/`. SQL/PLSQL still implements database APIs and native page processes. The large `apex/kcv-explorer.sql` is an engine export for deployment; it is not the maintained application definition.

## Current candidate

R7 adds local context search and saved-objective previews on page 10. Its [validation record](../db/verification/context-search-validation.json) reports native upgrade/repeat, search regressions, APEX import with nine pages/seven assets/33 parsed components, and scoped browser search/filter checks. The [R5 deletion record](../db/verification/context-delete-validation.json) retains successful native tests and browser review/Cancel; permanent-delete browser confirmation remains pending.

The preceding [fresh R4 deployment](../db/verification/fresh-dev-validation.json) passed schema/data, native/model and personal/sample browser checks. The historical [R4 record](../db/verification/c3-r4-validation.json) and [journey record](../references/my-contexts-c3-validation.json) retain the earlier browser expiry pass and separate malformed-JSON native failure. These results describe their own source versions. Fresh R7 and generated Worksheet installer execution remain unverified; no release promotion is implied.

| Page | Implementation |
| --- | --- |
| 10 — My Contexts | Native search/status items, owner-filtered classic report, bounded pagination and create/sample navigation. |
| 11 — Context editor | Native full-context form, including eligible topics, explicit clarity, purpose, horizon, background and constraints. A name alone can be saved. |
| 12 — Review changes | Native modal comparing the draft with the ready revision. Collection/topic changes require a refreshed preview before explicit Apply. |
| 13 — Context overview | Draft/ready status, edit, archive/restore, duplicate, activation, new/reopened conversations, revision paging and interrupted-operation review. |
| 14 — Sample Contexts | Deliberate copying into an owned draft, with fictional identity/background cleared by the API. |
| 15 — Delete context | Owner-checked counts and permanent-delete confirmation; unfinished cleanup is routed here for explicit retry. |
| 1 — Conversation | Specialized conversation, evidence and answer explanations for either an owned personal conversation or an explicit fictional sample. |

Saving drafts may refresh embeddings with the local database model; it makes no chat/GenAI request or RDF graph. The library combines text and local semantic search over owned saved drafts, with an objective preview and explicit coverage notice. Its API result is computed once per request and reused by the report and pagination controls. Applying a reviewed draft publishes a private immutable context revision; it does not modify public source knowledge. Existing conversations remain pinned until the user selects **Use the latest ready revision**. A shared application login is one identity; separate people require separate application accounts.

Use the [starting walkthrough](my-contexts-draft-walkthrough.md), [complete manual candidate review](my-contexts-manual-test.md) and [API contract](my-contexts-api.md). Learning-loop planning/assessment and evaluation of the Explorer are separate future epics. The existing observation capture and explicit refinement do not implement those future workflows.

## Author and validate

1. Edit `.apx` page/shared-component files directly, including the conversation region in `pages/p00001-home.apx`. Maintain `apex/explorer.js` and `apex/explorer.css` for the existing specialized workspace. There is no separate HTML page generator.
2. Run `python scripts/build_apex.py` to synchronize static assets. It never overwrites an authored page. If an asset changes, deliberately update its page cache-version reference to the SHA-256 prefix reported by the helper, review that source edit, and run the helper again.
3. Run `python scripts/build_apex.py --check` and `python -m unittest discover -s tests -p test_apex_authoring.py -v`.
4. Use the pinned SQLcl compiler to validate the complete directory. This works without a database login:

```text
sql /nolog
apex validate -input apex/application
exit
```

The connected C3 metadata check used SQLcl `26.3.1.0`, build `26.3.1.301.1413`, against APEX `26.1.6`. It reported validation success with the existing page 1 `regionBody` deprecation warning. Offline SQLcl may use newer metadata and report differences that do not describe the target engine. Repeat validation using `apex validate -input apex/application -workspace YOUR_TEST_WORKSPACE` after privately connecting to the target. Inspect the output for compile errors: a zero SQLcl process exit code alone is insufficient. Neither offline nor connected metadata validation proves PL/SQL compilation, identity isolation or browser behavior.

Keep `.apx` files UTF-8 with LF line endings, as specified in `.gitattributes`; this compiler reports syntax errors for CRLF input. The native reports allow up to four UTF-8 bytes per permitted character for short fields and use SQL `VARCHAR2(32767)` for longer values. Target acceptance must verify that size is supported and that multibyte text survives save, list, overview and editor round trips. The API also limits the combined draft to 16,000 UTF-8 bytes, so several individually valid fields can still exceed the total limit and require shortening.

APEXlang commands compile the application and execute generated PL/SQL during import. This does not make hand-written `wwv_flow_imp_page` calls the authoring source. See [Oracle's command reference](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/commands-overview-apexlang.html) and [APEXlang component reference](https://docs.oracle.com/en/database/oracle/apex/26.1/apxln/index.html).

## Database API boundary

Page queries use `KCV_PERSONAL_CONTEXT_API` and `KCV_PERSONAL_JOURNEY` rather than unrestricted personal-table queries. Native form processes call the same authorized API as any other client. Hidden context IDs, expected versions and request tokens are protected by APEX session-state checks, and the package rechecks authenticated ownership. There is no automatic form DML against personal-context tables.

Native form saves preserve the request token on a failed submission and the expected draft version reviewed by the user. Successful mutations redirect to an owner-checked overview. IDs in generated URLs are opaque identifiers only; context fields are not carried in the URL. Read access to archived work does not authorize mutation. Do not reuse the old permissive `Administration Rights` scheme to authorize these operations.

The Oracle APEX Accounts authentication scheme calls `KCV_ACCESS.CAPTURE_IDENTITY` after sign-in. It pins the native account ID in the restricted application item `KCV_AUTH_ACCOUNT_ID`; normal requests cannot set this item. Context reads and writes require the pinned account ID to match the current account. This prevents an old session from acquiring a recreated account's identity when a username is reused. Install the appended identity migration and application metadata together, then sign out and in again. Tests using `APEX_SESSION.CREATE_SESSION` must explicitly invoke the trusted capture callback for a new synthetic session; attaching an existing session must never refresh its pin.

Library and overview paging is processed on submit, before APEX redirects back to the page. Conversation history and observations are fetched through authorized read-only AJAX calls without a model request. The reports disable header sorting and preserve the API's order, so a header cannot reorder only the current page and imply a different global order.

## Engine export and Worksheet packaging

Export the reviewed, deployed candidate through APEX/SQLcl to `apex/kcv-explorer.sql` and record its tested scope and unresolved limitations separately. Never hand-edit this generated SQL to imitate new pages. Retain the app's page numbers/aliases and use a supported engine export.

The current nine-page engine export and [export-validation.json](../apex/export-validation.json) identify the tested R7 source and seven application assets. New/upgrade Worksheet wrappers are generated from that artifact but require separate execution acceptance. The receipt validates artifact provenance; it does not certify every deployment route, model response or release readiness.

The wrapper supports two distinct modes:

```text
python scripts/build_apex_worksheet.py --mode new
python scripts/build_apex_worksheet.py --mode upgrade
```

Those commands use the legacy KCV_KNOWLEDGE/KCV_LAB defaults. For a separate fresh development target, specify every target explicitly; verify the workspace mapping before executing the result:

```bash
python scripts/build_apex_worksheet.py --mode new --workspace KCV_V2_FRESH --schema KCV_V2_FRESH --alias KCV-FRESH-EXPLORER --output work/fresh/20_install_apex.sql
```

Follow [fresh dev deployment](fresh-dev-deployment.md) for the complete setup. Execute either generated Worksheet wrapper with **Run Statement (Ctrl+Enter)** as the intended owner: select the complete outer `DECLARE` through the final `END;`, excluding the final slash. Supply any target binds and the existing app ID for an upgrade. F5 does not open these bind prompts. Choose the wrapper or native APEXlang import for that installation; running both creates separate apps and does not establish a single tested deployment path.

`new` allocates a new application ID. `upgrade` generates `work/worksheet/20_upgrade_apex.sql`, requires the existing app ID in a Worksheet bind prompt, and checks workspace, parsing schema, alias, the completed `2.0.0-c3-r7-ready` migration and all sixteen required package specification/body objects, including personal-journey, conversation, deletion and context search before import. It preserves the application ID. APEX generates an offset to avoid internal metadata collisions; page numbers and aliases are retained, but internal numeric component IDs are not an ownership key.

For product version 2 or later, **both new and upgrade modes** require `apex/export-validation.json`, recorded only after the actual engine import/export acceptance, containing:

```json
{
  "product_version": "2.0.0",
  "application_source_sha256": "hash of the complete authored application tree",
  "export_sql_sha256": "hash of the engine SQL export with LF text endings",
  "engine_import_export_verified": true
}
```

`application_source_hash()` in `scripts/build_apex_worksheet.py` computes the portable source-tree hash. The receipt ties the checked-in source, SQL export and product version together; it is not a signature or an automatic test result. Do not create a positive receipt from an offline compiler run alone. A missing or stale receipt blocks v2 installer generation, preventing the old v1 export from being silently treated as v2. The legacy fresh-installer path remains supported for a version-1 source tree (including a legacy tree without `VERSION`).

Test fresh install and same-ID upgrade separately. A context saved before an app upgrade must remain visible afterward, and another application's session must not attach it. Browser tests also cover blank creation, failed-save retention, sample copying, more than 20 contexts, archive/restore, two-account tampering, keyboard operation and narrow layouts. Keep private environment/login details out of screenshots and public test records.
