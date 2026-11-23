# Start here: deploy to a new ADB Serverless instance

This is the beginner route to the complete Knowledge Context Explorer application. No previous Autonomous Database (ADB), SQL, graph or APEX experience is assumed. Work through the labs below in order. Each task identifies the account, the screen or terminal, the action and the expected outcome.

| Order | Lab | Result |
| --- | --- | --- |
| Start | [Introduction](../labs/introduction/introduction.md) | Understand the experience, accounts and resources |
| 1 | [Prepare your working environment](../labs/prepare-environment/prepare-environment.md) | Local authoring files and application installer are ready |
| 2 | [Create the database](../labs/provision-database/provision-database.md) | A new Serverless database and ADMIN Worksheet are available |
| 3 | [Configure database and model access](../labs/configure-database/configure-database.md) | Java, lab user, grants, schema and a working model profile |
| 4 | [Load knowledge and install the scenario](../labs/load-knowledge/load-knowledge.md) | The pinned GitHub summary dataset, native graph and scenario team are installed |
| 5 | [Deploy the application](../labs/deploy-explorer/deploy-explorer.md) | APEX workspace, application and app-user login |
| 6 | [Explore the evidence](../labs/explore-evidence/explore-evidence.md) | Inspect an answer, refine context and compare saved evidence |
| Help | [Need help?](../labs/need-help/need-help.md) | Diagnose the failing step without restarting everything |

**Use this route for a new instance.** The [upgrade guide](epics-upgrade.md) is for an existing installation. The older numbered lab files remain deeper technical/optional exercises. You do not need the older KCV_TEAM, claim approval, an Oracle client wallet, a direct database driver, a separate graph service, or a LiveLabs sandbox reservation for this route.

Provisioning/restarting the database and OCI access policies are Console/administrator activities. All database setup uses browser-based Database Actions SQL Worksheet. An Oracle Linux terminal generates the public-source artifacts and the APEX installer. Credentials are entered privately in the browser; they are never part of the repository.

The shared loading lab defaults to the [public GitHub summary dataset](github-dataset-load.md). Its manifest and JSON parts must already be published at the chosen commit. Test the dev candidate using its full commit SHA and keep release unchanged until native acceptance passes. To test your own extracted authoring passages instead, use the local numbered SQL fallback described in that guide, in a separate fresh lab schema. Ordinary release learners use the promoted package and need no local build.

The expanded public-content build also requires an APEX developer to [replace the supplied application JavaScript](content-ingestion-upgrade.md#required-application-file-update) after importing the app. Its engine SQL export has not yet been regenerated. The deployment lab identifies this step explicitly; KCV_USER remains an end-user login.

## What is verified

The scripts, application and evidence/refinement flows were exercised on the existing temporary Serverless instance, including the latest response-explanation feature. An explicitly requested project teardown, clean checkpoint and dev rebuild passed on 21–23 November, with JAVAVM retained; native and signed-in browser tests passed. This did not repeat database provisioning or first-time Java enablement. This new beginner sequence has been reviewed against those dependencies, but has **not yet been rehearsed end to end on another empty database by a new learner**. That clean-install rehearsal and the remaining platform screenshots are the next documentation acceptance checks. See [validation](scenario-validation.md).

The labs follow the public LiveLabs authoring template's content conventions. WMS manifests, reservation metadata and publication scaffolding are intentionally excluded. This is a standalone adaptation, not a claim of official LiveLabs publication or QA approval. See [authoring alignment](livelabs-authoring-alignment.md) and the [screenshot checklist](screenshots.md).
