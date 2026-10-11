#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
if [ -f .env ]; then
  set -a; source .env; set +a
fi

API="http://127.0.0.1:8000"

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

echo "=== 2. Comprobar Disponibilidad de la Interfaz Web ==="
code_index=$(curl -s -o /tmp/ui_index.html -w "%{http_code}" $API/ui/index.html)
if [ "$code_index" -eq 200 ] && grep -qi "html" /tmp/ui_index.html; then
  echo "PASS UI1: Interfaz Web VOX DEI (index.html) servida exitosamente con HTTP 200"
else
  echo "FAIL UI1: index.html devolvió HTTP $code_index"
  exit 1
fi

code_dash=$(curl -s -o /tmp/ui_dash.html -w "%{http_code}" $API/ui/dashboard.html)
if [ "$code_dash" -eq 200 ] && grep -qi "html" /tmp/ui_dash.html; then
  echo "PASS UI2: Dashboard SOC Operations (dashboard.html) servido exitosamente con HTTP 200"
else
  echo "FAIL UI2: dashboard.html devolvió HTTP $code_dash"
  exit 1
fi

echo "--- RESULTADO FINAL: MÓDULO FRONTEND Y DASHBOARD PASÓ EXITOSAMENTE (UI1-UI2) ---"
