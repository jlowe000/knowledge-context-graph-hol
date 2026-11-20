#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON="${KCV_RUN_PYTHON:-.venv/bin/python}"
"$PYTHON" -m kcv.cli fetch
"$PYTHON" -m kcv.cli prepare
"$PYTHON" -m kcv.cli build
"$PYTHON" -m kcv.cli worksheet
"$PYTHON" scripts/sync_doc_snippets.py --check
"$PYTHON" scripts/build_apex.py --check
"$PYTHON" -m unittest discover -s tests -v
