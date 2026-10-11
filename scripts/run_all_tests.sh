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

run_suite "[1/12] Pruebas de API Base y RLS Postgres (API1-API5)" "./scripts/test_api_v1.sh"
run_suite "[2/12] Pruebas de Valkey Async / Heartbeat (VK1-VK3)" "./scripts/test_valkey_v1.sh"
run_suite "[3/12] Pruebas de OpenSearch Telemetría (OS1-OS3)" "./scripts/test_opensearch_v1.sh"
run_suite "[4/12] Pruebas de Autenticación JWT Parte 1 (AUTH1-AUTH3)" "./scripts/test_auth_v1.sh"
run_suite "[4b/12] Pruebas de Protección JWT Parte 2 (SEC1-SEC2)" "./scripts/test_jwt_protection_v1.sh"
run_suite "[5/12] Pruebas de Control de Acceso RBAC (RBAC1-RBAC5)" "./scripts/test_rbac_full_v1.sh"
run_suite "[6/12] Pruebas de Enrolamiento de Sensores (ENROLL1-ENROLL2)" "./scripts/test_enrollment_v1.sh"
run_suite "[7/12] Pruebas de Autenticación de Agente vía API Key (SAK1-SAK2)" "./scripts/test_sensor_auth_v1.sh"
run_suite "[8/12] Pruebas de Ingesta Masiva por Lotes Bulk (BATCH1)" "./scripts/test_telemetry_batch_v1.sh"
run_suite "[9/12] Pruebas de Ingesta Suricata EVE JSON (EVE1)" "./scripts/test_suricata_ingest_v1.sh"
run_suite "[10/12] Pruebas del Motor de Alertas en Tiempo Real (ALERT1-ALERT2)" "./scripts/test_alert_engine_v1.sh"
run_suite "[11/12] Pruebas de Interfaz Web y Dashboard SOC (UI1-UI2)" "./scripts/test_frontend_v1.sh"
run_suite "[12/12] Pruebas del Motor de Inferencia ML (ML1-ML2)" "./scripts/test_ml_inference_v1.sh"

echo ""
echo "=================================================="
echo "  TODAS LAS SUITES E2E PASARON CON ÉXITO (100%)   "
echo "=================================================="
