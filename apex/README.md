# APEX application deployment

This v2.1.0 distribution contains two application transports. Its four prepared-environment deployment routes passed within the separate scopes in [v2.1 validation](../db/verification/release-v2.1-paths-validation.json); older r13/v2.0 tests retain their historical scope.

| Route | Artifact | Backend/readiness |
| --- | --- | --- |
| APEX-led clean or supported upgrade | [kcv-explorer.apx.zip](kcv-explorer.apx.zip) in App Builder | Supporting Objects Install/Upgrade verifies and binds the schema; guided setup explicitly enables learning |
| SQL-first new app | [20_install_apex.sql](../sql/install/20_install_apex.sql) | Ordered schema first, app import, generated 03 binding, final model-test/readiness/enable gates |
| SQL-first existing app | [20_upgrade_apex.sql](../sql/install/20_upgrade_apex.sql) | Upgrade schema and same app ID, then binding/readiness; saved data retained |

Use the [installation selector](../docs/installation-paths.md). A GitHub source archive is not the application ZIP. The standard [SQL app export](kcv-explorer.sql) is definition-only; importing it alone is not a complete installation. Do not run both Supporting Objects and a second SQL-first schema installer.

For Worksheet app installers, select the complete outer DECLARE through END without the final slash and use **Run Statement** for target binds. Schema parts use **Run Script**. Use the actual owner, not ADMIN with CURRENT_SCHEMA changed.

APEXlang is maintained by dev; package users need no authoring environment. APEX 26.1-compatible support and the APEXlang route's ORDS/REST prerequisites are described in [administrator preparation](../docs/apex-led-administrator-preparation.md). Do not alter version metadata to force import.

The export includes application definitions, versioned assets and applicable attribution. It does not contain learner rows, credentials, app accounts, downloaded PDFs or populated personal graphs. The [architecture](../docs/architecture.md) explains runtime services; [deployment readiness](../docs/deployment-setup.md) explains the six required checks and optional keyword fallback.
