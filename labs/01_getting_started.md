# Lab 1 — Get Started

## Objective

Prepare an independent Oracle Linux/Bash workspace, generate inspectable artifacts, and understand the administrator/learner boundary for a standard ADB Serverless database.

## Run the artifact-only path

From the project root:

```bash
bash scripts/bootstrap.sh
bash scripts/build_artifacts.sh
```

Open `generated/dataset-preview.md`. Inspect `generated/build-report.json`: it must label native Serverless and model validation as not run until those steps are actually performed. The starting graph intentionally contains no accepted extracted claims.

## Continue with the full database path

Follow [setup.md](../docs/setup.md) in order:

1. Configure the temporary Serverless connection privately.
2. Administrator checks Java; if absent, requests enablement, restarts the instance and waits for VALID.
3. Administrator creates KCV_LAB and applies explicit grants/quota.
4. Configure model access using either [your OCI user API signing key or a resource principal](../docs/authentication.md). The user-key path does not require a dynamic group.
5. Learner creates own objects, RDF network and AI profile.

The setup scripts do not provide OCI resources or restart the database automatically. A model endpoint, IAM permission and network path must exist before model calls. A laptop-side Oracle Linux client can connect to Serverless directly; a separate Compute VM is optional.

## Inspect before proceeding

Explain why a prepared sandbox can skip user/grant setup, while a standard database cannot. Explain why installing Java on the client does not enable database JVM. Only proceed to native RDF loading when readiness passes under the lab user.
