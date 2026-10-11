# VERSIONES

> **Estado:** Documento de referencia de imágenes probadas y fijadas para el Incremento 0.

## Imágenes probadas y fijadas

| Componente | Etiqueta | Digest (linux/amd64) | Antigüedad | Estado |
|---|---|---|---|---|
| PostgreSQL | `postgres:16-bookworm` | `sha256:0ea6700a3b4f0ae6ce746519073558aed4d88a79d8d07622a9a644946c7319c4` | ~5 días | `VERIFICADO` (Fijado en `.env` y `.env.example`) |
| Valkey | `valkey/valkey:8-bookworm` | `sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571` | ~13 meses (ver R-17) | `VERIFICADO` (Fijado en `.env` y `.env.example`) |
| OpenSearch | `opensearchproject/opensearch:2.19.6` | `sha256:e321cb03c643874c42240458a618db56bc1e4fc143b10c41bec653542bc6851b` | ~3 semanas | `VERIFICADO` (Fijado en `.env` y `.env.example`) |

## Comprobaciones de Infraestructura Realizadas

| Elemento | Resultado | Estado |
|---|---|---|
| `pg_isready` en PostgreSQL | Servicio `healthy`; puertos expuestos únicamente en `127.0.0.1:5432` | `VERIFICADO` |
| `curl` en OpenSearch | Clúster `green`/`yellow`; puertos expuestos en `127.0.0.1:9200` | `VERIFICADO` |
| Persistencia de datos en OpenSearch | Documentos conservados tras ciclo `down` / `up -d` (sin `-v`) | `VERIFICADO` |
| Reconstrucción limpia | Purgado e inicialización de volúmenes con `down -v` / `up -d` | `VERIFICADO` |
| Autenticación Valkey | `REDISCLI_AUTH` con lectura de secreto montado (`uid 999`, `600`) | `VERIFICADO` |
