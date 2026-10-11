# ALMA CLOUD - entorno local de desarrollo

Este repositorio levanta la infraestructura local mínima para desarrollo de ALMA CLOUD
(plataforma SaaS multi-tenant SOC/XDR).

Incluye únicamente:

- PostgreSQL 16 como base principal.
- Valkey 8 como caché/cola auxiliar.
- OpenSearch 2.19.6 para eventos.

No implementa backend, tablas, RLS, autenticación ni lógica de negocio.

---

## Nota sobre el sistema operativo del host

Los comandos de este README están escritos para un host Unix-like (Linux, macOS,
o WSL2 en Windows). Comandos como `grep`, `ss`, `chmod`, `mkdir`, `printf` y las
tuberías asumen shell POSIX.

Si trabajas desde CMD o PowerShell en Windows, ejecútalos dentro de WSL2 o usa
equivalentes nativos. La ruta sugerida es WSL2 para evitar mezclar rutas y
comportamientos.

---

## Advertencia importante sobre OpenSearch

En este entorno local OpenSearch se levanta con:

    DISABLE_SECURITY_PLUGIN: "true"

Esto significa que OpenSearch **no tiene autenticación ni aislamiento entre tenants**.
Es válido **solo para desarrollo local**. Nunca debe usarse en producción ni exponerse
fuera de loopback.

Los puertos de todos los servicios se publican únicamente en `127.0.0.1`.

---

## Requisito del host: vm.max_map_count

OpenSearch requiere que el host tenga:

    vm.max_map_count=262144

Comprobar:

    sysctl vm.max_map_count

Aplicar temporalmente:

    sudo sysctl -w vm.max_map_count=262144

Hacerlo persistente:

    echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-alma-cloud.conf
    sudo sysctl --system

Si no se cumple, OpenSearch puede fallar al arrancar.

---

## Arranque

1. Copiar variables de entorno:

       cp .env.example .env

2. Generar secretos locales. Se recomienda `-hex` porque `-base64` puede producir
   `/`, `+` y `=`, que rompen cadenas de conexión.

3. Generar los secretos de Valkey. La contraseña va en dos archivos con nombres
   **exactamente iguales** a los declarados en `docker-compose.yml`:

   - `secrets/valkey_password` → solo la clave, lo lee el healthcheck.
   - `secrets/valkey_auth.conf` → directiva `requirepass`, lo lee Valkey vía `include`.

   Comandos:

       mkdir -p secrets
       umask 077
       p=$(openssl rand -hex 32)
       printf '%s' "$p" > secrets/valkey_password
       printf 'requirepass %s\n' "$p" > secrets/valkey_auth.conf

   `umask 077` crea los archivos con permisos `600` por defecto (lectura/escritura
   solo del propietario). **No se recomienda `644` como valor por defecto.** Los
   secretos en Docker son montajes por archivo; los permisos efectivos dentro del
   contenedor dependen del usuario con el que corre el proceso y de la política de
   Docker. Verificar la legibilidad antes de dar el entorno por bueno
   (ver `VERSIONES.md`).

   Si el proceso del contenedor no puede leer los secretos, ajustar permisos o
   propietario según corresponda, documentarlo y volver a probar. No cambiar a
   `644` de forma automática como solución por defecto.

   Editar `.env` y reemplazar `CAMBIAR_ESTO_postgres_password`.

4. Verificar que no quedan placeholders con `CAMBIAR_ESTO`:

       if grep -q 'CAMBIAR_ESTO' .env; then
         echo "Faltan secretos en .env"
         exit 1
       fi

   El chequeo falla si `.env` todavía contiene valores de ejemplo. Es necesario
   porque `docker compose config` no detecta placeholders conocidos: no están
   vacíos y por tanto pasan la validación `${VAR:?}`.

5. Validar la configuración de Compose **sin imprimirla**:

       docker compose config -q

   `-q` valida sintaxis y resolución de variables sin volcar el contenido. No
   demuestra que los servicios arranquen, pero es un primer control seguro.

   **No uses** `docker compose config | grep -i password`: `POSTGRES_PASSWORD`
   se define en `environment` y aparecería en la salida, que puede acabar en
   logs de CI o en el historial de la terminal.

6. Levantar servicios:

       docker compose up -d

7. Ver estado:

       docker compose ps

8. Ver logs:

       docker compose logs -f postgres
       docker compose logs -f valkey
       docker compose logs -f opensearch

---

## Comprobaciones de salud

### PostgreSQL

    docker compose exec postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h 127.0.0.1'

Conexión real:

    docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'SELECT 1;'

### Valkey

    docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli ping'

Respuesta esperada: `PONG`.

`REDISCLI_AUTH` está marcado como `PENDIENTE_VERIFICACION` en `VERSIONES.md`.

### OpenSearch

    curl -s "http://127.0.0.1:9200/_cluster/health?pretty"

Estado esperado: `green` o `yellow`.

OpenSearch tarda en arrancar. El healthcheck usa `start_period: 120s`.

---

## Pruebas de persistencia

### Valkey

    docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli SET alma_persist_test ok'
    docker compose restart valkey
    docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli GET alma_persist_test'
    # Debe devolver "ok"
    docker compose exec valkey sh -c 'REDISCLI_AUTH="$(cat /run/secrets/valkey_password)" valkey-cli DEL alma_persist_test'

### PostgreSQL

    docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'CREATE TABLE IF NOT EXISTS _alma_persist_test (id int);'
    docker compose restart postgres
    docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'SELECT * FROM _alma_persist_test;'
    docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'DROP TABLE _alma_persist_test;'

---

## Parada y reinicio

Parar sin borrar datos:

    docker compose stop

Reiniciar:

    docker compose restart

Bajar servicios conservando volúmenes:

    docker compose down

Bajar servicios y borrar volúmenes:

    docker compose down -v

> **DESTRUCTIVO:** `docker compose down -v` borra los datos persistidos en volúmenes.
> Úsalo solo si quieres reiniciar el entorno desde cero.

---

## Puertos, volúmenes y persistencia

| Servicio | Puerto host | Puerto contenedor | Uso | Persistencia |
|---|---:|---:|---|---|
| PostgreSQL | `127.0.0.1:${POSTGRES_PORT:-5432}` | `5432` | Base principal | Volumen `postgres_data` |
| Valkey | `127.0.0.1:${VALKEY_PORT:-6379}` | `6379` | Caché/cola auxiliar | Volumen `valkey_data`, AOF `appendonly yes` |
| OpenSearch | `127.0.0.1:${OPENSEARCH_PORT:-9200}` | `9200` | Eventos | Volumen `opensearch_data` |

Volúmenes nombrados (nombre final = `${COMPOSE_PROJECT_NAME}-<sufijo>`):

| Volumen | Punto de montaje | Contenido |
|---|---|---|
| `postgres-data` | `/var/lib/postgresql/data` | Datos PostgreSQL |
| `valkey-data` | `/data` | Datos Valkey/AOF |
| `opensearch-data` | `/usr/share/opensearch/data` | Datos OpenSearch |

---

## PostgreSQL: usuario actual y roles futuros

En esta fase `POSTGRES_USER` es **superusuario y dueño de la base**. Por eso se salta
RLS y cualquier política que se defina más adelante.

Por lo tanto, `POSTGRES_USER` **nunca** debe usarse como rol de aplicación.
Se usa solo para administración local del entorno.

Más adelante se prevé:

- Un rol de migraciones.
- Un rol de aplicación.
- El rol de aplicación **no será dueño de las tablas**.

Eso queda fuera de este entorno local inicial.

---

## Valkey: no es fuente de verdad

Valkey se usa como caché/cola auxiliar.

Lo que no pueda perderse, por ejemplo:

- Tokens revocados.
- Auditoría.

Debe ir en PostgreSQL. Valkey no es fuente de verdad.

### Comportamiento bajo `maxmemory-policy noeviction`

Con `noeviction`, cuando Valkey alcanza `maxmemory` **rechaza escrituras** con error
en vez de desalojar claves. En desarrollo esto se manifiesta como fallos de
escritura en la cola/caché. Ajustar `VALKEY_MAXMEMORY` según el entorno.

---

## Valkey: cómo se evita la contraseña en argv

La contraseña **no** aparece en `command`, por lo que no queda en:

- `docker inspect`.
- `docker compose config`.
- Lista de procesos del contenedor (`docker top`).

Se inyecta vía `include` desde un archivo montado como secreto
(`/run/secrets/valkey_auth_conf`) y se lee desde el healthcheck vía
`/run/secrets/valkey_password`.

PENDIENTE_VERIFICACION sobre esta decisión:

- Que la imagen de Valkey respete `include` de un archivo en `/run/secrets`.
- Que los permisos de los secretos permitan al usuario del contenedor leerlos.
- Que mantener `command: ["valkey-server", ...]` conserve la bajada de privilegios
  del entrypoint oficial.

---

## Nota sobre `POSTGRES_PASSWORD`

A diferencia de Valkey, la contraseña de PostgreSQL se pasa por variable de
entorno (`POSTGRES_PASSWORD`). Esto implica que:

- Aparece en `docker compose config` (por eso se usa `-q`).
- Aparece en `docker inspect` del contenedor.
- Puede acabar en logs de CI si se vuelca la configuración.

Mitigación pendiente de evaluar en una fase posterior: usar
`POSTGRES_PASSWORD_FILE` con secreto montado, siguiendo el mismo patrón que Valkey.
No se aplica todavía para no rediseñar el Compose sin verificación previa.
Ver `RIESGOS.md` R-14.

---

## Qué NO está implementado todavía

- Backend.
- Tablas.
- RLS.
- Autenticación.
- Autorización.
- Aislamiento multi-tenant en OpenSearch.
- OpenSearch Dashboards.
- Migraciones de base de datos.
- Roles de aplicación.
- Backups.

---

## Prioridad antes de cerrar la Fase 0

1. Corregir el nombre del secreto en el README (hecho).
2. Revisar permisos y legibilidad de ambos secretos.
3. Ejecutar `docker compose config -q`.
4. Confirmar imágenes y digests. La inspección de etiquetas **no** es una prueba
   de funcionamiento.
5. Levantar los servicios solo tras comprobar requisitos y confirmar que los
   datos existentes se conservan.
6. Validar healthchecks y pruebas de persistencia.
7. Actualizar `RIESGOS.md` y el contexto maestro con resultados reales.