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
