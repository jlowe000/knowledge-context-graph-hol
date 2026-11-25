#!/usr/bin/env bash
# Legacy v1 direct-driver automation. v2 schema changes use SQLcl/Liquibase.
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON="${KCV_RUN_PYTHON:-.venv/bin/python}"
: "${KCV_DB_DSN:?Set your private Serverless connection configuration first}"
mode="${1:-check}"
case "$mode" in
  check) "$PYTHON" -m kcv.cli check-db ;;
  provision)
    if [[ "${KCV_DB_USER:-KCV_LAB}" != KCV_LAB ]]; then
      printf '%s\n' 'Legacy provision creates KCV_LAB only. Use the parameterized Worksheet setup for a different owner.' >&2
      exit 2
    fi
    "$PYTHON" -m kcv.cli provision
    "$PYTHON" -m kcv.cli apply-sql --admin --schema KCV_LAB --file sql/admin/02_grants.sql
    ;;
  schema)
    if [[ -f VERSION && "$(cut -d. -f1 VERSION)" -ge 2 ]]; then
      printf '%s\n' 'v2 schema setup uses db/changelog.xml through SQLcl/Liquibase. See docs/database-migrations.md; do not mix raw CREATE scripts with migration-managed objects.' >&2
      exit 2
    fi
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/01_objects.sql
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/02_network.sql
    "$PYTHON" -m kcv.cli apply-sql --file sql/schema/03_tools.sql
    ;;
  profile) "$PYTHON" -m kcv.cli configure-profile ;;
  agents) "$PYTHON" -m kcv.cli apply-sql --file sql/schema/04_agents.sql ;;
  *) printf '%s\n' 'Usage: setup_serverless.sh check|provision|schema|profile|agents' >&2; exit 2 ;;
esac
