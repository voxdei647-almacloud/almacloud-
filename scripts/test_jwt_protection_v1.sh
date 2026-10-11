#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Limpiando y preparando entorno de prueba ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'jwt-user@tenant-a.com';
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

echo "=== 2. Registrar usuario e inicie sesión para obtener Token ==="
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "jwt-user@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

login_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "jwt-user@tenant-a.com", "password": "Password123!"}')

TOKEN=$(echo "$login_res" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Consultar /auth/me sin Token (Debe fallar HTTP 401) ==="
code_no_token=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/v1/auth/me)
if [ "$code_no_token" -eq 401 ]; then
  echo "PASS SEC1: Acceso a /auth/me rechazado (401) sin token Bearer"
else
  echo "FAIL SEC1: Se esperaba HTTP 401 pero se obtuvo $code_no_token"
  exit 1
fi

echo "=== 4. Consultar /auth/me con Token Bearer Válido ==="
me_res=$(curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8000/api/v1/auth/me)
if echo "$me_res" | grep -q "jwt-user@tenant-a.com"; then
  echo "PASS SEC2: Perfil recuperado exitosamente usando Token Bearer JWT"
else
  echo "FAIL SEC2: Falla al consultar /auth/me: $me_res"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE PROTECCIÓN JWT PASARON EXITOSAMENTE (SEC1-SEC2) ---"
