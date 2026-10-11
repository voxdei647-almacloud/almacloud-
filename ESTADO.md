# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Integración E2E de Autenticación de Agentes por API Key (7/7 Suites PASS).

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **Incremento 1a:** Roles `alma_migrator` / `alma_app` con RLS forzado (`12/12 PASS`).
- **Incremento 2:** Credenciales independientes y enrolamiento atómico (`PASS E1-E4`).
- **Incremento 3:** Auditoría inmutable (`PASS A1-A4`).
- **Incremento 4:** Index Template en OpenSearch y caché Valkey (`PASS OS1-OS3, VK1`).

## 3. Capa de Servicios Backend (FastAPI / Python)
- **Capa de Datos:** SQLAlchemy 2.0 Async + AsyncPG bajo el rol `alma_app` con RLS en `tenants`, `users`, `sensors` y `audit_logs` (`PASS API1-API5`).
- **Capa de Seguridad & Autenticación:** Hashing Argon2id, firmado/verificación JWT HS256, inyección de usuario (`get_current_user`) y protección Bearer (`PASS AUTH1-AUTH3, SEC1-SEC2`).
- **Control de Acceso (RBAC):** Restricción de permisos granular por roles (`admin`, `analyst`, `sensor`, `system`) (`PASS RBAC1-RBAC5`).
- **Enrolamiento y Autenticación de Sensores:** Endpoint `/api/v1/sensors/enrollment` y validación de `X-API-Key` para agentes distribuidos (`PASS ENROLL1-ENROLL2, SAK1-SAK2`).
- **Capa de Cache:** Valkey Async (`redis-py`) con espacio de nombres (`tenant:<id>:sensor:<id>:heartbeat`) y TTL de 5 min (`PASS VK1-VK3`).
- **Capa de Telemetría:** OpenSearch Async (`opensearch-py` + `aiohttp`) con filtro estricto por `tenant_id` (`PASS OS1-OS3`).

## 4. Próximos Pasos
- Endpoint de Ingesta Masiva por Lotes (Batch Ingestion) de eventos NIDS Suricata (`POST /api/v1/telemetry/events/batch`).
- Pipeline de Normalización EVE JSON (Suricata) a esquema unificado de alertas ALMA.
