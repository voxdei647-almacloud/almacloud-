#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Limpiando y preparando entorno para prueba de API Key de Sensor ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.sensors WHERE hostname = 'sensor-agent-ak';
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

echo "=== 2. Enrolar Sensor para obtener API Key ==="
enroll_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/sensors/enrollment \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"hostname": "sensor-agent-ak", "profile": "endpoint", "enrollment_key": "alma-secret-enroll-key-2026"}')

API_KEY=$(echo "$enroll_res" | grep -o '"api_key":"[^"]*' | cut -d'"' -f4)
SENSOR_ID=$(echo "$enroll_res" | grep -o '"sensor_id":"[^"]*' | cut -d'"' -f4)

if [ -n "$API_KEY" ]; then
  echo "PASS SAK1: API Key generada correctamente: ${API_KEY:0:10}..."
else
  echo "FAIL SAK1: No se pudo obtener API Key: $enroll_res"
  exit 1
fi

echo "=== 3. Enviar Heartbeat usando X-Tenant-ID ==="
hb_res=$(curl -s -X POST "http://127.0.0.1:8000/api/v1/sensors/$SENSOR_ID/heartbeat" \
  -H "X-Tenant-ID: $TENANT_A")

if echo "$hb_res" | grep -q '"status":"online"'; then
  echo "PASS SAK2: Heartbeat aceptado correctamente para el agente"
else
  echo "FAIL SAK2: Heartbeat rechazado: $hb_res"
  exit 1
fi

echo "--- RESULTADO FINAL: AUTENTICACIÓN DE AGENTE PASÓ EXITOSAMENTE (SAK1-SAK2) ---"
