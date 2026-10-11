#!/usr/bin/env bash
set -eo pipefail

echo "=================================================="
echo "      ALMA CLOUD - SUITE INTEGRAL E2E"
echo "=================================================="

run_suite() {
  local desc="$1"
  local script="$2"
  echo ""
  echo ">>> $desc..."
  "$script"
  sleep 1
}

run_suite "[1/9] Pruebas de API Base y RLS Postgres (API1-API5)" "./scripts/test_api_v1.sh"
run_suite "[2/9] Pruebas de Valkey Async / Heartbeat (VK1-VK3)" "./scripts/test_valkey_v1.sh"
run_suite "[3/9] Pruebas de OpenSearch Telemetría (OS1-OS3)" "./scripts/test_opensearch_v1.sh"
run_suite "[4/9] Pruebas de Autenticación JWT Parte 1 (AUTH1-AUTH3)" "./scripts/test_auth_v1.sh"
run_suite "[4b/9] Pruebas de Protección JWT Parte 2 (SEC1-SEC2)" "./scripts/test_jwt_protection_v1.sh"
run_suite "[5/9] Pruebas de Control de Acceso RBAC (RBAC1-RBAC5)" "./scripts/test_rbac_full_v1.sh"
run_suite "[6/9] Pruebas de Enrolamiento de Sensores (ENROLL1-ENROLL2)" "./scripts/test_enrollment_v1.sh"
run_suite "[7/9] Pruebas de Autenticación de Agente vía API Key (SAK1-SAK2)" "./scripts/test_sensor_auth_v1.sh"
run_suite "[8/9] Pruebas de Ingesta Masiva por Lotes Bulk (BATCH1)" "./scripts/test_telemetry_batch_v1.sh"
run_suite "[9/9] Pruebas de Ingesta Suricata EVE JSON (EVE1)" "./scripts/test_suricata_ingest_v1.sh"

echo ""
echo "=================================================="
echo "  TODAS LAS SUITES E2E PASARON CON ÉXITO (100%)   "
echo "=================================================="
