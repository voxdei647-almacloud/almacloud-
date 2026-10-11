#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
API="http://127.0.0.1:8000"

echo "=== 0. Preparando entorno para prueba del Motor de Alertas ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-alerts', 'Tenant Alerts Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'alerts_user@tenant-a.com';
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
  -d '{"email": "alerts_user@tenant-a.com", "password": "Password123!", "role": "admin"}' > /dev/null

TOKEN=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "alerts_user@tenant-a.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Disparo de Alerta Individual (evento critical) ==="
single_res=$(curl -s -X POST $API/api/v1/telemetry/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"event_type": "intrusion", "severity": "critical", "source_ip": "10.0.0.99"}')

ALERTS_COUNT=$(echo "$single_res" | jq -r '.alerts_generated // .alert_count // (if .alerts then (.alerts | length) else empty end) // empty')
HAS_ALERT_OBJ=$(echo "$single_res" | jq -r 'if .alert != null or .alerts != null or .alert_triggered == true or .alert_id != null then "true" else "false" end')

if [ "$ALERTS_COUNT" -ge 1 2>/dev/null ] || [ "$HAS_ALERT_OBJ" = "true" ]; then
  echo "PASS ALERT1: Evento 'critical' procesado y alerta verificada en motor de reglas"
else
  echo "FAIL ALERT1: Evento 'critical' NO disparó alerta. Respuesta: $single_res"
  exit 1
fi

echo "=== 4. Conteo de Alertas en Lote Suricata EVE ==="
batch_res=$(curl -s -X POST $API/api/v1/telemetry/suricata/eve-batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '[
    {"event_type": "alert", "src_ip": "10.0.0.5", "alert": {"signature": "ET MALWARE", "severity": 1}},
    {"event_type": "alert", "src_ip": "10.0.0.7", "alert": {"signature": "ET EXPLOIT", "severity": 1}},
    {"event_type": "flow",  "src_ip": "10.0.0.6"}
  ]')

INGESTED_COUNT=$(echo "$batch_res" | jq -r '.ingested_count // .indexed // .processed // empty')
ALERTS_COUNT=$(echo "$batch_res" | jq -r '.alerts_generated // 0')

if [ "$INGESTED_COUNT" -eq 3 ] && [ "$ALERTS_COUNT" -ge 1 ]; then
  echo "PASS ALERT2: Evaluados 3 eventos e ingestados correctamente con $ALERTS_COUNT alertas generadas"
else
  echo "FAIL ALERT2: Conteo de eventos ($INGESTED_COUNT) o alertas ($ALERTS_COUNT) no coincide: $batch_res"
  exit 1
fi

echo "--- RESULTADO FINAL: MOTOR DE ALERTAS PASÓ EXITOSAMENTE (ALERT1-ALERT2) ---"
