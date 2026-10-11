# ALMA CLOUD — Capa de datos: diagnóstico y propuesta (v0.1)

**Fecha:** 2026-10-09 · **Estado de todo este documento: `PROPUESTO`.** Nada de lo descrito está implementado ni verificado. Base: Plan Maestro (secciones 7, 9, 10), contexto maestro v1.4 y decisiones A1/A2 (cerradas) y A3/A5/A6, R1, C1 (pendientes).

Vocabulario de estado: `PROPUESTO` · `A REALIZAR POR EL USUARIO` · `REALIZADO (sin evidencia)` · `VERIFICADO (evidencia pegada)`.

---

## 1. Diagnóstico: qué existe realmente en persistencia

| Elemento | Estado | Evidencia |
|---|---|---|
| Servicios PostgreSQL / Valkey / OpenSearch en Compose | `PROPUESTO` (texto de 0.2-MODO-AVANCE v2 con hallazgos G1–G9 abiertos) | Texto en la conversación. No consta que los archivos se hayan creado ni ejecutado. |
| Roles de PostgreSQL (migraciones, aplicación) | No existe | Solo descritos como futuros |
| Tablas, migraciones Alembic, RLS, índices | No existe | — |
| Plantillas/índices de OpenSearch, política de retención | No existe | — |
| Esquemas Pydantic (ALMA Common Schema) | No existe | Prompt 0.3 sin ejecutar |
| Pruebas de persistencia/aislamiento | Ninguna ejecutada | — |

**Conclusión:** declarar los tres servicios en Compose no equivale a una capa de datos. Hoy hay **cero** persistencia implementada y **cero** verificada.

## 2. Responsabilidades (según decisiones vigentes y Plan, sección 9)

| Sistema | Responsable de | No debe contener |
|---|---|---|
| **PostgreSQL 16** | Fuente de verdad transaccional: tenants, identidad, RBAC, sensores y credenciales (solo hash), tokens de enrolamiento, auditoría, configuración y, más adelante, comandos e incidentes | Telemetría masiva ni copias de eventos |
| **OpenSearch 2.x** | Eventos, alertas históricas y búsqueda de series de tiempo | Identidad, credenciales, estado de sesiones; ninguna decisión de autorización |
| **Valkey (C1 pendiente)** | Estado efímero reconstruible: liveness de sensores (TTL), contadores de rate limiting, cachés, broker de workers de notificación | Nada que no pueda perderse (revocaciones, auditoría, credenciales) |

## 3. Modelo relacional inicial (todas las tablas son candidatas hasta aprobar el modelo)

**Convenciones propuestas:** PK `uuid`; fechas `timestamptz`; enumeraciones como `text` + `CHECK` (más fáciles de migrar que `ENUM`); toda tabla tenant-scoped lleva `tenant_id uuid NOT NULL REFERENCES tenants(id)` y `UNIQUE (tenant_id, id)` para permitir **claves foráneas compuestas** `(tenant_id, x_id)`, de modo que ninguna fila pueda referenciar una entidad de otro tenant ni siquiera sin RLS.

### 3.1 Alcance inicial (primeras entregas)

| Tabla | Clase | Campos principales | Restricciones / índices |
|---|---|---|---|
| `tenants` | Global, acceso controlado | `id`, `slug`, `name`, `status`, `created_at`, `updated_at` | `slug` único con `CHECK` de formato; `status IN (active, suspended, cancelled)` (Plan) |
| `platform_users` | Global / identidad | `id`, `email`, `password_hash` (Argon2id), `is_active`, `created_at` | Índice único en `lower(email)` |
| `users` | Tenant-scoped (+ búsqueda de login, ver D-L5) | `id`, `tenant_id`, `email`, `password_hash`, `role`, `is_active`, `created_at`, `last_login_at` | `role IN (tenant_admin, tenant_viewer)`; `UNIQUE (tenant_id, id)`; índice único en `lower(email)` (global, D-L5) |
| `sensors` | Tenant-scoped | `id`, `tenant_id`, `hostname`, `profile`, `lifecycle_status`, `last_seen_at` (grueso), `created_at` | `profile IN (endpoint, network)`; `lifecycle_status IN (active, revoked)`; `UNIQUE (tenant_id, id)`; índice `(tenant_id)` |
| `sensor_credentials` | Identidad: tenant-scoped, con búsqueda previa a autenticación (ver 4.3) | `id`, `tenant_id`, `sensor_id`, `channel`, `key_prefix`, `key_hash`, `status`, `created_at`, `expires_at`, `revoked_at` | `channel IN (control, telemetry)` (A2); `key_prefix` único; `CHECK (octet_length(key_hash)=32)` (SHA-256); FK compuesta a `sensors`; índice `(sensor_id, channel, status)`. Hasta 2 activas por sensor y canal (solape de rotación) |
| `enrollment_tokens` | Identidad: tenant-scoped, con canje previo a autenticación (ver 4.3) | `id`, `tenant_id`, `token_hash`, `created_by`, `created_at`, `expires_at`, `consumed_at`, `consumed_sensor_id` | `token_hash` único; `CHECK (expires_at > created_at)`; consumo atómico; índice `(tenant_id, expires_at)`. Duración: valor candidato pendiente |
| `audit_logs` | Tenant-scoped con filas de plataforma (`tenant_id` nulo) | `id` (identity), `occurred_at`, `tenant_id`, `actor_type`, `actor_id`, `action`, `target_type`, `target_id`, `outcome`, `source_ip`, `request_id`, `details` (jsonb) | Solo append: el rol de aplicación tiene `INSERT` y `SELECT`, sin `UPDATE`/`DELETE` (+ trigger que lo bloquee); índices `(tenant_id, occurred_at DESC)` y `(action, occurred_at)`; `details` con tope de tamaño y sin secretos. Retención: pendiente |

### 3.2 Diferido (se modela cuando se apruebe su fase)

`refresh_token_families` / `refresh_tokens` (depende de **R1** y ADR-0005: esbozo `family_id`, sujeto, `token_hash`, `issued_at`, `expires_at`, `consumed_at`, `revoked_at`); `signing_keys` (solo claves públicas y `kid`; la privada no vive en la BD); `notification_settings` (Fase 3); `agent_commands` (Fase 4, con `idempotency_key` y `expires_at` del Plan); `incidents` (+ referencias a alertas de OpenSearch; Plan: "próximas fases").

## 4. Aislamiento multi-tenant

### 4.1 Roles de PostgreSQL

| Rol | Uso | Propiedades |
|---|---|---|
| Superusuario de arranque (`POSTGRES_USER` del Compose) | Solo bootstrap local | Nunca lo usa la aplicación ni las migraciones |
| `alma_migrator` | Alembic / DDL | Dueño de los objetos. Sujeto a RLS donde `FORCE` |
| `alma_app` | Backend en ejecución | `NOSUPERUSER`, `NOBYPASSRLS`, **no dueño**, solo `GRANT` mínimos por tabla, sin DDL |
| `alma_auth` (más adelante, `NOLOGIN`) | Dueño de funciones `SECURITY DEFINER` de búsqueda previa a autenticación | Sin `BYPASSRLS`; política RLS específica y `GRANT` de columnas acotado |
| `alma_platform` (pendiente D-L3) | Operaciones de super_admin entre tenants | Pool y credenciales separados del de tenant |

### 4.2 RLS
- `ENABLE` + `FORCE ROW LEVEL SECURITY` en toda tabla tenant-scoped (A3).
- Política con `USING` y `WITH CHECK` sobre `tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid` (patrón del Plan); sin contexto devuelve cero filas.
- Contexto establecido con `SET LOCAL` en cada transacción (compatible con pool).
- **Límite conocido:** el contexto lo fija la propia aplicación; una inyección SQL capaz de ejecutar `SET` lo cambiaría. RLS es defensa en profundidad, no sustituye a la autorización de la API ni a consultas parametrizadas. Por eso se propone un pool y rol distintos para operaciones de plataforma (D-L3).

### 4.3 Flujos previos a la autenticación (no hay tenant conocido)
Se resuelven con funciones `SECURITY DEFINER` mínimas, no con un bypass genérico de RLS (ajustes 3 y 12 de 0.3b): `search_path` fijo, dueño sin privilegios amplios, `REVOKE EXECUTE FROM PUBLIC`, `GRANT EXECUTE` solo a `alma_app`, y prueba negativa con un rol no autorizado.
- `authenticate_sensor_credential(prefix)` → devuelve `sensor_id`, `tenant_id`, `key_hash`, `status`; el servidor compara el hash en tiempo constante.
- `enroll_sensor(token_hash, hostname, profile)` → en **una sola transacción** consume el token (`UPDATE … WHERE consumed_at IS NULL AND expires_at > now() RETURNING`), crea sensor y credenciales. Si algo falla, todo revierte y el token sigue sin consumir hasta que expire. Si el sensor pierde la respuesta tras el commit, el token ya está consumido y hay que emitir otro (se documenta).
- `lookup_user_for_login(email)` (si D-L5 = email único global).

## 5. Migraciones y reproducibilidad
- **Alembic**, migraciones versionadas en el repositorio; conexión con `alma_migrator`.
- Los **roles** son objetos del clúster, no de la base: se crean con un script idempotente de bootstrap (`DO $$ … IF NOT EXISTS …`), ejecutado por el superusuario con contraseñas tomadas de secretos. No se usa `docker-entrypoint-initdb.d` porque solo corre con un volumen vacío.
- Receta reproducible de desarrollo (destructiva y marcada así): `docker compose down -v` → `up -d` → bootstrap de roles → `alembic upgrade head`.
- Pruebas de migración: `upgrade head` sobre base vacía; `downgrade base` y de nuevo `upgrade head`; comparar el esquema resultante.

## 6. Pydantic, API y entidades persistidas

| Capa | Ubicación propuesta (**verificar contra sección 13 del Plan**) | Regla |
|---|---|---|
| Entidades persistidas | SQLAlchemy 2.x en `backend/app/models/` | Nunca se serializan directamente a la API |
| Contratos de API (request/response) | Pydantic v2, versionados (`/api/v1`) | `tenant_id` y `sensor_id` **no** se aceptan del cliente en endpoints tenant-scoped: salen del contexto autenticado. `password_hash`, `key_hash` nunca en respuestas |
| Eventos (ALMA Common Schema) | `schemas/` (prompt 0.3) | Validan la entrada; el tenant lo inyecta la ingesta desde la credencial. Se mapean a OpenSearch, no a PostgreSQL |

## 7. OpenSearch: búsqueda, retención y eliminación
- Documentos de eventos y alertas; **PostgreSQL no guarda copia**. Un incidente futuro guardará solo referencias a IDs de alertas.
- Índices del Plan: `alma-events-{tenant_id}-{yyyy.mm}`. Para alertas, el nombre es candidato (no figura en el Plan). Plantilla con mapeo estricto en los campos ALMA y el evento crudo almacenado sin indexar.
- La API construye el nombre del índice solo con el `tenant_id` autenticado, jamás con un patrón del cliente, **y** añade un filtro `tenant_id` obligatorio (doble capa). Los índices por tenant **no** son frontera de seguridad suficiente.
- Retención por política ISM que elimina índices mensuales antiguos. Duración: **valor candidato pendiente**. Eliminar los datos de un tenant = borrar sus índices.
- **Riesgo:** muchos tenants × meses × shards puede saturar el clúster; mitigar con un shard primario por índice y reconsiderar índices compartidos con filtro de tenant si crece (decisión pendiente).
- En desarrollo el plugin de seguridad está desactivado: **no hay aislamiento**. La prueba de acceso cruzado en OpenSearch exige un entorno de pruebas con seguridad activada (a diseñar).

## 8. Pruebas mínimas

| Prueba | Verifica | Requiere |
|---|---|---|
| Migración: `upgrade`, `downgrade`, `upgrade` | Reproducibilidad | PostgreSQL arriba |
| `alma_app` no es dueño, no es superusuario ni `BYPASSRLS`; `relforcerowsecurity` activo | A3 | Roles y tablas |
| Con contexto del tenant A: `SELECT`/`INSERT`/`UPDATE`/`DELETE` sobre filas del tenant B | Aislamiento por RLS (negativa) | Dos tenants de prueba |
| Sin contexto: cero filas | Fallo seguro | — |
| Fuga por pool: tras `SET LOCAL` y `COMMIT`, la siguiente transacción no ve el tenant anterior | PoC 1 del Plan | Pool real |
| FK compuesta: credencial de A apuntando a sensor de B es rechazada | Integridad entre tenants | — |
| `EXECUTE` de funciones definer con rol no autorizado falla; `proconfig` fija `search_path` | Ajuste 12 | Funciones |
| Canje de enrolamiento en paralelo: exactamente uno tiene éxito; fallo a mitad no consume el token | Atomicidad | Concurrencia |
| `audit_logs`: `UPDATE`/`DELETE` como `alma_app` falla | Inmutabilidad | — |
| Persistencia tras reinicio de PostgreSQL | Volumen y datos | Compose validado |
| OpenSearch: la consulta del tenant A nunca devuelve documentos de B | Aislamiento analítico | Entorno con seguridad activada |
| Contrato: la respuesta de API no contiene hashes; el cuerpo con `tenant_id` ajeno es rechazado | Pydantic ↔ API | API mínima |

## 9. Desviaciones respecto al Plan Maestro (todas propuestas)

1. El Plan guarda `enrollment_token` en `TENANTS`; el requisito de token de un solo uso con hash exige tabla propia (`enrollment_tokens`).
2. Super_admin como tabla separada (`platform_users`) en lugar de un `users` con `tenant_id` nulo.
3. El Plan guarda `last_heartbeat` en `sensors`; se propone liveness en Valkey y `last_seen_at` grueso en PostgreSQL.
4. Refresh tokens: el Plan los ponía en Redis; se recomienda PostgreSQL como fuente de verdad (R1, pendiente).
5. Eventos y alertas solo en OpenSearch; el ER del Plan relaciona `EVENTS → ALERTS → INCIDENTS` sin decir dónde vive cada uno.

## 10. Decisiones pendientes y recomendación

| ID | Decisión | Recomendación | Justificación | Bloquea |
|---|---|---|---|---|
| A3 | Rol de aplicación no dueño + `FORCE RLS` | Aprobar | Sin esto RLS no protege | Entrega 1 |
| D-L1 | Roles `alma_migrator` y `alma_app` ya; `alma_auth` y `alma_platform` después | Aprobar | Mínimo para probar aislamiento | Entrega 1 |
| D-L2 | Bootstrap de roles con script idempotente, no `initdb.d` | Aprobar | `initdb.d` no es reproducible con volumen existente | Entrega 1 |
| D-L4 | Driver: `psycopg` 3 para app, Alembic y pruebas, o `asyncpg` + otro driver para Alembic | `psycopg` 3 (un solo driver, soporta async) | Menos dependencias; la ventaja de rendimiento de `asyncpg` no está verificada aquí. Versión: `PENDIENTE` | Entrega 1 |
| D-L5 | Login: email único global + función definer, o `tenant_slug` en el login | Email único global | Menos fricción; la función evita un bypass | Entrega 3 |
| D-L3 | Pool y rol separados para super_admin | Aprobar | Reduce el impacto de un fallo de la aplicación | Entrega 3 |
| R1 / C1 | Refresh tokens en PostgreSQL; Valkey solo efímero | Esperar ADR-0005 | Las revocaciones deben sobrevivir a reinicios | Auth |
| OS-1 | Índices por tenant vs. compartidos con filtro | Mantener los del Plan; revisar con métricas | Decisión ya tomada en el Plan | Ingesta |
| Retención | Duraciones de datos y auditoría | Valores candidatos tras revisión del negocio | No hay política acordada | Producción |

## 11. Incrementos (flujo vertical)

Objetivo: recibir un evento, validarlo, asociarlo al tenant desde la credencial, persistirlo y consultarlo con autorización.

| # | Incremento | Archivos (aprox.) | Depende de |
|---|---|---|---|
| 0 | Compose v3 corregido (G1–G9) y validaciones B ejecutadas | Archivos de 0.2 | Tú ejecutas y pegas salidas |
| **1** | **Bootstrap de roles + Alembic + `tenants` + `sensors` con RLS + pruebas negativas** | `scripts/db-bootstrap.sql`, `backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/versions/0001_*.py`, `backend/tests/db/` | Inc. 0; A3, D-L1, D-L2, D-L4 |
| 2 | `sensor_credentials`, `enrollment_tokens`, función de enrolamiento + prueba de concurrencia | Migración 0002, función, tests | Inc. 1 |
| 3 | Esquemas de evento (0.3) + endpoint de ingesta autenticado por credencial + escritura a OpenSearch | `schemas/`, `backend/app/…` | Inc. 2, versión de Pydantic |
| 4 | `users`/JWT mínimos + consulta autorizada a OpenSearch + prueba de acceso cruzado | Auth, consulta | Inc. 3, R1 |
