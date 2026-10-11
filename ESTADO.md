# Estado del Proyecto ALMA CLOUD

## Fase 0: Entorno Base y Orquestación Docker Compose
- [x] Corrección de contextos de build para Backend y Frontend
- [x] Variables de entorno `.env` alineadas (`POSTGRES_APP_PASSWORD`)
- [x] Secretos y permisos de Valkey configurados (Autenticación verificada)
- [x] Salud de OpenSearch confirmada (`status: green`)
- [x] Sintaxis ESM corregida en Frontend (`node:http`)
- [x] Proxy Nginx sirviendo tráfico restringido a `127.0.0.1:80`
- **Estado:** COMPLETADO Y VERIFICADO (12/12 SUITES PASS)

## Fase 1: Capa de Datos, Autenticación, Tenants y RLS
- [x] Estructura base de base de datos y esquema `alma`
- [x] Migraciones relacionales aplicadas (`tenants`, `users`, `sensors`, `audit_logs`)
- [x] Aplicación de políticas de PostgreSQL Row Level Security (RLS)
- [x] Ingesta masiva Bulk, Suricata EVE JSON y Motor de Alertas
- [x] Prototipo UI / Dashboard SOC servido vía Nginx
- **Estado:** COMPLETADO Y VERIFICADO (Línea Base Opción A)

## Bloque B: Evolución de Arquitectura y Endurecimiento (En Progreso)
- [ ] Transición de JWT HS256 a RS256 (ADR-D2)
- [ ] Cercado de Motor ML (`ENABLE_ML_DETECTION=false`)
- [ ] Reestructuración de RBAC (`super_admin` vs `tenant_admin`)
- [ ] Evaluación de Frontend Refine.dev (ADR-D1)
