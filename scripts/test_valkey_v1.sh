#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"
TENANT_B="22222222-2222-2222-2222-222222222222"

echo "=== 0. Sembrando Tenants de prueba y usuarios para Valkey ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES
  ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test'),
  ('$TENANT_B', 'tenant-b-test', 'Tenant Beta Test')
ON CONFLICT (id) DO NOTHING;

DELETE FROM alma.users WHERE email IN ('admin-vk@tenant-a.com', 'admin-vk@tenant-b.com');
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
  -d '{"email": "admin-vk@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_B" \
  -d '{"email": "admin-vk@tenant-b.com", "password": "Password123!", "role": "admin"}' > /dev/null

TOKEN_A=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "admin-vk@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

TOKEN_B=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_B" \
  -d '{"email": "admin-vk@tenant-b.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Crear Sensor bajo Tenant A ==="
sensor_json=$(curl -s -X POST http://127.0.0.1:8000/api/v1/sensors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -d '{"hostname": "vk-sensor-node1", "profile": "endpoint"}')

SENSOR_ID=$(echo "$sensor_json" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo "Sensor ID Creado: $SENSOR_ID"

echo "=== 3. Enviar Heartbeat a Valkey ==="
hb_res=$(curl -s -X POST "http://127.0.0.1:8000/api/v1/sensors/$SENSOR_ID/heartbeat" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "X-Tenant-ID: $TENANT_A")

if echo "$hb_res" | grep -q '"status":"online"'; then
  echo "PASS VK1: Heartbeat registrado exitosamente en Valkey"
else
  echo "FAIL VK1: Falla al registrar heartbeat: $hb_res"
  exit 1
fi

echo "=== 4. Consultar Estado en Vivo desde Valkey (Tenant A) ==="
status_a=$(curl -s -H "Authorization: Bearer $TOKEN_A" "http://127.0.0.1:8000/api/v1/sensors/$SENSOR_ID/status")
if echo "$status_a" | grep -q '"status":"online"'; then
  echo "PASS VK2: Estado 'online' recuperado correctamente de Valkey para Tenant A"
else
  echo "FAIL VK2: Estado incorrecto: $status_a"
  exit 1
fi

echo "=== 5. Verificar Rechazo de Consulta desde Tenant B (Aislamiento RLS) ==="
status_b_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN_B" "http://127.0.0.1:8000/api/v1/sensors/$SENSOR_ID/status")
if [ "$status_b_code" -eq 404 ]; then
  echo "PASS VK3: Tenant B recibe 404 al intentar acceder al estado del sensor de Tenant A"
else
  echo "FAIL VK3: Se esperaba HTTP 404 para Tenant B pero se obtuvo $status_b_code"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE VALKEY / HEARTBEAT PASARON EXITOSAMENTE (VK1-VK3) ---"
