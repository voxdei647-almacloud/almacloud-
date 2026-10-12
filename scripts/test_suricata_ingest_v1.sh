#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

TENANT_A="11111111-1111-1111-1111-111111111111"

echo "=== 0. Preparando entorno para prueba Suricata EVE ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-test', 'Tenant Alpha Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'suricata-admin@tenant-a.com';
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

./scripts/lib/seed_user.sh "$TENANT_A" "suricata-admin@tenant-a.com" "Password123!" "admin"

TOKEN_ADMIN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "suricata-admin@tenant-a.com", "password": "Password123!"}' | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Enviar Lote EVE JSON Nativo de Suricata ==="
eve_res=$(curl -s -X POST http://127.0.0.1:8000/api/v1/telemetry/suricata/eve-batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ADMIN" \
  -d '[
    {
      "event_type": "alert",
      "src_ip": "192.168.10.50",
      "dest_ip": "10.0.0.25",
      "alert": {
        "signature": "ET SCAN Nmap Scripting Engine User-Agent Detected",
        "category": "Attempted Information Leak",
        "severity": 2
      }
    },
    {
      "event_type": "dns",
      "src_ip": "192.168.10.50",
      "dest_ip": "1.1.1.1",
      "dns": {
        "rrname": "malicious-c2-domain.com"
      }
    }
  ]')

if echo "$eve_res" | grep -q '"ingested_count":2'; then
  echo "PASS EVE1: Lote EVE JSON normalizado e indexado correctamente en OpenSearch"
else
  echo "FAIL EVE1: Error en ingesta EVE: $eve_res"
  exit 1
fi

echo "--- RESULTADO FINAL: INGESTA SURICATA EVE PASÓ EXITOSAMENTE (EVE1) ---"
