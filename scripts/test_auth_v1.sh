#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"
TENANT_B="22222222-2222-2222-2222-222222222222"

echo "=== 0. Sembrando Tenants y limpiando usuarios de prueba ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES
  ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test'),
  ('$TENANT_B', 'tenant-b-test', 'Tenant Beta Test')
ON CONFLICT (id) DO NOTHING;

DELETE FROM alma.users WHERE email = 'admin@tenant-a.com';
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

echo "=== 2. Registrar usuario en Tenant A ==="
reg_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{
    "email": "admin@tenant-a.com",
    "password": "SecurePassword123!",
    "role": "admin"
  }')

if echo "$reg_res" | grep -q "admin@tenant-a.com"; then
  echo "PASS AUTH1: Usuario registrado correctamente en Tenant A"
else
  echo "FAIL AUTH1: Error en registro: $reg_res"
  exit 1
fi

echo "=== 3. Iniciar sesión y obtener JWT token ==="
login_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{
    "email": "admin@tenant-a.com",
    "password": "SecurePassword123!"
  }')

TOKEN=$(echo "$login_res" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
  echo "PASS AUTH2: Token JWT emitido exitosamente para Tenant A"
else
  echo "FAIL AUTH2: Falla al obtener Token JWT: $login_res"
  exit 1
fi

echo "=== 4. Validar rechazo de autenticación en Tenant B con las mismas credenciales ==="
login_b_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_B" \
  -d '{
    "email": "admin@tenant-a.com",
    "password": "SecurePassword123!"
  }')

if [ "$login_b_code" -eq 401 ]; then
  echo "PASS AUTH3: Autenticación rechazada (401) en Tenant B por aislamiento de usuarios RLS"
else
  echo "FAIL AUTH3: Se esperaba HTTP 401 pero se obtuvo $login_b_code"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE AUTENTICACIÓN / JWT PASARON EXITOSAMENTE (AUTH1-AUTH3) ---"
