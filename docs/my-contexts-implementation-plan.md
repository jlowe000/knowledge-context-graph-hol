# EPIC-03: My Contexts implementation plan

Status: R7 dev candidate, 25 November 2026. The [context-search record](../db/verification/context-search-validation.json) reports successful native upgrade/repeat, search regressions, APEX import and scoped browser search/filter checks. The [R5 deletion record](../db/verification/context-delete-validation.json) retains successful native tests and browser review/Cancel, with permanent-delete confirmation pending. My Contexts retains APEXlang authoring and Liquibase on dev; NVIDIA Auto Ontology remains excluded. Earlier [fresh deployment](../db/verification/fresh-dev-validation.json) and [R4](../db/verification/c3-r4-validation.json) records retain their own results and earlier separate model-format failure. Fresh R7 and generated Worksheet execution remain unverified; release is unchanged. This plan is not an acceptance record; use the linked records and [manual review](my-contexts-manual-test.md) for tested scope and expected outcomes.

Target product version: **v2.0.0**, following the existing published baseline **v1.0.0**. Use **major.minor.patch**: major for backward incompatibility or significant functional uplift, minor for compatible features, patch for compatible fixes/maintenance. My Contexts warrants a major release for its functional uplift even while preserving the sample HOL and providing an additive upgrade. See the [version and tagging policy](branch-workflow.md#product-versions-and-git-tags) for exact baseline commit targets, immutable tags and dev-source provenance. The baseline `v1.0.0` tag has been published; no `v2.0.0` tag or release promotion has occurred.

## Outcome and scope

A signed-in person can create a context for their own idea, save it while its objective is uncertain, explore the public collection, inspect answer-specific evidence, record learning, refine the context and reopen the work after signing in again. Each context can have several conversations. Earlier answers retain their original context and evidence.

Deliver this as one epic. Database changes, authorization, native APEX pages, migration tooling and validation are implementation stories within it. Preserve the existing Alex/Sam/Casey HOL journeys and the separate dev and release learning experiences.

The first delivery retains the current public-evidence retrieval policy: any selected topic may match, the collection is pinned, curriculum sources precede catalogue IDs, and the packet is limited to six passages and two source locators per source version. Question wording, role, objective, organisation and constraints inform the answer but do not become new source filters. Observations do not automatically change context or source knowledge. Industry/availability filters, semantic ranking of public evidence, source ingestion, graph maintenance and collaborative sharing are separate enhancements. The R7 [private context-library search](context-search.md) is a separate local semantic/text lookup over saved drafts; its scoped native/browser acceptance is recorded separately in the [search validation record](../db/verification/context-search-validation.json).

## Implementation decisions

| Area | Decision |
| --- | --- |
| UI source | Directly maintained APEXlang under `apex/application/`, with native APEX regions, reports, forms, items, validations, buttons and dialogs wherever supported. |
| Custom UI | Keep JavaScript for interactive graphs, answer explanations and conversation behavior that benefits from it. Avoid rebuilding the complete context library/editor as one static HTML region. |
| Database logic | Retain SQL/PLSQL packages for ownership, revisions, RDF operations, agents, evidence and audit. Native form submit processes call these APIs; automatic table DML must not bypass them. |
| Schema evolution on dev | SQLcl's Liquibase integration manages ordered, reviewed migrations for project-owned static schema/program objects. Pin and test the SQLcl/Liquibase/APEX versions before establishing the baseline. Changelogs and migration authoring tools stay on dev. |
| Learner deployment on release | Keep Database Actions SQL Worksheet as the documented route: prepared database install/upgrade scripts and the generated APEX Worksheet installer. Generate app deployment artifacts from the tested APEXlang source. No learner Liquibase, SQLcl or Python dependency. |
| Persistence | Reuse current revisions, chat rows, turns, observations and trace records; add durable personal-context ownership and authenticated attachments for reopening. |
| Data boundary | Personal contexts, conversations and observations are runtime data. They never enter the public dataset, generated fixtures, APEX export supporting data or release package. |
| Promotion | Implement and accept on dev first. Generate the curated release only after native database, real-model and browser checks pass. |

NVIDIA Auto Ontology is explicitly outside this implementation. Do not introduce its code, services, connectors or model dependencies. The curated public graph, Oracle RDF/OWL/SPARQL implementation and current evidence selection remain the foundation. Personal-context changes add private runtime records and versioned context overlays; they do not automatically add assertions to the shared source graph or change the public ontology.

The [epic register](implementation-epics.md) also reserves **EPIC-04 — A deliberate learning loop** and **EPIC-05 — Evaluate the Explorer** as separate future work. My Contexts retains observation capture and explicit refinement already specified here. It does not add activity-planning/assessment workflows, automated publication, evaluation telemetry or a knowledge-value score. Complete and manually test this epic before taking on those future scopes.

## APEXlang: current position and target

The v1 application generated its home page around a separate HTML region, JavaScript and CSS. Current dev maintains the page region directly in [p00001-home.apx](../apex/application/pages/p00001-home.apx); [build_apex.py](../scripts/build_apex.py) only synchronizes assets and checks source. The large `apex/kcv-explorer.sql` file is an engine export tied to reviewed source by `apex/export-validation.json`; the current receipt identifies the tested R7 search source. Generated Worksheet wrappers require separate deployment testing.

For this epic:

1. Make the application `.apx` files the authoritative page/component definitions. Change the build helper so it synchronizes assets and checks consistency without overwriting directly authored pages.
2. Define native library, context editor/review, overview/history and sample-selection screens. Keep the existing conversation/evidence workspace as a specialized region where appropriate.
3. Route form submissions through the context API. Owner identities come from authenticated server state, never editable or hidden page items. Reports, LOVs, downloads and trace routes must apply server-side authorization too.
4. Validate the APEXlang source against the target's supported metadata version, import into an isolated app, then export/check the application. Do not assume a newer documentation example is valid on the installed APEX 26.1-compatible deployment.
5. On dev, validate/import the directly maintained APEXlang application. For release, generate the APEX SQL export and Worksheet installer from that same tested application, keeping the established learner route. APEXlang source may remain available for learning, but learners do not compile it. Never maintain a second handwritten `wwv_flow_imp_page` implementation.

APEXlang import itself compiles the application and executes resulting PL/SQL. Seeing generated PL/SQL in a deployment does not mean the application was authored in PL/SQL. See [SQLcl APEXlang commands](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/commands-overview-apexlang.html), [APEXlang package structure](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/creating-an-application-with-APEXlang.html) and [declarative components](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/using-apexlang-coding-agents.html).

The original workshop's pinned [chatbot lab](https://github.com/oracle-livelabs/spatial-graph/blob/e88a08bd3f9df46031fd09bc62bc1cfe528be6a1/adb-graph/f1-ontology-vector-rag/chat-with-agents/chat-with-agents.md) opens a preinstalled application from reservation information. It does not teach application construction or import, and does not establish the original author's choice of App Builder versus code. Our standalone deployment is additional learning material.

## Liquibase: migration and deployment strategy

Use SQLcl/Liquibase as the developer migration runner. SQLcl provides changelog generation, validation, update, status and related commands; SQL payloads support Oracle-specific packages and API calls. This remains SQL-first authoring. The Liquibase client runs outside Database Actions; a SQL Worksheet does not execute `lb` commands. SQLcl also needs its own authenticated database connection, independently of an open browser Worksheet session. See [SQLcl Liquibase command reference](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.1/sqcug/liquibase.html).

Migration layout introduced by the C2 implementation:

```text
db/
  manifest.json                # phases, dependencies, payload hashes, postconditions
  changelog.xml                 # explicitly ordered includes
  baseline/                    # known pre-My-Contexts schema contract
  changes/                     # immutable versioned changesets + SQL payloads
  verification/                # baseline and postcondition SQL
  recovery/                    # reviewed recovery/compensating operations
sql/install/                   # generated learner install and upgrade bundles
apex/application/              # directly maintained APEXlang + assets
```

The maintained SQL package files remain readable development sources. When a migration is prepared, freeze the reviewed SQL into a versioned payload under `db/changes/`; that immutable payload is the authority for that migration. A check verifies the newest payload against the maintained package source. Both Liquibase and generated Worksheet bundles consume the ordered manifest and the same frozen payloads. Never point an old changeset at a package file that will change later, or run both a generated install bundle and the old raw initialization scripts against the same objects.

Migration rules:

- Version tables, columns, constraints, indexes, views, packages and necessary static RDF setup. Runtime context/revision graph creation stays in the application API; do not create a Liquibase changeset for each user's activity.
- Use an explicitly ordered changelog, stable change IDs and immutable payloads after publication. Adopt new changesets for subsequent changes. Generate versioned package payloads from the reviewed source rather than maintaining divergent code copies. Shared dependencies have a declared compile order.
- Validate PL/SQL statement boundaries with the pinned runner. Package bodies contain internal semicolons; do not rely on default splitting. Use a tested per-object execution convention and generate Worksheet separators only where needed. [Liquibase SQL files](https://docs.liquibase.com/reference-guide/change-types/sqlfile) and [delimiter handling](https://docs.liquibase.com/change-types/enddelimiter-sql.html) describe the relevant controls.
- Add a project migration registry containing version, payload hash, phase and completion. Both supported install paths use the same canonical SQL payloads and postconditions. Liquibase retains its own execution ledger separately; Worksheet scripts must not fabricate Liquibase tracking rows.
- Establish a verified baseline for the existing installation before applying new changes. Compare the expected object structure and package versions; do not equate an existing table name with a compatible schema. If moving a verified Worksheet install into Liquibase, synchronize only the exact verified baseline/applied set, leaving pending changes pending. Do not blanket-clear checksums or mark every changeset applied. [Liquibase baseline synchronization](https://docs.liquibase.com/community/reference-guide-5-0/database-inspection-change-tracking-and-utility-commands/changelog-sync?entryId=6kc3S0T53giDzoZ9H6q8VZ) records changes without executing them, so verification must precede that operation.
- The migration registry must check hashes and postconditions for a previously completed step, reject mismatches and explicitly recover partially completed steps. If an interrupted manual step is physically complete but not recorded, verify all its postconditions before reconciliation. Existence-only checks must not hide an incompatible or half-applied migration.
- A successful `CREATE OR REPLACE` is not sufficient proof of a valid program object. Required object-validity and `USER_ERRORS` checks must pass before a migration/program-deployment step receives its successful completion receipt. Check only the expected project objects and report failures clearly.
- Oracle DDL and RDF API commits require phased recovery. Do not promise all-or-nothing database rollback or an automatic inverse for arbitrary SQL. Prefer compatible additive changes; record compensating steps where safe, and retain personal records during application fallback.
- Keep credentials, passwords, user/account bootstrap and one-way Java enablement outside captured migrations. Use a whitelist of project-owned objects if generating metadata; never snapshot runtime rows or private configuration into the repository.
- Coordinate app import after database postconditions and package compilation checks. Keep application artifact hash and schema migration version together in the acceptance record. Do not treat SQLcl Liquibase's APEX export integration as a replacement for directly authored APEXlang.

A fresh database and an existing Worksheet-installed database both need tested entry paths. SQL Worksheet remains the release learner route; SQLcl/Liquibase is the dev route for iterative developer upgrades. The release package contains ordered SQL, simple schema-version receipts and verification steps, not the dev `db/` changelogs, Liquibase tooling or developer migration instructions. Moving a learner installation into dev is an explicit verified baseline operation, not an assumption that the two deployment ledgers are interchangeable. Release scripts should also fail clearly if a detected database version is newer than or incompatible with their supported upgrade baseline.

## Storage and runtime contract

The context root and draft-operation records were implemented in C2. C3 adds attachments, conversation links and model-session continuation; consult the [API contract](my-contexts-api.md) for the implemented operations and the candidate validation record for what has actually passed.

| Record/change | Responsibility |
| --- | --- |
| `KCV_PERSONAL_CONTEXTS` | Durable owner principal and application scope, title, draft/active/archived state, last activity, draft JSON/version, latest ready revision, template/copy provenance and context-update lease. |
| Owner binding | Resolve a stable authenticated account subject server-side. Verify account rename/recreation behavior during preflight; a display name is not an identity. SQL Worksheet operations use a separate database-principal scope. |
| `KCV_CHAT_SESSIONS.PERSONAL_CONTEXT_ID` | Nullable link to a personal context. Keep existing `SESSION_ID` as the durable conversation key so turns, audits and response traces retain their keys. |
| `KCV_CONTEXT_ATTACHMENTS` | Server-created binding between an owned conversation and the current authenticated APEX session. More than one signed-in session can attach independently. |
| Existing `KCV_SCENARIO_REVISIONS` | Ready immutable context JSON and a small RDF overlay against a pinned base graph. Personal identifiers must fit the existing 32-character context key and IRI validation. |
| Model-session history | Record provider/model conversation replacements and the bounded continuation history supplied. Existing response-run model IDs remain historical values. |
| Operation/migration records | Support idempotent submission, lease ownership, expected revisions, operation phases, error diagnosis and deliberate recovery. |

Drafts are stored without creating an RDF graph or model conversation. A name alone is sufficient. Activation requires a starting question and at least one topic with eligible evidence in the chosen collection; a defined objective is optional. If the user chooses **Defined**, require the objective text. Keep explicit constraints separate from learning interests.

The initial sample-copy flow clears fictional identity, background and constraints, presents question/purpose/topics as suggestions and requires review. Duplicating an owned context copies its reviewed context fields only, with a new identifier; conversations, observations and answer evidence are not copied as new events.

Legacy sessions without a personal-context link retain the existing session-bound behavior. Do not automatically claim or expose old shared `KCV_USER` conversations. Keep their recorded data intact. Any later adoption feature needs a separately reviewed identity/provenance rule.

The shared app login is a single identity. Multi-person use requires separate application accounts. Reopening must verify durable ownership and create a valid current-session attachment; removing the `APP_SESSION` predicate alone is not an acceptable implementation. Both `KCV_SCENARIO` and `KCV_TRACE` must call the same authorization helper.

## Stories, dependencies and completion gates

| Story | Implementation work | Completion gate |
| --- | --- | --- |
| **E3.1 Establish the baseline and contracts** | Inventory exact app/database/tool versions; record app and source hashes; define context JSON/API responses and lifecycle; prove APEXlang import and a representative PL/SQL Liquibase migration in an isolated target. Verify stable account identity. | Agreed contracts, pinned tooling and verified baseline; no live-user data exported. |
| **E3.2 Add migration-managed storage** | Implement the context root, attachments, conversation link and operation records. Establish the project migration registry, immutable changelog and both installer entry paths. | Fresh install and existing-baseline upgrade pass; second run is safe; an interrupted step is detected/recovered without losing data. |
| **E3.3 Implement ownership and lifecycle APIs** | Owner-scoped list/search, draft creation/edit, activation, open/attach, duplicate, archive/restore and paginated history. Separate authenticated library routes from routes requiring an existing conversation. | Two distinct app users are isolated on every operation, including guessed IDs and historical trace reads. Legacy session checks still pass. |
| **E3.4 Connect revisions and evidence** | Centralize eligible-topic vocabulary for the pinned graph; implement full-context preview/apply with independent clarity; maintain current retrieval and add selection-versus-interpretation explanation fields. Add explicit collection-update review/adoption. | Objective-only changes preserve evidence; controlled topic changes follow actual paths; historical traces remain unchanged. |
| **E3.5 Add continuation and recovery** | Reopen saved conversations, handle confirmed model-conversation expiry, record bounded history and model-session boundaries. Protect context heads and in-flight conversation operations; implement phased RDF publication recovery. | New-login and expiry journeys pass; stale previews and overlapping requests fail safely; orphan RDF work cannot become the current revision accidentally. |
| **E3.6 Build the native APEXlang experience** | Directly author library, creation/editor, review, history and sample screens. Integrate the existing conversation/evidence visuals; native processes call authorized APIs. Add unsaved-change handling, loading/error states and archive read-only behavior. | APEXlang validation/import passes; full keyboard/narrow-screen flow works; direct page-state manipulation cannot bypass ownership or preview/apply. |
| **E3.7 Run integrated acceptance** | Exercise real model replies, evidence capture, two-account isolation, interrupted work and the existing HOL. Test both deployment routes against the same expected schema/app. | Recorded results identify the exact tested code/data/app hashes and actual native/browser outcomes. |
| **E3.8 Package and document release** | Update release learning journeys, beginner Worksheet steps, upgrade guide and generated database/app SQL artifacts. Retain APEXlang for source learning; keep Liquibase changelogs/tooling and adaptation instructions on dev. Regenerate the curated release and verify publication exclusions and hashes. | Learners can install/use the feature without Liquibase, SQLcl or Python; private runtime data is absent; release candidate passes its own Worksheet upgrade and learner smoke checks. |

Sequence: E3.1 precedes the storage/API work. E3.2 enables E3.3; E3.3 enables integrated E3.4/E3.5. E3.6 can progress against agreed contracts while APIs are built. E3.7 integrates all lanes; E3.8 follows successful acceptance. No release promotion based only on mocked tests or the flow prototype.

## Specific implementation details to resolve

1. **Central authorization:** replace duplicated session-only logic in the scenario and trace packages with one helper supporting authorized personal attachments and the unchanged legacy pathway. Authenticate every request and reauthorize every referenced context/conversation/turn. Server state determines the owner.
2. **Pinned vocabulary:** `PROPOSE_CHANGE` currently uses global `ACTIVE_GRAPH` for its vocabulary, while retrieval uses the revision's base graph. Change proposals, editors, activation and apply validation to use the same pinned eligible-topic service. Metadata membership alone does not establish retrievable evidence.
3. **Context head and conversation revision:** applying a change updates the personal context head and the initiating conversation after successful publication. Other conversations stay pinned until explicit adoption. Preview checks the expected head and conversation revision. A newer head is visible without silently changing an in-flight answer.
4. **RDF publication:** persist an operation token, intended graph/revision IDs, expected head and phase before graph APIs that may commit. Publish the new pointers only after successful graph validation and a compare-and-set check. Test failure after graph creation and before publication. Recover only identified project-owned orphan work; never clear a running lease solely because of its age.
5. **Model expiry:** distinguish an expired/missing model conversation from authorization, rate limit or arbitrary model errors. Create a replacement only for the confirmed recovery case, with a documented bounded transcript. Record the new model-session boundary; keep application history available. Do not replay an uncertain model request automatically or promise exactly-once external inference.
6. **History and observations:** replace the current last-20-turn-only UI contract with owner-checked pagination. Observations belong to the active conversation's revision at capture time, even when another conversation has advanced the context head. Ordinary chat and observation saves do not apply refinements.
7. **Graph meaning in the UI:** show which selected topics/collection/policy retrieved the evidence and which objective/background/constraints were available to frame the answer. Do not claim these fields were independent graph filters or prove the model's internal reasoning. Topic selection remains a union; weights remain unranked.
8. **Native form behavior:** use native validation/items for accessibility, but put authority in the API. Disable automatic form DML against context/revision/ownership records. Preview/apply cannot be bypassed by a direct submit or an altered hidden identifier.
9. **Collection changes:** updating source data does not silently move existing contexts. Validate topic compatibility during explicit adoption, create a new revision and keep the original graph/source evidence available for prior answers. Archive is reversible and does not delete graph history.
10. **Deployment boundaries:** block new writes and inspect/drain in-flight operations for incompatible package/app upgrades. A Liquibase lock prevents competing migration runners; it is not an application maintenance gate. Preserve the existing app ID when ownership is app-scoped; changing app/workspace scope requires explicit mapping and validation.

## Detailed dev execution backlog

Work in the existing `dev` checkout or isolated task worktrees based on its reviewed state. Preserve unrelated local changes. The sequence below is the implementation runbook; it does not authorize a teardown or imply any of the gates have passed.

### E3.1 — Establish the development baseline

1. Record the starting commit, uncommitted source hashes, public dataset manifest/hash, installed package fingerprints, actual APEX version and application compatibility mode. The current application source uses compatibility mode `24.2`; this is not evidence of the installed APEX engine version.
   Use the recorded `v1.0.0` source/release commits for compatibility checks; distinguish product version from schema migration IDs and platform versions. Plan the candidate as `v2.0.0` unreleased until acceptance and publication.
2. Inventory the existing schema structurally: tables, columns, constraints, indexes, package specifications/bodies, tool wrappers and prerequisite grants. The existing `SCHEMA_VERSION = 1` setting is insufficient to identify all later extensions. Define `db/baseline/contract.json` and verification SQL using project-owned objects only.
3. Use Oracle Linux/Bash for the supported dev instructions, including a laptop VM or OCI host. Pin a compatible SQLcl distribution and its bundled Liquibase, required Java runtime and APEXlang metadata version. Keep Python for existing preparation/build/test utilities; it is not the application runtime or the schema migration runner.
4. Prove a private SQLcl connection to an isolated Serverless schema. A browser Worksheet login does not authenticate SQLcl. Keep wallets, passwords and connection details outside tracked files. Reuse the approved OCI GenAI setup without putting credential/profile values into schema snapshots.
5. Run two small feasibility checks in that isolated target: a representative package containing internal semicolons through Liquibase, and a native form/report/dialog through APEXlang validate/import. Check `USER_ERRORS` and the actual resulting APEX components, not just command exit codes.
6. Verify a stable principal for the current Oracle APEX Accounts authentication scheme, scoped to the workspace/application. Test rename, deletion/recreation and fresh-login behavior before selecting its stored representation. If the available identity cannot safely distinguish recreated accounts, define an explicit enrollment mapping rather than silently binding by username.
7. Freeze the API response shapes, context field validation, identifier formats, page responsibilities and SQL dependency order below. Select a 32-character-or-shorter, letter-prefixed context identifier; do not concatenate a prefix with a full 32-character GUID into the existing field.

**Deliverables:** baseline contract, tool/version record, API contract document and a redacted feasibility result. **Exit gate:** the migration runner, native APEX components and identity strategy work on the target versions. No feature implementation starts from an assumed baseline.

### E3.2 — Introduce migration-managed storage

Create the following records or equivalent fields, keeping existing conversation/turn/evidence identifiers intact:

| Proposed storage | Required fields and rules |
| --- | --- |
| `KCV_PERSONAL_CONTEXTS` | Context ID, stable owner scope/subject, title, lifecycle, previous lifecycle for restore, draft JSON/version, latest ready revision, sample/copy provenance and activity timestamps. Index owner/scope/status/activity for the library. |
| Conversation link | Nullable personal-context foreign key on `KCV_CHAT_SESSIONS`. Index it for owned conversation history. Existing sample sessions remain unclaimed legacy records. |
| `KCV_CONTEXT_ATTACHMENTS` | Conversation, authenticated app/session scope, stable principal and creation/expiry metadata. Uniqueness prevents duplicate attachment for the same session. It is a server-created authorization binding, not a client bearer token. |
| Operation records | Operation ID, owned target, action, request hash, expected versions, lease/fencing token, phase, intended revision/graph/model IDs and sanitized outcome. Use them for duplicate-request handling and recovery across API commits. |
| Model continuation records | Durable conversation, old/new model conversation IDs, reason, actual supplied history bounds/turn IDs and timestamps. Retain original response-run identifiers. |
| Migration receipts | Ordered migration ID, immutable payload hash, phase, completion and postcondition version. Keep this project registry separate from `DATABASECHANGELOG` and its lock table. |

Implement explicitly ordered migration groups: baseline storage, baseline package specifications/bodies, new personal storage, common authorization/topic services, context/scenario/trace APIs, APEX callback and wrappers, then postconditions. Resolve the existing scenario/trace dependency by installing specifications before dependent bodies where necessary. Extract mixed DDL/package files into appropriate frozen payloads; numeric filenames are not an execution plan.

Add `db/manifest.json`, baseline-only and root changelogs, immutable changesets, `db/verification/` and reviewed `db/recovery/` scripts. Add `scripts/build_database_installers.py` to generate fresh, supported-upgrade and verification Worksheet bundles from the same manifest. Preserve literal text, PL/SQL boundaries and Worksheet-safe ampersands; do not emit SQLcl-only directives or nested `@` file dependencies into a Worksheet bundle.

Test two dev entry paths: an empty project schema receives baseline plus feature; an existing Worksheet install first passes the structural baseline check, then only the verified baseline is synchronized before pending feature migrations run. Treat schema drift as a reportable failure. Keep ADMIN bootstrap, JAVAVM enablement, credentials and environment-specific profile creation outside these migrations. Inventory agent/tool/team registrations separately and deliberately update affected definitions after prerequisites are ready; do not rerun initial creation scripts as an upgrade shortcut.

**Deliverables:** migrations, verification/recovery SQL, bundle generator and migration tests. **Exit gate:** fresh and existing installations reach the same object contract; rerun is a no-op; mismatched checksums, invalid packages and incomplete phases cannot receive a successful receipt.

### E3.3 — Implement the context and authorization APIs

Introduce a shared access helper (proposed `KCV_ACCESS`) and a context lifecycle package (proposed `KCV_PERSONAL_CONTEXT_API`). Preserve existing scenario APIs for the sample HOL. Both `KCV_SCENARIO` and `KCV_TRACE` call the shared access helper; the context package must not become a second competing authorization implementation.

The transport names below are proposed contract names. All calls derive owner/application identity on the server. All mutations carry an operation token and a request hash scoped to the authorized target/action. Repeating the same completed request returns its recorded result; reuse with different content fails. Do not claim this makes an uncertain external model request exactly-once.

| Operation | Input/state | Result and validation |
| --- | --- | --- |
| `list_contexts`, `get_context` | Authenticated identity; optional status/search/cursor | Owner-filtered summaries or overview, current draft/head versions, allowed actions. No RDF retrieval or model call. |
| `create_draft`, `save_draft` | Title/context fields; expected draft version for edit | Durable draft and incremented version. A title alone is sufficient. Reject unknown fields, excessive lengths and stale edits. |
| `copy_sample`, `duplicate_context` | Public sample ID or owned context ID | New draft with provenance. Clear fictional identity/background for sample copies; never copy turns, observations or traces as new events. |
| `preview_context`, `apply_context` | Edited allowed fields, expected draft/head and initiating conversation revision if present | Preview token with before/after, eligibility and warnings; explicit apply publishes a ready revision only if those versions still match. |
| `list_conversations`, `start_conversation`, `open_conversation` | Owned context/conversation; Active is required to start | Summaries or durable conversation plus current-session attachment. Archived work can reopen read-only. Reopen preserves its pinned revision; it does not automatically adopt the context head. |
| `adopt_revision`, `adopt_collection` | Owned conversation/context, selected target and expected versions | Reviewed adoption creates or selects the appropriate revision explicitly; invalid/missing topics require resolution. |
| `list_turns`, `list_observations`, `observe` | Authorized conversation/context; bounded cursor or observation fields | Stable pagination and revision-linked observations. Saves do not change the context head. |
| `archive_context`, `restore_context` | Owned context, expected version | Reversible lifecycle update. Restore a former draft as a draft; reject mutations while archived and retain read access. |
| Existing ask/evidence/trace routes | Authorized attached conversation; trace additionally identifies its recorded run/turn | Current evidence for ask; stored snapshots for historical trace. Never recompute an old explanation from the current graph. |

Use stable client error codes such as `NOT_AUTHENTICATED`, `CONTEXT_UNAVAILABLE`, `STALE_VERSION`, `CONTEXT_ARCHIVED`, `OPERATION_IN_PROGRESS`, `INVALID_TOPIC` and `MODEL_REAUTH_REQUIRED`, with a safe message and correlation ID. Authorization failures must not reveal whether another person's identifier exists. Keep detailed SQL backtraces/private data in restricted diagnostics rather than returning the current dispatch's full backtrace to the browser. Preserve structured validation fields for native form feedback. Every mutation rechecks lifecycle: a read attachment to archived work must not allow ask, observe, apply or a new conversation; owner-checked historical reads remain available.

Refactor `05_apex_api.sql`: library/draft/overview routes dispatch before conversation validation and return only their contracted data. They must not fall through to the current unconditional `STATE`, evidence retrieval, complete source catalogue and last-20-turn response. Native report queries, LOVs and form processes call owner-filtered APIs or protected query interfaces; automatic table DML is disabled. The current `Administration Rights` scheme returns true and is not an owner or maintenance authorization control.

**Deliverables:** context/access packages, explicit dispatch routing, request/response fixtures and native authorization tests. **Exit gate:** two real application accounts cannot access each other's records through any route, native page process, report, LOV, pagination or explanation.

### E3.4 — Connect personal contexts to graph and evidence

1. Persist draft fields separately from the latest ready revision. Editing or saving a draft on an active context must not silently change that ready revision or an existing conversation. Preview/apply is the publication boundary. Keep objective clarity independent from whether objective text is present.
2. Centralize the eligible topic vocabulary for the selected base graph and use it in editor LOVs, activation, proposals and apply. Fix `PROPOSE_CHANGE` using global `ACTIVE_GRAPH`. Reuse existing topic identifiers; this feature is not a vocabulary rename or a rebuild of the public ontology.
3. Reuse `ContextSnapshot`, `focusesOn`, `focalPerson`, `forEngagement` and `supersedesSnapshot` in the context overlay. Stable owner identifiers stay in relational authorization records. Personal names/background need not be embedded as public RDF labels.
4. Stage a preview with field differences, expected context head/conversation revision and topic compatibility. On apply, acquire the owned operation, create/validate the overlay and publish pointers with a compare-and-set guard. Another conversation stays on its revision until explicit adoption.
5. Preserve current topic-union retrieval, source ordering and packet limits, including the existing retrieval-policy identifier in response snapshots. Add explanation fields separating collection/topics used to select evidence from background/objective/constraints supplied to frame the response. Retain legacy trace rendering when those new fields are absent.
6. Preserve topic removal as a learning-focus change. A model proposal remains a proposal; an ordinary question, observation, consensus vote or model recommendation cannot apply a revision or edit source knowledge.

**Deliverables:** revision/apply implementation, shared vocabulary service, updated trace contract and deterministic graph tests. **Exit gate:** objective-only changes preserve evidence IDs/substantive paths under the same policy; topic changes follow actual returned paths; old explanations remain byte-for-byte unchanged in their stored snapshots.

### E3.5 — Implement continuation, concurrency and recovery

Add owner-checked pagination beyond the current 20-turn UI limit. Reopening in a new login creates an authorized attachment and loads persisted application work. Automatic recovery creates a replacement model conversation only for confirmed missing/expired model state; reading an archived conversation needs no model state. Separately, preserve the deliberate model-session reset when applying/adopting a changed context revision, recording the reset reason and old/new revision boundary. Specify a bounded continuation policy (turn count and character/token limit) during E3.1 and record the exact included turns/content bounds. Any supplied earlier-revision history is labelled historical and cannot override the selected context. Existing `HISTORY_JSON` listing prior application turns is not proof that all of them were supplied to the provider; keep the new continuation record distinct.

Use separate protection for the shared context head and each conversation's operation. A concurrent answer may finish against its original immutable revision while another conversation advances the head. A stale preview must fail without overwriting newer work. Persist operation phases before RDF/model APIs that can commit; test failure before and after graph creation, publication and model return. Recovery checks fencing/operation ownership and recorded postconditions rather than clearing leases solely because they are old. An uncertain model submission stays observable and requires deliberate retry handling.

**Deliverables:** continuation history, operation diagnostics/recovery and concurrency tests. **Exit gate:** fresh-login and forced-expiry journeys preserve history, while duplicate actions, stale previews and interrupted publication do not duplicate work or expose an unfinished revision.

### E3.6 — Build the directly authored APEXlang pages

Change `scripts/build_apex.py` first: synchronize/check static assets without generating the entire home page. Add a check that asset synchronization leaves authored `.apx` page definitions unchanged; any cache-version reference change in a page is a separate explicit source edit checked against the asset hash. Keep the existing graph/chat assets; do not introduce another frontend framework.

| Proposed page | Native experience and expected outcome |
| --- | --- |
| `10 — My Contexts` | Authenticated home with cards/report, search, status filter and create/open/duplicate/archive actions. Empty state offers a blank context or samples. Empty-query browsing makes no embedding call; a populated search may embed the query locally and never makes a chat/GenAI request. |
| `11 — Context editor` | Native items for title, question, purpose, clarity, objective, background, explicit constraints and topic selection. Save incomplete work as a draft or request a preview. Existing ready work stays usable until apply. |
| `12 — Review changes` | Modal before/after comparison, pinned collection, eligible topics and explicit Apply/Cancel. Field errors and stale preview recovery are visible. |
| `13 — Context overview` | Ready revision and draft status, conversation and observation reports, new/reopen actions and newer-revision/collection notices. Display archived work read-only. |
| `14 — Sample Contexts` | Alex/Sam/Casey cards with distinct Explore sample and Use as starting point actions. Copies require personal review. |
| Existing `1 — Conversation` | Retain specialized conversation/evidence/graph visuals; show saved context, pinned revision, pagination and a return to overview. Preserve answer-specific explanations and learner sample journeys. |

Update `application.apx` home navigation plus shared lists, LOVs and authorization schemes. Native submit processes call the same APIs as AJAX. Keep personal field contents out of URLs; server-generated opaque identifiers/checksums do not substitute for ownership checks. Test keyboard navigation, dialog focus return, unsaved edits, long/HTML-like input, slow requests and narrow layouts. Inspect actual imported component types to prove these are native pages rather than another generated HTML shell.

Keep two APEX deployment artifacts: a fresh installer that allocates an application ID, and an upgrade installer that validates workspace/parsing schema/application identity and preserves the existing application ID and compatible page numbers and aliases. The C2 wrapper now distinguishes these modes; actual new-install and same-ID upgrade acceptance is still required. Bind target details privately and reject an incompatible or wrong target. Internal numeric APEX component IDs may be regenerated; they are not the ownership key.

**Deliverables:** directly authored pages/shared components, synchronized assets, validated engine export and separate fresh/upgrade wrappers. **Exit gate:** context creation through reopening works in the imported app, and an in-place app upgrade preserves access to existing contexts/history.

### E3.7 — Accept the integrated dev build

Add focused contract tests under `tests/` and native SQL acceptance under `integration-test/`, using synthetic personal data. Local tests check payload validation, generation boundaries, pagination, idempotency helpers and publication exclusions. Native tests prove Oracle compilation, RDF behavior and migration/postcondition semantics; authenticated browser tests prove real APEX identity isolation and component behavior. The local ADB container can support component checks; Serverless is required for final native model/RDF acceptance.

Run the migration routes in the acceptance matrix, including a Worksheet-upgraded instance subsequently adopted by dev without synchronizing future migrations. Keep two deployment targets or sequential isolated runs for fresh and upgrade acceptance; do not reset the shared working lab just to satisfy the fresh-install test. Native SQL checks must include an invalid package, changed immutable payload and interrupted step, each with the expected failure and recovery outcome.

For app acceptance, run: blank draft; sample copy; activate and ask; inspect evidence; record learning; sign out/in; reopen; refine topics; start a second conversation; reject a stale preview; adopt a newer revision; inspect the first answer; archive and restore. Repeat cross-user tampering with a second account, force confirmed model expiry, traverse more than 20 turns and verify empty/insufficient evidence. Re-run Alex/Sam/Casey and the topic-removal wording regression using the real configured model and the public summary dataset.

**Deliverables:** redacted validation record with exact source/artifact/dataset hashes, installed versions, separate local/native/model/browser results, and unresolved issues. **Exit gate:** all required tests pass or the feature remains a dev candidate; mock results never substitute for a native pass.

### E3.8 — Complete developer documentation and release handover

Update `docs/development.md`, `docs/build-your-own.md` and `docs/branch-workflow.md` after the new route works. Add focused `docs/database-migrations.md`, `docs/apexlang-development.md` and `docs/my-contexts-api.md` guides. Document fresh dev setup, verified baseline adoption, adding a changeset, validation/update/status, failed-phase recovery, direct APEXlang editing/import and app upgrade. Explain which Python preparation tools remain optional/useful. Retire overlapping schema actions in `scripts/setup_serverless.sh` or label them diagnostic/legacy so they cannot bypass the migration workflow unknowingly.

Add one maintained product-version value and release notes to the build contract. Record `2.0.0`, unreleased/released status, the exact dev source commit, dataset manifest hash, compatible migration versions and app artifact hash in the appropriate manifest/validation records without creating self-referential file hashes. Propagate the same product version into the app's About/help information. Publish an annotated `v2.0.0` tag only on the accepted release commit; preserve the matching dev SHA in provenance. The retrospective `v1.0.0` tag identifies the recorded already-published release, not this working tree. Tag creation/push are separate execution steps.

Add learner My Contexts steps, expected results and an upgrade path in `release-docs/`. Keep app use, understanding the supplied graph and optional Worksheet deployment distinct from adapting/building on dev. The release builder must explicitly include the new generated SQL, APEXlang learning source, walkthrough and learner verification SQL: it currently uses fixed documentation/test lists and does not copy the APEXlang tree. Extend its allowlist and tests; do not copy the whole dev checkout. Exclude `db/`, dev configuration, migration tools, private runtime data and test logs. Verify that old installation steps do not run already-bundled DDL a second time.

**Deliverables:** complete developer runbook, learner documentation overrides, reproducible release candidate and publication checks. **Exit gate:** the candidate independently passes fresh Worksheet install and supported upgrade with no Python, SQLcl or Liquibase learner requirement. Only then is it eligible for the separately controlled release promotion process.

## Checkpoints and first implementation increment

| Checkpoint | Reviewable outcome | Must precede |
| --- | --- | --- |
| C1 — Baseline and contracts | Verified target/toolchain, schema identity, API/page contract and minimal APEXlang/Liquibase proofs | Parallel feature coding |
| C2 — Persistent library | Additive migrations and authorized create/list/save/reopen with no model calls; two-account isolation | Graph activation and conversation integration |
| C3 — Complete personal journey | Native APEX pages, versioned graph activation, conversation/evidence, observations and continuation | Final dev acceptance |
| C4 — Accepted dev candidate | Native/model/browser results, migration recovery and existing HOL regression | Release generation/handover |
| C5 — Accepted learner candidate | Same tested functionality through independent fresh/upgrade Worksheet paths | Any release promotion |

The first implementation increment is E3.1 followed by a thin E3.2/E3.3/E3.6 slice: create a named draft, list it, sign out, sign back in and reopen it through native APEX pages. This proves the new migration, authoring and ownership foundations before introducing graph/model side effects. It is an intermediate checkpoint, not completion of the epic.

## File ownership and parallel agents

Use four lanes after the contracts are settled. One integration owner controls shared interfaces and final deployment. Work in isolated branches/worktrees where needed; do not have two agents edit the same package simultaneously.

| Lane | Primary files/responsibility | Dependencies |
| --- | --- | --- |
| **Schema and migrations** | New `db/` changelogs/payloads, additive SQL, migration verification/recovery and generated Worksheet bundle contract. | E3.1 contracts; coordinate package snapshot boundaries with runtime owner. |
| **Runtime and graph** | Authorization/context API, `02_scenario_api.sql`, `05_apex_api.sql`, `06_response_provenance.sql`, eligible-topic selection, model continuation and native checks. | Stable schema/API contract. This lane owns all shared package edits. |
| **APEXlang experience** | `apex/application/`, graph/chat assets and asset synchronization changes in `build_apex.py`; native pages and dialogs. | API response contract; real integration after backend readiness. |
| **Integration, learning and release** | Cross-lane review, acceptance journeys, `release-docs/`, build/install packaging, public-data exclusion checks and validation record. | Can prepare tests/docs early; promotion depends on complete native/browser acceptance. |

Current files to update include [scenario API](../sql/extensions/02_scenario_api.sql), [APEX callback](../sql/extensions/05_apex_api.sql), [trace API](../sql/extensions/06_response_provenance.sql), [application source](../apex/application/), [release builder](../scripts/build_release.py), [Worksheet app builder](../scripts/build_apex_worksheet.py), [UI walkthrough](ui-walkthrough.md) and [release documentation](../release-docs/). New migrations and native checks must be explicitly included in install ordering; numeric filenames alone are not dependency ordering.

## Acceptance matrix

| Test | Required result |
| --- | --- |
| Blank draft and uncertain objective | Save with name only; reopen after sign-in; activate with a question/topic while retaining Emerging or Not sure yet. No graph/model call for incomplete draft saves. |
| Sample copy | Fictional identity/background/constraints cleared; suggestions reviewed; original sample untouched. |
| Personal end-to-end flow | Create, ask, inspect trace, observe, sign out/in, reopen, refine, ask again; original answer and observation revision unchanged. |
| Two users and tampered IDs | Every list/read/write/duplicate/archive/attachment/history/trace route enforces the correct owner and app scope. |
| Same collection/topics, different objective | Evidence IDs and substantive source paths remain the same apart from the new revision identity. Model wording/cited subset may vary. |
| Topic change | Eligible graph paths change as expected; bounded output may retain some sources through other selected topics. Removed interest is not a technical prohibition. |
| Insufficient evidence | Existing topics may still fail to support a question; the answer states the gap without inventing a source or assurance. |
| Concurrent work | Stale preview rejected; other conversations keep their revisions; explicit adoption works; in-flight answer evidence stays pinned. |
| Recovery | Confirmed model expiry, failed saves, duplicate submissions and interrupted RDF publication produce observable, recoverable states without silently replaying uncertain inference. |
| Duplicate/archive/restore | Duplicate excludes conversation/observation history; archive is readable and reversible; writes require restoration. |
| Collection upgrade | Existing contexts remain pinned; explicit adoption validates topics; earlier traces remain intact. |
| Liquibase lifecycle | Baseline verified, fresh install and upgrade pass, repeated update is clean, checksum mismatch fails, partial migration recovery is tested. |
| Worksheet lifecycle and path switch | Same final schema/program versions as Liquibase; registry/postconditions verified; scoped ledger reconciliation preserves still-pending migrations. |
| APEXlang and UI | Validate/import/export parity; native components use APIs; keyboard, focus, long text, HTML-like input, mobile layout and saved-history pagination pass. |
| Existing HOL and packaging | Alex/Sam/Casey graph/model/evidence flows pass. No personal data, credentials, environment URLs or private logs are included in either public distribution. |

Record native checks separately from local mocked checks. The existing local ADB container is useful for component checks but does not replace native RDF/model acceptance on ADB Serverless. Test the exact public summary dataset and app artifacts intended for release.

## Deployment, release and fallback

1. Complete local implementation and focused checks on dev. Retain the existing app export and package source hashes in private test records. Test the schema and APEXlang migrations in an isolated Serverless schema/app before upgrading the existing lab.
2. Verify the temporary instance's baseline and working profile; establish the checked migration baseline. Preserve JAVAVM, credentials, source data and existing evidence records. Do not perform a project teardown for this additive feature.
3. For dev acceptance, apply database changes through SQLcl/Liquibase, verify migration status/postconditions and package compilation, then validate/import the APEXlang application into the verified app/workspace/schema scope. Generate the release database SQL bundle and APEX Worksheet installer from these tested sources. Independently test those artifacts through Database Actions before release acceptance.
4. Use distinct app accounts for isolation acceptance and perform the full real-model/browser journey. Keep credentials in the authorized login/connection mechanism and private details outside tracked reports.
5. Update beginner documentation with each action, expected outcome and recovery step. Separate end-user use, developer understanding, optional deployment and dev adaptation. Release deployment instructions use Worksheet and its prepared app installer; dev documentation explains SQLcl/Liquibase and APEXlang authoring. Both explain how to resume saved work. Include complete SQL snippets under ten lines inline when useful.
6. Regenerate the SQL-first release package from tested dev, include the tested Worksheet database/app artifacts, verify hashes/licenses/public-data exclusions, and test the candidate upgrade plus learner path before promotion. Keep migration tooling and changelogs on dev. Record exactly what was tested; do not carry a historical acceptance label onto untested artifacts.
7. If fallback is needed, restore the compatible prior application/packages under the reviewed maintenance procedure and retain additive personal tables/revisions for recovery. A pre-EPIC-03 app is not assumed to understand durable context attachments: disable My Contexts during that fallback unless the restored package set is proven compatible. Do not drop personal records to make a rollback appear complete. Document whether each migration has a tested inverse or requires a forward correction. JAVAVM remains enabled.

No new OCI service, Python runtime service or new model provider is needed for this feature. Dev gains a tested SQLcl/Liquibase migration workflow and directly maintained APEXlang; release retains prepared Worksheet scripts with no additional command-line requirement. Commits, publication and database deployment are execution steps after implementation, not actions performed by this plan.
