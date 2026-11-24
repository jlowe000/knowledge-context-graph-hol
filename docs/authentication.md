# OCI Generative AI authentication

Choose one path. Both use the same `KCV_GENAI` profile and the same lab code. A database grant permits package use; OCI IAM separately authorizes inference. The user-key path is the default in the example profile and optional automation configuration.

**Current dev owner:** the account names and Worksheet prompts below describe the v1 KCV_LAB setup. For a new v2 schema, complete the [fresh dev bootstrap and private owner connection](fresh-dev-deployment.md) first. Its parameterized bootstrap supplies the package grants; do not run hard-coded KCV_LAB administration scripts against a different target. Migrations create KCV_SETTINGS. A NO AUTHENTICATION owner uses SQLcl proxy access, not a direct Worksheet password login; SQLcl does not automatically open Worksheet bind dialogs. Create the signing-key credential privately in the actual new owner. The fresh rehearsal rejected a schema-qualified credential name with ORA-20010 during profile creation, before any model call; the guide records that finding rather than treating cross-schema reuse as an established alternative.

| Choice | OCI identity making model calls | Database credential | Dynamic group |
| --- | --- | --- | --- |
| User API signing key | Your OCI user | `OCI_USER_CRED`, owned by KCV_LAB | Not required |
| Resource principal | This Autonomous Database | `OCI$RESOURCE_PRINCIPAL` | Required for this documented path |

## A. Existing OCI user credentials

In Worksheet's bind dialog, match each value to its **field name**, not its position. `OCI_FINGERPRINT` is the short fingerprint shown for the registered public key, not the private-key body or a file path. `OCI_PRIVATE_KEY` takes the matching unencrypted key body without PEM BEGIN/END lines. Use Run Statement on the complete BEGIN–END block without the slash. If a bind is reported undeclared, reopen that complete block through Run Statement. A fingerprint-length error is an input-field check; inspect the field privately rather than sharing the entered values.

Use this path if your OCI user already has inference permission in the intended compartment. Console/SSO access alone does not supply a database credential: this path requires an **OCI API signing key**, rather than your Console password, an OCI auth token or a Generative AI bearer API key. Oracle documents the [signing-key credential parameters](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/dbms-cloud-subprograms.html).

1. In your OCI user's API Keys settings, identify an existing registered signing key or register a public key according to your organisation's process. You need the user OCID, tenancy OCID, matching fingerprint and corresponding private key. If you already use an OCI CLI configuration, its `user`, `tenancy` and `fingerprint` fields supply the first values; `key_file` points to the private key, not a value the database can read.
2. Confirm your user group has inference access in the compartment you will put in the profile. Reuse existing permissions where sufficient. An administrator can grant chat inference with a compartment-scoped policy such as the following, replacing the placeholders and using your identity-domain-qualified group name where applicable:

```text
Allow group <domain>/<group-name> to use generative-ai-chat in compartment <inference-compartment>
```

This lab calls chat models. Model discovery in the Console may separately require `inspect generative-ai-model`; dedicated endpoints or other operations may need additional permissions. See [Generative AI model permissions](https://docs.oracle.com/en-us/iaas/Content/generative-ai/models-api-permissions.htm). Permission for a different region/compartment/model does not establish that this profile's selection will work.

3. As ADMIN, run the current [grants script](../sql/admin/02_grants.sql), which includes direct `DBMS_CLOUD` execution access. If you ran an earlier version, rerun this additive grants script.
4. As **KCV_LAB**, create the credential below. Select `BEGIN` through `END;`, excluding `/`, and use **Run Statement** so Worksheet prompts for bind values. Supply the private key body without the PEM BEGIN/END lines; passphrase-protected keys are unsupported. Keep the key out of saved scripts, Git, screenshots and chat. Use an approved private credential-entry interface if your environment does not permit secret values in Worksheet bind dialogs.

<!-- include-sql: sql/schema/00_user_credential_worksheet.sql -->

```sql
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name=>'OCI_USER_CRED',
    user_ocid=>:OCI_USER_OCID, tenancy_ocid=>:OCI_TENANCY_OCID,
    private_key=>:OCI_PRIVATE_KEY,
    fingerprint=>:OCI_FINGERPRINT);
END;
/
```

[Script: 00_user_credential_worksheet.sql](../sql/schema/00_user_credential_worksheet.sql)

<!-- /include-sql -->

The credential is stored in the database, so treat this as granting the lab schema use of that OCI identity. See Oracle's [credential storage documentation](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-manage-credentials.html). An existing `OCI_USER_CRED` is not overwritten; inspect its ownership and intended use first. A credential in ADMIN's schema is not the lab user's credential.

5. Skip the resource-principal script and dynamic group steps. Continue with the common profile step below.

## B. Resource principal alternative

This path uses the database identity. An OCI IAM administrator performs the first two steps in the Console; they cannot be performed in SQL Worksheet.

1. Create a dynamic group, for example `KCV_ADB_GENAI`, whose matching rule selects only this database:

```text
resource.id = '<autonomous-database-OCID>'
```

Use the database resource OCID from its OCI details, not its database name or compartment OCID. Oracle explains identity-domain placement and matching rules in [resource-principal prerequisites](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/resource-principal.html).

2. Give that dynamic group chat inference access to the compartment used by the profile. Use the appropriate domain-qualified name for your tenancy:

```text
Allow dynamic-group <domain>/KCV_ADB_GENAI to use generative-ai-chat in compartment <inference-compartment>
```

Allow IAM changes to propagate before testing. These examples authorize inference rather than management of models or clusters; additional operations require corresponding permissions.

3. As ADMIN, run [03_resource_principal.sql](../sql/admin/03_resource_principal.sql). Its copyable block is in the [setup guide](setup.md#oci-model-authentication).
4. In the profile script, change `l_credential` to `'OCI$RESOURCE_PRINCIPAL'`. Do not create `OCI_USER_CRED` for this path. See [Select AI provider authentication](https://docs.oracle.com/en/database/oracle/oracle-database/26/selai/use-select-ai-ai-providers.html).

## Common profile and connection check

Edit [05_profile_worksheet.sql](../sql/schema/05_profile_worksheet.sql) locally: set `l_region`, `l_compartment` to the inference compartment OCID, `l_model` to the exact model name/identifier supported by Select AI for the chosen region and access mode, and `l_credential` to the chosen name. Run as KCV_LAB using **Run Script (F5)**. The script creates `KCV_GENAI` independently of lab tables; it does not silently replace an existing profile. It builds attributes with `JSON_OBJECT_T` and serializes to CLOB before the package call. No secret values belong in the profile script.

After the profile exists and the lab tables have been created, register its name for extraction and agents. On current v2, the tables come from migrations; on a matching v1 checkout, they come from `01_objects.sql`. Run the following in the actual lab-owner session, using **F5** in Worksheet or the linked script with SQLcl `@`:

<!-- include-sql: sql/schema/06_register_profile.sql -->

```sql
MERGE INTO kcv_settings t USING (SELECT 'AI_PROFILE' setting_key FROM dual) s
 ON(t.setting_key=s.setting_key) WHEN MATCHED THEN UPDATE SET t.setting_value='KCV_GENAI'
 WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES('AI_PROFILE','KCV_GENAI')
/
COMMIT
/
```

[Script: 06_register_profile.sql](../sql/schema/06_register_profile.sql)

<!-- /include-sql -->

If an earlier version failed with `PLS-00684` for the inline `JSON_OBJECT(... RETURNING CLOB)` and `ORA-00942` for `KCV_SETTINGS`, these are separate compile errors. The block did not execute. Use the corrected profile script; defer registration until the tables exist. Do not drop credentials or recreate an existing schema to fix these errors.

Optionally run the following as KCV_LAB. **This invokes the model and can incur inference charges.** A greeting verifies access; it does not validate the graph, extraction quality or agents.

<!-- include-sql: sql/queries/00_test_genai.sql -->

```sql
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt=>'Reply with a short greeting.',profile_name=>'KCV_GENAI',action=>'chat') AS response
FROM dual
/
```

[Script: 00_test_genai.sql](../sql/queries/00_test_genai.sql)

<!-- /include-sql -->

If it fails, inspect the reported error: check schema credential ownership, matching signing key/fingerprint, effective user-group or dynamic-group policies, compartment, supported model/region and database outbound connectivity. Authentication and inference remain unvalidated until a real call succeeds.

### JSON syntax error when exercising the profile

`ORA-20000` wrapping `ORA-40441` during `DBMS_CLOUD_AI.GENERATE` means JSON parsing failed inside the call. The stack alone does not identify the malformed input or response, and does not prove a signing-key or IAM failure. This is different from the profile-creation compile errors above. Do not drop the credential or rebuild the schema based on this error.

First inspect selected profile attributes, without making another model call:

<!-- include-sql: sql/queries/00_inspect_ai_profile.sql -->

```sql
SELECT attribute_name, attribute_value
FROM user_cloud_ai_profile_attributes
WHERE profile_name='KCV_GENAI'
  AND attribute_name IN ('provider','region','model','oci_apiformat','credential_name')
ORDER BY attribute_name
/
```

[Script: 00_inspect_ai_profile.sql](../sql/queries/00_inspect_ai_profile.sql)

<!-- /include-sql -->

For this lab's on-demand path, use the supported Select AI model name/identifier, not an assumed model-catalog OCID. The working deployment used `openai.gpt-6.1-terra`; availability and support must be checked for your tenancy and region. Check the exact identifier, region and whether the selection is an on-demand model or a dedicated endpoint. Oracle's [Select AI OCI examples](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/select-ai-examples.html) show `oci_apiformat` values `GENERIC` for Meta Llama and `COHERE` for Cohere. A missing or incorrect model API format is a configuration item to investigate, not a confirmed explanation for every `ORA-40441`. Match the selected model and current Select AI support before changing attributes; do not guess a format for another model family.

When retiring the temporary lab, drop only its dedicated stored credential after checking dependencies. Removing the stored copy does not revoke your OCI API key. Revoke an OCI key only if it was created solely for this lab and is no longer used elsewhere; see [cleanup](cleanup.md).
