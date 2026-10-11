#!/usr/bin/env bash
set -eo pipefail

PSQL="docker exec -i alma-cloud-dev-postgres psql -U postgres -d postgres -t -A"
PSQL_APP="docker exec -i alma-cloud-dev-postgres psql -U alma_app -d postgres -t -A"

# Asegurar tenants de prueba
$PSQL -c "INSERT INTO tenants (id, slug, name) VALUES ('00000000-0000-0000-0000-000000000001', 'tenant-a', 'Tenant A') ON CONFLICT DO NOTHING;" > /dev/null
$PSQL -c "INSERT INTO tenants (id, slug, name) VALUES ('00000000-0000-0000-0000-000000000002', 'tenant-b', 'Tenant B') ON CONFLICT DO NOTHING;" > /dev/null
$PSQL -c "DELETE FROM sensors;" > /dev/null

pass_count=0
fail_count=0

run_test() {
    local test_num="$1"
    local desc="$2"
    local expected="$3"
    local sql="$4"

    res=$($PSQL_APP -c "$sql" 2>&1 || true)
    if echo "$res" | grep -qi "violates row-level security policy"; then
        res_clean="ERROR_RLS"
    else
        res_clean=$(echo "$res" | tr -d '\r' | xargs)
    fi

    if [ "$res_clean" = "$expected" ]; then
        echo "PASS: Test $test_num - $desc"
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: Test $test_num - $desc (Esperado: '$expected', Obtenido: '$res_clean')"
        fail_count=$((fail_count + 1))
    fi
}

run_test "1" "Consulta sin contexto de tenant devuelve 0 filas" "0" \
    "SELECT count(*) FROM sensors;"

run_test "2" "Inserción de sensor en Tenant A con contexto activo" "1" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000001'; INSERT INTO sensors (id, tenant_id, hostname, profile) VALUES ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'srv-tenant-a', 'endpoint'); SELECT count(*) FROM sensors;"

run_test "3" "Lectura bajo contexto Tenant A devuelve exactamente 1 sensor" "1" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000001'; SELECT count(*) FROM sensors;"

run_test "4" "Inserción de sensor en Tenant B con contexto activo" "1" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; INSERT INTO sensors (id, tenant_id, hostname, profile) VALUES ('b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'srv-tenant-b', 'network'); SELECT count(*) FROM sensors;"

run_test "5" "Lectura bajo contexto Tenant B devuelve sólo el sensor B" "srv-tenant-b" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; SELECT hostname FROM sensors;"

run_test "6" "Aislamiento de lectura: Tenant B no ve el sensor de Tenant A" "0" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; SELECT count(*) FROM sensors WHERE id = 'a0000000-0000-0000-0000-000000000001';"

run_test "7" "Aislamiento de escritura: UPDATE de Tenant B sobre Sensor A no afecta filas" "0" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; WITH updated AS (UPDATE sensors SET hostname = 'hacked' WHERE id = 'a0000000-0000-0000-0000-000000000001' RETURNING *) SELECT count(*) FROM updated;"

run_test "8" "Aislamiento de borrado: DELETE de Tenant B sobre Sensor A no afecta filas" "0" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; WITH deleted AS (DELETE FROM sensors WHERE id = 'a0000000-0000-0000-0000-000000000001' RETURNING *) SELECT count(*) FROM deleted;"

run_test "9" "Rechazo de inyección/discrepancia de tenant en INSERT" "ERROR_RLS" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000002'; INSERT INTO sensors (id, tenant_id, hostname, profile) VALUES ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'fake-sensor', 'endpoint');"

run_test "10" "Conmutación de contexto restaura visión exclusiva de Tenant A" "srv-tenant-a" \
    "SET app.current_tenant_id = '00000000-0000-0000-0000-000000000001'; SELECT hostname FROM sensors;"

run_test "11" "Limpieza de contexto vuelve a ocultar todos los sensores" "0" \
    "SET app.current_tenant_id = ''; SELECT count(*) FROM sensors;"

force_rls=$($PSQL -c "SELECT relforcerowsecurity FROM pg_class WHERE relname = 'sensors';" | tr -d '\r' | xargs)
if [ "$force_rls" = "t" ]; then
    echo "PASS: Test 12 - Verificación de FORCE ROW LEVEL SECURITY en metadatos de PostgreSQL"
    pass_count=$((pass_count + 1))
else
    echo "FAIL: Test 12 - FORCE ROW LEVEL SECURITY no está activo"
    fail_count=$((fail_count + 1))
fi

echo "--- RESULTADO FINAL: $pass_count PASS, $fail_count FAIL ---"
