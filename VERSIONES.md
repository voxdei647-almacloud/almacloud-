# VERSIONES

| Componente | Tag de imagen | Digest | Estado del tag | Fuente |
|---|---|---|---|---|
| PostgreSQL | `postgres:16-bookworm` | `PENDIENTE_VERIFICACION` | `PENDIENTE_VERIFICACION` | https://hub.docker.com/_/postgres |
| Valkey | `valkey/valkey:8-bookworm` | `PENDIENTE_VERIFICACION` | `PENDIENTE_VERIFICACION` | https://hub.docker.com/r/valkey/valkey |
| OpenSearch | `opensearchproject/opensearch:2.19.6` | `PENDIENTE_VERIFICACION` | `PENDIENTE_VERIFICACION` | https://hub.docker.com/r/opensearchproject/opensearch |

## Comando para obtener digest

```bash
docker buildx imagetools inspect <imagen>