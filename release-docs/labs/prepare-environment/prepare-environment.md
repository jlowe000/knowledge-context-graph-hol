# Prepare the matching package and choose your route

## Introduction

This v2.1.0 distribution has four independently tested installation paths on prepared environments; review the [recorded scopes and limits](../../db/verification/release-v2.1-paths-validation.json). If a facilitator supplied an app URL and login, skip deployment and start [My Contexts](../my-contexts/my-contexts.md). App users need no OCI, database or local-tool access.

Estimated Lab Time: 10–15 minutes; planning estimate.

### Objectives

- Choose APEX-led or SQL-first installation, and clean versus upgrade.
- Obtain matching versioned artifacts and identify accounts.
- Keep credentials and environment details private.

## Task 1: Choose the experience

Use the [installation selector](../../docs/installation-paths.md). APEX-led begins with [administrator preparation](../../docs/apex-led-administrator-preparation.md), then imports the intact app ZIP through Builder. SQL-first uses Database Actions and ordered prepared SQL. DEV-led adaptation remains on the dev branch with its own tooling.

An empty schema is a clean target; an existing published v2.0.0 app is an upgrade even on a temporary database. For v1 use the [published v2.0.0 bridge](../../docs/migrate-to-v2.md) first. Unknown/customised/partial states need review. Never delete existing objects to make a target qualify as empty.

## Task 2: Obtain one complete package

Use the facilitator's exact reviewed package or a published release package, not an arbitrary branch-head download. Confirm VERSION, source commit, artifact hashes and [route validation](../../db/verification/release-v2.1-paths-validation.json). Local release preparation does not publish GitHub files; verify the version you actually downloaded.

Required route files include:

- APEX-led: apex/kcv-explorer.apx.zip, its matching manifest and [clean](../../docs/apex-led-installation.md)/[upgrade](../../docs/apex-led-upgrade.md) instructions.
- SQL-first: ordered schema parts and full verifier; [20_install_apex.sql](../../sql/install/20_install_apex.sql) or [20_upgrade_apex.sql](../../sql/install/20_upgrade_apex.sql); generated [03 binding](../../sql/install/03_bind_deployment_owner.sql).
- Both: public dataset pin/manifest, applicable licences/notices, required administrator/model preparation and shared [readiness](../../docs/deployment-setup.md).

The current package excludes v1 adoption/completion helpers; those belong to the pinned v2.0.0 bridge. No Python, SQLcl, wallet or local Java is needed for these release installation routes.

## Task 3: Identify accounts and private inputs

ADMIN performs platform/owner/grant/workspace tasks. SQL-first schema work runs as the actual owner; changing CURRENT_SCHEMA under ADMIN is not an owner login. APEX-led setup uses an authorised workspace administrator after Supporting Objects. Each learner uses an individual app-only account.

Keep passwords, signing keys, configuration values and live URLs out of saved scripts, screenshots and public diagnostics. Private bind fields are matched by name, not screen order. The [authentication guide](../../docs/authentication.md) distinguishes OCI signing credentials from Console passwords and resource principal.

## Task 4: Use the correct transport

For SQL-first complete files, use Worksheet Open File/upload SQL, confirm completeness and choose the stated mode. Generated schema parts use **Run Script/F5**. Bind-bearing setup/app/binding blocks use **Run Statement**, selecting the whole outer DECLARE/BEGIN through END without the slash. Do not paste a filename as SQL or split a PL/SQL block.

Short inline examples can be copied directly without Markdown fences or copy-wrapper tags. APEX-led imports the application ZIP intact through Builder; it does not upload a GitHub source archive or paste backend SQL into the app.

Expected outcome: one matching package, a supported starting state and clear account/route responsibilities. Continue to [SQL-first clean](../../docs/fresh-serverless-deployment.md) or the selected APEX-led guide. Check results after every action and stop on dependent errors.

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
