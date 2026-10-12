#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Preparando usuario para prueba de Ingesta por Lotes ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'batch-admin@tenant-a.com';
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

./scripts/lib/seed_user.sh "$TENANT_A" "batch-admin@tenant-a.com" "Password123!" "admin"

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "batch-admin@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Enviar Lote de 3 Eventos de Telemetría ==="
batch_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/events/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '{
    "events": [
      {"event_type": "suricata.alert", "severity": "high", "source_ip": "10.0.0.5", "destination_ip": "10.0.0.1", "raw_event": {"sig": "Rule 1"}},
      {"event_type": "suricata.alert", "severity": "medium", "source_ip": "10.0.0.6", "destination_ip": "10.0.0.1", "raw_event": {"sig": "Rule 2"}},
      {"event_type": "syslog.notice", "severity": "low", "source_ip": "10.0.0.7", "destination_ip": "10.0.0.1", "raw_event": {"msg": "SSH auth success"}}
    ]
  }')

if echo "$batch_res" | grep -q '"ingested_count":3'; then
  echo "PASS BATCH1: Lote de 3 eventos indexado exitosamente en OpenSearch via Bulk API"
else
  echo "FAIL BATCH1: Error en ingesta por lote: $batch_res"
  exit 1
fi

echo "--- RESULTADO FINAL: INGESTA POR LOTES PASÓ EXITOSAMENTE (BATCH1) ---"
