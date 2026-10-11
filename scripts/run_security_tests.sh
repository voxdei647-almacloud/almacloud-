#!/usr/bin/env bash
set -eo pipefail

if [ -f .env ]; then
  set -a; source .env; set +a
fi

echo "=================================================="
echo "    ALMA CLOUD - SUITE DE SEGURIDAD Y ABUSO"
echo "=================================================="

echo ""
echo ">>> [1/2] Pruebas Negativas de Seguridad (Cross-Tenant, JWT Manipulado/Expirado, API Key Invalida)..."
./scripts/test_security_negative_v1.sh

echo ""
echo ">>> [2/2] Rate Limiting y Abuso de Peticiones (Bloqueo HTTP 429)..."
./scripts/test_rate_limit_v1.sh

echo ""
echo "=================================================="
echo "  SUITE DE SEGURIDAD PASÓ EXITOSAMENTE (100%)"
echo "=================================================="
