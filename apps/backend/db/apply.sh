#!/usr/bin/env bash
# ALMA CLOUD - aplica y prueba la capa de datos (desarrollo local). Uso: bash apps/backend/db/apply.sh <orden>
set -euo pipefail
cd "$(dirname "$0")/../../.."          # raíz del repositorio
psqlr() { docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1'; }
case "${1:-}" in
  bootstrap) psqlr < apps/backend/db/bootstrap/001_roles.sql ;;
  migrate)   psqlr < apps/backend/db/migrations/0001_tenants_sensors.sql ;;
  test)      psqlr < apps/backend/db/tests/rls_negative.sql 2>&1 ;;
  mutation)  # prueba que la prueba sabe fallar: apaga RLS, ejecuta, y lo vuelve a encender
             echo "ALTER TABLE alma.sensors DISABLE ROW LEVEL SECURITY;" | psqlr
             psqlr < apps/backend/db/tests/rls_negative.sql 2>&1 | grep -E "FAIL|ERROR" || true
             echo "ALTER TABLE alma.sensors ENABLE ROW LEVEL SECURITY;" | psqlr ;;
  *) echo "uso: bash $0 bootstrap|migrate|test|mutation"; exit 2 ;;
esac
