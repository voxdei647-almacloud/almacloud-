#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
API="http://127.0.0.1:8000"

echo "=== 0. Preparando entorno para prueba del Motor de ML ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-ml', 'Tenant ML Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'ml_user@tenant-a.com';
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
curl -s -X POST $API/api/v1/auth/register \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "ml_user@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

TOKEN=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "ml_user@tenant-a.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Inferencia ML en Evento Individual ==="
ml_res=$(curl -s -X POST $API/api/v1/telemetry/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"event_type": "network_flow", "severity": "high", "source_ip": "10.0.0.42", "raw_event": {"bytes": 99999}}')

ANOMALY=$(echo "$ml_res" | jq -r '.anomaly_score // .ml_score // .raw_event.anomaly_score // empty')
RISK=$(echo "$ml_res"    | jq -r '.risk_level // .ml_risk // .raw_event.risk_level // empty')
ML_STAT_STATUS=$(echo "$ml_res" | jq -r '.ml_statistics.status // empty')

if [ -n "$ANOMALY" ] || [ -n "$RISK" ] || [ "$ML_STAT_STATUS" = "enabled" ] || [ "$ML_STAT_STATUS" = "processed" ]; then
  echo "PASS ML1: Inferencia ML (IsolationForest) procesada en el pipeline"
else
  echo "FAIL ML1: La respuesta no contiene atributos de inferencia ML: $ml_res"
  exit 1
fi

echo "=== 4. Estadísticas ML en Ingesta por Lote ==="
batch_res=$(curl -s -X POST $API/api/v1/telemetry/events/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{
    "events": [
      {"event_type": "network_flow", "severity": "low",  "source_ip": "10.0.0.10", "raw_event": {"bytes": 100}},
      {"event_type": "network_flow", "severity": "high", "source_ip": "10.0.0.11", "raw_event": {"bytes": 999999}},
      {"event_type": "network_flow", "severity": "medium", "source_ip": "10.0.0.12", "raw_event": {"bytes": 5000}}
    ]
  }')

BATCH_COUNT=$(echo "$batch_res" | jq -r '.ingested_count // .indexed // .processed // .count // empty')
if [ "$BATCH_COUNT" -eq 3 ]; then
  echo "PASS ML2: Ingesta por lote procesada e indexada con 3 registros en OpenSearch"
else
  echo "FAIL ML2: Conteo de lote no coincide (esperados 3): $batch_res"
  exit 1
fi

echo "--- RESULTADO FINAL: MOTOR DE INFERENCIA ML PASÓ EXITOSAMENTE (ML1-ML2) ---"
