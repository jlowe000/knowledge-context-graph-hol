# Load the public dataset directly from GitHub

The preferred learner path is one short SQL Worksheet call. ADB fetches a pinned manifest and JSON files from public GitHub, checks their SHA-256 hashes and declared counts, then loads the source catalogue, editorial summaries, learner contexts and native RDF graph. The database does not execute downloaded SQL or fetch the original research sites during installation.

The package contains attributed editorial summaries and public reference metadata. See [dataset provenance and coverage](release-dataset.md). Installation does not require Python, a client wallet, a GitHub token, a resource principal or an Object Storage bucket. OCI model credentials are still needed for later inference and are configured separately.

## Before the first load

Follow the [database configuration lab](../labs/configure-database/configure-database.md): apply the owner grants, install the ordered v2 schema parts and verify them, then create the owner-private RDF network. The complete schema already includes KCV_DATASET and its run log. Do not replay raw table/tool/importer DDL. Existing installations first select their [version-specific upgrade](installation-paths.md); loading another public collection is optional and independent of an app upgrade.

The manifest and every referenced JSON part must already exist at the selected immutable public commit. Normally use the published release commit; a maintainer may specify an earlier published commit when its dataset bytes and manifest hash are unchanged. Local generated files are not available to ADB through GitHub. Generating this package does not publish it; an older remote commit without `data/load/` cannot load the new content.

## Choose a published version

1. Open [the repository](https://github.com/jlowe000/knowledge-context-graph-hol), select **release**, and locate [data/load/manifest.json](../data/load/manifest.json).
2. Open the release commit that contains the intended dataset. Copy its **full 40-character commit SHA** from the commit page. A branch name or shortened SHA is not accepted. Keep that SHA for repeatable lab installations.
3. View [sql/install/10_load_github.sql](../sql/install/10_load_github.sql) at the **same commit**. Its manifest hash is already filled in; replace only its commit placeholder. This hash identifies the manifest bytes, not the graph hash or the `dataset_id` value inside the manifest.
4. Check the pinned manifest's Raw link in a signed-out/private browser window. Its URL has the form `https://raw.githubusercontent.com/jlowe000/knowledge-context-graph-hol/<FULL_COMMIT_SHA>/data/load/manifest.json`. It should display JSON without a sign-in prompt. If the file is absent, wait for the intended release to be published; do not substitute a different branch or disable the integrity checks.

This binds the dataset to both a specific repository commit and an expected manifest. Always use the caller and manifest from the same published version.

## Run the short call

**Where:** Database Actions → SQL Worksheet. **Account:** the project owner (KCV_LAB by default).

Run `SELECT USER FROM dual;` first and confirm the chosen project owner. Replace the editor with the prepared caller and choose **Run Script (F5)**. The seven-line form is:

```sql
BEGIN
  KCV_DATASET.LOAD_GITHUB(
    p_owner=>'jlowe000', p_repo=>'knowledge-context-graph-hol',
    p_ref=>'PASTE_FULL_40_CHARACTER_COMMIT_SHA',
    p_expected_manifest_sha256=>'PASTE_64_CHARACTER_HASH_FROM_MATCHING_CALLER');
END;
/
```

The [supplied caller](../sql/install/10_load_github.sql) already has the manifest hash filled in. Never put passwords, API keys or GitHub tokens into this call. The download is anonymous: Oracle documents public GitHub Raw file access with `credential_name => NULL` in its [supported URI formats](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/file-uri-formats.html).

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
| Table or package missing | Return to schema verification in the configuration/migration route. Do not install isolated raw packages or recreate the schema. |

A retry is supported. A previously successful matching manifest can reactivate its ready snapshot; a failed load can create a new snapshot on retry. Progress timestamps record completed checkpoints rather than a percentage or an estimated finish time. A browser timeout alone does not prove the database stopped; inspect the run before retrying. A killed or disconnected database session can leave a stale RUNNING record. If its status is uncertain, ask the administrator to check that specific run/session before retrying; do not delete the run log or clear a lock to force progress.

The acceptance script deliberately submits an incorrect manifest hash. In the recorded run, this left one expected `FAILED` row at `FETCHING_MANIFEST` with error `-20070`; the final correct retry was `SUCCEEDED` / `REUSED_READY_GRAPH`. Read the phase and test context as well as the status. An unexplained failed row should still be investigated.

For a 404/not-found response, check the owner, repository, full commit and published `data/load/` files. For a hash or count mismatch, obtain the unchanged caller and data from the same commit; do not edit hashes to suppress the failure. For network/package errors, ask the database administrator to check public HTTPS access and the documented execution grants. The dataset path does not require OCI model IAM changes.

## Verify the loaded graph

After `SUCCEEDED`, run [01_inspect.sql](../sql/queries/01_inspect.sql) and [verify_worksheet.sql](../integration-test/verify_worksheet.sql) as KCV_LAB with F5. Confirm a ready ACTIVE_GRAPH and the expected PASS message. Run [verify_source_packet_scope.sql](../integration-test/verify_source_packet_scope.sql) alone with F5 to confirm the source packet returns only evidence from the active graph. It creates and rolls back a temporary out-of-graph test passage without deleting historical evidence. Then continue with the [conversation-service and native checks](../labs/load-knowledge/load-knowledge.md#task-2-check-conversation-services). If guided setup already prepared the components, do not rerun standalone registration. These checks make no model inference calls.

The [native validation record](../references/github-dataset-validation.json) documents a successful ADB Serverless run on 23 November 2026 at dev commit `6eb868ee732f0ca3a0d8a6f9e68f838590d77b47`, with manifest SHA-256 `dae8efdcd9e99874c8dfc3d9a3ccaf4a861f76b3b5442f71f075a6d9b64ef8ad`. The importer, source tools, scenario and APEX backend packages compiled without errors. The observed load took 9.528 seconds and installed 834 sources, 762 passages, three contexts and 30,144 RDF triples, activating the new graph while preserving its predecessor. This timing describes one run, not a performance guarantee.

All four supplied native verification scripts passed, as did rejection of a second-session load while the importer lock was held. The final retry after lock release reused the ready graph in 0.181 seconds; both original and new graphs remained READY. The database reported Oracle AI Database 26ai version 23.26.4.1.0 and APEX 26.1.6. No GenAI inference or APEX browser/UI test was performed in this acceptance, and interruption during a native load remains untested. These results apply to the recorded dev code/data commit, separately from later documentation-only commits; they do not establish execution from a release commit. Public classification, source retrieval and editorial accuracy remain separate from verifying that a load completed.

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

For ORA-24247, ask ADMIN to inspect the effective host ACE for KCV_LAB and the exact destination. Restrict any needed exception to that destination rather than a wildcard grant. Timeout/DNS errors need route investigation; 403/404 errors need endpoint, publication and access checks. In the recorded temporary-instance acceptance, ROUTE_OUTBOUND_CONNECTIONS was unset and the GitHub download succeeded without network ACL changes. Other database/network configurations still need their own checks.

The [GitHub acceptance script](../integration-test/verify_github_dataset.sql) checks reuse, rejection of mutable refs, a wrong manifest hash, preservation of the active graph and retry. Run it after the first GitHub load succeeds, alongside [the source-scope check](../integration-test/verify_source_packet_scope.sql) for native acceptance. It makes public downloads and adds expected failure/success run-log records; it makes no model calls. Both scripts passed in the recorded native run. A separate two-session test held the importer lock for 30 seconds; the competing load returned `-20070`, preserved the active graph, and the first session released its lock. Forced interruption or a failure during native bulk loading was not tested.

## SQL fallback

If your environment cannot fetch public GitHub, use the supplied [numbered-parts guide](../sql/install/dataset-parts/README.md). Run complete SQL parts in numeric order using F5, one at a time; wait for success before continuing. If a part fails, fix the cause and restart from the first part. The combined [10_load_dataset.sql](../sql/install/10_load_dataset.sql) is an alternative for a client that can handle its size. Choose one dataset/load method; do not run both forms or load concurrently.

Building a different collection belongs on the dev branch. Release users do not need the Python extraction/build tools or the original research application.
