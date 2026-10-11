#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Preparando usuarios para prueba RBAC Global ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email IN ('admin-full@tenant-a.com', 'analyst-full@tenant-a.com');
" > /dev/null

echo "=== 1. Iniciando FastAPI ==="
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
UVICORN_PID=$!

cleanup() {
  echo "Deteniendo Uvicorn (PID $UVICORN_PID)..."
  kill $UVICORN_PID 2>/dev/null || true
}
trap cleanup EXIT

for i in {1..10}; do
  if curl -s http://127.0.0.1:8000/healthz | grep -q "healthy"; then
    break
  fi
  sleep 0.5
done

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "admin-full@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "analyst-full@tenant-a.com", "password": "Password123!", "role": "analyst"}' > /dev/null

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "admin-full@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

TOKEN_ANALYST=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "analyst-full@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Audit Logs: Admin (200 OK) vs Analyst (403 Forbidden) ==="
code_admin_audit=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN_ADMIN" http://127.0.0.1:8000/api/v1/audit-logs)
code_analyst_audit=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN_ANALYST" http://127.0.0.1:8000/api/v1/audit-logs)

if [ "$code_admin_audit" -eq 200 ] && [ "$code_analyst_audit" -eq 403 ]; then
  echo "PASS RBAC4: Acceso a /audit-logs restringido correctamente a 'admin'"
else
  echo "FAIL RBAC4: Esperado (200/403), obtenido ($code_admin_audit/$code_analyst_audit)"
  exit 1
fi

echo "=== 3. Telemetry Read: Analyst (200 OK) ==="
code_analyst_telem=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN_ANALYST" http://127.0.0.1:8000/api/v1/telemetry/events)

if [ "$code_analyst_telem" -eq 200 ]; then
  echo "PASS RBAC5: 'analyst' puede consultar telemetria en /telemetry/events"
else
  echo "FAIL RBAC5: Esperado 200, obtenido $code_analyst_telem"
  exit 1
fi

echo "--- RESULTADO FINAL: PROTECCIÓN RBAC COMPLETA PASÓ EXITOSAMENTE (RBAC1-RBAC5) ---"
