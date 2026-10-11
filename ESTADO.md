# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Integración de Caché Valkey Async y Estado de Sensores en Tiempo Real.

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
- **Pruebas API v1:** Endpoints `/api/v1/sensors` y `/api/v1/audit-logs` con trazabilidad automática y aislamiento RLS verificado (`PASS API1-API5`).

## 4. Próximos Pasos
- Cliente asíncrono para **OpenSearch** (procesamiento y consulta de eventos NIDS/EDR).
- Módulo de Autenticación y firmado de Tokens JWT por Tenant.
