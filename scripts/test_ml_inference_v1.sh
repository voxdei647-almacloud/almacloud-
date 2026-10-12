#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Preparando entorno para prueba del Motor de ML ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'ml-admin@tenant-a.com';
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
  if curl -s http://127.0.0.1:8000/healthz | grep -q "healthy"; then
    break
  fi
  sleep 0.5
done

./scripts/lib/seed_user.sh "$TENANT_A" "ml-admin@tenant-a.com" "Password123!" "admin"

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "ml-admin@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Probar Inferencia ML en Evento Individual ==="
ml_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '{"event_type": "suricata.exploit", "severity": "critical", "source_ip": "10.0.0.50", "destination_ip": "10.0.0.1", "raw_event": {"signature": "Buffer Overflow Attempt", "dest_port": 445}}')

if echo "$ml_res" | grep -q '"anomaly_score":'; then
  echo "PASS ML1: Inferencia de Machine Learning (IsolationForest) calculó 'anomaly_score' y 'risk_level' exitosamente"
else
  echo "FAIL ML1: No se calculó la puntuación de anomalía: $ml_res"
  exit 1
fi

echo "=== 3. Probar Estadísticas ML en Ingesta por Lote ==="
batch_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/events/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '{"events": [
    {"event_type": "suricata.alert", "severity": "high", "source_ip": "192.168.1.100", "destination_ip": "10.0.0.5", "raw_event": {"dest_port": 80}},
    {"event_type": "suricata.flow", "severity": "info", "source_ip": "192.168.1.101", "destination_ip": "10.0.0.5", "raw_event": {"dest_port": 443}}
  ]}')

if echo "$batch_res" | grep -q '"ml_statistics":'; then
  echo "PASS ML2: Generación de estadísticas de anomalía por lote completada con éxito"
else
  echo "FAIL ML2: Error al generar estadísticas de ML: $batch_res"
  exit 1
fi

echo "--- RESULTADO FINAL: MOTOR DE INFERENCIA ML PASÓ EXITOSAMENTE (ML1-ML2) ---"
