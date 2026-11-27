# Choose a deployment experience

Updated **28 November 2026**. Current curated package: **v2.1.0**, within the scopes of the [four-route record](../db/verification/release-v2.1-paths-validation.json). The [v2.0.0 SQL-first record](../db/verification/release-v2-paths-validation.json) and [dev build validation](dev-build-lifecycle.md#validation-scope) remain historical evidence for their exact execution paths.

The [v2.1.0 packaging plan](apex-led-release-packaging-plan.md) records four passed prepared-environment routes and local release-promotion approval. The [earlier acceptance review](apex-led-acceptance-review.md) retains the preceding candidate's evidence and limits.

There are three experiences for getting Knowledge Context Explorer ready and working with it. Choose according to what you want to achieve and who will look after the environment. The **v2.1.0 package adds the APEX-led experience alongside SQL-first installation, with clean and upgrade paths tested independently**. Local promotion is approved; remote publication is a separate action. The published v2.0.0 export does not install its backend through Supporting Objects; the newer implementation is described in the [APEX-led deployment plan](apex-led-deployment-plan.md).

R13 passed clean ZIP installation, guided setup, real learner evidence and new-sign-in persistence, plus a populated published-v2 same-application upgrade and historical evidence reopening. Reviewer isolation and bounded native credential/concurrency/recovery checks also passed. The [acceptance review](apex-led-acceptance-review.md) retains exact scopes and earlier evidence; the [curated-package record](../db/verification/release-v2.1-paths-validation.json) records the subsequent four-route results. Audit/request-log protection remains unproven; new-database provisioning and first Java enablement/restart were not rehearsed.

| Experience | Start here when… | Main activity | Intended outcome | Current position |
| --- | --- | --- | --- | --- |
| **APEX-led** | You want a guided path from OCI database/workspace preparation to installing and using the collection | Prepare ADB and the workspace with administrator support, then upload the application ZIP through App Builder and complete guided setup | A working supplied app; backend installation after preparation needs no installer shell tools or manual schema SQL | v2.1.0 prepared-ADB clean and populated-upgrade core paths passed; local promotion approved. Novice provisioning and platform audit protection are not claimed. |
| **OCI/DBA-led** | You or your facilitator can prepare ADB and want to deploy the supplied solution | Follow the SQL-first configuration, installation and verification steps | A working supplied application with explicit database and model setup | v2.1.0 clean/upgrade paths passed; the clean rehearsal used Worksheet plus genuine-owner SQLcl for model testing and enablement. |
| **DEV-led** | You want to build or change your own version | Develop the collection, ontology, database APIs and APEXlang application; migrate and test | A separately validated adaptation | Available on dev; follow its own deployment and validation guides |

These describe deployment and development responsibilities. Release's [learning paths](../release-docs/docs/learning-paths.md) still distinguish **using the collection** from **understanding the supplied collection as a developer**. Neither learning goal requires becoming a maintainer.

## If you only want to use the app

Ask your facilitator for the application URL and an individual application login. Start with [My Contexts](../release-docs/labs/my-contexts/my-contexts.md) or the [evidence walkthrough](ui-walkthrough.md). You do not need an OCI tenancy, database account, SQLcl, a wallet or App Builder access to use an already configured application.

The application account is separate from database, OCI and APEX developer accounts. For example, `KCV_USER` is an app-only account scoped to its workspace. Use individual accounts when people need separate personal libraries; sharing an account shares its saved context library. The facilitator remains responsible for platform availability, model access and operating costs.

## APEX-led: guided installation and use

The full experience starts with **provisioning ADB Serverless in OCI**, includes administrator preparation and APEX workspace creation, and then installs the application. These are documented steps with named responsibilities, not an assumption that a beginner already knows the platform. The primary application deliverable is one **APEXlang application ZIP**, uploaded intact through **App Builder → Import**. Its Supporting Objects install and compile the backend before guided runtime configuration and public collection loading.

| Phase | Who acts and what happens | Expected checkpoint |
| --- | --- | --- |
| **1. Provision ADB in OCI** | An authorised tenancy user chooses the supported database configuration, access/network settings and resources, creates ADB and waits for Available | The database and its administration tools are reachable; resource/cost responsibility is understood |
| **2. Prepare the database as ADMIN** | Verify required capabilities, Java/RDF and VECTOR support; create the intended schema and direct grants; approve API-key/IAM access and choose the credential route | The owner is ready for application backend installation; credentials stay outside the package |
| **3. Create the APEX workspace and access** | Create and enable the workspace, map the parsing schema, verify REST readiness and establish Builder and runtime installer access | The installer can enter the intended workspace and later sign into setup with its native administrator account |
| **4. Import the application ZIP** | Upload the supplied ZIP intact in App Builder and install its Supporting Objects | Backend objects compile and verify in the intended schema; the installation is bound to the correct app/workspace |
| **5. Complete guided setup** | Prepare the graph network, use an existing local credential or the accepted creation form, configure/test the model, register runtime components, load the pinned GitHub collection and enable learning after readiness passes | Required schema, model, collection and evidence checks pass; optional semantic search has an explicit status |
| **6. Start learning** | Each learner signs into the configured app with an individual app-only account | My Contexts and Sample Contexts are usable without setup privileges |

**Prepared-environment shortcut:** if a facilitator has already completed phases 1–3, review their readiness checkpoints and start at phase 4. Do not provision another database, recreate a schema/workspace or reset credentials just to follow the full guide. For a supported upgrade, verify the existing preparation and use the preservation-aware upgrade path with the same application identity and saved work.

The facilitator checks the browser-import prerequisites during workspace preparation, including ORDS 26.1.1+ and at least one REST-enabled schema in the workspace. The ZIP is imported after these steps; it does not provision the database or workspace itself. ADB's Builder database sign-in and the application's native APEX account are separate access paths to verify. See [Oracle's import requirements](https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/importing-export-files.html).

The candidate supplies database objects, compilation and verification steps, application pages and assets. Guided setup creates or verifies the owner-private RDF network, loads the pinned public GitHub dataset, configures the permitted model profile and registers the conversation components. Optional local semantic-search setup remains a facilitator task with its own capability check and outcome. The graph is reconstructed from the supplied data; no private graph dump or existing user's conversations are distributed.

The APEX installation adapter has separate native/browser evidence for execution identity and the scoped r9 fresh path; it does not merely run Worksheet files with their owner checks removed. The later same-application upgrade preserved its published-v2 table/receipt baseline and saved draft; the scoped r13 learner flow also passed. Remaining acceptance limits are recorded separately. Passing Worksheet or SQLcl tests alone does not prove the browser route.

For credential preparation, retain an existing owner-local credential, use the facilitator's private process, or use **Create a local OCI signing credential** in the reviewed candidate. The r12 rehearsal separately passed private app creation, scoped privacy checks and an explicit model connection test. An authorised installer can create fixed owner-local `OCI_USER_CRED` without an owner Worksheet login. The form refuses overwrite, takes the matching OCI user/tenancy/fingerprint and unencrypted base64 key body only (maximum 4,000 submitted bytes), and requires a separate model test. OCI API-key registration and IAM permissions remain administrator prerequisites. Only that labelled form accepts a key; profile and learner fields do not. See [the credential steps and current gate](apex-led-deployment.md#optional-create-the-owner-local-credential).

Database provisioning, Java/RDF availability, required package grants, schema storage, workspace mapping and model/IAM/network permissions are part of this guide's administrator/facilitator phases. An application import cannot supply a tenancy or provision a model service. Credentials must be entered through an approved private setup path and must never be included in the export, sample data or public repository. The installer role must remain separate from the learner's app-only login. See [administrator preparation](apex-led-administrator-preparation.md) and [the installation guide](apex-led-deployment.md).

Beginner acceptance must cover the full provisioning/workspace path as well as the prepared-environment shortcut, with clear screens, handoffs and outcomes. The rehearsals used an existing ADB; **new-database provisioning and first-time Java enablement/restart have not been validated for this new route**. Keep the passed r9 learner results and r12 credential/guided-setup checks separate from the remaining gates.

## OCI/DBA-led: SQL-first deployment of the supplied solution

This experience starts with the desired outcome: a working application and knowledge collection. An administrator or facilitator prepares the database and access, then follows the supplied, ordered SQL route. The person doing the installation may also be the learner, but the responsibilities remain distinct.

Use the release branch's [installation-path guide](../release-docs/docs/installation-paths.md), choosing its [clean-installation walkthrough](../release-docs/docs/fresh-serverless-deployment.md) or [v2.0.0-to-v2.1.0 migration guide](../release-docs/docs/migrate-to-v2.1.md). A v1 installation first uses the separate [published v2.0.0 bridge](../release-docs/docs/migrate-to-v2.md). Database Actions SQL Worksheet provides the documented execution interface and expected checkpoints. The release package supplies the required SQL and data artifacts; a learner does not need Python, Liquibase or a local build to deploy it.

The administrator handles platform readiness, schema privileges, accounts and access policies. The project owner installs/verifies the static schema and application, then establishes owner binding. A separate native APEX workspace-administrator installer uses the running app's Deployment setup for the RDF network, credential creation/selection, profile/model test, runtime registrations and public collection. Credentials and model configuration are not entered into the normal SQL installation files. A successful import alone is not completion: verify compilation, dataset/graph readiness, a real answer and its evidence, then hand over the app login. Follow the execution control specified for each script; bind-bearing app installers use the documented complete-block **Run Statement** route.

The [v2.1.0 recorded rehearsals](../db/verification/release-v2.1-paths-validation.json) covered clean project schemas and populated v2.0.0 upgrades on an existing temporary ADB. SQL-first clean used Worksheet for schema/app installation and genuine-owner SQLcl for its successful model test and enablement; it is not an all-Worksheet completion claim. Combined schema-file transport, new-database provisioning and first-time Java enablement remain outside these passes. The dev copies of [the older fresh walkthrough](fresh-serverless-deployment.md) and [existing-target APEX reference](serverless-apex-deployment.md) are v1 references, not current installation instructions.

## DEV-led: build and validate your own version

Start with [Build your own version](build-your-own.md) and [development setup](development.md). This experience covers changing sources, taxonomy/ontology, retrieval, context behavior, evidence and UI, as well as generating a package for others to use.

Use **APEXlang** for application authoring, **local SQLcl** for the database connection and **Liquibase** for ordered development migrations. After workspace/account creation, app import and owner binding, configure the credential/profile through the same runtime **Deployment setup** interface. Keep manual SQL for separately chosen headless/diagnostic needs; do not repeat it after successful app setup. Follow [APEXlang development](apexlang-development.md), [database migrations](database-migrations.md) and [fresh dev deployment](fresh-dev-deployment.md). Oracle Linux/Bash is the documented shell environment; Java and SQLcl run locally without requiring a container. Dev also includes Python authoring and packaging tools, separate from the learner's SQL-first route.

Use the [build lifecycle](dev-build-lifecycle.md) to select an isolated owner/workspace, preserve other installations and retire a replaced build only after validation and reviewed recovery preparation. The developer owns the implementation tests, native database and model checks, browser review, provenance and learner documentation for the changed behavior. See the [manual review](my-contexts-manual-test.md) and [branch workflow](branch-workflow.md) before packaging or promotion.

## Clean installation, migration and shared contracts

All three experiences target the same versioned application and database model. They should consume one migration manifest and its immutable payloads, dependency rules, verification checks and receipts. An eventual APEX installer must not maintain a separate schema definition that can drift from SQL-first or Liquibase installations.

| Operation | Meaning | Saved-work expectation |
| --- | --- | --- |
| **Clean installation** | Install into a new, empty project schema and its intended workspace; the database itself may already exist | Starts a new personal library; other installations are preserved |
| **Migration** | Verify a supported starting installation, apply ordered upgrades and update the existing application identity | Preserve existing data and evidence within the tested migration contract; check the recorded limits |
| **Replacement build** | Create and validate another isolated deployment before deciding whether to retire the old one | Does not automatically transfer personal contexts, accounts or conversations |

Product versions use `major.minor.patch`. A dev identity such as `KCV_V2_002` identifies a deployment build; it is not a new product version. Record the source commit, product version, migration checkpoint and dataset commit/hash together. Reusing an app username in a new workspace does not transfer ownership of saved work.

The supplied release data consists of attributed editorial summaries and public references loaded from a pinned GitHub commit with manifest/hash checks. Dev can additionally generate extracted authoring passages for local review. Those are distinct evidence editions and must not silently replace one another during packaging. Personal contexts, conversations, observations, credentials and private environment configuration are runtime data, not release seed data.

## Packaging and platform boundaries

The intended packaging is **two supplied-solution deployment experiences on release**—APEX-led after implementation and acceptance, and the existing OCI/DBA-led SQL-first route—and **the DEV-led experience on dev**. Release should continue to support both end users and developers exploring the supplied collection. This planning document does not add an APEX-led installer to release or promote any changes.

The current full implementation requires ADB Serverless 26ai with native RDF/Java, Select AI Agent and the required packages and grants, plus a compatible APEX version; current guidance uses APEX 26.1+. Native `VECTOR` support is required by the v2 schema even when the optional ONNX model is absent and context search falls back to keywords.

No compatibility with **oracleapex.com free workspaces** is promised. An accessible APEX workspace does not establish access to these database services or administrative capabilities. Each new deployment route needs acceptance in its actual execution environment; packaging does not remove those requirements.
