# Complete deployment readiness

Both v2.1.0 experiences use the same backend/readiness contract. **This package's four APEX-led and SQL-first prepared-environment routes passed within their recorded scopes**; see [validation](scenario-validation.md). Installing objects, importing the app and enabling learners are separate steps.

## Required checks

| Check | Expected state |
| --- | --- |
| Database objects | Matching receipts, physical objects and valid program source |
| Graph network | Verified owner-private RDF network |
| Model profile | Intended owner-local credential and supported configuration |
| Model connection test | Explicit successful setup test for the current profile |
| Conversation components | Required teams/tasks/tools registered |
| Public collection | Approved collection is READY |

Six READY rows can still mean learning is paused. **Enable learning** is deliberate. A manual DBMS_CLOUD_AI greeting does not record the setup API's model-test receipt. Optional semantic search is not a seventh required check.

## APEX guided setup

Sign into the running app as an authorised **APEX workspace administrator**. Learners and developer-only accounts cannot invoke setup. Each action checks the owner/app/workspace binding.

| Action | When to use it | Expected outcome |
| --- | --- | --- |
| Prepare graph network | Network is not ready | Creates/verifies the owner-private network |
| Create local OCI credential | No suitable owner-local credential exists | Creates only OCI_USER_CRED; never replaces a name |
| Save model configuration | Profile is missing or an intentional change is approved | Selects credential name, region, compartment and supported model name; no chat request |
| Test model connection once | Current connection check is not READY | One fixed greeting/test result; may incur inference charges |
| Prepare conversation components | Registrations are missing | Registers/verifies without deleting conversations |
| Load approved public collection | No ready collection, or an approved separate update | Verifies the pinned public manifest/content and builds/activates the graph |
| Enable learning | All six checks READY | Ready for learners; My Contexts/Sample Contexts enabled |

**Refresh readiness** is read-only and makes no model call. An explicit new Test click is a new request. Setup changes pause learning until explicitly enabled. On upgrade retain ready resources; do not save/reload them just to click every button.

### Create a credential privately, if needed

Agree the [OCI identity/IAM](authentication.md) first. Its public signing key must already be registered. The form does not create OCI users, register keys or grant permissions.

Enter user OCID, tenancy OCID, registered fingerprint and matching unencrypted **Private key body** in the dedicated masked fields. Use only the base64 body, without PEM BEGIN/END lines or an OCI_API_KEY label. The submitted key field allows at most 4,000 bytes including whitespace; never truncate a key to fit. Submit once. Creation makes no model call; the fields are designed to clear after submission/navigation.

Select the stored credential name under Configure model access, then save/test the intended profile. Never put a key into profile fields, chat, URLs or shared diagnostics. An existing name is retained; repair is a separate facilitator action. Resource principal is a separately prepared alternative in [authentication](authentication.md).

Earlier r13 tests covered bounded input clearing, canaries and recovery, not every possible audit/request log. Review local logging controls before real-key entry. No key is distributed in the package.

## SQL-first owner binding

After schema verification and matching app import, sign into the **actual project owner's Worksheet**. ADMIN with CURRENT_SCHEMA changed is not an owner login. Open [03_bind_deployment_owner.sql](../sql/install/03_bind_deployment_owner.sql), select its complete outer block without the trailing slash and use **Run Statement**.

Supply the nonsecret `KCV_APPLICATION_ID` from import and exact `KCV_WORKSPACE`. Do not run the maintained template under sql/schema; the generated installer includes verification.

Expected: `KCV_DEPLOYMENT_BINDING=READY_FOR_SETUP`. It verifies the contract/native mapping and pauses learning. An exact repeat returns `ALREADY_VERIFIED` without changing maintenance. A different binding or unresolved active work requires review, not a forced reassignment.

## SQL-first final readiness

Use **Run Statement** as the owner. These are alternatives to installer-UI calls, not extra requests after a successful UI test.

```sql
SELECT KCV_DEPLOY.STATUS_JSON FROM dual;
```

Complete missing runtime setup using the [SQL catalogue](sql-catalogue.md). When the intended profile is ready but its test is not, run this once; it makes a real model request:

```sql
BEGIN
  KCV_DEPLOY.TEST_MODEL(LOWER(RAWTOHEX(SYS_GUID())));
END;
```

Refresh status. When all required checks are READY, explicitly enable learning:

```sql
BEGIN
  KCV_DEPLOY.ENABLE_LEARNING(LOWER(RAWTOHEX(SYS_GUID())));
END;
```

Every execution creates a new request token. Do not automatically rerun after a timeout; inspect progress first. Reusing an old successful enable token cannot clear maintenance introduced later.

Verify status, then [test the learner experience](../labs/deploy-explorer/deploy-explorer.md#task-5-verify-the-learner-experience). Without the optional embedding model, expect **Keyword matches only: the local semantic search model is unavailable.** Chat still needs its configured inference model. See [recovery](deployment-recovery.md) for incomplete required checks.
