# ALMA CLOUD — Entorno de Desarrollo y Producción Local

Plataforma de ciberseguridad y telemetría multi-tenant basada en microservicios y contenedores Docker.

## Estado del Sistema
- **Estado General:** 100% Funcional y Validado vía Suite Integral E2E (`scripts/run_all_tests.sh`).
- **Backend:** FastAPI (Python 3.13) con arquitectura asíncrona, JWT Bearer Auth y RBAC.
- **Base de Datos Relacional:** PostgreSQL 16 con Row Level Security (RLS) habilitado (`alma.tenants`, `alma.sensors`, `alma.users`, `alma.audit_logs`).
- **Caché y Live Status:** Valkey 8 con autenticación por archivo de secretos.
- **Búsqueda y Telemetría:** OpenSearch 2.19.6 con mapeo directo de `tenant_id` (`keyword`) y plantillas configuradas.
- **Proxy Inverso:** Nginx con resolución DNS interna de Docker (`127.0.0.11`).
- **Motor ML:** Inferencia en tiempo real mediante `IsolationForest` para detección de anomalías.

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

### Verificar

```bash
curl -s http://127.0.0.1:8000/healthz
# {"status":"healthy","service":"ALMA Cloud"}
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

Cubre 6 pruebas negativas (cross-tenant, JWT manipulado, JWT expirado, API Key inválida, API Key cross-tenant, sin auth, JWT sin `tenant_id`) más rate limiting (HTTP 429).

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

- **Usuarios humanos**: JWT RS256 con `tenant_id` y `role` en el payload. Emitido por `/auth/login`.
- **Agentes sensores**: API Key por header `X-API-Key`. Validada contra `alma.sensor_credentials` (JOIN por `sensor_id` y `tenant_id`, `hmac.compare_digest`).
- **Enrollment**: clave compartida (`ENROLLMENT_KEY`) + `X-Tenant-ID`. Genera API Key del canal `control`.

### Modelo de tenant

- Multi-tenant con Row-Level Security (RLS) de PostgreSQL.
- El backend conecta como `alma_app` (rol sin superusuario, sin `BYPASSRLS`).
- Contexto de tenant inyectado por request en `app.current_tenant_id`.

---

## Problemas conocidos

La línea base actual tiene los siguientes huecos identificados y pendientes de corrección. **No usar en producción hasta cerrarlos.**

| # | Problema | Severidad |
|---|---|---|
| 1 | `POST /api/v1/auth/register` es público y acepta `role` del cuerpo. Explotable con roles permitidos por `users_role_check` (p. ej. `analyst`) | 🔴 Crítico |
| 2 | `config.py` cae a `alma_dev` (superusuario) si falta la credencial de `alma_app` | 🔴 Crítico |
| 3 | `database.py` usa `set_config(..., false)` (sesión, no transacción). Riesgo de fuga entre conexiones del pool | 🟠 Alto |
| 4 | `deps.py` acepta `X-Tenant-ID` como fuente de autorización cuando no hay JWT | 🟠 Alto |
| 5 | `users_role_check` no permite `super_admin` ni `tenant_admin`. La rama de roles de plataforma en `require_roles(...)` es código muerto | 🟠 Alto |
| 6 | JWT no exige `exp` presente; sin `kid` para rotación de claves | 🟡 Medio |
| 7 | `alma_migrator` tiene login habilitado; debería ser `NOLOGIN` en producción | 🟡 Medio |
| 8 | Credencial de `alma_app` en variable de entorno (12 caracteres) en lugar de archivo en `secrets/` con 32+ bytes | 🟡 Medio |

Ver `ALMA_CLOUD_MASTER_CONTEXT.md` para el detalle completo y el plan de cierre.

---

## Convenciones

- **Puertos solo en loopback** (`127.0.0.1`). Ningún servicio se publica a la red en desarrollo.
- **Secretos nunca en Git.** `.env` y `secrets/*` ignorados. Ver `.gitignore`.
- **Migraciones SQL versionadas** en `apps/backend/db/migrations/`.
- **Pruebas por comportamiento** en `scripts/`, no unitarias. Se ejecutan contra el backend real en `127.0.0.1:8000`.

---

## Licencia

Pendiente de definir.
