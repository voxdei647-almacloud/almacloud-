#!/usr/bin/env bash
# USO: ./scripts/lib/seed_user.sh <tenant_id> <email> <password> [role]
set -euo pipefail

TENANT_ID="${1:-}"
EMAIL="${2:-}"
PASSWORD="${3:-}"
ROLE="${4:-admin}"

if [ -z "$TENANT_ID" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "[!] Error: Faltan parámetros. Uso: $0 <tenant_id> <email> <password> [role]"
  exit 1
fi

set -a; [ -f .env ] && source .env 2>/dev/null; set +a
PG_USER="${POSTGRES_USER:-alma_dev}"
PG_DB="${POSTGRES_DB:-alma_cloud}"

HASHED_PW=$(PYTHONPATH=apps/backend .venv/bin/python -c \
  "from app.core.security import hash_password; print(hash_password('$PASSWORD'))")

docker compose exec -T postgres psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.users (tenant_id, email, password_hash, role, created_at)
VALUES ('$TENANT_ID', '$EMAIL', '$HASHED_PW', '$ROLE', NOW())
ON CONFLICT (tenant_id, email) DO UPDATE
  SET password_hash = EXCLUDED.password_hash,
      role          = EXCLUDED.role;
" > /dev/null

echo "  [seed_user] Usuario $EMAIL ($ROLE) sembrado en tenant $TENANT_ID"
