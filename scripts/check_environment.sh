#!/usr/bin/env bash
set -euo pipefail
if [[ ! -r /etc/os-release ]]; then printf '%s\n' 'Run this supported setup in Oracle Linux.' >&2; exit 1; fi
source /etc/os-release
if [[ "${ID:-}" != ol ]]; then printf '%s\n' 'Supported execution baseline is Oracle Linux (ID=ol).' >&2; exit 1; fi
PYTHON="${KCV_PYTHON:-python3.12}"
command -v "$PYTHON" >/dev/null
"$PYTHON" -c 'import sys; assert sys.version_info >= (3,11), "Python 3.11+ required"; print(sys.version.split()[0])'
printf 'Oracle Linux %s; Bash %s\n' "$VERSION_ID" "$BASH_VERSION"
