#!/usr/bin/env bash
set -eo pipefail

echo "=================================================="
echo "      ALMA CLOUD - SUITE INTEGRAL E2E"
echo "=================================================="

echo ""
echo ">>> [1/5] Ejecutando Pruebas de API Base y RLS Postgres (API1-API5)..."
./scripts/test_api_v1.sh

echo ""
echo ">>> [2/5] Ejecutando Pruebas de Valkey Async / Heartbeat (VK1-VK3)..."
./scripts/test_valkey_v1.sh

echo ""
echo ">>> [3/5] Ejecutando Pruebas de OpenSearch Telemetría (OS1-OS3)..."
./scripts/test_opensearch_v1.sh

echo ""
echo ">>> [4/5] Ejecutando Pruebas de Autenticación y JWT (AUTH1-AUTH3, SEC1-SEC2)..."
./scripts/test_auth_v1.sh
./scripts/test_jwt_protection_v1.sh

echo ""
echo ">>> [5/5] Ejecutando Pruebas de Control de Acceso RBAC (RBAC1-RBAC5)..."
./scripts/test_rbac_full_v1.sh

echo ""
echo "=================================================="
echo "  TODAS LAS SUITES E2E PASARON CON ÉXITO (100%)   "
echo "=================================================="
