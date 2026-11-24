# Private SQLcl connection for v2 development tests

This is a dev-only setup step. SQL Worksheet authentication is separate from SQLcl. Never put a database password, wallet, private connection string or saved connection export into Git or chat.

Use Oracle Linux/Bash for development, on a laptop or an OCI host. The SQLcl launcher also supports **Windows x64 with Git Bash in Windows Terminal**, using native Windows Java and `sql.exe`. Java and SQLcl run locally; no container or local database is required. The database target remains ADB Serverless. Installing the client tools and configuring a database connection are separate steps.

## Prepare and open local SQLcl

Open an interactive Bash terminal in the dev repository. On Oracle Linux, the launcher needs `curl`, `unzip`, `tar`, `gzip` and `coreutils`; if absent, install those utilities with `sudo dnf install curl unzip tar gzip coreutils`. Git Bash supplies these utilities on Windows. Use a Git Bash profile in Windows Terminal for the interactive Windows prompt; standalone MinTTY/winpty has not been validated. Neither Python nor a database wallet is required to install the tools.

Run:

```bash
bash scripts/open_dev_sqlcl.sh
```

The launcher:

1. Reuses Java 17, 21 or 25 from `JAVA_HOME` or `PATH`; otherwise downloads Oracle JDK 25 for the host architecture and verifies Oracle's SHA256 checksum before extraction.
2. Reuses SQLcl 26.2 or newer from `PATH`; otherwise downloads the pinned SQLcl **26.3.1.301.1413** ZIP and verifies Oracle's published SHA1 before extraction.
3. Prints the actual Java and SQLcl versions. Downloads and tool installations remain under ignored `work/local-tools/`; they are not included in either branch or covered by this project's MIT licence.
4. Opens SQLcl with `/nolog`, disables SQL command history, and uses a dedicated local connection store at `$HOME/.local/share/kcv/sqlcl`, outside the repository. It preserves the current directory for relative migration and APEXlang commands.

Expected outcome: a `SQL>` prompt with **no database connection**. There is no root installation, system `PATH` change or shell-profile edit. Do not run it in a terminal whose input is being recorded or shared. On a shared computer, protect the private directory with your operating system's user permissions; Git Bash's `umask` does not replace Windows access controls.

To prepare/check the tools without entering the prompt:

```bash
bash scripts/open_dev_sqlcl.sh --install-only
```

Subsequent runs reuse the local installation; they do not download again or silently update it. Java's `latest` URL is used only on a fresh installation, so the printed version is the actual patch level installed. For a deliberate refresh, choose a new private tool-cache directory with `KCV_TOOLS_DIR` and revalidate that toolchain. Failed downloads/extractions remain in ignored staging directories for diagnosis and are never used as completed installations.

The optional settings below are local environment variables, not repository configuration:

| Setting | Purpose |
| --- | --- |
| `KCV_TOOLS_DIR` | Absolute local directory for downloaded tools; default is ignored `work/local-tools/`. Keep custom locations outside tracked source directories. |
| `KCV_SQLCL_BIN` | Select an existing SQLcl executable explicitly. An invalid/older explicit selection fails instead of silently switching tools. |
| `KCV_SQLCL_HOME` | Absolute private connection-store directory outside this repository. |
| `JAVA_HOME` | Select an existing supported Java installation. |

Quote paths containing spaces. Git Bash accepts `/c/...` or `C:/...` paths for the directory settings. Run `bash scripts/open_dev_sqlcl.sh --help` for a concise reference.

Saved connections belong to the local store where they were created. **A connection saved in an earlier container or another SQLcl home will not appear here.** Configure it again privately below; the launcher does not inspect, copy or export another store.

**WSL and Windows Git Bash are separate environments.** A checkout opened as `/mnt/c/...` is using WSL. Its default `$HOME/.local/share/kcv/sqlcl` is in the Linux user's home, while Git Bash resolves the same expression under the Windows user's home. Sharing the checkout does not share saved connections. Open SQLcl from the same environment and Linux/Windows account where you saved the alias; a missing alias in the other store is not an ADB authentication failure. Oracle Linux under WSL uses the normal Bash command above and does not require a container.

### Downloads and tool versions

The official [SQLcl download page](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/) supplies the pinned ZIP, published checksum and Oracle Free Use licence. The [Oracle Java downloads page](https://www.oracle.com/java/technologies/downloads/) supplies JDK 25 platform archives, SHA256 checksums and Oracle No-Fee Terms and Conditions. Licence/notice files stay with the downloaded tools. The [SQLcl 26.2 release notes](https://www.oracle.com/tools/sqlcl/sqlcl-relnotes-26.2.html) list Java 17, 21 and 25 support.

The earlier Serverless migration/app acceptance used SQLcl 26.2.1.209.2118 with Java 21.0.12.1 on Oracle Linux 8.10. That historical test is not acceptance of every newer SQLcl/JDK combination. The native launcher checks tool startup; rerun the relevant migration/APEX checks when changing the toolchain.

On 24 November 2026, the native Windows/Git Bash launcher passed fresh Java/SQLcl download and checksum checks, cached-tool reuse, a disconnected interactive prompt, preserved working directory and `lb version` (Liquibase 4.33.0, extension 26.3.1.0). Installed versions were Java 25.0.5.1 and SQLcl 26.3.1.301.1413. Invalid options, repository-local credential stores and a fabricated bad Java checksum were rejected. All repository Bash scripts passed syntax checks. These Windows checks did not connect to ADB.

On the same date, the user completed local setup and saved a private connection in Oracle Linux under WSL. The launcher then passed a tool-reuse/version check there with Java 25.0.5.1 and SQLcl 26.3.1.301.1413. Using the documented alias from that Linux store successfully connected to ADB as ADMIN. Read-only checks confirmed the isolated v2 schema and app, 48 complete project migrations, the C2 identity-ready checkpoint, 49 Liquibase changesets with no active lock, zero invalid schema objects, and 834 sources/762 passages. The original app and valid JAVAVM remained present. No database objects or credentials were changed. This establishes local Linux connectivity and checkpoint health; it does not rerun migration execution, model responses or browser acceptance with the newer toolchain.

Java 25 emitted a JLine native-access warning before the Windows prompt during this test; SQLcl and `lb version` still completed successfully. This warning is separate from database authentication.

## Configure the temporary database privately

For an isolated test schema to be created on the temporary Serverless instance, save an ADMIN connection with the alias `KCV_V2_ADMIN`. Supply your actual connection identifier privately in the command below; omit the password so SQLcl prompts for it:

```sql
connect -save KCV_V2_ADMIN -savepwd ADMIN@<private_connection_identifier>
```

Use the database connection information supplied by OCI, not the Database Actions HTTPS URL. If your connection requires an ADB wallet, save it privately on this computer outside the project and add `-cloudconfig /private/path/wallet.zip` to the connection command. On Windows, use a native path such as `C:/private/wallet.zip` at the SQL prompt. Replace example paths with your actual private location. SQLcl prompts for required secrets; do not add them to the command line or a script.

`-savepwd` explicitly authorizes SQLcl to retain the connection credential in its private connection store for subsequent test commands. If you prefer not to save it, omit that flag and use an interactive authenticated session for each test run; the agent cannot assume unattended access in that case. Do not export or display the connection definition.

Verify the session without displaying connection details:

```sql
select user as connected_user from dual;
```

Expected result: `ADMIN` on the intended temporary test database. Tell the collaborator only that `KCV_V2_ADMIN` is ready and whether password saving was selected. If you already have an isolated developer schema and prefer to use it, provide its saved connection alias and schema name only; it needs the documented migration prerequisites.

Test setup must create/use a separately identified test schema and app, verify its scope before mutation, and preserve the existing `KCV_LAB` installation and JAVAVM. A saved ADMIN connection is for test bootstrap; application and migration checks run as the isolated schema owner. Native tests are not marked passed merely because SQLcl can connect.

## Save an isolated owner connection with an ADB wallet

For a test schema already approved to connect through ADMIN, use the explicit SQLcl proxy syntax below. An administrator must first grant `ALTER USER KCV_V2_TEST GRANT CONNECT THROUGH ADMIN` on the intended temporary database. This grant does not change the schema password or transfer any cloud credential.

Inside SQLcl in the same Oracle Linux environment as the launcher, replace the wallet path and TNS service alias with your private values:

```sql
connect -cloudconfig "/mnt/c/path/to/Wallet.zip" -save KCV_V2_OWNER -savepwd ADMIN[KCV_V2_TEST]@your_tns_service_name
```

Enter the **ADMIN password** at SQLcl's private prompt. Use the service alias from that wallet's `tnsnames.ora`, rather than a Database Actions URL. For Oracle Linux outside WSL, use that host's Linux wallet path. The brackets around `KCV_V2_TEST` are literal proxy syntax. Add `-replace` only when deliberately replacing an existing `KCV_V2_OWNER` saved connection.

Verify both identities:

```sql
select user, sys_context('USERENV','PROXY_USER') as proxy_user from dual;
```

Expected: `KCV_V2_TEST` and `ADMIN`. A later `connect -name KCV_V2_OWNER` must return the same identities before migrations run. `ALTER SESSION SET CURRENT_SCHEMA` alone does not establish an owner connection. Preserve the separate `KCV_V2_ADMIN` alias for administration. See Oracle's [SQLcl proxy connection syntax](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/22.4/sqcug/accessing-databases.html).
