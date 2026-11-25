# Explore Knowledge in Context

## Introduction

Use a curated knowledge collection to explore a question, inspect its evidence and refine the next conversation. Choose an app-user experience or a developer experience that explains how the supplied collection works. Deployment is an additional route when an environment has not been provided.

Estimated Lab Time: 10 minutes to choose a route. Allow 20–30 minutes for app use, 45–60 minutes for developer learning, or a half-day for a first deployment; these are planning estimates, with model/service waiting time additional.

### Objectives

In this introduction, you will:

- Choose the experience that matches your learning objective.
- Identify which account/access that experience needs.
- Understand the public/fictional sample and evidence boundaries.

### Prerequisites

| Route | Prerequisites |
| --- | --- |
| App user | Browser, working app URL and app login supplied by your facilitator |
| Developer learning | Release files and a deployed sample with private KCV_LAB Worksheet access |
| Deploy the sample | Approved OCI/ADB resources, administrator support and model inference permission; the setup labs explain each step |

No Python or local build is required on release. No OCI Console or SQL knowledge is required for app use. Developer learning introduces the sample-specific SQL/graph concepts as you follow the implementation. ADB means Autonomous Database; APEX is the browser application platform included with it.

## Task 1: Choose a learning experience

1. Choose the question you want to answer:

   | Your question | Continue to |
   | --- | --- |
   | How can this collection help with my own question? | [My Contexts](../my-contexts/my-contexts.md) |
   | How can I try a supplied fictional example first? | [Explore a sample](../explore-evidence/explore-evidence.md) |
   | How do context, sources, the graph, agents and the UI work together? | [Understand the collection as a developer](../understand-collection/understand-collection.md) |
   | How do I install the supplied sample? | [Prepare release files](../prepare-environment/prepare-environment.md), then follow the deployment route |
   | How do I build my own collection or change this implementation? | Select dev and read `docs/build-your-own.md` |

2. Read [Learning paths](../../docs/learning-paths.md). Release supports both app users and developers learning this example. Dev supports people building a new adaptation; the branch choice is about your intended outcome, not your technical seniority.

**Expected outcome:** you have a clear starting point without taking on unrelated setup work.

## Task 2: Identify the required accounts

1. Identify the account for your chosen route:

   | Identity | Used for |
   | --- | --- |
   | KCV_USER or facilitator-supplied app login | The app-user experience |
   | KCV_LAB | Developer SQL exercises and ownership of the sample data/code |
   | ADMIN | Database/workspace setup when deploying the sample |
   | Your OCI user | Cloud provisioning and model permissions when your role requires them |

2. Use an individual app account for private My Contexts work: a shared login shares that library. Keep the credentials distinct and private. An app user does not need an ADMIN password. A developer inspecting a graph does not need to change cloud IAM when the sample is already configured.

**Expected outcome:** you know which login is relevant and who supplies it.

## Task 3: Understand the sample

1. Review the sample: nine reviewed public presentation records, the expanded public research catalogue and attributed editorial summaries of selected content, three fictional learner contexts and a prepared APEX app. The supplied SQL loads the collection. It does not redistribute the original PDFs.

2. Notice the boundary: context changes affect which evidence is selected. They do not rewrite source facts, certify correctness or train the model. A matched citation points to supplied evidence; follow its original page link to check the source.

3. Continue on your selected path. If blocked, use [Need help?](../need-help/need-help.md).

**Expected outcome:** you can describe the experience as question → connected evidence → refinement → next question or action.

## Learn More

- [Choose your learning path](../../docs/learning-paths.md)
- [Source attribution](../../NOTICE.md)
- [Deployment route](../../docs/fresh-serverless-deployment.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
