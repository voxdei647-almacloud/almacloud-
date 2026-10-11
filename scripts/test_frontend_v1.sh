#!/usr/bin/env bash
set -eo pipefail

export PYTHONPATH="${PYTHONPATH}:$(pwd)/apps/backend"
source .env

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

echo "=== 2. Comprobar Disponibilidad de la Interfaz Web ==="
code_ui=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ui/index.html)
if [ "$code_ui" -eq 200 ]; then
  echo "PASS UI1: Interfaz Web VOX DEI (index.html) servida exitosamente con HTTP 200"
else
  echo "FAIL UI1: Error al acceder a la interfaz web UI: $code_ui"
  exit 1
fi

code_dash=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ui/dashboard.html)
if [ "$code_dash" -eq 200 ]; then
  echo "PASS UI2: Dashboard SOC Operations (dashboard.html) servido exitosamente con HTTP 200"
else
  echo "FAIL UI2: Error al acceder al dashboard SOC: $code_dash"
  exit 1
fi

echo "--- RESULTADO FINAL: MÓDULO FRONTEND Y DASHBOARD PASÓ EXITOSAMENTE (UI1-UI2) ---"
