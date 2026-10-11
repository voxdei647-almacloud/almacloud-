# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Integración del Cliente OpenSearch Async e Ingesta/Consulta de Telemetría Multi-tenant.

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **Incremento 1a:** Roles `alma_migrator` / `alma_app` con RLS forzado (`12/12 PASS`).
- **Incremento 2:** Credenciales independientes y enrolamiento atómico (`PASS E1-E4`).
- **Incremento 3:** Auditoría inmutable (`PASS A1-A4`).
- **Incremento 4:** Index Template en OpenSearch y caché Valkey (`PASS OS1-OS3, VK1`).

## 3. Capa de Servicios Backend (FastAPI / Python)
- **Capa de Datos:** SQLAlchemy 2.0 Async + AsyncPG bajo el rol `alma_app` y tipos nativos (`PG_UUID`, `JSONB`, `INET`).
- **Capa de Cache:** Valkey Async (`redis-py`) con gestión de claves con espacio de nombres (`tenant:<id>:sensor:<id>:heartbeat`) y TTL de 5 min (`PASS VK1-VK3`).
- **Capa de Telemetría:** OpenSearch Async (`opensearch-py` + `aiohttp`) con consultas filtradas estrictamente por `tenant_id` (`PASS OS1-OS3`).
- **Pruebas API v1:** Endpoints `/api/v1/sensors`, `/api/v1/audit-logs` y `/api/v1/telemetry/events` con trazabilidad y aislamiento RLS/NoSQL verificado.

## 4. Próximos Pasos
- Módulo de Autenticación, hashing de contraseñas (Argon2) y firmado/validación de Tokens JWT por Tenant.
