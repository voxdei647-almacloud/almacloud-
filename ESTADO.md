# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Validación E2E de API Backend FastAPI y Aislamiento RLS.

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **Incremento 1a:** Roles `alma_migrator` / `alma_app` con RLS forzado (`12/12 PASS`).
- **Incremento 2:** Credenciales independientes y enrolamiento atómico (`PASS E1-E4`).
- **Incremento 3:** Auditoría inmutable (`PASS A1-A4`).
- **Incremento 4:** Index Template en OpenSearch y caché Valkey (`PASS OS1-OS3, VK1`).

## 3. Capa de Servicios Backend (FastAPI / Python)
- **Capa de Datos:** SQLAlchemy 2.0 Async + AsyncPG ejecutando bajo el rol no-superusuario `alma_app`.
- **Inyección RLS:** Contexto de sesión inyectado mediante encabezado HTTP `X-Tenant-ID` en `deps.py`.
- **Pruebas API v1:** Endpoint `/api/v1/sensors` con aislamiento estricto RLS verificado (`PASS API1-API4`).

## 4. Próximos Pasos
- Endpoint de auditoría inmutable (`GET /api/v1/audit-logs`).
- Integración de clientes asíncronos para **Valkey** (estado de sensores) y **OpenSearch** (telemetría).
- Capa de autenticación y firmado JWT/mTLS para comunicación con agentes de borde.
