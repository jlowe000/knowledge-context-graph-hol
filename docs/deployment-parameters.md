# Parameters used in deployment examples

Deployment examples use named tokens so the instructions can be reused for another product version or build. **Replace every `<TOKEN>` with your selected value before running a command.** The angle brackets are documentation notation: they are not Bash variables, SQLcl substitutions or Worksheet bind variables. Do not paste unresolved tokens into a terminal.

Choose the target once and use it consistently through schema creation, workspace creation, import and verification. Keep the completed target details private. A product version, deployment build number and APEX application ID are separate values.

| Token | Value to supply |
| --- | --- |
| `<KCV_VERSION>` | The full `major.minor.patch` value in this checkout's [VERSION](../VERSION). |
| `<KCV_MAJOR>` | The major component of that version. |
| `<KCV_BUILD>` | The next unused build number for that major version on the database, padded to at least three digits. Start at `001`; do not reuse retired numbers. |
| `<KCV_SCHEMA>` | `KCV_V<KCV_MAJOR>_<KCV_BUILD>`, after replacing its two component tokens. Use an uppercase name within the bootstrap's 30-character limit. |
| `<KCV_WORKSPACE>` | The same value as `<KCV_SCHEMA>` for the dev naming convention. |
| `<KCV_OWNER_CONNECTION>` | The schema name followed by `_OWNER`; save this alias in your private SQLcl connection store. |
| `<KCV_ADMIN_CONNECTION>` | Your existing saved ADMIN alias. Its name does not need to change when the product version changes. |
| `<KCV_APP_ALIAS>` | `KCV-V<KCV_MAJOR>-<KCV_BUILD>`, with its component tokens replaced. |
| `<KCV_APP_ID>` | An explicitly selected unused numeric APEX ID for a new native import, or the verified existing ID for an in-place upgrade. It is not derived from the build number. The new-app Worksheet wrapper allocates this ID itself. |
| `<KCV_BUILD_ROOT>` | The absolute output directory for this build's generated files. It can be outside the repository and `work/`. |
| `<WALLET_ZIP>`, `<TNS_SERVICE>` | Your private wallet ZIP path and a service alias from its `tnsnames.ora`. Never publish populated connection examples. |
| `<KCV_NATIVE_EXPORT_DIR>`, `<KCV_SQL_EXPORT_DIR>` | The selected absolute native APEXlang and SQL export output directories. |

Replacement instructions use `<KCV_REPLACEMENT_SCHEMA>`, `<KCV_REPLACEMENT_WORKSPACE>`, `<KCV_REPLACEMENT_OWNER_CONNECTION>` and `<KCV_REPLACEMENT_APP_ALIAS>` for the separately allocated build. Derive these from its own new build number. `<KCV_RETIRED_OWNER_CONNECTION>` means only the saved alias of a build whose retirement has already been verified. Do not reuse the current target's alias as a retirement token.

## Read the product version from source

In Bash, from the repository root:

```bash
KCV_VERSION="$(tr -d '\r\n' < VERSION)"
KCV_MAJOR="${KCV_VERSION%%.*}"
printf 'Product version: %s; major: %s\n' "$KCV_VERSION" "$KCV_MAJOR"
```

These are real Bash variables. They help determine the token values; SQLcl does not inherit them as SQL variables, and JSON receipts do not expand them. Build guides may define other real Bash variables such as `$KCV_BUILD_ROOT`; use them only after the guide's assignment step.

## SQL and connection templates

Keep SQL string quotes around a substituted name. A SQLcl example declares its bind before assigning it:

```sql
VARIABLE KCV_DEV_SCHEMA VARCHAR2(30)
EXEC :KCV_DEV_SCHEMA := '<KCV_SCHEMA>';
```

Here `<KCV_SCHEMA>` must be replaced manually; `:KCV_DEV_SCHEMA` is the actual SQLcl bind. Worksheet Run Statement instead prompts for the bind names used by its supplied script. Do not substitute passwords or keys into documentation templates.

Proxy connection templates retain literal square brackets:

```text
connect -cloudconfig "<WALLET_ZIP>" -save <KCV_OWNER_CONNECTION> -savepwd ADMIN[<KCV_SCHEMA>]@<TNS_SERVICE>
```

Replace the angle-bracket tokens, keep `ADMIN[...]`, and enter the ADMIN password at SQLcl's private prompt. Shell and SQLcl command templates with unresolved tokens use `text` fences. SQL/PLSQL templates retain `sql` highlighting and their required string quotes; they still need token replacement.

## Values that remain explicit

Migration IDs, supported upgrade baselines, compatibility versions, pinned source URLs/hashes and historical test results identify a particular contract or observation. Keep those literal. Changing `VERSION` or a documentation token does not make a new schema, app export, receipt or upgrade path valid; follow the build and validation process for that version.

See [fresh dev deployment](fresh-dev-deployment.md), [connection setup](dev-connection-setup.md), [build lifecycle](dev-build-lifecycle.md) and [APEX source build](apex-build-process.md) for the steps that consume these values.
