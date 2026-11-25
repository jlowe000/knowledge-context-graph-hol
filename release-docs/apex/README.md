# APEX application deployment

App users start with [My Contexts](../labs/my-contexts/my-contexts.md) or [Sample Contexts](../labs/explore-evidence/explore-evidence.md). Developer learners use [Understand the collection](../labs/understand-collection/understand-collection.md). A working hosted app requires no database login.

## Choose the installation mode

Use [installation paths](../docs/installation-paths.md) before running SQL. In this v2.0.0 distribution, a clean schema uses the new-app installer; an existing supported installation uses the ordered schema migration and **same-ID** app upgrade. Both routes have passed scoped candidate02 [acceptance](../db/verification/release-v2-paths-validation.json), including fresh-sign-in reopening. The tested import body is unchanged; the supplied execution instruction incorporates the **Run Statement** correction.

| Mode | Prepared artifact | Identity behavior |
| --- | --- | --- |
| New application | [20_install_apex.sql](../sql/install/20_install_apex.sql) | Allocates a new app ID in the chosen workspace/schema |
| Existing application | [20_upgrade_apex.sql](../sql/install/20_upgrade_apex.sql) | Requires its existing app ID and matching workspace/schema/alias |

The bind names are `KCV_SCHEMA`, `KCV_WORKSPACE`, `KCV_APP_ALIAS`; upgrade also uses `KCV_APPLICATION_ID`. Blank nonsecret values select documented defaults. Do not select a different ID to bypass a mismatch. Account creation and passwords are separate ADMIN tasks; upgrades retain existing accounts.

After R7 schema verification, open the supplied installer in the project owner's Database Actions Worksheet. Select its complete outer `DECLARE` through the final `END;`, excluding the final slash, and use **Run Statement (Ctrl+Enter)**. Supply the target binds and, for an upgrade, the existing application ID. These bind-bearing installers require Run Statement; F5 does not open their bind prompts. The schema gate checks the checkpoint and sixteen required package specification/body objects. The app contains nine pages and seven packaged assets. A compatible APEX 26.1+ service is required; current native tests used 26.1.6. The standard [engine export](kcv-explorer.sql) is also available to an authorized App Builder developer, but its import alone does not perform the full deployment checks.

## APEXlang and runtime services

Maintainers author native APEXlang (`.apx`) pages on dev, together with UI assets and SQL/PLSQL APIs. The release supplies the verified engine export and Worksheet wrappers, so no Python, SQLcl, APEXlang compiler or frontend server is required by learners. The [export receipt](export-validation.json) identifies the prepared artifact, not universal deployment acceptance.

Question evidence is retrieved by the application before `KCV_GROUNDED_TEAM`; the separate explorer team handles proposals. The database owner already has its model profile/credential. No browser API key or separate APEX Generative AI service configuration is required. Local context search uses an independently installed database embedding model and explicit keyword fallback.

Follow the [clean deployment lab](../labs/deploy-explorer/deploy-explorer.md) or [migration guide](../docs/migrate-to-v2.md). After import, verify app login, both personal/sample paths, historical evidence and saved-work reopening. Installation may expire a browser session; sign back in with the same app account.
