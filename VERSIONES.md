# VERSIONES

> Este archivo registra lo **probado**, no aprueba versiones. La matriz de versiones (V1) sigue pendiente de revisión y aprobación.

## Imágenes probadas (linux/amd64)

| Componente | Etiqueta | Digest | Antigüedad al probarla | Estado |
|---|---|---|---|---|
| PostgreSQL | `postgres:16-bookworm` | `sha256:0ea6700a3b4f0ae6ce746519073558aed4d88a79d8d07622a9a644946c7319c4` | ~5 días | Digest y fijación VERIFICADOS |
| Valkey | `valkey/valkey:8-bookworm` | `sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571` | ~13 meses (R-17) | Digest y fijación VERIFICADOS |
| OpenSearch | `opensearchproject/opensearch:2.19.6` | `sha256:e321cb03c643874c42240458a618db56bc1e4fc143b10c41bec653542bc6851b` | ~3 semanas | Digest y fijación VERIFICADOS |

Evidencia de fijación: `grep -n IMAGE .env.example` (líneas 16-18) y `docker compose ps`, que muestra las tres imágenes con `@sha256`. Todos los servicios estuvieron `healthy` más de 2 horas.

## Comprobado en las imágenes reales

| Elemento | Resultado | Estado |
|---|---|---|
| `pg_isready` y `psql` en PostgreSQL | `healthy`; `SELECT 1` devuelve 1 | VERIFICADO |
| `curl` en OpenSearch (healthcheck) | Clúster `green`; healthcheck operativo | VERIFICADO |
| `bootstrap.memory_lock` con los `ulimits` definidos | OpenSearch arrancó | VERIFICADO |
| `DISABLE_SECURITY_PLUGIN` | Arranque correcto con aviso "Security plugin installed but disabled" | VERIFICADO |
| `DISABLE_INSTALL_DEMO_CONFIG` | Arranque correcto con ambas variables | VERIFICADO (no se aisló el efecto de esta variable) |
| `valkey-cli` y `REDISCLI_AUTH` | Sin clave `NOAUTH`; con clave `PONG` | VERIFICADO |
| `include /run/secrets/valkey_auth_conf` | Funciona tras `chown 999` de los secretos (modo 600) | VERIFICADO |
| Clave de Valkey fuera de `argv` | `docker compose top valkey` sin `requirepass` | VERIFICADO |
| Persistencia | Valkey, PostgreSQL y OpenSearch conservan datos tras reinicio o `down`/`up` sin `-v` | VERIFICADO |
| Reconstrucción limpia | `down -v` y `up -d` recrearon volúmenes y red sin descargas | VERIFICADO |

## Pendiente

- Registrar el parche exacto de cada componente (las etiquetas son de rama).
- Revisar si existe una rama de Valkey más reciente y su estado de parches (R-17).
- Revisión legal Valkey/Redis (R-04).
- Aprobación de la matriz de versiones (V1) y de la variante `-bookworm` (V2).
