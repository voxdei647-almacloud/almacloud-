# Bitácora de Avance — Backend ALMA CLOUD

## Entorno y Roles de Base de Datos
| Rol de BD | Propósito | Atributos | Uso actual |
|-----------|-----------|-----------|------------|
| `alma_dev` | Superusuario local | Superuser, Bypass RLS | Usado por el host / migraciones locales |
| `alma_migrator` | Dueño del esquema | Cannot login | Ejecuta DDL |
| `alma_app` | App Backend | Login, sin super, sin bypass | Usado por FastAPI (vía `POSTGRES_APP_USER`) |

## Hitos y Cambios

### 2026-10-18 — Limpieza Técnica Pre-Producción (Rama: `chore/tech-debt-cleanup`)
- **Docker Prod:** Eliminado el servicio y volumen de OpenSearch en `docker-compose.prod.yml`. Restaurada la red `alma_network`.
- **Pydantic v2:** Migrado `class Config` a `model_config = ConfigDict(...)` y `example=` a `json_schema_extra`.
- **FastAPI Lifespan:** Reemplazado `@app.on_event` por `@asynccontextmanager`.
- **Tests:** 6/6 pasando, 0 warnings.

### 2026-10-18 — Integración E2E y Facturación Real (Fases B y C)
- **Autenticación Cross-VM:** El SIEM (VM 105) consume exitosamente los endpoints de ALMA (VM 107) usando `ALMA_SERVICE_TOKEN`.
- **Login Arreglado:** Se resolvió el bug de RLS en `audit_logs` durante el login. El JWT ahora se emite con el `tenant_id` real.
- **Facturación Real:** Implementada tabla `billing_snapshots` (Migración 0007) y lógica de cálculo de MRR en `/admin/billing/metrics` (devuelve `_mock: false`).
- **Validación Frontend:** Los logs de Flask confirman que el dashboard de Armando consume los 4 endpoints de admin correctamente (HTTP 200).

### 2026-10-18 — Endpoints de Escritura (Admin CRUD)
- Añadidos endpoints POST, PATCH y DELETE a `admin.py`.
- Otorgados permisos de UPDATE/DELETE a `alma_app` en PostgreSQL.
- Probado exitosamente: creación de usuario, suspensión de tenant y revocación de usuario.

### 2026-10-18 — Reestructuración a Control Plane y Admin Router (Rama: `refactor/control-plane-only`)
- **Limpieza:** Eliminados `opensearch`, `telemetry`, `ml_engine`, `alert_engine`, `suricata_parser`. 616 líneas borradas.
- **Migración 0005:** Añadidas columnas `plan`, `status` y `updated_at` a `alma.tenants`.
- **Nuevo Módulo:** `admin.py` con 5 endpoints GET para el dashboard (capa de agregación).
- **Testing:** Infraestructura base de `pytest` creada. 6 tests pasando (mockeados, sin DB).

### 2026-10-18 — Incremento 0007: Seguridad y RLS (Rama: `feat/inc-0007-security`)
- **Hallazgo:** RLS ya estaba configurado parcialmente en las migraciones (0001-0004), pero con `set_config(..., false)` (session-level), lo cual es inseguro con connection pooling.
- **Acción:** Migrar a `SET LOCAL` (transaction-level) y ajustar políticas para permitir acceso cross-tenant a `super_admin`.