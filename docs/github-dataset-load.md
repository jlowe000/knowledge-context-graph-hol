# Load the public dataset directly from GitHub

The preferred learner path is one short SQL Worksheet call. ADB fetches a pinned manifest and JSON files from public GitHub, checks their SHA-256 hashes and declared counts, then loads the source catalogue, editorial summaries, learner contexts and native RDF graph. The database does not execute downloaded SQL or fetch the original research sites during installation.

The GitHub package contains **attributed editorial summaries and public reference metadata**. It is published on dev first for native acceptance, then promoted to release after validation. Dev's locally extracted passages remain a separate authoring dataset; they are not published in this package. Installation does not require Python, a client wallet, a GitHub token, a resource principal or an Object Storage bucket. OCI model credentials are still needed for later inference and are configured separately.

## Before the first load

Follow the [database configuration lab](../labs/configure-database/configure-database.md). ADMIN applies the current `sql/admin/02_grants.sql`; KCV_LAB creates the base tables, KCV_NET and read-only tools, then runs [06_dataset_import.sql](../sql/schema/06_dataset_import.sql) once to install KCV_DATASET and its run log. Do not rerun all initial schema scripts on an existing installation.

For an existing lab owner, apply the current grants as ADMIN, replace [03_tools.sql](../sql/schema/03_tools.sql) as KCV_LAB with F5, then install the importer. The current source packet limits evidence to passages in the active graph; older code could mix historical extracted passages with summaries sharing the same source edition. Its signature is unchanged and historical data is retained. Complete this replacement before native verification. Use a fresh lab schema for a separate summary exercise when existing conversations must remain in their current environment. Follow the [content locator upgrade](content-ingestion-upgrade.md) where applicable; installing an importer does not update the application.

The manifest and every referenced JSON part must already be committed and pushed to a public repository commit. **For the current acceptance cycle, use dev and keep release unchanged until dev is proven.** Local generated files are not available to ADB through GitHub; an older remote commit without `data/load/` cannot load the new content. The importer uses the immutable commit SHA, not a branch name.

## Choose a published version

1. Open [the repository](https://github.com/jlowe000/knowledge-context-graph-hol), select **dev** for native acceptance, and locate [data/load/manifest.json](../data/load/manifest.json). Ordinary learners use release after the tested package has been promoted.
2. Open the dev commit containing the intended package. Copy its **full 40-character commit SHA** from the commit page. A branch name or shortened SHA is not accepted. Keep that SHA for repeatable tests.
3. View [sql/install/10_load_github.sql](../sql/install/10_load_github.sql) at the **same commit**. Its manifest hash is already filled in; replace only its commit placeholder. This hash identifies the manifest bytes, not the graph hash or the `dataset_id` value inside the manifest.
4. Check the pinned manifest's Raw link in a signed-out/private browser window. Its URL has the form `https://raw.githubusercontent.com/jlowe000/knowledge-context-graph-hol/<FULL_COMMIT_SHA>/data/load/manifest.json`. It should display JSON without a sign-in prompt. If the file is absent, verify that the intended dev commit and complete package were pushed; do not substitute another dataset or disable the integrity checks.

This binds the dataset to both a specific repository commit and an expected manifest. Always use the caller and manifest from the same published version.

## Run the short call

**Where:** Database Actions → SQL Worksheet. **Account:** KCV_LAB.

Run `SELECT USER FROM dual;` first and confirm KCV_LAB. Replace the editor with the prepared caller and choose **Run Script (F5)**. The seven-line form is:

```sql
BEGIN
  KCV_DATASET.LOAD_GITHUB(
    p_owner=>'jlowe000', p_repo=>'knowledge-context-graph-hol',
    p_ref=>'PASTE_FULL_40_CHARACTER_COMMIT_SHA',
    p_expected_manifest_sha256=>'PASTE_64_CHARACTER_HASH_FROM_MATCHING_CALLER');
END;
/
```

The generated caller already supplies the manifest hash. Never put passwords, API keys or GitHub tokens into this call. The download is anonymous: Oracle documents public GitHub Raw file access with `credential_name => NULL` in its [supported URI formats](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/file-uri-formats.html).

The importer loads bounded JSON parts, builds a graph snapshot and changes ACTIVE_GRAPH only after the load succeeds. Run one loader at a time. The GitHub importer prevents a second GitHub load while its first load holds the lock; do not start a fallback SQL loader alongside it.

## Check progress and handle errors

Worksheet may display DBMS Output only when the call finishes. While it is running, use a second KCV_LAB Worksheet to run this read-only query:

```sql
SELECT run_id,status,phase,source_ref,graph_name,error_code,started_at,updated_at
FROM kcv_dataset_runs
ORDER BY started_at DESC
FETCH FIRST 5 ROWS ONLY;
```

| Result | Meaning and next step |
| --- | --- |
| `RUNNING` | Read `phase` and `updated_at`; wait for the existing call. Do not start another load just to check progress. |
| `SUCCEEDED` | The manifest completed and the ready graph was activated. Run the native verification below. |
| `FAILED` | Retain the run ID, phase, error code and Worksheet error. Correct the cause, then rerun the same complete call. The previous ACTIVE_GRAPH is preserved. |
| No rows | No recorded load reached this log, or you are in the wrong schema. Check `SELECT USER FROM dual;`, package installation and the immediate Worksheet error. |
| Table or package missing | Return to the configuration lab and install `06_dataset_import.sql` as KCV_LAB after the base objects/grants. Do not recreate the whole schema. |

A retry is supported. A previously successful matching manifest can reactivate its ready snapshot; a failed load can create a new snapshot on retry. Progress timestamps record completed checkpoints rather than a percentage or an estimated finish time. A browser timeout alone does not prove the database stopped; inspect the run before retrying. A killed or disconnected database session can leave a stale RUNNING record. If its status is uncertain, ask the administrator to check that specific run/session before retrying; do not delete the run log or clear a lock to force progress.

For a 404/not-found response, check the owner, repository, full commit and published `data/load/` files. For a hash or count mismatch, obtain the unchanged caller and data from the same commit; do not edit hashes to suppress the failure. For network/package errors, ask the database administrator to check public HTTPS access and the documented execution grants. The dataset path does not require OCI model IAM changes.

## Verify the loaded graph

After `SUCCEEDED`, run [01_inspect.sql](../sql/queries/01_inspect.sql) and [verify_worksheet.sql](../integration-test/verify_worksheet.sql) as KCV_LAB with F5. Confirm a ready ACTIVE_GRAPH and the expected PASS message. Run [verify_source_packet_scope.sql](../integration-test/verify_source_packet_scope.sql) alone with F5 to confirm the source packet returns only evidence from the active graph. It creates and rolls back a temporary out-of-graph test passage without deleting historical evidence. Then continue with the [scenario backend and native checks](../labs/load-knowledge/load-knowledge.md#task-2-install-the-application-backend). These checks make no model inference calls.

The new GitHub importer and expanded summary dataset still need native compilation/execution and model/browser acceptance on ADB Serverless. Local packaging and code checks do not establish those outcomes. Public classification, source retrieval and editorial accuracy remain separate from verifying that a load completed.

## Network ACLs and outbound routes

Standard GitHub Raw and OCI Object Storage URLs are recognized DBMS_CLOUD endpoints. On a standard ADB Serverless configuration, an additional database host ACL is normally unnecessary. Custom endpoints may require explicit host ACEs. This applies to this DBMS_CLOUD loader, not arbitrary UTL_HTTP code. See [endpoint management](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-endpoint.html) and [supported URI formats](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/file-uri-formats.html).

| Control | Public GitHub dataset | OCI Object Storage alternative |
| --- | --- | --- |
| Package permission | KCV_LAB needs EXECUTE on DBMS_CLOUD | Same |
| Standard endpoint host ACL | Normally already supported | Normally already supported |
| Data authorization | Public repository; no credential | Public object/PAR URL, or authorized credential/resource principal for private access |
| Enforced private VCN route | Internet egress, typically NAT, plus DNS and HTTPS/443 | A regional OCI Service Gateway route can reach Object Storage privately |

A host ACE restricted to Object Storage does not grant access to a GitHub hostname. An Object Storage-only Service Gateway route does not provide internet access. Database host ACLs also do not grant bucket permissions or create routes. The OCI Console ACL controlling clients connecting **into** ADB is separate from an outgoing download.

As ADMIN, inspect the routing property without changing it:

```sql
SELECT property_name,property_value
FROM database_properties
WHERE property_name='ROUTE_OUTBOUND_CONNECTIONS';
```

No row means the property is unset. On a private endpoint, `ENFORCE_PRIVATE_ENDPOINT` applies VCN routing and egress rules to DBMS_CLOUD; the older `PRIVATE_ENDPOINT` value does not enforce them for that package family. Do not change this database-wide setting just to load the lab. See [Oracle's outbound routing table](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/private-endpoints-autonomous.html) and [Service Gateway configuration](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/servicegateway.htm).

For ORA-24247, ask ADMIN to inspect the effective host ACE for KCV_LAB and the exact destination. Restrict any needed exception to that destination rather than a wildcard grant. Timeout/DNS errors need route investigation; 403/404 errors need endpoint, publication and access checks. The project keeps GitHub as the default and has not inspected or changed your database network settings.

The [GitHub acceptance script](../integration-test/verify_github_dataset.sql) checks reuse, rejection of mutable refs, a wrong manifest hash, preservation of the active graph and retry. Run it after the first GitHub load succeeds, alongside [the source-scope check](../integration-test/verify_source_packet_scope.sql) for native acceptance. It makes public downloads and adds expected failure/success run-log records; it makes no model calls. Native compilation, interrupted native loading and two-session concurrency still need database testing.

## Fallback and development paths

Maintainers generate the summary package on dev with `scripts/build_github_dataset.py --output data/load --loader sql/install/10_load_github.sql`, using the project's Python environment. Follow [publish and test on dev](development.md#publish-and-test-the-github-dataset-on-dev) for the exact command and acceptance sequence. The checked-in JSON package contains attributed summaries; raw authoring text and source bodies stay in ignored local files. Promote to release only after the dev candidate passes native acceptance.

The release retains `sql/install/dataset-parts/README.md` and numbered SQL files for environments where GitHub downloads are unavailable. Run complete parts in numeric order using F5, one at a time; wait for success before continuing. If a part fails, fix the cause and restart from the first part. The combined `sql/install/10_load_dataset.sql` is an alternative for a client that can handle its size. Choose one form; do not run both.

Dev-generated `work/worksheet/dataset-parts/` and `work/worksheet/10_load_dataset.sql` instead contain the locally prepared authoring passages. Keep those files local. Building your own release still uses the dev pipeline; ordinary release installation does not.
