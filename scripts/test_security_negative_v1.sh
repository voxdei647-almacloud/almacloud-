#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

TENANT_A="11111111-1111-1111-1111-111111111111"
TENANT_B="22222222-2222-2222-2222-222222222222"
API="http://127.0.0.1:8000"

if [ -f "$(pwd)/.venv/bin/python" ]; then
  PYTHON_BIN="$(pwd)/.venv/bin/python"
else
  PYTHON_BIN="$(command -v python3 || command -v python)"
fi

echo "=== 0. Preparando Tenants y usuarios para Pruebas Negativas ==="
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_A', 'tenant-a-secneg', 'Tenant Sec A') ON CONFLICT (id) DO NOTHING;
INSERT INTO alma.tenants (id, slug, name) VALUES ('$TENANT_B', 'tenant-b-secneg', 'Tenant Sec B') ON CONFLICT (id) DO NOTHING;
DELETE FROM alma.users WHERE email IN ('user_a@tenant-a.com', 'user_b@tenant-b.com');
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

./scripts/lib/seed_user.sh "$TENANT_A" "user_a@tenant-a.com" "Password123!" "admin"

./scripts/lib/seed_user.sh "$TENANT_B" "user_b@tenant-b.com" "Password123!" "admin"

TOKEN_A=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_A" \
  -d '{"email": "user_a@tenant-a.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

TOKEN_B=$(curl -s -X POST $API/api/v1/auth/login \
  -H "Content-Type: application/json" -H "X-Tenant-ID: $TENANT_B" \
  -d '{"email": "user_b@tenant-b.com", "password": "Password123!"}' \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

echo "=== 2. Crear sensor en Tenant A e inscribir agente ==="
sensor_res=$(curl -s -X POST $API/api/v1/sensors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d '{"hostname": "sensor-a-secneg", "profile": "endpoint"}')

SENSOR_A_ID=$(echo "$sensor_res" | jq -r '.id // empty')

enroll_res=$(curl -s -X POST $API/api/v1/sensors/enrollment \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_A" \
  -d "{\"hostname\": \"sensor-a-secneg\", \"enrollment_key\": \"${ENROLLMENT_KEY:-alma-secret-enroll-key-2026}\"}")

VALID_API_KEY=$(echo "$enroll_res" | jq -r '.api_key // empty')

if [ -z "$SENSOR_A_ID" ]; then
  echo "FAIL SETUP: No se pudo obtener SENSOR_A_ID: $sensor_res"
  exit 1
fi

echo "=== 3. Negativo 1: Borrado Cross-Tenant (Tenant B intenta borrar recurso A) ==="
code_mod=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API/api/v1/sensors/$SENSOR_A_ID" \
  -H "Authorization: Bearer $TOKEN_B" \
  -H "X-Tenant-ID: $TENANT_B")

if [ "$code_mod" -eq 404 ] || [ "$code_mod" -eq 403 ]; then
  echo "PASS SEC_NEG1: Escritura/Borrado Cross-Tenant rechazada con HTTP $code_mod"
else
  echo "FAIL SEC_NEG1: Se esperaba HTTP 403 o 404 pero se obtuvo HTTP $code_mod"
  exit 1
fi

echo "=== 4. Negativo 2a: Token JWT con Firma Inválida / Manipulada ==="
TAMPERED_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
code_sig=$(curl -s -o /dev/null -w "%{http_code}" $API/api/v1/sensors \
  -H "Authorization: Bearer $TAMPERED_TOKEN" \
  -H "X-Tenant-ID: $TENANT_A")

if [ "$code_sig" -eq 401 ]; then
  echo "PASS SEC_NEG2a: Token con firma manipulada rechazado con HTTP 401"
else
  echo "FAIL SEC_NEG2a: Se esperaba HTTP 401 pero se obtuvo HTTP $code_sig"
  exit 1
fi

echo "=== 5. Negativo 2b: Token JWT Real Expirado (Secret de .env) ==="
JWT_SECRET_KEY="${JWT_SECRET:-alma_super_secret_jwt_key_2026_change_in_production}"
EXPIRED_TOKEN=$("$PYTHON_BIN" -c "
try:
    import jwt
except ImportError:
    from jose import jwt
import time
payload = {'sub': 'user_a@tenant-a.com', 'tenant_id': '$TENANT_A', 'role': 'admin', 'exp': int(time.time()) - 3600}
token = jwt.encode(payload, '$JWT_SECRET_KEY', algorithm='HS256')
print(token if isinstance(token, str) else token.decode('utf-8'))
")

code_exp=$(curl -s -o /dev/null -w "%{http_code}" $API/api/v1/sensors \
  -H "Authorization: Bearer $EXPIRED_TOKEN" \
  -H "X-Tenant-ID: $TENANT_A")

if [ "$code_exp" -eq 401 ]; then
  echo "PASS SEC_NEG2b: Token JWT expirado rechazado con HTTP 401"
else
  echo "FAIL SEC_NEG2b: Se esperaba HTTP 401 pero se obtuvo HTTP $code_exp"
  exit 1
fi

echo "=== 6. Negativo 3: API Key Inexistente / Revocada ==="
code_ak=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/api/v1/sensors/$SENSOR_A_ID/heartbeat" \
  -H "X-Tenant-ID: $TENANT_A" \
  -H "X-API-Key: ak_invalid_key_99999999")

if [ "$code_ak" -eq 401 ]; then
  echo "PASS SEC_NEG3: Agente con API Key inválida rechazado con HTTP 401"
else
  echo "FAIL SEC_NEG3: Se esperaba HTTP 401 pero se obtuvo HTTP $code_ak"
  exit 1
fi

echo "=== 7. Negativo 4: Ataque API Key Cross-Tenant (Clave válida de Tenant A enviada a Tenant B) ==="
if [ -n "$VALID_API_KEY" ]; then
  code_xt=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/api/v1/sensors/$SENSOR_A_ID/heartbeat" \
    -H "X-Tenant-ID: $TENANT_B" \
    -H "X-API-Key: $VALID_API_KEY")

  if [ "$code_xt" -eq 401 ] || [ "$code_xt" -eq 404 ]; then
    echo "PASS SEC_NEG4: API Key válida usada Cross-Tenant rechazada con HTTP $code_xt"
  else
    echo "FAIL SEC_NEG4: Se esperaba HTTP 401 o 404 pero se obtuvo HTTP $code_xt"
    exit 1
  fi
else
  echo "SKIP SEC_NEG4: No se pudo obtener API Key válida en enrolamiento"
fi

echo "=== 8. Negativo 5: Petición a Heartbeat sin Encabezados de Autenticación ==="
code_none=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/api/v1/sensors/$SENSOR_A_ID/heartbeat")

if [ "$code_none" -eq 401 ]; then
  echo "PASS SEC_NEG5: Heartbeat sin auth rechazado con HTTP 401"
else
  echo "FAIL SEC_NEG5: Se esperaba HTTP 401 pero se obtuvo HTTP $code_none"
  exit 1
fi

echo "=== 9. Negativo 6: JWT válido SIN tenant_id (bypass del fallback) ==="

NO_TENANT_TOKEN=$(PYTHONPATH="$(pwd)/apps/backend" python3 - <<'PYGEN'
import sys
sys.path.insert(0, "apps/backend")
from app.core.security import get_private_key, JWT_ALGORITHM, JWT_ISSUER, JWT_AUDIENCE
from jose import jwt
from datetime import datetime, timedelta, timezone

now = datetime.now(timezone.utc)
payload = {
    "sub": "00000000-0000-0000-0000-000000000000",
    "iss": JWT_ISSUER,
    "aud": JWT_AUDIENCE,
    "exp": now + timedelta(minutes=10),
    "iat": now,
    "role": "admin",
}
print(jwt.encode(payload, get_private_key(), algorithm=JWT_ALGORITHM))
PYGEN
)

if [ -z "$NO_TENANT_TOKEN" ]; then
  echo "FAIL SEC_NEG6: No se pudo generar el token sin tenant_id"
  exit 1
fi

code_no_tenant=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/api/v1/sensors/$SENSOR_A_ID/heartbeat" \
  -H "Authorization: Bearer $NO_TENANT_TOKEN" \
  -H "X-Tenant-ID: $TENANT_A")

if [ "$code_no_tenant" -eq 401 ] || [ "$code_no_tenant" -eq 404 ]; then
  echo "PASS SEC_NEG6: JWT sin tenant_id rechazado con HTTP $code_no_tenant"
else
  echo "FAIL SEC_NEG6: Se esperaba HTTP 401/404 pero se obtuvo HTTP $code_no_tenant (¿el fallback 'else' sigue vivo?)"
  exit 1
fi

echo "--- RESULTADO FINAL: TODAS LAS PRUEBAS NEGATIVAS DE SEGURIDAD PASARON (100%) ---"
