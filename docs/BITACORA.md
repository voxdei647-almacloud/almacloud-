# Bitácora de Avance — Backend ALMA CLOUD

## Entorno y Roles de Base de Datos
| Rol de BD | Propósito | Atributos | Uso actual |
|-----------|-----------|-----------|------------|
| `alma_dev` | Superusuario local | Superuser, Bypass RLS | Usado por el host / migraciones locales |
| `alma_migrator` | Dueño del esquema | Cannot login | Ejecuta DDL |
| `alma_app` | App Backend | Login, sin super, sin bypass | Usado por FastAPI (vía `POSTGRES_APP_USER`) |

## Hitos y Cambios

### 2026-10-18 — Reestructuración a Control Plane y Admin Router (Rama: `refactor/control-plane-only`)
- **Limpieza:** Eliminados `opensearch`, `telemetry`, `ml_engine`, `alert_engine`, `suricata_parser`. 616 líneas borradas.
- **Migración 0005:** Añadidas columnas `plan`, `status` y `updated_at` a `alma.tenants`.
- **Nuevo Módulo:** `admin.py` con 5 endpoints GET para el dashboard (capa de agregación).
- **Testing:** Infraestructura base de `pytest` creada. 6 tests pasando (mockeados, sin DB).

### 2026-10-18 — Incremento 0007: Seguridad y RLS (Rama: `feat/inc-0007-security`)
- **Hallazgo:** RLS ya estaba configurado parcialmente en las migraciones (0001-0004), pero con `set_config(..., false)` (session-level), lo cual es inseguro con connection pooling.
- **Acción:** Migrar a `SET LOCAL` (transaction-level) y ajustar políticas para permitir acceso cross-tenant a `super_admin`.
