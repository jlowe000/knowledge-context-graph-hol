# Knowledge Context Explorer application

Application icons use Font APEX from the Oracle APEX team. See [attribution](../third-party/font-apex/README.md) and the [retained licence](../third-party/font-apex/LICENSE.txt). Include these files and [NOTICE](../NOTICE.md) when distributing the SQL export or Worksheet installer separately.

For the learning experience, start with [app use](../labs/explore-evidence/explore-evidence.md) or [understand the collection as a developer](../labs/understand-collection/understand-collection.md). Installation below is needed only when no suitable deployment is supplied.

Use the supplied [Worksheet installer](../sql/install/20_install_apex.sql) as KCV_LAB after completing database and scenario setup. Follow the [deployment lab](../labs/deploy-explorer/deploy-explorer.md), including ADMIN workspace and app-user creation. The installer allocates a new application ID; it does not require App Builder or Python.

The [standard APEX export](kcv-explorer.sql) is also supplied for an APEX developer importing through App Builder. It was generated on APEX 26.1.5 and tested on Serverless 26.1.6; use a compatible APEX 26.1+ service. KCV_USER is an application end user, not an App Builder developer.

APEX HTML/CSS/JavaScript source and application-building tools are available on dev. The release SQL export already contains the runtime assets; no external frontend build/server is required. It uses the database KCV_GENAI profile and KCV_EXPLORER_TEAM. No separate APEX Generative AI service configuration or browser API key is needed.

This release uses [attributed editorial summaries](../docs/release-dataset.md). See [validation status](../docs/scenario-validation.md) and the [UI walkthrough](../docs/ui-walkthrough.md).


## APEXlang and the supplied installer

APEXlang (`.apx`) is the authoring representation of the application definition. The prepared app also uses HTML/CSS/JavaScript UI assets and a PL/SQL database API. Dev contains that source and the build/export workflow for adaptations.

The release supplies the APEX-engine-generated SQL export and its Worksheet installer. Those deploy the prepared application and assets; learners do not have to compile APEXlang or run authoring tools. See [deployment architecture](../docs/architecture.md#how-apexlang-relates-to-deployment) for the relationship between those artifacts and the running experience.
