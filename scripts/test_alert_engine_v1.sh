#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Preparando entorno para prueba del Motor de Alertas ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'alert-admin@tenant-a.com';
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

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/register -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "alert-admin@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "alert-admin@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Probar Disparo de Alerta Individual ==="
alert_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '{"event_type": "suricata.alert", "severity": "critical", "source_ip": "192.168.1.99", "destination_ip": "10.0.0.1", "raw_event": {"sig": "Exploit Attempt"}}')

if echo "$alert_res" | grep -q '"alert_triggered":true'; then
  echo "PASS ALERT1: Evento 'critical' disparó alerta correctamente en el motor de reglas"
else
  echo "FAIL ALERT1: No se disparó la alerta: $alert_res"
  exit 1
fi

echo "=== 3. Probar Conteo de Alertas en Lote Suricata EVE ==="
batch_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/suricata/eve-batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '[
    {"event_type": "alert", "src_ip": "10.0.0.2", "dest_ip": "10.0.0.1", "alert": {"signature": "Att1", "severity": 1}},
    {"event_type": "alert", "src_ip": "10.0.0.3", "dest_ip": "10.0.0.1", "alert": {"signature": "Att2", "severity": 2}},
    {"event_type": "dns", "src_ip": "10.0.0.4", "dest_ip": "1.1.1.1", "dns": {"rrname": "google.com"}}
  ]')

if echo "$batch_res" | grep -q '"alerts_generated":2'; then
  echo "PASS ALERT2: Evaluados 3 eventos en lote y generadas 2 alertas de alta severidad"
else
  echo "FAIL ALERT2: Conteo incorrecto de alertas: $batch_res"
  exit 1
fi

echo "--- RESULTADO FINAL: MOTOR DE ALERTAS PASÓ EXITOSAMENTE (ALERT1-ALERT2) ---"
