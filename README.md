# Knowledge Context Explorer — SQL-first HOL

This is the **release branch**, for deploying and using the lab. No Python, Oracle client driver, wallet or local build is required. Use a browser and an approved ADB Serverless 26ai database with Java/RDF, model access and compatible APEX.

**Start with the [beginner deployment walkthrough](docs/fresh-serverless-deployment.md).** It identifies the account, screen, action and expected result at each step.

## What is included

- SQL for user/grant setup, native graphs, model access, agents and the application backend.
- [Ready-to-run dataset loader](sql/install/10_load_dataset.sql).
- [Ready-to-run APEX Worksheet installer](sql/install/20_install_apex.sql) and [standard application export](apex/kcv-explorer.sql).
- Nine public-source records, 17 clearly labelled editorial summaries, three fictional learner contexts, ontology and native SQL verification.
- Sources and Answer lineage views, context refinements and observations.

The [dataset](docs/release-dataset.md) contains attributed summaries of public presentation pages, **not verbatim PDF extracts**. Each summary has its own ID/hash and links to the original page. A matched citation establishes a link to the summary; read the PDF to check the underlying source. Original presentations remain with their rights holders.

## Choose the right branch

Stay on `release` to install/use the lab. Select `dev` in the repository's branch selector for Python source preparation, tests, UI/build source and optional developer tools. Contributor setup is documented only on `dev` in `docs/development.md`; the release is not a developer checkout.

See [validation and remaining checks](docs/scenario-validation.md). The application was tested with the earlier extracted-passage dataset; the new summary distribution has build checks but still needs native acceptance on a fresh database. Do not treat this as a production deployment certification.

[UPL 1.0 licence](LICENSE.txt) · [attribution](NOTICE.md) · [cleanup](docs/cleanup.md). No WMS/reservation metadata or other upstream workshops are included.
