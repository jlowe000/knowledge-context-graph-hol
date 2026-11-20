# Explore Knowledge in Context

## Introduction

You will deploy an application that connects a person's question to curated public knowledge. You will inspect the evidence behind an answer, refine the person's context and see how the next conversation changes.

Estimated Workshop Time: allow a half-day for a first installation. This is a planning allowance, not a measured completion time; account access, provisioning and model availability can add waiting time.

### Objectives

In this workshop, you will:

- Prepare a new Autonomous AI Database Serverless instance.
- Load public source metadata, attributed editorial summaries and graph relationships.
- Deploy the Knowledge Context Explorer APEX application.
- Inspect source connections and recorded answer lineage.
- Refine context and record what should be explored next.

### Prerequisites

This workshop assumes you have:

- An OCI account with permission to create a lab database, or an administrator who will perform that task.
- An approved lab budget and access to OCI Generative AI chat inference.
- A browser and plain-text editor; no Python, shell or local database software is required.
- This standalone project downloaded/extracted from the location supplied by your facilitator.

No ADB, SQL, RDF or APEX experience is required. OCI means Oracle Cloud Infrastructure. A compartment is a folder-like boundary for cloud resources and permissions. A schema is a database user's collection of tables and code. APEX is the browser application platform included with the database.

## Task 1: Understand the accounts

1. Keep the four identities below distinct. Your facilitator or OCI administrator can help with cloud permissions; do not substitute ADMIN for every login.

   | Identity | Where it is used | Purpose |
   | --- | --- | --- |
   | Your OCI user | OCI Console | Create/manage the database and authorize model access |
   | ADMIN | Database Actions SQL Worksheet | Create the lab database user and APEX workspace/account |
   | KCV_LAB | Database Actions SQL Worksheet | Own the knowledge tables, graph, profile and application code |
   | KCV_USER | Knowledge Context Explorer login | Use the finished application |

2. Keep passwords and API signing keys in your approved private credential store. An APEX workspace name is not a username. The three database/app login passwords are separate from your OCI Console login.

**Expected outcome:** you know which identity to use when a later task says ADMIN, KCV_LAB or KCV_USER.

## Task 2: Understand what is supplied

1. Review the supplied content: nine public presentation records, 17 attributed editorial summaries, three fictional learners and a prebuilt APEX application export. The supplied SQL loads the summaries; it does not download or redistribute the original PDF text.

2. Notice the starting boundary: the graph is curated source/topic/evidence knowledge. Asking a question does not automatically discover new websites, retrain a model or edit source facts. This workshop refines the learner's context.

3. Continue to [Prepare your working environment](../prepare-environment/prepare-environment.md). If you are blocked at any point, use [Need help?](../need-help/need-help.md).

**Expected outcome:** you can describe the final experience: question → connected evidence → context refinement → next question or action.

## Learn More

- [Standalone project scope and attribution](../../NOTICE.md)
- [Workshop route](../../docs/fresh-serverless-deployment.md)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Upstream workshop** — Oracle LiveLabs authors credited in NOTICE.md
- **Last Updated** — November 2026
