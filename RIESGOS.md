# RIESGOS

> **Estado de este documento:** Registros actualizados con evidencia de ejecución del cierre del Incremento 0.

| ID | Riesgo | Impacto | Mitigación | Estado |
|---|---|---|---|---|
| R-01 | Tags flotantes de PostgreSQL, Valkey y OpenSearch. | Reproducibilidad comprometida. | Fijar etiqueta + digest en `.env.example`, `.env` y `VERSIONES.md`. | `VERIFICADO`: Reconstrucción probada y confirmada mediante digests SHA-256 en `.env`. |
| R-02 | OpenSearch con seguridad desactivada en desarrollo. | Sin autenticación ni aislamiento entre tenants. | Solo loopback, nunca producción. | `ACEPTADO` solo en desarrollo local (`VERIFICADO`). |
| R-03 | Contraseña de Valkey visible en la lista de procesos. | Exposición local del secreto. | Secreto montado e `include` en `valkey.conf`. | `VERIFICADO`: `docker compose top valkey` sin `requirepass`. |
| R-04 | Licencia de Valkey/Redis pendiente de revisión legal. | Riesgo legal. | No congelar la decisión hasta la revisión legal. | `PENDIENTE` |
| R-05 | Healthchecks sin verificar contra las imágenes reales. | Falsos positivos/negativos. | Ejecutar contra las imágenes reales. | `VERIFICADO`: los tres servicios `healthy`. |
| R-06 | `curl` podría no existir en la imagen de OpenSearch. | Healthcheck fallaría. | Confirmar disponibilidad. | `VERIFICADO`: healthcheck con `curl` operativo. |
| R-07 | `REDISCLI_AUTH` en `valkey-cli`. | Healthcheck de Valkey fallaría. | Confirmar soporte. | `VERIFICADO`: `NOAUTH` sin clave y `PONG` con `REDISCLI_AUTH`. |
| R-08 | `vm.max_map_count` bajo en el host. | OpenSearch falla al arrancar. | Configurar 262144 en el host. | `VERIFICADO`: valor 262144 activo en Debian 13 host. |
| R-09 | OpenSearch en modo single-node. | Sin alta disponibilidad. | Aceptado solo en desarrollo local. | `ACEPTADO` |
| R-10 | `docker compose down -v` borra datos. | Pérdida irreversible de volúmenes. | Ejecución bajo autorización explícita. | `VERIFICADO`: Reconstrucción limpia ejecutada y documentada en README.md. |
| R-11 | Placeholders `CAMBIAR_ESTO` en `.env`. | Arranque con contraseñas por defecto. | Chequeo explícito ignorando líneas comentadas. | `VERIFICADO`: Validación incluida en README.md. |
| R-12 | `POSTGRES_USER` es superusuario. | Salta RLS. | Roles separados `alma_migrator` y `alma_app` (A3 y D-L1 aprobadas). | Decisión aprobada; implementación diferida al Incremento 1 (`PENDIENTE`). |
| R-13 | `noeviction` en Valkey. | Rechazo de escrituras al llenar memoria. | Documentado; ajustar `VALKEY_MAXMEMORY`. | `DOCUMENTADO` |
| R-14 | `POSTGRES_PASSWORD` en `docker inspect`. | Fuga local de credenciales. | Evitar `docker compose config` sin `-q`. | `DOCUMENTADO` |
| R-15 | Comandos asumen shell POSIX. | Fallos en Windows. | Trabajo en Linux nativo (Debian 13). | `VERIFICADO`: Entorno Debian 13 nativo. |
| R-16 | Permisos de secretos (`uid 999`). | Valkey no arranca por `Permission denied`. | Secretos con propietario `uid 999` y modo `600`. | `VERIFICADO`: Corregido y documentado en README.md. |
| R-17 | Antigüedad de imagen `valkey/valkey:8-bookworm` (~13 meses). | Parches de seguridad no incorporados. | Evaluar ramas recientes en la matriz de versiones. | `ABIERTO` |
| R-18 | Archivos truncados o vacíos por copia/pegado SSH. | Configuración o scripts incompletos. | Verificación de tamaño (`test -s`) y reconstrucción desde migraciones. | `VERIFICADO`: `test -s` en `valkey.conf` e inspección de archivos integrados. |
