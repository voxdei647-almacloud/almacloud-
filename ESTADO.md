# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Validación E2E de Autenticación JWT, Valkey, OpenSearch y RLS Multi-tenant.

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **Incremento 1a:** Roles `alma_migrator` / `alma_app` con RLS forzado (`12/12 PASS`).
- **Incremento 2:** Credenciales independientes y enrolamiento atómico (`PASS E1-E4`).
- **Incremento 3:** Auditoría inmutable (`PASS A1-A4`).
- **Incremento 4:** Index Template en OpenSearch y caché Valkey (`PASS OS1-OS3, VK1`).

## 3. Capa de Servicios Backend (FastAPI / Python)
- **Capa de Datos:** SQLAlchemy 2.0 Async + AsyncPG bajo el rol `alma_app` con RLS en `tenants`, `users`, `sensors` y `audit_logs` (`PASS API1-API5`).
- **Capa de Seguridad & Autenticación:** Hashing Argon2id, firmado/verificación de Tokens JWT HS256 y aislamiento RLS de usuarios (`PASS AUTH1-AUTH3`).
- **Capa de Cache:** Valkey Async (`redis-py`) con espacio de nombres (`tenant:<id>:sensor:<id>:heartbeat`) y TTL de 5 min (`PASS VK1-VK3`).
- **Capa de Telemetría:** OpenSearch Async (`opensearch-py` + `aiohttp`) con filtro estricto por `tenant_id` (`PASS OS1-OS3`).

## 4. Próximos Pasos
- Dependencia `get_current_user` para extraer el usuario autenticado desde el Token Bearer.
- Control de Acceso Basado en Roles (RBAC: `admin`, `analyst`, `sensor`, `system`).
- Pruebas de integración de endpoints protegidos mediante cabecera `Authorization: Bearer <token>`.
