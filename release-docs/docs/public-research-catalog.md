# Explore the public research catalogue

The sample graph includes research references admitted through recorded access checks or the [manually approved public-source rules](../references/public-source-policy.json). Each item connects its public URL and versioned catalogue record to topic and domain classifications. The release includes this metadata in JSON, RDF and the prepared SQL dataset, so learners can inspect the collection without running the research tools. A manual public classification and an actual access-test result are recorded separately.

The existing `S` sources retain their selected PDF pages. The added `R` sources now have actual extracted passages where readable public content was obtained. Dev keeps those bodies in ignored local files; release supplies AI-assisted editorial paraphrases of selected passages. Remaining references are explicitly **catalogue only**. Each build computes coverage from its supplied text. Web pages and repository files use section or line locators, with no invented PDF page number. See the [content ingestion record](../references/content-ingestion-checks.json) and [build report](../generated/build-report.json) for exact counts.

## Task 1: Inspect the sources and access record

1. Download the release files and open [public-catalog.html](../generated/public-catalog.html) in your browser. Search by title, topic or source ID; combine the topic, domain, format and evidence-coverage filters. The page runs locally, with no server or external libraries. GitHub's file view shows its HTML source; open the downloaded file to use its filters.
2. Open [public-catalog.json](../data/public-catalog.json) for the underlying metadata. For an item, inspect its title, public URL, content format, version hash, classification, access result, topics and limitations. `classification_status="manually marked as public"` identifies a decision under the recorded rules. `access_verified=true` identifies successful anonymous verification; `false` preserves an unverified or failed result.
3. Open [public-access-checks.json](../references/public-access-checks.json). Review the actual check, timestamp and any `reason` for failure; the catalogue metadata calls that field `verification_error`. A successful result means the resource was reachable through an unauthenticated request at that time. A manually public reference can remain included when a check fails or its content type is unsupported; that result is not relabelled as successful verification. When `version.hash_basis="catalogue_metadata"`, the hash identifies the metadata record because source content was not retrieved. It is not a source-body hash.
4. Open the public URL in a browser where you are not signed into Oracle. Confirm that you reach the intended content. A publicly accessible landing page does not establish that every linked download, video or service is also accessible.

**Expected outcome:** you can distinguish the public-classification decision, observed accessibility, hash basis and material actually supplied to the lab. The catalogue does not bundle full source documents or extracted bodies. A public classification does not transfer copyright or change the source owner's licence.

## Task 2: Browse the active catalogue in SQL Worksheet

**Where:** Database Actions SQL Worksheet. **Account:** KCV_LAB. Complete the [dataset deployment](fresh-serverless-deployment.md) first. These read queries make no model request.

Run the following with **Run Statement**. It lists one row per topic for each added research item in the active graph snapshot. Multiple rows for a source are expected.

```sql
SELECT j.source_id, j.title, j.topic, j.source_url, j.access_status, j.access_verified
FROM kcv_graph_sources gs,
 JSON_TABLE(gs.metadata_json, '$' COLUMNS (
  source_id VARCHAR2(32) PATH '$.id', title VARCHAR2(1000) PATH '$.title',
  source_url VARCHAR2(4000) PATH '$.url', access_status VARCHAR2(40) PATH '$.access_status',
  access_verified VARCHAR2(5) PATH '$.access_verified', NESTED PATH '$.topics[*]' COLUMNS (topic VARCHAR2(200) PATH '$'))) j
WHERE gs.graph_name=(SELECT setting_value FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH')
 AND j.source_id LIKE 'R%'
ORDER BY j.source_id, j.topic;
```

To narrow the results, add a predicate before `ORDER BY`, such as `AND LOWER(j.topic) LIKE '%cloud%'`. Topic assignments are editorial navigation aids. They do not establish that a source endorses a product, proves an outcome or applies to your organisation.

**Expected outcome:** you can find public material by topic and follow its original URL. Reading this metadata does not require downloading the source or sending it to a model.

## Task 3: Follow the relationships with SPARQL

Read the active graph name:

```sql
SELECT setting_value AS graph_name
FROM kcv_settings WHERE setting_key='ACTIVE_GRAPH';
```

Replace `KCV_G_REPLACE` below with that returned name, keeping the single quotes. Run the statement as KCV_LAB. The fixed SPARQL joins content to topic, source version and public URL, selecting the explicit catalogue-only coverage flag.

```sql
SELECT item,title,topic_label,ver,url FROM TABLE(SEM_MATCH(
 'PREFIX k: <https://example.org/kcv/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
 SELECT ?item ?title ?topic_label ?ver ?url WHERE {
  ?item rdfs:label ?title ; k:coversTopic ?topic ; k:hasVersion ?ver .
  ?topic rdfs:label ?topic_label .
  ?ver k:sourceURL ?url ; k:evidenceCoverage "catalogue_only" .
 } ORDER BY ?item ?topic_label LIMIT 50',
 SEM_MODELS('KCV_G_REPLACE'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,
 USER,'KCV_NET'));
```

**Expected outcome:** you see actual graph bindings for the source-topic-version relationship. The limit keeps the result manageable; it does not describe the catalogue's total size. Change it deliberately or narrow the topic when exploring further.

## Task 4: Understand the answer boundary

The chatbot's evidence tool follows `content → version → passage`. Eligible inspected passages can now enter that path. Dev retains all extracted chunks for authoring, but graph-scoped `retrievalEligible` flags limit answers to the selected editorial basis. Release summary passages are eligible. Catalogue-only versions have no `hasPassage` relationship. A matching title or topic alone does not make a source answer evidence, and the topic selector excludes sources without eligible passages.

Use the catalogue to choose a source for review. Open the cited page, section or file lines and compare the response with that content. Release summaries identify their source edition, basis-passage IDs and text hashes. They are AI-assisted paraphrases, not independently fact-checked claims or exhaustive document summaries. Keep preview, availability and regional qualifications in view. No summary is automatically accepted as a Claim node.

Selection is deterministic: the original curriculum sources come first, followed by added sources in ID order, with bounded locators and six passages per tool call. Refining topics can select new research sources; merely rewording the question does not implement semantic search. The original Alex exercises retain their priority, while Casey can also receive additional matching research after the S10 overview/disclaimer pages.

To inspect real answer-eligible paths, replace the graph placeholder as above:

```sql
SELECT item,passage,url FROM TABLE(SEM_MATCH(
 'PREFIX k: <https://example.org/kcv/>
 SELECT ?item ?passage ?url WHERE {
  ?item k:hasVersion ?v . ?v k:hasPassage ?passage .
  ?passage k:retrievalEligible true ; k:sourceURL ?url .
 } ORDER BY ?item ?passage LIMIT 30',
 SEM_MODELS('KCV_G_REPLACE'),NULL,NULL,NULL,NULL,NULL,NULL,NULL,USER,'KCV_NET'));
```

For an app exercise after deployment, start a new conversation, refine the topics toward **Multicloud** or **Security and patching**, preview and apply the change, then ask what the available material supports. Open Evidence and the response explanation: added sources have `R` identities, selected summaries, public locators and actual graph paths. Compare a source statement with your proposed relevance; record a clarification, validation or discussion outcome as feedback. Topic assignments are editorial and broad categories can still return material requiring further refinement.

**Expected outcome:** you can explain the difference between discovering a source and grounding an answer in inspected source content. The catalogue extends the graph's discoverable material while preserving the existing evidence boundary.

## Freshness and validation

The catalogue reflects the supplied research-report snapshot, public-source rules and access-test timestamps. Matching rules admit catalogue references as **manually marked as public**, including references with failed or unsupported access checks. Those entries retain their actual result and use a metadata hash when source content was not retrieved. Other unresolved conflicts remain in a `to_be_reviewed` array outside the Git repositories; prohibited source destinations remain excluded. Redirects, source editions and access requirements can change after checking.

The private conflict report retains the `conflicts`, `manually_marked_public` and `to_be_reviewed` arrays, with review items ordered by site and ID. It is not distributed with the release. The public [policy file](../references/public-source-policy.json) records the approved URL scopes and title condition.

Local artifact checks validate the catalogue's graph relationships, source references and release packaging. Native ADB execution of a newly expanded catalogue remains a separate deployment check. Follow [validation status](scenario-validation.md) for the results actually recorded for this release.

## Publisher and video review scope

The public rules include `www.oracle.com`, `livelabs.oracle.com`, `community.oracle.com` and `docs.oracle.com`, alongside the previously approved GitHub and Oracle AI World session paths. A `www.youtube.com` reference is manually public only when its research-catalogue title contains **Oracle AI World 2026** (case-insensitive, with normalized whitespace). The title match is recorded as a catalogue-based decision; page access does not establish video playback. Other YouTube titles remain in review.

Industry and third-party publications outside the explicitly approved scopes are withheld in the private `to_be_reviewed` array, even if their URLs respond successfully. Existing verified official Oracle publications and established Oracle repositories are retained. Partner participation in an approved public event source does not override that source's explicit public rule. See [public-source-policy.json](../references/public-source-policy.json) for the precise rules.
