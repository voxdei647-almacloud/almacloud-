#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
API="http://127.0.0.1:8000"

echo "=== 0. Preparando usuario para prueba de Ingesta por Lotes ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-batch', 'Tenant Batch Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'batch_user@tenant-a.com';
" > /dev/null

echo "=== 1. Iniciando FastAPI ==="
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
UVICORN_PID=$!

cleanup() {
  echo "Deteniendo Uvicorn (PID $UVICORN_PID)..."
  kill $UVICORN_PID 2>/dev/null || true
  wait $UVICORN_PID 2>/dev/null || true
  sleep 1
}
trap cleanup EXIT

for i in {1..15}; do
  curl -s $API/healthz | grep -q "healthy" && break
  sleep 0.5
done

echo "=== 2. Registrando usuario y obteniendo token ==="
./scripts/lib/seed_user.sh "$TENANT_A" "batch_user@tenant-a.com" "Password123!" "admin"

TOKEN=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "batch_user@tenant-a.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Enviar Lote de 3 Eventos de Telemetría ==="
code=$(curl -s -o /tmp/batch_res.json -w "%{http_code}" -X POST $API/api/v1/telemetry/events/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{
    "events": [
      {"event_type": "network_flow", "severity": "low",  "source_ip": "10.0.0.1"},
      {"event_type": "network_flow", "severity": "medium",  "source_ip": "10.0.0.2"},
      {"event_type": "network_flow", "severity": "high", "source_ip": "10.0.0.3"}
    ]
  }')

if [ "$code" -eq 201 ]; then
  echo "PASS BATCH1: Lote de 3 eventos indexado exitosamente en OpenSearch via Bulk API"
else
  echo "FAIL BATCH1: Se esperaba HTTP 201 pero se obtuvo HTTP $code"
  cat /tmp/batch_res.json; echo ""
  exit 1
fi

echo "--- RESULTADO FINAL: INGESTA POR LOTES PASÓ EXITOSAMENTE (BATCH1) ---"
