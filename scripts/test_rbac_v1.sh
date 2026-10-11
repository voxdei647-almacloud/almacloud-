#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Limpiando y preparando usuarios para pruebas RBAC ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email IN ('admin-rbac@tenant-a.com', 'analyst-rbac@tenant-a.com');
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

echo "=== 2. Registrar Usuario Admin y Usuario Analyst ==="
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "admin-rbac@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "analyst-rbac@tenant-a.com", "password": "Password123!", "role": "analyst"}' > /dev/null

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "admin-rbac@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

TOKEN_ANALYST=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "analyst-rbac@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Crear Sensor con Rol Admin (Debe permitir HTTP 201) ==="
code_admin_create=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8000/api/v1/sensors \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '{"hostname": "rbac-sensor-admin", "profile": "endpoint"}')

if [ "$code_admin_create" -eq 201 ]; then
  echo "PASS RBAC1: Rol 'admin' puede crear sensores exitosamente (201)"
else
  echo "FAIL RBAC1: Se esperaba HTTP 201 pero se obtuvo $code_admin_create"
  exit 1
fi

echo "=== 4. Intentar Crear Sensor con Rol Analyst (Debe ser rechazado HTTP 403) ==="
code_analyst_create=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8000/api/v1/sensors \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN_ANALYST" \
  -d '{"hostname": "rbac-sensor-analyst", "profile": "endpoint"}')

if [ "$code_analyst_create" -eq 403 ]; then
  echo "PASS RBAC2: Rol 'analyst' rechazado con HTTP 403 al intentar crear sensor"
else
  echo "FAIL RBAC2: Se esperaba HTTP 403 pero se obtuvo $code_analyst_create"
  exit 1
fi

echo "=== 5. Listar Sensores con Rol Analyst (Debe ser permitido HTTP 200) ==="
code_analyst_list=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/v1/sensors \
  -H "Authorization: Bearer $TOKEN_ANALYST")

if [ "$code_analyst_list" -eq 200 ]; then
  echo "PASS RBAC3: Rol 'analyst' puede listar sensores (200)"
else
  echo "FAIL RBAC3: Se esperaba HTTP 200 pero se obtuvo $code_analyst_list"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE CONTROL RBAC PASARON EXITOSAMENTE (RBAC1-RBAC3) ---"
