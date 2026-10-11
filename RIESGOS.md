# RIESGOS

Estados basados únicamente en evidencia de terminal pegada (2026-10-11). `VERIFICADO` = hay salida real. `PENDIENTE` = sin evidencia o sin decidir.

| ID | Riesgo | Impacto | Mitigación | Estado |
|---|---|---|---|---|
| R-01 | Etiquetas flotantes de las imágenes | Reproducibilidad | Etiqueta más digest en `.env.example` y `.env` | VERIFICADO la fijación (`grep` y `docker compose ps` con `@sha256`). La fijación no aprueba versiones (V1 pendiente) |
| R-02 | OpenSearch con seguridad desactivada | Sin autenticación ni aislamiento entre tenants | Solo loopback; nunca producción | ACEPTADO solo en desarrollo local |
| R-03 | Clave de Valkey en la lista de procesos | Exposición local del secreto | Secreto montado e `include` | VERIFICADO (`docker compose top valkey` sin `requirepass`) |
| R-04 | Licencia Valkey/Redis | Riesgo legal | No congelar sin revisión legal | PENDIENTE |
| R-05 | Healthchecks sin probar en las imágenes reales | Falsos positivos o negativos | Probar con las imágenes reales | VERIFICADO (tres servicios `healthy` más de 2 horas) |
| R-06 | `curl` ausente en OpenSearch | Healthcheck fallaría | Confirmar disponibilidad | VERIFICADO |
| R-07 | `REDISCLI_AUTH` no soportado en `valkey-cli` | Healthcheck de Valkey fallaría | Confirmar soporte | VERIFICADO (`NOAUTH` y `PONG`) |
| R-08 | `vm.max_map_count` bajo | OpenSearch no arranca | Configurar 262144 | VERIFICADO |
| R-09 | OpenSearch de un solo nodo | Sin alta disponibilidad | Solo desarrollo | ACEPTADO |
| R-10 | `docker compose down -v` borra datos | Pérdida irreversible | Solo con autorización; documentado en README | VERIFICADO el procedimiento (`down -v` y reconstrucción ejecutados con autorización) |
| R-11 | Placeholders `CAMBIAR_ESTO` en `.env` | Arranque con contraseña conocida | Comprobación manual excluyendo comentarios | VERIFICADO manualmente; no hay bloqueo automático |
| R-12 | `POSTGRES_USER` es superusuario | Salta RLS | No usarlo como rol de aplicación; roles `alma_*` | Documentado. Roles: PROPUESTOS (Incremento 1a), sin ejecutar |
| R-13 | `noeviction` en Valkey | Escrituras rechazadas al llenarse | Documentado; ajustar `VALKEY_MAXMEMORY` | Documentado; no probado |
| R-14 | `POSTGRES_PASSWORD` en `environment` | Visible en `docker inspect` y `docker compose config` | Usar `config -q`; evaluar `POSTGRES_PASSWORD_FILE` | ABIERTO; aceptado en desarrollo |
| R-15 | Comandos asumen shell POSIX | Fallos en CMD o PowerShell | Usar Linux o WSL2 | Documentado |
| R-16 | Permisos de secretos y uid del contenedor | Valkey no arranca si no lee el secreto | `chown 999` solo de los dos archivos, modo 600 | VERIFICADO funcionalmente. Depende del uid de esta imagen |
| R-17 | Imagen `valkey:8-bookworm` con compilación de hace ~13 meses | Parches de seguridad posiblemente ausentes | Revisar ramas más recientes antes de congelar la matriz | ABIERTO |
| R-18 | Pegar archivos largos con `cat <<EOF` por SSH | Archivos truncados o corruptos | `scp` y `sha256sum` | OCURRIÓ (README.md y RIESGOS.md del commit `2e28dd3`); corregido en este paquete |
