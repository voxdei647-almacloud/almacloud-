#!/usr/bin/env bash
set -eo pipefail

VALKEY_PASS=$(cat secrets/valkey_password)
VALKEY_CLI="docker compose exec -T valkey valkey-cli -a $VALKEY_PASS --no-auth-warning"

echo "=== 1. Aplicando Index Template en OpenSearch ==="
curl -s -X PUT "http://127.0.0.1:9200/_index_template/alma-telemetry-template" \
  -H "Content-Type: application/json" \
  -d @apps/backend/opensearch/0001_telemetry_template.json | grep -q '"acknowledged":true'
echo "PASS OS1: Index Template 'alma-telemetry-template' registrado correctamente"

echo "=== 2. Creando índice de prueba e ingiriendo evento ==="
curl -s -X PUT "http://127.0.0.1:9200/alma-telemetry-2026.10.10/_doc/doc-1" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "33333333-3333-3333-3333-333333333333",
    "sensor_id": "s-101",
    "channel": "telemetry",
    "event_type": "process_start",
    "severity": "info",
    "timestamp": "2026-10-10T18:00:00Z",
    "payload": {"process": "ls", "pid": 1234}
  }' | grep -q '"result":"created"'
echo "PASS OS2: Documento de telemetría indexado correctamente"

echo "=== 3. Validando aislamiento de búsqueda por tenant ==="
os_count=$(curl -s -X POST "http://127.0.0.1:9200/alma-telemetry-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "term": { "tenant_id": "33333333-3333-3333-3333-333333333333" }
    }
  }' | grep -o '"value":1' | wc -l)

if [ "$os_count" -eq 1 ]; then
  echo "PASS OS3: Búsqueda en OpenSearch filtrada por tenant_id exitosa"
else
  echo "FAIL OS3: Error al filtrar por tenant en OpenSearch"
  exit 1
fi

echo "=== 4. Validando caché multi-tenant y TTL en Valkey ==="
$VALKEY_CLI SET "tenant:33333333-3333-3333-3333-333333333333:sensor:s-101:status" "online" EX 60 > /dev/null
val_val=$($VALKEY_CLI GET "tenant:33333333-3333-3333-3333-333333333333:sensor:s-101:status" | tr -d '\r')
val_ttl=$($VALKEY_CLI TTL "tenant:33333333-3333-3333-3333-333333333333:sensor:s-101:status" | tr -d '\r')

if [ "$val_val" = "online" ] && [ "$val_ttl" -gt 0 ]; then
  echo "PASS VK1: Operación SET/GET con prefijo multi-tenant y TTL ($val_ttl sec) verificada en Valkey"
else
  echo "FAIL VK1: Error en almacenamiento Valkey"
  exit 1
fi

echo "--- RESULTADO FINAL: TODOS LOS TESTS PASARON (OS1-OS3, VK1) ---"
