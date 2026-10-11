# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Cierre de Capa de Datos e Infraestructura Base.

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.
- Secretos de Valkey con permisos `600` (`uid 999`).
- Persistencia y healthchecks verificados.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **Incremento 1a:** Roles `alma_migrator` / `alma_app` con RLS forzado (`12/12 PASS`).
- **Incremento 2:** Credenciales independientes y enrolamiento atómico (`PASS E1-E4`).
- **Incremento 3:** Auditoría inmutable con denegación de UPDATE/DELETE (`PASS A1-A4`).
- **Incremento 4:** Index Template en OpenSearch y caché con TTL en Valkey (`PASS OS1-OS3, VK1`).

## 3. Próximo Hito: Backend Python / FastAPI (Fase 1)
- Estructuración de paquetes en `apps/backend/`.
- Configuración de SQLAlchemy Async + AsyncPG + Alembic.
- Middleware de inyección de contexto de tenant (`app.current_tenant_id`).
