#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"
TENANT_B="22222222-2222-2222-2222-222222222222"

echo "=== 0. Sembrando Tenants de prueba ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES
  ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test'),
  ('$TENANT_B', 'tenant-b-test', 'Tenant Beta Test')
ON CONFLICT (id) DO NOTHING;
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

echo "=== 2. Indexar evento de telemetría para Tenant A ==="
ingest_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/events \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{
    "event_type": "suricata.alert",
    "severity": "high",
    "source_ip": "192.168.1.100",
    "destination_ip": "10.0.0.1",
    "raw_event": {"signature": "ET EXPLOIT Possible SQLi", "category": "Attempted Admin Access"}
  }')

if echo "$ingest_res" | grep -q '"status":"indexed"'; then
  echo "PASS OS1: Evento de telemetría indexado correctamente en OpenSearch"
else
  echo "FAIL OS1: Error indexando telemetría: $ingest_res"
  exit 1
fi

echo "=== 3. Consultar telemetría de Tenant A ==="
events_a=$(curl -s -H "X-Tenant-ID: $TENANT_A" http://127.0.0.1:8000/api/v1/telemetry/events)

if echo "$events_a" | grep -q "suricata.alert"; then
  echo "PASS OS2: Tenant A recupera sus eventos de telemetría desde OpenSearch"
else
  echo "FAIL OS2: Error recuperando telemetría de Tenant A: $events_a"
  exit 1
fi

echo "=== 4. Verificar aislamiento: Tenant B no ve eventos de Tenant A ==="
events_b=$(curl -s -H "X-Tenant-ID: $TENANT_B" http://127.0.0.1:8000/api/v1/telemetry/events)

if ! echo "$events_b" | grep -q "suricata.alert"; then
  echo "PASS OS3: Tenant B NO puede ver los eventos de telemetría de Tenant A (Aislamiento OpenSearch verificado)"
else
  echo "FAIL OS3: Violación de aislamiento multi-tenant en OpenSearch"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE OPENSEARCH / TELEMETRÍA PASARON EXITOSAMENTE (OS1-OS3) ---"
