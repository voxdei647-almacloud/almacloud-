# ESTADO DEL PROYECTO — ALMA CLOUD

> **Última actualización:** Integración del Motor de IA / Machine Learning No Supervisado (12/12 Suites PASS - 100% de Pruebas Exitosas).

## 1. Infraestructura Base (Incremento 0)
- **PostgreSQL 16**, **Valkey 8** y **OpenSearch 2.19.6** operativos en Docker Compose.

## 2. Capa Relacional y NoSQL (Incrementos 1a a 4)
- **PostgreSQL RLS:** Tenant Isolation forzado para roles `alma_app` (`12/12 PASS`).
- **Enrolamiento Atómico & Auditoría:** Esquema relacional inmutable (`PASS E1-E4, A1-A4`).
- **OpenSearch & Valkey:** Index Templates y almacenamiento en caché asíncrono (`PASS OS1-OS3, VK1-VK3`).

## 3. Capa de Servicios Backend & Inteligencia Artificial
- **Capa de Datos:** SQLAlchemy 2.0 Async + AsyncPG bajo el rol `alma_app` (`PASS API1-API5`).
- **Seguridad & Autenticación:** Hashing Argon2id, firmado/verificación JWT HS256 y protección Bearer (`PASS AUTH1-AUTH3, SEC1-SEC2`).
- **Control de Acceso (RBAC):** Permisos de API restringidos por roles (`admin`, `analyst`, `sensor`, `system`) (`PASS RBAC1-RBAC5`).
- **Gestión de Sensores:** Enrolamiento seguro `/api/v1/sensors/enrollment` y verificación de `X-API-Key` (`PASS ENROLL1-ENROLL2, SAK1-SAK2`).
- **Ingesta & Normalización:** Inserción por lotes y parsing EVE Suricata (`POST /api/v1/telemetry/suricata/eve-batch`) (`PASS BATCH1, PARSER1, EVE1`).
- **Motor de Alertas & Notificaciones:** Evaluador `AlertRuleEngine` y despacho asíncrono a Webhooks (`PASS ALERT1-ALERT2`).
- **Motor de Inferencia de IA (ML):** Evaluador con `IsolationForest` (detección de anomalías), `KMeans` (clustering), categorización por Nivel de Riesgo y estadísticas agregadas por lote (`PASS ML1-ML2`).

## 4. Capa de Presentación / Frontend Web
- **Interfaz Base VOX DEI:** Portal de login y registro montado bajo `/ui/index.html` conectando con la API REST (`PASS UI1`).
- **SOC Operations Dashboard:** Consola interactiva en `/ui/dashboard.html` con gráficos de Chart.js y feed de Suricata EVE (`PASS UI2`).

## 5. Próximos Pasos
- Despliegue en GCP (Google Cloud Platform) con máquina `e2-standard-2` o clúster de producción con Nginx / TLS.

## [2026-10-11] - Estabilización de Capa de Datos y Ejecución Exitosa E2E (100%)

### Cambios y Correcciones Realizados:
1. **Autenticación PostgreSQL**: Sincronizado el rol `alma_app` con la contraseña de entorno `POSTGRES_APP_PASSWORD`. Se ejecutaron e inspeccionaron las migraciones SQL iniciales (`001_roles.sql` a `0003_audit_logs.sql`).
2. **OpenSearch Telemetría**: Cargada la plantilla `0001_telemetry_template.json` con `tenant_id` como tipo `keyword` nativo. Se ajustó el filtro en `apps/backend/app/api/v1/telemetry.py` para consultar directamente sobre el campo.
3. **Nginx Proxy**: Actualizada la configuración en `apps/proxy/conf.d/default.conf` con el resolver interno de Docker (`127.0.0.11`) para enrutar `/api` al backend y `/` al frontend.
4. **Validación E2E**: Cobertura del 100% aprobada en las 12 suites de pruebas integrales (`scripts/run_all_tests.sh`), incluyendo API Base, RLS, Valkey, OpenSearch, JWT, RBAC, Enrolamiento, Ingesta Bulk/EVE JSON, Motor de Alertas, Interfaz Web e Inferencia ML (IsolationForest).
