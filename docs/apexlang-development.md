# APEXlang development on dev

The v2 application is authored directly under `apex/application/`. SQL/PLSQL still implements database APIs and native page processes. The large `apex/kcv-explorer.sql` is an engine export for deployment; it is not the maintained application definition.

## Current candidate

The v2.1.0 source has versioned native SQL/APEXlang exports with 11 pages and 16 maintained assets. Native application-only import/export, ZIP validation and all four curated-package deployment routes passed within the prepared-environment scopes in [the packaging plan](apex-led-release-packaging-plan.md). Local release promotion is approved; remote publication is a separate action.

Historical v2.0.0 R7 adds local context search and saved-objective previews on page 10. Its [validation record](../db/verification/context-search-validation.json) reports native upgrade/repeat, search regressions, APEX import with nine pages/seven assets/33 parsed components, and scoped browser search/filter checks. The [R5 deletion record](../db/verification/context-delete-validation.json) retains successful native tests and browser review/Cancel; permanent-delete browser confirmation remains pending.

The preceding [fresh R4 deployment](../db/verification/fresh-dev-validation.json) passed schema/data, native/model and personal/sample browser checks. The historical [R4 record](../db/verification/c3-r4-validation.json) and [journey record](../references/my-contexts-c3-validation.json) retain the earlier browser expiry pass and separate malformed-JSON native failure. The later [SQL-first installation-path rehearsal](../db/verification/release-v2-paths-validation.json) covers a clean R7 installation and a published-v1 migration, including new-app and same-ID Worksheet imports with the documented Run Statement correction. These records describe their tested source versions and routes; they do not certify an untested replacement build or imply release promotion.

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

## Target one dev build explicitly

Use `KCV_V<major>_<build>` for the schema and workspace, padding the build number to at least three digits: for example, `KCV_V2_001`. Use the matching owner connection `KCV_V2_001_OWNER` and application alias `KCV-V2-001`. Keep the shared `KCV_V2_ADMIN` connection for administrative operations. The [private connection guide](dev-connection-setup.md) describes the wallet/proxy setup; [fresh dev deployment](fresh-dev-deployment.md) creates and enables the workspace before import.

A replacement uses `KCV_V2_002`, `KCV_V2_002_OWNER` and `KCV-V2-002`, with a separate unused application ID. The build number does not select an APEX app ID or change the product version. Existing-ID upgrade mode updates an app in its existing build; it is not a way to move an app into a replacement workspace.

Create `KCV_USER` as an app-only account in the target workspace through the deployment instructions. It is not the schema owner or a database login. The same username in another workspace is a separate identity; a new build does not automatically inherit that account's private contexts. Follow the [dev build lifecycle](dev-build-lifecycle.md) to validate the replacement and recovery material before retiring the old schema/workspace/app. Obsolete owner aliases can be removed locally only after retirement is verified; keep the shared ADMIN connection.

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

The connected C3 metadata check used SQLcl `26.3.1.0`, build `26.3.1.301.1413`, against APEX `26.1.6`. It reported validation success with the existing page 1 `regionBody` deprecation warning. Offline SQLcl may use newer metadata and report differences that do not describe the target engine. Repeat validation using `apex validate -input apex/application -workspace KCV_V2_001` after privately connecting to the selected build. Substitute the replacement workspace when applicable. Inspect the output for compile errors: a zero SQLcl process exit code alone is insufficient. Neither offline nor connected metadata validation proves PL/SQL compilation, identity isolation or browser behavior.

Keep `.apx` files UTF-8 with LF line endings, as specified in `.gitattributes`; this compiler reports syntax errors for CRLF input. The native reports allow up to four UTF-8 bytes per permitted character for short fields and use SQL `VARCHAR2(32767)` for longer values. Target acceptance must verify that size is supported and that multibyte text survives save, list, overview and editor round trips. The API also limits the combined draft to 16,000 UTF-8 bytes, so several individually valid fields can still exceed the total limit and require shortening.

APEXlang commands compile the application and execute generated PL/SQL during import. This does not make hand-written `wwv_flow_imp_page` calls the authoring source. See [Oracle's command reference](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/commands-overview-apexlang.html) and [APEXlang component reference](https://docs.oracle.com/en/database/oracle/apex/26.1/apxln/index.html).

## Database API boundary

Page queries use `KCV_PERSONAL_CONTEXT_API` and `KCV_PERSONAL_JOURNEY` rather than unrestricted personal-table queries. Native form processes call the same authorized API as any other client. Hidden context IDs, expected versions and request tokens are protected by APEX session-state checks, and the package rechecks authenticated ownership. There is no automatic form DML against personal-context tables.

Native form saves preserve the request token on a failed submission and the expected draft version reviewed by the user. Successful mutations redirect to an owner-checked overview. IDs in generated URLs are opaque identifiers only; context fields are not carried in the URL. Read access to archived work does not authorize mutation. Do not reuse the old permissive `Administration Rights` scheme to authorize these operations.

The Oracle APEX Accounts authentication scheme calls `KCV_ACCESS.CAPTURE_IDENTITY` after sign-in. It pins the native account ID in the restricted application item `KCV_AUTH_ACCOUNT_ID`; normal requests cannot set this item. Context reads and writes require the pinned account ID to match the current account. This prevents an old session from acquiring a recreated account's identity when a username is reused. Install the appended identity migration and application metadata together, then sign out and in again. Tests using `APEX_SESSION.CREATE_SESSION` must explicitly invoke the trusted capture callback for a new synthetic session; attaching an existing session must never refresh its pin.

Library and overview paging is processed on submit, before APEX redirects back to the page. Conversation history and observations are fetched through authorized read-only AJAX calls without a model request. The reports disable header sorting and preserve the API's order, so a header cannot reorder only the current page and imply a different global order.

## Engine export and Worksheet packaging

Export the reviewed, deployed candidate through APEX/SQLcl to `apex/kcv-explorer.sql` and record its tested scope and unresolved limitations separately. Never hand-edit this generated SQL to imitate new pages. Retain the app's page numbers/aliases and use a supported engine export.

The current [SQL export receipt](../apex/export-validation.json) identifies the versioned v2.1.0 definition-only export: 11 pages and 16 maintained assets. The companion [APEXlang receipt](../apex/apexlang-export-validation.json) identifies the native ZIP and canonical Supporting Objects. Native import/export ran without executing those Supporting Objects; its success does not establish backend or learner readiness. The older nine-page/seven-asset R7 receipt and [v2.0.0 route rehearsal](../db/verification/release-v2-paths-validation.json) retain their historical scope. Current packaging uses the explicit inputs and four independent route checks in [the packaging plan](apex-led-release-packaging-plan.md).

The wrapper supports distinct `new` and `upgrade` modes. Its defaults are the legacy KCV_KNOWLEDGE/KCV_LAB target, so dev builds must specify every target explicitly. Verify the workspace mapping before executing the generated result. For a new first build:

```bash
python scripts/build_apex_worksheet.py --mode new --workspace KCV_V2_001 --schema KCV_V2_001 --alias KCV-V2-001 --output work/builds/v2_001/20_install_apex.sql
```

To upgrade the existing app inside that same build:

```bash
python scripts/build_apex_worksheet.py --mode upgrade --workspace KCV_V2_001 --schema KCV_V2_001 --alias KCV-V2-001 --output work/builds/v2_001/20_upgrade_apex.sql
```

For a replacement, use `new` with the `KCV_V2_002` schema/workspace, `KCV-V2-002` alias and a separate `work/builds/v2_002/` output location. Keep the old build and its generated artifacts intact until its retirement is approved and verified.

Follow [fresh dev deployment](fresh-dev-deployment.md) for the normal native APEXlang route. The dev owner is `NO AUTHENTICATION` and uses SQLcl proxy access; it has no direct Worksheet password. The generated Worksheet route is for a deployment with an authenticated owner Worksheet, as used in the SQL-first release rehearsal. Execute either wrapper there with **Run Statement (Ctrl+Enter)**: select the complete outer `DECLARE` through the final `END;`, excluding the final slash. Supply any target binds and the existing app ID for an upgrade. F5 does not open these bind prompts. Choose one import route for that installation; running both new-install routes creates separate apps and does not establish a single tested deployment path.

`new` allocates a new application ID. Native APEXlang import instead takes an explicit `-id`; use an unused ID and the chosen build's explicit workspace, schema and alias as described in the fresh-deployment guide. Do not assume a historical app ID is available. `upgrade` requires the existing app ID in a Worksheet bind prompt, and checks workspace, parsing schema and alias, then verifies the matching canonical schema contract before import. The current contract has 121 completed migrations ending at `2.1.0-apl-r4-ready`; retain the full verifier rather than substituting a receipt count. It preserves the application ID. APEX generates an offset to avoid internal metadata collisions; page numbers and aliases are retained, but internal numeric component IDs are not an ownership key.

For product version 2 or later, **both new and upgrade modes** require `apex/export-validation.json`, recorded only after the actual engine import/export acceptance, containing:

```json
{
  "product_version": "2.1.0",
  "application_source_sha256": "hash of the complete authored application tree",
  "export_sql_sha256": "hash of the engine SQL export with LF text endings",
  "engine_import_export_verified": true
}
```

`application_source_hash()` in `scripts/build_apex_worksheet.py` computes the portable source-tree hash. The receipt ties the checked-in source, SQL export and product version together; it is not a signature or an automatic test result. Do not create a positive receipt from an offline compiler run alone. A missing or stale receipt blocks v2 installer generation, preventing the old v1 export from being silently treated as v2. The legacy fresh-installer path remains supported for a version-1 source tree (including a legacy tree without `VERSION`).

For SQL-first v2.1.0, run the generated owner binding after app import, then the required setup TEST_MODEL and explicit ENABLE_LEARNING gates; use [owner binding](deployment-owner-binding.md). App Builder uses the companion ZIP's guarded Supporting Objects path. Keep those distinct; the definition-only SQL export must not execute the backend installation a second time.

Test fresh install and same-ID upgrade separately. A context saved before an app upgrade must remain visible afterward, and another application's session must not attach it. Browser tests also cover blank creation, failed-save retention, sample copying, more than 20 contexts, archive/restore, two-account tampering, keyboard operation and narrow layouts. Keep private environment/login details out of screenshots and public test records.
