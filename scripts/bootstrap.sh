#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check_environment.sh
"${KCV_PYTHON:-python3.12}" -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
printf '%s\n' 'Environment ready. No database has been modified.'
