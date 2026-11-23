# Configure the Database and Model Access

## Introduction

Prepare database Java, a dedicated lab owner and access to a chat model. These are separate tasks: granting database permissions does not grant permission to call an OCI model.

Estimated Lab Time: 30–45 minutes plus restart, installation and IAM propagation time; planning estimate.

### Objectives

In this lab, you will:

- Check and, when needed, enable database Java.
- Create KCV_LAB with the required own-schema privileges.
- Configure an OCI credential and a working KCV_GENAI profile.

### Prerequisites

The database is Available; you can use ADMIN SQL Worksheet; the release SQL files are accessible; and an OCI administrator can provide model access if needed.

## Task 1: Check database Java

**Where:** SQL Worksheet. **Account:** ADMIN.

1. Run the following with F5:

<!-- include-sql: sql/admin/00_java_status.sql -->

```sql
<copy>
SELECT status, version FROM dba_registry WHERE comp_id='JAVAVM'
/
</copy>
```

[Script: 00_java_status.sql](../../sql/admin/00_java_status.sql)

<!-- /include-sql -->

2. Interpret the result. VALID means continue to Task 2. No rows means Java is not installed. LOADING means wait and check again; do not submit repeated enablement requests.

3. If Java is absent, this lab database's owner must intentionally enable it. This is database-wide and cannot be disabled afterwards. Run the block below once with F5, then return to the database's OCI details page and choose its Restart action.

<!-- include-sql: sql/admin/01_enable_java.sql -->

```sql
<copy>
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_FEATURE(feature_name=>'JAVAVM');
END;
/
</copy>
```

[Script: 01_enable_java.sql](../../sql/admin/01_enable_java.sql)

<!-- /include-sql -->

4. After the database returns to Available, sign back into ADMIN Worksheet and repeat the status query until it is VALID. Installation can continue after the restart. Check the runtime:

<!-- include-sql: sql/queries/00_java_runtime.sql -->

```sql
<copy>
SELECT dbms_java.get_jdk_version AS java_version FROM dual
/
</copy>
```

[Script: 00_java_runtime.sql](../../sql/queries/00_java_runtime.sql)

<!-- /include-sql -->

**Expected outcome:** JAVAVM is VALID and the runtime query returns a version string. The precise version can change with service maintenance. Installing Java on your Linux machine does not enable database Java. See [Oracle's Java enablement and verification instructions](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-oracle-java.html).

## Task 2: Create the lab owner and enable its Worksheet

**Where:** SQL Worksheet. **Account:** ADMIN.

1. Open [01_create_user_worksheet.sql](../../sql/admin/01_create_user_worksheet.sql). Copy DECLARE through END; into Worksheet, excluding the final slash, and choose **Run Statement**. Enter a private KCV_LAB_PASSWORD value in the bind dialog. The script accepts 12–64 characters from its documented set and refuses to reset an existing user.

2. Open [02_grants.sql](../../sql/admin/02_grants.sql), replace the editor contents with the complete script, and choose **Run Script (F5)**. This gives KCV_LAB own-object creation privileges, package execution and the quota set during user creation; it does not make the user a DBA.

3. Enable Database Actions for the new schema with F5:

<!-- include-sql: sql/admin/04_enable_database_actions.sql -->

```sql
<copy>
BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(p_enabled=>TRUE,p_schema=>'KCV_LAB',
    p_url_mapping_type=>'BASE_PATH',p_url_mapping_pattern=>'kcv_lab',p_auto_rest_auth=>TRUE);
END;
/
</copy>
```

[Script: 04_enable_database_actions.sql](../../sql/admin/04_enable_database_actions.sql)

<!-- /include-sql -->

4. Check that the user exists:

   ```sql
   <copy>
   SELECT username,account_status FROM dba_users WHERE username='KCV_LAB';
   </copy>
   ```

**Expected outcome:** the user is OPEN and the grants/route script finishes without errors. If the user already exists, stop and inspect the earlier attempt; do not drop it or reset its password to bypass the message.

## Task 3: Sign in as KCV_LAB and create its objects

**Where:** SQL Worksheet. **Account:** KCV_LAB, not ADMIN.

1. Open the same database's KCV_LAB Database Actions sign-in. For example, change only the schema segment of your own ADMIN Worksheet URL from `/ords/admin/_sdw/` to `/ords/kcv_lab/_sdw/`. Retain the rest of your own host/path. Sign in with the password from Task 2.

2. Run `SELECT USER FROM dual;` with Run Statement. Continue only when it returns KCV_LAB. Signing in as another database user may expire the earlier Worksheet login; sign back into ADMIN only when a later task asks for it.

3. Run each full file below with F5, in this order:

   | Order | File | Expected result |
   | --- | --- | --- |
   | 1 | [01_objects.sql](../../sql/schema/01_objects.sql) | KCV tables created, including KCV_SETTINGS |
   | 2 | [02_network.sql](../../sql/schema/02_network.sql) | KCV_NET RDF network created in this schema |
   | 3 | [03_tools.sql](../../sql/schema/03_tools.sql) | Read-only source/context/evidence functions compiled |
   | 4 | [06_dataset_import.sql](../../sql/schema/06_dataset_import.sql) | GitHub dataset importer and persistent load-progress log installed |

4. Check compilation:

   ```sql
   <copy>
   SELECT name,type,line,text FROM user_errors ORDER BY name,sequence;
   </copy>
   ```

**Expected outcome:** no rows from USER_ERRORS. The tables/network now exist, but source data and the model profile are not loaded yet. An empty Navigator may need its Refresh button; the query result is more useful than whether the tree has refreshed.

The dataset importer uses the `DBMS_CLOUD`, `DBMS_CRYPTO` and `DBMS_LOCK` execution grants supplied by ADMIN in Task 2. These support downloads, hash verification and one load at a time. Its public GitHub download needs no GitHub token, OCI signing key, resource principal or Object Storage bucket. The following OCI authentication task is for model inference, a separate connection.

## Task 4: Configure OCI model authentication

**Where:** OCI Console for identity permissions; KCV_LAB Worksheet for the stored credential.

1. Follow [authentication path A](../../docs/authentication.md#a-existing-oci-user-credentials) if using your own OCI user. Obtain your user OCID, tenancy OCID, registered API-key fingerprint and matching private key. OCIDs are Oracle resource identifiers. An OCI Console password or browser login is not an API signing key.

2. Ask the OCI administrator to confirm chat inference permission in the chosen compartment. If you cannot change policies, the administrator performs that part; creating the database credential will not fix missing IAM permission.

3. As KCV_LAB, create the credential using **Run Statement**, excluding the slash. Enter the bind values privately; the private-key value uses the key body without PEM BEGIN/END lines. Do not capture a screenshot containing the entered values.

<!-- include-sql: sql/schema/00_user_credential_worksheet.sql -->

```sql
<copy>
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name=>'OCI_USER_CRED',
    user_ocid=>:OCI_USER_OCID, tenancy_ocid=>:OCI_TENANCY_OCID,
    private_key=>:OCI_PRIVATE_KEY,
    fingerprint=>:OCI_FINGERPRINT);
END;
</copy>
```

[Script: 00_user_credential_worksheet.sql](../../sql/schema/00_user_credential_worksheet.sql)

<!-- /include-sql -->

4. If your organization instead uses the database's resource principal, follow [authentication path B](../../docs/authentication.md#b-resource-principal-alternative) completely: dynamic group, inference policy and ADMIN enablement. Skip this signing-key block and use `OCI$RESOURCE_PRINCIPAL` in the profile. Choose one path, not both.

**Expected outcome:** OCI_USER_CRED exists in KCV_LAB for path A, or the resource-principal path is configured for path B. No inference has been tested yet. Keep secrets out of saved SQL files, repository configuration, screenshots and chat.

## Task 5: Create and test the profile

**Where:** SQL Worksheet. **Account:** KCV_LAB.

1. Open [05_profile_worksheet.sql](../../sql/schema/05_profile_worksheet.sql) in a local text editor. Replace its NULL settings before copying it into Worksheet:

   | Variable | Value to enter |
   | --- | --- |
   | `l_region` | OCI inference region identifier, for example `us-chicago-1` if your model is available there |
   | `l_compartment` | OCID of the compartment authorized for inference |
   | `l_model` | Exact model name/identifier supported by Select AI for the intended on-demand model |
   | `l_credential` | OCI_USER_CRED for path A; OCI$RESOURCE_PRINCIPAL for path B |

2. For this workshop's validated on-demand path, a supported model name was used; do not assume a model OCID copied from the model catalog is interchangeable with that name. The existing validation used `openai.gpt-6.1-terra`, but that is not a guarantee of availability/support in your region or tenancy. Obtain the current supported selection from your facilitator or the [Select AI provider documentation](https://docs.oracle.com/en/database/oracle/oracle-database/26/selai/use-select-ai-ai-providers.html). Dedicated endpoints are outside this default profile recipe.

3. Run the edited profile script with F5. Then run [06_register_profile.sql](../../sql/schema/06_register_profile.sql) with F5. The first creates KCV_GENAI; the second writes that name into the existing KCV_SETTINGS table.

4. Test the profile with this small model call. This uses the inference service and can incur usage charges.

<!-- include-sql: sql/queries/00_test_genai.sql -->

```sql
<copy>
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt=>'Reply with a short greeting.',profile_name=>'KCV_GENAI',action=>'chat') AS response
FROM dual
/
</copy>
```

[Script: 00_test_genai.sql](../../sql/queries/00_test_genai.sql)

<!-- /include-sql -->

**Expected outcome:** a short greeting is returned. This verifies the credential/model path, not the graph. If an error occurs, check the region, model name, compartment, credential ownership and IAM permission using [Need help?](../need-help/need-help.md). Do not rebuild the schema or delete credentials to address an unexplained model error.

Continue to [Load knowledge and install the scenario](../load-knowledge/load-knowledge.md).

## Learn More

- [Detailed authentication choices](../../docs/authentication.md)
- Database setup reference (technical reference on the dev branch: `docs/setup.md`)

## Acknowledgements

- **Author** — Jason Lowe, standalone adaptation
- **Last Updated** — November 2026
