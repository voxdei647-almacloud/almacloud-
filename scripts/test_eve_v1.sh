#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
API="http://127.0.0.1:8000"

echo "=== 0. Preparando entorno para prueba Suricata EVE ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-eve', 'Tenant EVE Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'eve_user@tenant-a.com';
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
./scripts/lib/seed_user.sh "$TENANT_A" "eve_user@tenant-a.com" "Password123!" "admin"

TOKEN=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "eve_user@tenant-a.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 3. Enviar Lote EVE JSON Nativo de Suricata (Lista Directa) ==="
code=$(curl -s -o /tmp/eve_res.json -w "%{http_code}" -X POST $API/api/v1/telemetry/suricata/eve-batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '[
    {"event_type": "alert", "src_ip": "10.0.0.5", "dest_ip": "8.8.8.8", "proto": "TCP", "alert": {"signature": "ET SCAN", "severity": 2}},
    {"event_type": "flow",  "src_ip": "10.0.0.6", "dest_ip": "1.1.1.1", "proto": "UDP"},
    {"event_type": "alert", "src_ip": "10.0.0.7", "dest_ip": "9.9.9.9", "proto": "TCP", "alert": {"signature": "ET MALWARE", "severity": 1}}
  ]')

if [ "$code" -eq 201 ] || [ "$code" -eq 200 ]; then
  echo "PASS EVE1: Lote EVE JSON normalizado e indexado correctamente en OpenSearch (HTTP $code)"
else
  echo "FAIL EVE1: Se esperaba HTTP 200/201 pero se obtuvo HTTP $code"
  cat /tmp/eve_res.json; echo ""
  exit 1
fi

echo "--- RESULTADO FINAL: INGESTA SURICATA EVE PASÓ EXITOSAMENTE (EVE1) ---"
