#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"
TENANT_B="22222222-2222-2222-2222-222222222222"

echo "=== 0. Sembrando Tenants de prueba en PostgreSQL ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES
  ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test'),
  ('$TENANT_B', 'tenant-b-test', 'Tenant Beta Test')
ON CONFLICT (id) DO NOTHING;
" > /dev/null

echo "=== 1. Iniciando servidor Uvicorn en segundo plano ==="
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
UVICORN_PID=$!

cleanup() {
  echo "Deteniendo Uvicorn (PID $UVICORN_PID)..."
  kill $UVICORN_PID 2>/dev/null || true
}
trap cleanup EXIT

for i in {1..10}; do
  if curl -s http://127.0.0.1:8000/healthz | grep -q "healthy"; then
    echo "PASS API1: Backend en línea y responde /healthz"
    break
  fi
  sleep 0.5
done

echo "=== 2. Validando rechazo por falta de encabezado X-Tenant-ID ==="
code_no_header=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/v1/sensors)
if [ "$code_no_header" -eq 400 ]; then
  echo "PASS API2: Petición sin X-Tenant-ID rechazada con HTTP 400"
else
  echo "FAIL API2: Se esperaba 400 pero se obtuvo $code_no_header"
  exit 1
fi

echo "=== 3. Creando sensor para Tenant A y comprobando registro de auditoría ==="
post_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/sensors \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"hostname": "api-audit-sensor-a1", "profile": "endpoint"}')

if echo "$post_res" | grep -q '"hostname":"api-audit-sensor-a1"'; then
  echo "PASS API3: Sensor creado exitosamente bajo Tenant A via API"
else
  echo "FAIL API3: Error al crear sensor: $post_res"
  exit 1
fi

echo "=== 4. Validando aislamiento RLS en sensores (Tenant A vs Tenant B) ==="
sensors_a=$(curl -s -H "X-Tenant-ID: $TENANT_A" http://127.0.0.1:8000/api/v1/sensors)
sensors_b=$(curl -s -H "X-Tenant-ID: $TENANT_B" http://127.0.0.1:8000/api/v1/sensors)

if echo "$sensors_a" | grep -q "api-audit-sensor-a1" && ! echo "$sensors_b" | grep -q "api-audit-sensor-a1"; then
  echo "PASS API4: Tenant A visualiza su sensor y Tenant B no tiene acceso a él (RLS verificado)"
else
  echo "FAIL API4: Falla de aislamiento RLS en API de sensores"
  exit 1
fi

echo "=== 5. Validando consulta de Audit Logs y aislamiento RLS (Tenant A vs Tenant B) ==="
logs_a=$(curl -s -H "X-Tenant-ID: $TENANT_A" http://127.0.0.1:8000/api/v1/audit-logs)
logs_b=$(curl -s -H "X-Tenant-ID: $TENANT_B" http://127.0.0.1:8000/api/v1/audit-logs)

if echo "$logs_a" | grep -q "sensor.create" && ! echo "$logs_b" | grep -q "sensor.create"; then
  echo "PASS API5: Tenant A visualiza sus logs de auditoría y Tenant B no (RLS verificado en audit-logs)"
else
  echo "FAIL API5: Falla de aislamiento RLS en API de audit-logs"
  echo "Respuesta Tenant A: $logs_a"
  echo "Respuesta Tenant B: $logs_b"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE API Y AUDITORÍA PASARON EXITOSAMENTE (API1-API5) ---"
