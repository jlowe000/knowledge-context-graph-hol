#!/usr/bin/env bash
# Native client only. Tool archives are ignored; connection credentials stay private.
set -euo pipefail
umask 077

usage() {
  cat <<'EOF'
Usage: bash scripts/open_dev_sqlcl.sh [--install-only]

Reuse compatible local Java and SQLcl, downloading missing tools from Oracle.
Then open SQLcl with history disabled and /nolog (no database connection).
Supported hosts: Oracle Linux x64/ARM64; Windows x64 with Git Bash in Windows Terminal.
--install-only    Prepare tools and print versions without opening the SQL prompt.
-h, --help        Show this help.

Optional environment variables:
  KCV_TOOLS_DIR   Absolute tool-cache directory (default: repo/work/local-tools).
  KCV_SQLCL_BIN   Explicit local SQLcl executable; must be SQLcl 26.2 or newer.
  KCV_SQLCL_HOME  Absolute private store outside the repo
                  (default: $HOME/.local/share/kcv/sqlcl).
  JAVA_HOME      Existing Java 17, 21 or 25 installation; PATH is also checked.

No container, root install, shell-profile edit or database login is required.
Downloaded tools retain their own licences. See docs/dev-connection-setup.md.
EOF
}
fail() { printf 'SQLcl setup: %s\n' "$1" >&2; exit 2; }
note() { printf '%s\n' "$1" >&2; }
kcv_install_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-only) kcv_install_only=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail 'Unknown option. Use --help for usage.' ;;
  esac
done

kcv_platform='linux'
kcv_arch=$(uname -m)
case "$(uname -s)" in
  Linux)
    [[ -r /etc/os-release ]] || fail 'Oracle Linux is required for the Linux route.'
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == ol ]] || fail 'Use Oracle Linux for the supported Linux workflow.'
    case "$kcv_arch" in x86_64) kcv_arch=x64 ;; aarch64) ;; *) fail 'Unsupported Linux architecture.' ;; esac ;;
  MINGW*|MSYS*)
    [[ "$kcv_arch" == x86_64 ]] || fail 'The Git Bash route requires Windows x64.'
    kcv_platform=windows; kcv_arch=x64 ;;
  *) fail 'Use Oracle Linux Bash or Windows x64 Git Bash.' ;;
esac

absolute_path() {
  local path="$1"
  if [[ "$kcv_platform" == windows ]]; then path=$(cygpath -u "$path"); fi
  [[ "$path" == /* ]] || fail 'Tool/store paths must be absolute.'
  realpath -m -- "$path"
}
kcv_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
kcv_tools=$(absolute_path "${KCV_TOOLS_DIR:-$kcv_repo/work/local-tools}")
kcv_store=$(absolute_path "${KCV_SQLCL_HOME:-$HOME/.local/share/kcv/sqlcl}")
# A separate store prevents credentials from entering this checkout, even when
# the caller selects a custom path. Fold case for Windows path comparisons.
kcv_store_check="$kcv_store"; kcv_repo_check="$kcv_repo"
if [[ "$kcv_platform" == windows ]]; then
  kcv_store_check="${kcv_store_check,,}"; kcv_repo_check="${kcv_repo_check,,}"
fi
case "$kcv_store_check/" in "$kcv_repo_check/"*) fail 'KCV_SQLCL_HOME must be outside the repository.' ;; esac

download() {
  command -v curl >/dev/null 2>&1 || fail 'Install curl, then retry (Oracle Linux: sudo dnf install curl unzip tar gzip coreutils).'
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
    --connect-timeout 30 --max-time 1200 --retry 2 --output "$2" "$1"
}
need_tool() { command -v "$1" >/dev/null 2>&1 || fail "Install $1, then retry (Oracle Linux: sudo dnf install curl unzip tar gzip coreutils)."; }

java_compatible() {
  local info major
  info=$("$1" -version 2>&1) || return 1
  major=$(printf '%s\n' "$info" | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -n 1)
  [[ "$major" == 17 || "$major" == 21 || "$major" == 25 ]]
}
kcv_java=''
if [[ -n "${JAVA_HOME:-}" ]] && java_compatible "$JAVA_HOME/bin/java"; then
  kcv_java="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1 && java_compatible "$(command -v java)"; then
  kcv_java=$(command -v java)
fi
if [[ -z "$kcv_java" ]]; then
  kcv_java_dir="$kcv_tools/jdk-25-$kcv_platform-$kcv_arch"
  if [[ ! -e "$kcv_java_dir" ]]; then
    need_tool sha256sum
    if [[ "$kcv_platform" == windows ]]; then
      need_tool unzip; kcv_java_archive="jdk-25_windows-x64_bin.zip"
    else
      need_tool tar; need_tool gzip; kcv_java_archive="jdk-25_linux-${kcv_arch}_bin.tar.gz"
    fi
    mkdir -p -- "$kcv_tools"
    kcv_stage=$(mktemp -d "$kcv_tools/java-download.XXXXXX")
    kcv_java_url="https://download.oracle.com/java/25/latest/$kcv_java_archive"
    note 'Downloading Oracle JDK 25 and its SHA256 checksum...'
    download "$kcv_java_url.sha256" "$kcv_stage/checksum.txt"
    kcv_expected=$(tr -d '\r\n' < "$kcv_stage/checksum.txt")
    [[ "$kcv_expected" =~ ^[[:xdigit:]]{64}$ ]] || fail 'Invalid Java checksum response; nothing has been installed.'
    download "$kcv_java_url" "$kcv_stage/$kcv_java_archive"
    kcv_actual=$(sha256sum "$kcv_stage/$kcv_java_archive"); kcv_actual=${kcv_actual%% *}
    [[ "${kcv_actual,,}" == "${kcv_expected,,}" ]] || fail 'Java checksum mismatch; nothing has been installed. Retry the command.'
    mkdir -- "$kcv_stage/unpacked"
    if [[ "$kcv_platform" == windows ]]; then
      unzip -q "$kcv_stage/$kcv_java_archive" -d "$kcv_stage/unpacked"
    else
      tar -xzf "$kcv_stage/$kcv_java_archive" -C "$kcv_stage/unpacked" --no-same-owner
    fi
    kcv_jdks=("$kcv_stage"/unpacked/jdk-*)
    [[ ${#kcv_jdks[@]} -eq 1 ]] && java_compatible "${kcv_jdks[0]}/bin/java" || fail 'Downloaded Java did not start.'
    # Both paths are within the verified absolute cache; never overwrite a cache.
    [[ ! -e "$kcv_java_dir" ]] || fail 'Java cache changed during install; retry.'
    mv -T -- "${kcv_jdks[0]}" "$kcv_java_dir"
  fi
  java_compatible "$kcv_java_dir/bin/java" || fail 'Cached Java is unusable. Choose a new KCV_TOOLS_DIR and retry.'
  kcv_java="$kcv_java_dir/bin/java"
fi
# Resolve the actual runtime home, including a symlinked Java found on PATH.
kcv_java_home=$("$kcv_java" -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java.home = //p' | tr -d '\r')
[[ -n "$kcv_java_home" ]] || fail 'Cannot identify the local Java home.'
kcv_java_home=$(absolute_path "$kcv_java_home")
export JAVA_HOME="$kcv_java_home"
export PATH="$kcv_java_home/bin:$PATH"
if [[ "$kcv_platform" == windows ]]; then
  JAVA_HOME=$(cygpath -m "$kcv_java_home")
fi

sqlcl_compatible() {
  local version
  version=$("$1" -version 2>&1) || return 1
  [[ "$version" =~ SQLcl:.*Release[[:space:]]+([0-9]+)\.([0-9]+) ]] || return 1
  (( BASH_REMATCH[1] > 26 || (BASH_REMATCH[1] == 26 && BASH_REMATCH[2] >= 2) ))
}
kcv_sqlcl=''
kcv_sqlcl_entry=sql
if [[ "$kcv_platform" == windows ]]; then kcv_sqlcl_entry=sql.exe; fi
if [[ -n "${KCV_SQLCL_BIN:-}" ]]; then
  kcv_sqlcl=$(command -v "$KCV_SQLCL_BIN") || fail 'KCV_SQLCL_BIN was not found.'
  sqlcl_compatible "$kcv_sqlcl" || fail 'KCV_SQLCL_BIN must launch SQLcl 26.2 or newer.'
elif command -v "$kcv_sqlcl_entry" >/dev/null 2>&1 && sqlcl_compatible "$(command -v "$kcv_sqlcl_entry")"; then
  kcv_sqlcl=$(command -v "$kcv_sqlcl_entry")
else
  kcv_sqlcl_version=26.3.1.301.1413
  kcv_sqlcl_dir="$kcv_tools/sqlcl-$kcv_sqlcl_version"
  if [[ ! -e "$kcv_sqlcl_dir" ]]; then
    need_tool unzip; need_tool sha1sum
    mkdir -p -- "$kcv_tools"
    kcv_stage=$(mktemp -d "$kcv_tools/sqlcl-download.XXXXXX")
    note "Downloading Oracle SQLcl $kcv_sqlcl_version..."
    download "https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-$kcv_sqlcl_version.zip" "$kcv_stage/sqlcl.zip"
    # Oracle publishes this SHA1 on its SQLcl download page (linked in the guide).
    kcv_actual=$(sha1sum "$kcv_stage/sqlcl.zip"); kcv_actual=${kcv_actual%% *}
    [[ "$kcv_actual" == 3b0e930c621b81833162909a8c584e42ead4372d ]] || fail 'SQLcl checksum mismatch; nothing has been installed.'
    unzip -q "$kcv_stage/sqlcl.zip" -d "$kcv_stage/unpacked"
    sqlcl_compatible "$kcv_stage/unpacked/sqlcl/bin/$kcv_sqlcl_entry" || fail 'Downloaded SQLcl did not start.'
    [[ ! -e "$kcv_sqlcl_dir" ]] || fail 'SQLcl cache changed during install; retry.'
    mv -T -- "$kcv_stage/unpacked/sqlcl" "$kcv_sqlcl_dir"
  fi
  kcv_sqlcl="$kcv_sqlcl_dir/bin/$kcv_sqlcl_entry"
  sqlcl_compatible "$kcv_sqlcl" || fail 'Cached SQLcl is unusable. Choose a new KCV_TOOLS_DIR and retry.'
fi

"$kcv_java" -version
"$kcv_sqlcl" -version
if [[ "$kcv_install_only" == true ]]; then
  note 'Local tools are ready. No database connection was opened.'
  exit 0
fi
mkdir -p -- "$kcv_store"
if [[ "$kcv_platform" == windows ]]; then
  kcv_store=$(cygpath -m "$kcv_store")
  # Apply only at launch: curl still needs normal Git Bash path conversion above.
  # Prevent Git Bash from turning SQLcl's /nolog into a Windows filesystem path.
  export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:+$MSYS2_ARG_CONV_EXCL;}/nolog"
  export MSYS_NO_PATHCONV=1
fi
note 'Opening local SQLcl with history disabled. Configure/connect privately at the SQL prompt.'
exec "$kcv_sqlcl" -nohistory -home "$kcv_store" /nolog
