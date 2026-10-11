# ALMA CLOUD — Bitácora de Avance y Estado del Sistema

## 1. Infraestructura Base (Fase 0) — COMPLETADA
- **Docker Engine / Compose**: Instalados y verificados.
- **Servicios Activos (Docker Compose)**:
  - `postgres` (`postgres:16-bookworm`): Motor relacional principal.
  - `valkey` (`valkey/valkey:8-bookworm`): Caché de alta velocidad e imágenes de estado.
  - `opensearch` (`opensearchproject/opensearch:2.19.6`): Motor de búsqueda y SIEM/SOC para telemetría.
- **Configuración**: Secretos generados (`secrets/valkey_password`), `.env` configurado, `vm.max_map_count=262144`.

---

## 2. Capa de Datos y Seguridad Multi-Tenant — COMPLETADA

### Incremento 1a: Esquema Base y Aislamiento RLS
- **Roles PostgreSQL**:
  - `alma_migrator`: Administrador DDL y dueño del esquema `alma`.
  - `alma_app`: Rol restringido DML de la aplicación (sin `BYPASSRLS`, `NOSUPERUSER`).
- **Tablas**: `alma.tenants`, `alma.sensors`.
- **Seguridad**: `ENABLE ROW LEVEL SECURITY` y `FORCE ROW LEVEL SECURITY` activos.
- **Verificación**: Suite de 12 pruebas de aislamiento (+ prueba negativa de detección de vulnerabilidades).

### Incremento 2: Credenciales y Enrolamiento Atómico
- **Tablas**:
  - `alma.sensor_credentials`: Separación de canales de `control` y `telemetry` (hashes SHA-256).
  - `alma.enrollment_tokens`: Tokens de enrolamiento de un solo uso con fecha de expiración.
- **Lógica Atómica**: Función `alma.enroll_sensor()` (`SECURITY DEFINER`) para canje de token, registro de sensor y expedición de credenciales en una sola transacción.
- **Verificación**: Pruebas `E1-E4` aprobadas (rechazo de tokens usados y expirados).

### Incremento 3: Registros de Auditoría Inmutables
- **Tabla**: `alma.audit_logs` con aislamiento RLS por `tenant_id`.
- **Inmutabilidad RDBMS**: Permisos explícitos asignados únicamente a `SELECT` e `INSERT` para `alma_app`. Modificaciones (`UPDATE`) y eliminaciones (`DELETE`) bloqueadas a nivel de motor.
- **Verificación**: Pruebas `A1-A4` aprobadas.

### Incremento 4: Telemetría y Caché NoSQL Multi-Tenant
- **OpenSearch**:
  - Plantilla `alma-telemetry-template` aplicada para índices `alma-telemetry-*`.
  - Mapeo estricto con `tenant_id` (`keyword`) para búsquedas SIEM aisladas.
- **Valkey**:
  - Estructura de claves con espacio de nombres `tenant:<tenant_id>:sensor:<sensor_id>:status`.
  - Políticas de expiración automática (TTL) validadas.
- **Verificación**: Búsqueda por término exacto en OpenSearch y operaciones de caché en Valkey confirmadas (`OS1-OS3`, `VK1`).

---

## 3. Próximo Hito: Backend Python / FastAPI (Fase 1)
- Estructuración de paquetes en `apps/backend/`.
- Configuración de conexión con SQLAlchemy / AsyncPG + Alembic.
- Middleware de inyección de contexto de tenant (`app.current_tenant_id`).
