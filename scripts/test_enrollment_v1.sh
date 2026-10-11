#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Limpiando y preparando entorno ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.sensors WHERE hostname = 'edge-suricata-01';
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

echo "=== 2. Enrolar Sensor con Clave Inválida (Debe fallar HTTP 401) ==="
code_bad_key=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8000/api/v1/sensors/enrollment \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"hostname": "edge-suricata-01", "profile": "endpoint", "enrollment_key": "clave-falsa"}')

if [ "$code_bad_key" -eq 401 ]; then
  echo "PASS ENROLL1: Enrolamiento rechazado con HTTP 401 por clave inválida"
else
  echo "FAIL ENROLL1: Se esperaba HTTP 401 pero se obtuvo $code_bad_key"
  exit 1
fi

echo "=== 3. Enrolar Sensor con Clave Válida (Debe responder HTTP 201 y generar API Key) ==="
enroll_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/sensors/enrollment \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"hostname": "edge-suricata-01", "profile": "endpoint", "enrollment_key": "alma-secret-enroll-key-2026"}')

if echo "$enroll_res" | grep -q "ak_"; then
  echo "PASS ENROLL2: Sensor enrolado exitosamente y API Key generada"
else
  echo "FAIL ENROLL2: Error en enrolamiento: $enroll_res"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE ENROLAMIENTO PASARON EXITOSAMENTE (ENROLL1-ENROLL2) ---"
