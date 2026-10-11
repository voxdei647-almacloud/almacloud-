#!/usr/bin/env bash
set -eo pipefail

if [ -f .env ]; then
  set -a; source .env; set +a
fi

export ENABLE_RATE_LIMIT="${ENABLE_RATE_LIMIT:-true}"

if [ -f secrets/valkey_password ]; then
  VALKEY_PASS=$(cat secrets/valkey_password | tr -d '\r\n')
else
  VALKEY_PASS="${VALKEY_PASSWORD:-${REDIS_PASSWORD:-}}"
fi

run_suite() {
  local title="$1"
  local script="$2"

  echo ""
  echo ">>> ${title}..."

  if [ -n "$VALKEY_PASS" ]; then
    docker compose exec -T -e REDISCLI_AUTH="$VALKEY_PASS" valkey \
      valkey-cli --scan --pattern "rate_limit:*" \
      | xargs -r docker compose exec -T -e REDISCLI_AUTH="$VALKEY_PASS" valkey valkey-cli DEL > /dev/null 2>&1 || true
  else
    docker compose exec -T valkey valkey-cli --scan --pattern "rate_limit:*" \
      | xargs -r docker compose exec -T valkey valkey-cli DEL > /dev/null 2>&1 || true
  fi

  bash "${script}"
}

echo "=================================================="
echo "      ALMA CLOUD - SUITE INTEGRAL E2E"
echo "=================================================="

run_suite "[1/12]  API Base y RLS Postgres (API1-API5)"              "./scripts/test_api_v1.sh"
run_suite "[2/12]  Valkey Async / Heartbeat (VK1-VK3)"               "./scripts/test_valkey_v1.sh"
run_suite "[3/12]  OpenSearch Telemetría (OS1-OS3)"                  "./scripts/test_opensearch_v1.sh"
run_suite "[4/12]  Autenticación JWT Parte 1 (AUTH1-AUTH3)"          "./scripts/test_auth_v1.sh"
run_suite "[4b/12] Protección JWT Parte 2 (SEC1-SEC2)"               "./scripts/test_security_v1.sh"
run_suite "[5/12]  Control de Acceso RBAC (RBAC1-RBAC3)"             "./scripts/test_rbac_v1.sh"
run_suite "[6/12]  Enrolamiento de Sensores (ENROLL1-ENROLL2)"       "./scripts/test_enrollment_v1.sh"
run_suite "[7/12]  Autenticación de Agente vía API Key (SAK1-SAK2)"  "./scripts/test_sensor_key_v1.sh"
run_suite "[8/12]  Ingesta Masiva por Lotes Bulk (BATCH1)"           "./scripts/test_bulk_v1.sh"
run_suite "[9/12]  Ingesta Suricata EVE JSON (EVE1)"                 "./scripts/test_eve_v1.sh"
run_suite "[10/12] Motor de Alertas en Tiempo Real (ALERT1-ALERT2)"  "./scripts/test_alerts_v1.sh"
run_suite "[11/12] Interfaz Web y Dashboard SOC (UI1-UI2)"           "./scripts/test_ui_v1.sh"
run_suite "[12/12] Motor de Inferencia ML (ML1-ML2)"                 "./scripts/test_ml_v1.sh"

echo ""
echo "=================================================="
echo "  TODAS LAS SUITES E2E PASARON CON ÉXITO (100%)"
echo "=================================================="
