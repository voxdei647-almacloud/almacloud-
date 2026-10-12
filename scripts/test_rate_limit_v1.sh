#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
API="http://127.0.0.1:8000"

if [ -f secrets/valkey_password ]; then
  VALKEY_PASS=$(cat secrets/valkey_password | tr -d '\r\n')
else
  VALKEY_PASS="${VALKEY_PASSWORD:-${REDIS_PASSWORD:-}}"
fi

echo "=== 0. Limpiando contadores de Rate Limit en Valkey ==="
if [ -n "$VALKEY_PASS" ]; then
  docker compose exec -T -e REDISCLI_AUTH="$VALKEY_PASS" valkey \
    valkey-cli --scan --pattern "rate_limit:*" \
    | xargs -r docker compose exec -T -e REDISCLI_AUTH="$VALKEY_PASS" valkey valkey-cli DEL > /dev/null 2>&1 || true
fi

echo "=== 1. Sembrando Tenant A ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-limiter', 'Tenant Limiter Test') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email = 'limiter_user@tenant-a.com';
" > /dev/null

echo "=== 2. Iniciando FastAPI con Rate Limit Estricto (máx 3 intentos) ==="
ENABLE_RATE_LIMIT=true RATE_LIMIT_MAX_LOGIN=3 python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
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

echo "=== 3. Registrando usuario de prueba ==="
./scripts/lib/seed_user.sh "$TENANT_A" "limiter_user@tenant-a.com" "Password123!" "admin"

echo "=== 4. Validando intentos dentro del límite (1 al 3) ==="
for i in {1..3}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST $API/api/v1/auth/login \
    -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
    -d '{"email": "limiter_user@tenant-a.com", "password": "Password123!"}')
  if [ "$code" -ne 200 ]; then
    echo "FAIL RATE1: El intento $i debió responder HTTP 200 pero devolvió HTTP $code"
    exit 1
  fi
  echo "Intento $i: HTTP 200 (Permitido)"
done

echo "=== 5. Validando bloqueo por exceso de peticiones (Intento 4) ==="
code_blocked=$(curl -s -o /dev/null -w "%{http_code}" -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "limiter_user@tenant-a.com", "password": "Password123!"}')

if [ "$code_blocked" -eq 429 ]; then
  echo "PASS RATE1: Middleware bloqueó la 4ª petición con HTTP 429 correctamente"
else
  echo "FAIL RATE1: Se esperaba HTTP 429 pero se obtuvo HTTP $code_blocked"
  exit 1
fi

echo "--- RESULTADO FINAL: PRUEBAS DE RATE LIMITING PASARON EXITOSAMENTE (RATE1) ---"
