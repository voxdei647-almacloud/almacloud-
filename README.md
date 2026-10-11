# ALMA CLOUD — entorno local de desarrollo

Infraestructura local mínima: PostgreSQL 16, Valkey 8 y OpenSearch 2.19.6 con Docker Compose.
**No hay backend, agentes ni lógica de negocio.** Estado verificado: ver `VERSIONES.md` y `RIESGOS.md`.

## Requisitos del host (verificado en Debian 13)

- Docker Engine y Docker Compose v2.
- `vm.max_map_count` de al menos 262144 (comprobar con `sysctl vm.max_map_count`).
- Shell POSIX (Linux o WSL2).

## Primer arranque

Desde la raíz del repositorio:

```bash
cp .env.example .env && chmod 600 .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 24)/" .env

mkdir -p secrets && chmod 700 secrets
( umask 077
  p=$(openssl rand -hex 32)
  printf '%s' "$p" > secrets/valkey_password
  printf 'requirepass %s\n' "$p" > secrets/valkey_auth.conf )
sudo chown 999 secrets/valkey_password secrets/valkey_auth.conf
```

- Solo los **dos archivos** pasan a ser del uid 999 (el usuario `valkey` de la imagen); el directorio `secrets/` sigue siendo tuyo. Sin este `chown`, Valkey no arranca (`Permission denied`).
- Comprueba el uid si cambias la imagen: `docker run --rm --entrypoint id <imagen_valkey> valkey`.
- No imprimas ni pegues el contenido de `.env` ni de `secrets/`.

Comprobaciones previas (no imprimen secretos):

```bash
grep -v '^[[:space:]]*#' .env | grep -q 'CAMBIAR_ESTO' && echo "ERROR: faltan secretos" || echo "OK: sin placeholders"
test -s config/valkey.conf && echo "OK: valkey.conf no vacío" || echo "ERROR: valkey.conf vacío"
docker compose config -q && echo "COMPOSE VÁLIDO"
```

Arranque:

```bash
docker compose pull
docker compose up -d
docker compose ps        # OpenSearch tarda 1-2 minutos en pasar a healthy
```

## Verificación

```bash
docker compose exec valkey valkey-cli ping                                                   # NOAUTH (sin clave)
docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli ping'   # PONG
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT 1;"'          # 1
curl -s http://127.0.0.1:9200/_cluster/health | grep -o '"status":"[a-z]*"'                  # green o yellow
ss -ltn | grep -E ':(5432|6379|9200)\b'                                                      # solo 127.0.0.1
```

## Pruebas de persistencia

```bash
# Valkey
docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli SET alma_test ok'
docker compose restart valkey && sleep 10
docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli GET alma_test'   # "ok"
docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli DEL alma_test'

# OpenSearch (crear índice, bajar y subir SIN -v, contar, borrar el índice)
curl -s -X PUT http://127.0.0.1:9200/test-persistence-01 -H 'Content-Type: application/json' -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}'
curl -s -X POST 'http://127.0.0.1:9200/test-persistence-01/_doc/1?refresh=true' -H 'Content-Type: application/json' -d '{"marker":"ok"}'
docker compose down && docker compose up -d
curl -s 'http://127.0.0.1:9200/test-persistence-01/_count'      # count 1 (esperar unos segundos a que OpenSearch arranque)
curl -s -X DELETE http://127.0.0.1:9200/test-persistence-01
```

## Parada y reinicio

```bash
docker compose stop        # parar conservando datos
docker compose restart
docker compose down        # elimina contenedores y red; CONSERVA los volúmenes
docker compose down -v     # DESTRUCTIVO: borra también los volúmenes (todos los datos)
```

## Puertos y volúmenes

| Servicio | Puerto (solo 127.0.0.1) | Volumen | Contenido |
|---|---|---|---|
| PostgreSQL | 5432 | `alma-cloud-dev-postgres-data` | Datos relacionales |
| Valkey | 6379 | `alma-cloud-dev-valkey-data` | AOF (`appendonly yes`) |
| OpenSearch | 9200 | `alma-cloud-dev-opensearch-data` | Índices |

## Advertencias

- **OpenSearch sin seguridad** (`DISABLE_SECURITY_PLUGIN=true`): sin autenticación ni aislamiento entre tenants. Solo desarrollo local, nunca producción.
- **`POSTGRES_PASSWORD`** va en `environment`: aparece en `docker inspect` y en `docker compose config` sin `-q`. Usa siempre `-q` al validar.
- **`POSTGRES_USER` es superusuario**: no usarlo como rol de aplicación (el rol de aplicación será `alma_app`, ver `apps/backend/db/`).
- **Valkey no es fuente de verdad**: lo que no pueda perderse (revocaciones, auditoría) va en PostgreSQL. Con `noeviction`, Valkey rechaza escrituras al llegar a `maxmemory`.
- **Archivos largos**: no los pegues con `cat <<EOF` por SSH (se corrompen, ver R-18). Transfiérelos con `scp` y comprueba `sha256sum`.

## Capa de datos (propuesta, ver `ALMA_DATA_LAYER_PROPOSAL.md`)

```bash
bash apps/backend/db/apply.sh bootstrap   # roles alma_migrator y alma_app (sin login, sin contraseñas)
bash apps/backend/db/apply.sh migrate     # tablas tenants y sensors con RLS
bash apps/backend/db/apply.sh test        # 12 líneas PASS esperadas
bash apps/backend/db/apply.sh mutation    # la prueba debe FALLAR con RLS apagado
```

## Qué NO está implementado

Backend, agentes, autenticación, aislamiento en la API y en OpenSearch, copias de seguridad, Alembic.
