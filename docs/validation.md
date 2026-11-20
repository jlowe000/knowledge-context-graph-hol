# Validation and remaining acceptance

As of 18 November 2026, the executable artifact pipeline has been run on the authoring host and in Oracle Linux 8.10 / Bash 4.4 / Python 3.12.14 inside an isolated temporary directory in the existing oaiw-adb container. Python dependencies for that run were installed only in its temporary target directory. No database schema, existing app or global Python installation was changed.

The public-source cache was verified against exact hashes, selected pages were extracted, artifacts regenerated and **13 tests passed** under Oracle Linux. The generated graph hash matched the authoring-host build and the SQL Worksheet export. Tests exercise source/version identity, real page coverage, citation/quote rejection, explicit review transitions, context-sensitive selection, separate review/Claim types, native-script delimiters, private-source URL exclusion, reproducible RDF generation and SQL literal handling for untrusted source text.

## Serverless readiness observed through SQL Worksheet

The user authenticated to Database Actions and an initial read-only query confirmed Oracle AI Database 26ai 23.26.4.1.0 and valid AI packages, with no JAVAVM registry entry. After explicit user authorisation, ENABLE_FEATURE completed successfully and the user restarted the instance through OCI. Post-restart checks now confirm **JAVAVM VALID** and **Java runtime 11.0.33**. SEM_APIS resolves through its public synonym to **MDSYS.RDF_APIS (VALID)**; SEM_MATCH resolves to **MDSYS.RDF_MATCH (VALID)**. No lab users or objects have been created. Native graph creation/query and model/agent operations are not yet validated. The private endpoint and screenshots remain outside publishable files.

The earlier object-name-only query did not resolve synonyms and could not establish RDF package absence. A read-only recheck of the local container also found valid RDF_APIS/RDF_MATCH targets through synonyms, while its Java registry remains empty. The local minimum support decision is unchanged: full acceptance remains on Serverless. The readiness SQL and Python check resolve synonyms rather than assuming package names match public API names.

The output has 9 public source editions, 20 real page-aware passages, 17 editorial review examples, 3 fictional contexts and 547 triples. There are initially **0 accepted extracted claims**. Context assessments are a deterministic topic baseline, not AI recommendations or observed value.

## Not yet validated on ADB Serverless

- User creation, exact required grants and native RDF network setup.
- SQL/PLSQL compilation and native RDF snapshot bulk load.
- SEM_MATCH-based evidence retrieval under the dedicated lab user.
- OCI model credential/profile connectivity and extraction quality.
- Native agent registration, task routing and evidence citation behaviour.
- Optional OWL2RL inference.

These artifacts have been generated, not represented as successfully deployed. The opt-in integration tests are skipped until configured. Skips are not passes. Database tests require KCV_RUN_SERVERLESS_TESTS=1; model and agent calls additionally require KCV_RUN_MODEL_TESTS=1 and KCV_RUN_AGENT_TESTS=1 respectively. The agent test checks that citations refer only to the actual retrieved evidence, not merely that a response exists.

## PDF extraction caveat

pypdf recovered structural warnings while reading S06 (9 warnings), S07 (51) and S09 (11). Selected pages yielded text and have valid hashes/locators, but that does not prove layout/text fidelity. Warnings are retained in `work/extraction-report.json` and summarized in `generated/build-report.json`. The source-grounded review examples are not exhaustive visual validation or a gold-standard extraction benchmark.

## Re-run

```bash
bash scripts/build_artifacts.sh
export KCV_RUN_SERVERLESS_TESTS=1
.venv/bin/python -m unittest discover -s integration-test -v
```

The default verification route is to run `integration-test/verify_worksheet.sql` in the lab Worksheet. The Python flags above are optional automation and require the additional `requirements-db.txt` and private direct-connection configuration. Record target database release, package/grant readiness, model configuration, test outcomes and failures before declaring a fully validated release. Do not copy the old validation.json as proof of a new execution.
