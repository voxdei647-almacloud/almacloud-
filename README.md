# ALMA CLOUD — Entorno de Desarrollo y Producción Local

Plataforma de ciberseguridad y telemetría multi-tenant basada en microservicios y contenedores Docker.

## Estado del Sistema

**Línea base:** `ADOPTADA, PARCIALMENTE VERIFICADA`. Las suites funcional (12/12) y de seguridad (13/13) pasan sobre el entorno actual. Existen deudas de hardening en curso (ver "Problemas conocidos"). **No usar en producción sin cerrarlas.**

- **Backend:** FastAPI (Python 3.13) con SQLAlchemy async, JWT RS256, RBAC multi-rol y aislamiento multi-tenant con RLS de PostgreSQL.
- **Autenticación de usuarios:** `/auth/register` protegido por `require_roles("super_admin","tenant_admin")` con jerarquía de roles. El primer `super_admin` se crea con `scripts/bootstrap_admin.py` (ver "Arranque rápido").
- **Base de Datos:** PostgreSQL 16 con Row Level Security forzado en `alma.tenants`, `alma.users`, `alma.sensors`, `alma.audit_logs`, `alma.sensor_credentials`. El backend conecta como `alma_app` (sin superusuario, sin `BYPASSRLS`).
- **Caché y Live Status:** Valkey 8 con autenticación por archivo de secretos.
- **Búsqueda y Telemetría:** OpenSearch 2.19.6 con índice `alma-telemetry-v1`.
- **Proxy Inverso:** Nginx con resolución DNS interna de Docker.
- **Motor ML:** Inferencia `IsolationForest` para scoring de anomalías. Fuera del MVP según Plan Maestro; actualmente activo en el pipeline de ingesta.
- **Suites:** 12 bloques funcionales + 13 pruebas negativas de seguridad. Todas en PASS en el entorno actual.

---

## Requisitos del Host (Debian 13 / Linux POSIX)
- Docker Engine y Docker Compose v2.
- `vm.max_map_count` de al menos 262144 (`sudo sysctl -w vm.max_map_count=262144`).
- Entorno virtual Python con dependencias instaladas (`.venv`).

---

## Despliegue de Servicios con Docker Compose

```bash
# Pull e inicio de contenedores en segundo plano
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# Verificar estado de los contenedores
docker compose -f docker-compose.prod.yml ps
Inicialización y Migraciones de Base de DatosBash# Bootstrap de roles y esquema principal
docker compose -f docker-compose.prod.yml exec -T postgres psql -U alma_dev -d alma_cloud -v ON_ERROR_STOP=1 < apps/backend/db/bootstrap/001_roles.sql

# Migraciones en orden
docker compose -f docker-compose.prod.yml exec -T postgres psql -U alma_dev -d alma_cloud -v ON_ERROR_STOP=1 < apps/backend/db/migrations/0001_tenants_sensors.sql
docker compose -f docker-compose.prod.yml exec -T postgres psql -U alma_dev -d alma_cloud -v ON_ERROR_STOP=1 < apps/backend/db/migrations/0002_credentials_and_enrollment.sql
docker compose -f docker-compose.prod.yml exec -T postgres psql -U alma_dev -d alma_cloud -v ON_ERROR_STOP=1 < apps/backend/db/migrations/0002_users.sql
docker compose -f docker-compose.prod.yml exec -T postgres psql -U alma_dev -d alma_cloud -v ON_ERROR_STOP=1 < apps/backend/db/migrations/0003_audit_logs.sql

# Sincronización de plantilla en OpenSearch
curl -X PUT "[http://127.0.0.1:9200/_index_template/telemetry_template](http://127.0.0.1:9200/_index_template/telemetry_template)" \
     -H "Content-Type: application/json" \
     -d @apps/backend/opensearch/0001_telemetry_template.json
Ejecución de Pruebas Integrales (E2E)Para ejecutar la suite automatizada de 12 módulos de prueba:Bashbash scripts/run_all_tests.sh
Cobertura de la Suite E2E:API Base y RLS Postgres: /healthz, aislamiento multi-tenant y auditoría.Valkey Async: Heartbeat de agentes y estados online.OpenSearch Telemetría: Indexación y aislamiento de consultas por tenant_id.JWT & Seguridad: Emisión de tokens, RBAC (admin, analyst, sensor) y /auth/me.Agentes: Enrolamiento por clave y autenticación con X-Tenant-ID.Ingesta Especializada: Lotes Bulk y registros Suricata EVE JSON.Motor de Alertas y ML: Reglas de severidad y cálculo de anomaly_score vía IsolationForest.Interfaz Web / SOC: Servidor de recursos estáticos en /ui/index.html y /ui/dashboard.html.Puertos y ServiciosServicioPuerto LocalContenedor / Red InternaNginx Proxy80proxyFastAPI Backend8000backendPostgreSQL 165432postgresValkey 86379valkeyOpenSearch9200opensearchEOF

# ALMA CLOUD — Backend de plataforma SOC/XDR multi-tenant

Backend FastAPI para la plataforma ALMA CLOUD (VOX DEI). Gestiona autenticación de usuarios y agentes, tenants aislados con Row-Level Security de PostgreSQL, ingesta de telemetría (Suricata EVE JSON y eventos genéricos), motor de alertas y una capa experimental de detección por ML.

> **Estado de la línea base: `ADOPTADA, NO VERIFICADA`.** Las suites E2E (12 funcionales + 6 de seguridad) pasan en el entorno de desarrollo, pero existen vulnerabilidades conocidas y pendientes de corregir. Ver "Problemas conocidos" más abajo. **No usar en producción.**

---

## Stack

| Componente | Versión | Rol |
|---|---|---|
| Python | 3.13 | Runtime |
| FastAPI | (instalada) | API HTTP |
| PostgreSQL | 16 (`postgres:16-bookworm`) | BD transaccional, RLS multi-tenant |
| Valkey | 8 (`valkey/valkey:8-bookworm`) | Heartbeats, caché, rate limiting |
| OpenSearch | 2.19.6 | Almacén de telemetría y búsqueda |
| SQLAlchemy | 2.x async + asyncpg | ORM y capa de datos |
| python-jose | RS256 | Firma/verificación de JWT |
| Argon2id | vía `argon2-cffi` | Hash de contraseñas humanas |

---

## Arranque rápido (desarrollo)

### Requisitos del host

```bash
# Necesario para OpenSearch
sudo sysctl -w vm.max_map_count=262144
# Persistente
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.d/99-opensearch.conf
```

### Preparar secretos

```bash
cp .env.example .env
# Generar secretos locales (NO commitear .env)
openssl rand -base64 32 > secrets/postgres_app_password
openssl rand -base64 32 > secrets/valkey_password
chmod 600 secrets/postgres_app_password secrets/valkey_password
```

Los archivos de `secrets/` están ignorados por Git (`secrets/*`). Solo `.gitkeep` se versiona.

### Levantar servicios e iniciar backend

```bash
docker compose up -d
docker compose ps                    # los tres servicios deben estar healthy

source .venv/bin/activate
export PYTHONPATH="$(pwd)/apps/backend"

python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### Inicializar el primer `super_admin` (una sola vez)

```bash
# 1. Añadir a .env las variables de bootstrap (con password aleatorio)
NEW_PW=$(openssl rand -hex 24)
cat >> .env <<EOF

# Bootstrap super_admin (dev)
BOOTSTRAP_ADMIN_EMAIL=admin@alma.io
BOOTSTRAP_ADMIN_PASSWORD=${NEW_PW}
BOOTSTRAP_TENANT_ID=00000000-0000-0000-0000-000000000000
BOOTSTRAP_TENANT_NAME=Plataforma ALMA System
BOOTSTRAP_TENANT_SLUG=alma-platform
EOF

# 2. Aplicar migración 0004 (roles CHECK ampliado)
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -f - < apps/backend/db/migrations/0004_users_role_check_extend.sql

# 3. Crear el super_admin (idempotente)
set -a; source .env; set +a
PYTHONPATH=apps/backend .venv/bin/python scripts/bootstrap_admin.py
curl -s http://127.0.0.1:8000/healthz

curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: 00000000-0000-0000-0000-000000000000" \
  -d "{\"email\": \"$BOOTSTRAP_ADMIN_EMAIL\", \"password\": \"$BOOTSTRAP_ADMIN_PASSWORD\"}" | head -c 100
# {"access_token":"eyJhbGciOiJSUzI1NiIs...
```

---

## Suites de pruebas

### Suite funcional (E2E)

```bash
ENABLE_RATE_LIMIT=true ./scripts/run_all_tests.sh
```

Cubre 12 bloques: API base, Valkey, OpenSearch, auth JWT, protección JWT, RBAC, enrollment de sensores, autenticación de agente por API Key, ingesta bulk, EVE JSON, motor de alertas, UI y ML.

### Suite de seguridad y abuso

```bash
./scripts/run_security_tests.sh
```

Cubre 13 pruebas negativas (SEC_NEG1-13) más rate limiting (RATE1):

- **Cross-tenant:** DELETE sobre recurso ajeno, API Key de A usada contra sensor de B
- **JWT:** firma manipulada, expirado, sin `tenant_id`
- **API Key:** inválida, cross-tenant, sin autenticación
- **`/register`:** sin token (401), rol insuficiente (403), escalada de privilegios (403)
- **Aislamiento de datos:** sin exposición de `api_key`/`key_hash`/`password` en listados
- **Hash de contraseñas:** verificación Argon2id en BD
- **Validación de entrada:** rol inválido → 422 (Pydantic)
- **Cabeceras HTTP de seguridad:** `nosniff`, `DENY`, `HSTS`, `CSP`
- **Rate limiting:** 4.º login → 429

---

## Arquitectura

```
apps/backend/app/
├── api/
│   ├── deps.py                    Dependencias: get_db, require_roles, verify_token
│   └── v1/
│       ├── auth.py                /register, /login, /me
│       ├── sensors.py             CRUD, enrollment, heartbeat, status
│       ├── telemetry.py           eventos, bulk, suricata/eve-batch
│       └── audit.py               /audit-logs
├── core/
│   ├── config.py                  Settings (pydantic-settings)
│   ├── database.py                Engine async, get_tenant_db
│   ├── security.py                RS256, Argon2id
│   ├── valkey.py                  Cliente Valkey
│   └── opensearch.py              Cliente OpenSearch
├── models/domain.py               User, Sensor, AuditLog, ...
└── schemas/domain.py              UserCreate, TokenRead, ...

apps/backend/db/
├── bootstrap/001_roles.sql        Roles NOLOGIN propuestos
├── migrations/                    Esquema, RLS
└── tests/                         Pruebas negativas de RLS
```

### Modelo de autenticación

- **Usuarios humanos:** JWT RS256 con `tenant_id` y `role` en el payload. Emitido por `/auth/login`. Algoritmo fijo (`RS256`), `iss`/`aud`/`exp` validados.
- **Registro de usuarios (`POST /auth/register`):** protegido con `require_roles("super_admin", "tenant_admin")`.
  - `tenant_admin` solo puede crear roles `{admin, analyst, sensor}` en su propio tenant.
  - `super_admin` puede crear cualquier rol del sistema.
  - El `tenant_id` del nuevo usuario se deriva del token del creador; `X-Tenant-ID` se ignora.
- **Bootstrap:** el primer `super_admin` se crea con `scripts/bootstrap_admin.py`. Requiere las variables `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_PASSWORD`, `BOOTSTRAP_TENANT_*` en `.env`.
- **Agentes sensores:** API Key por header `X-API-Key`. Validada contra `alma.sensor_credentials` (JOIN por `sensor_id` y `tenant_id`, `hmac.compare_digest`).
- **Enrollment:** clave compartida (`ENROLLMENT_KEY`) + `X-Tenant-ID`. Genera API Key del canal `control`.

### Modelo de tenant

- Multi-tenant con Row-Level Security (RLS) de PostgreSQL.
- El backend conecta como `alma_app` (rol sin superusuario, sin `BYPASSRLS`).
- Contexto de tenant inyectado por request en `app.current_tenant_id`.

---

## Problemas conocidos

### Cerrados en la sesión 2026-10-12 (Incremento 0004)

| # | Problema | Commit |
|---|---|---|
| C1 | `POST /auth/register` público con `role` del cuerpo | `e61671d` |
| C2 | `config.py` con fallback silencioso a `alma_dev` | `6a0721c` |
| C3 | `users_role_check` incompleto (sin `super_admin`/`tenant_admin`) | `5205b50` |
| C4 | Bearer del heartbeat sin `tenant_id` (bypass cross-tenant) | `ab6682e` |

### Abiertos (no usar en producción hasta cerrarlos)

| # | Problema | Severidad | Deuda |
|---|---|---|---|
| 1 | `database.py` usa `set_config(..., false)` (sesión, no transacción). Riesgo de fuga entre conexiones del pool | 🟠 Alto | Inc. 0007 |
| 2 | `deps.py` acepta `X-Tenant-ID` como fuente de autorización cuando no hay JWT | 🟠 Alto | Inc. 0005 |
| 3 | JWT no exige `exp` presente ni `kid` para rotación de claves | 🟡 Medio | Inc. 0006 |
| 4 | `alma_migrator` tiene login habilitado; debería ser `NOLOGIN` en producción | 🟡 Medio | — |
| 5 | `python-jose` con CVE-2026-85394 (mitigado por diseño: `algorithms=["RS256"]` fijo) | 🟡 Medio | Inc. 0008 |
| 6 | Credencial de `alma_app` en variable de entorno en lugar de archivo en `secrets/` con 32+ bytes | 🟡 Medio | — |

Ver `docs/audits/` para reportes y análisis detallados, y `ALMA_CLOUD_MASTER_CONTEXT.md` para el plan completo de incrementos.

---

## Convenciones

- **Puertos solo en loopback** (`127.0.0.1`). Ningún servicio se publica a la red en desarrollo.
- **Secretos nunca en Git.** `.env` y `secrets/*` ignorados. Ver `.gitignore`.
- **Migraciones SQL versionadas** en `apps/backend/db/migrations/`.
- **Pruebas por comportamiento** en `scripts/`, no unitarias. Se ejecutan contra el backend real en `127.0.0.1:8000`.

---

## Licencia

Pendiente de definir.
