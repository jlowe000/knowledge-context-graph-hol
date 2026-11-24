# LiveLabs HOL authoring alignment

Reviewed 19 November 2026 against Oracle's public [LiveLabs ultimate template](https://github.com/oracle-livelabs/developer/blob/main/livelabs-ultimate-template/intro/intro.md) and the pinned [upstream workshop](upstream-comparison.md). These are content-authoring conventions, not a claim that the project has passed Oracle publication review.

This is the historical v1 authoring review. Its beginner route is linked from [Start here](fresh-serverless-deployment.md) and remains in the published release. Current dev uses [migrations](database-migrations.md), [APEXlang authoring](apexlang-development.md) and the [My Contexts manual review](my-contexts-manual-test.md). Existing engineering reference documents and older numbered exercises remain available without becoming an alternative v2 setup sequence.

| Convention | Applied in this project |
| --- | --- |
| One clear lab title and Introduction | Each beginner lab begins with these |
| Estimated lab/workshop time | Planning estimates are labelled; service/IAM waiting time is explicit |
| Objectives and Prerequisites before tasks | Present in every beginner lab; no ADB knowledge assumed |
| Numbered Task headings and ordered steps | Tasks identify actions in sequence; account/location repeated at role changes |
| Short lowercase lab/folder names | For example `labs/configure-database/configure-database.md` |
| Copyable commands in fenced blocks | LiveLabs `<copy>` markers; GitHub readers are told to copy only the content between them |
| Retained SQL plus short inline examples | Generated from actual scripts; new lab bind-statement copies omit the script slash intentionally |
| Task-specific screenshots with alt text | Two real app images included; remaining platform captures explicitly tracked, not fabricated |
| Outcomes and recovery | Each task says what success looks like; Need Help covers likely failures |
| Learn More and Acknowledgements | Included in each beginner lab; upstream attribution retained |
| Explicit progression | Each lab links to the next; main path is separate from optional extraction/inference and upgrades |

## Deliberate standalone boundary

The public template also describes workshop manifests and the LiveLabs renderer's index page. Those belong to publication/runtime integration. They are **not** added here because this project was explicitly scoped to exclude WMS/reservation metadata. Plain relative links make the route usable in the repository. A LiveLabs renderer/publication package would be a separate, explicitly requested deliverable; no renderer or WMS QA pass is claimed.

The short-SQL synchronizer supports LiveLabs copy tags for the nested beginner lab folders while leaving reference-document examples unchanged. Its check is a consistency check, not an official LiveLabs validator.

## Remaining documentation acceptance

1. Run the full beginner route on a separate empty, approved Serverless instance using only the documented material.
2. Capture the platform images in the [screenshot checklist](screenshots.md), using no private connection/credential data.
3. Have a first-time ADB reader complete the path and record points requiring facilitator help.
4. If publication is later requested, perform the then-current LiveLabs renderer/WMS and accessibility review separately.
