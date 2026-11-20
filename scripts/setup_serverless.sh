#!/usr/bin/env bash
# Optional direct-driver automation. Preferred HOL route: Database Actions SQL Worksheet.
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON="${KCV_RUN_PYTHON:-.venv/bin/python}"
: "${KCV_DB_DSN:?Set your private Serverless connection configuration first}"
mode="${1:-check}"
case "$mode" in
  check) "$PYTHON" -m kcv.cli check-db ;;
  provision)
    "$PYTHON" -m kcv.cli provision
    "$PYTHON" -m kcv.cli apply-sql --admin --file sql/admin/02_grants.sql
    ;;
  schema)
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/01_objects.sql
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/02_network.sql
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/03_tools.sql
    ;;
  profile) "$PYTHON" -m kcv.cli configure-profile ;;
  agents) "$PYTHON" -m kcv.cli apply-sql --file sql/schema/04_agents.sql ;;
  *) printf '%s\n' 'Usage: setup_serverless.sh check|provision|schema|profile|agents' >&2; exit 2 ;;
esac
