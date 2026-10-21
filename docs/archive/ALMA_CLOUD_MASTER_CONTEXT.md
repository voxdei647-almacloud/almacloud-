# ALMA_CLOUD_MASTER_CONTEXT.md

**Versión del documento:** 1.2 (decisiones del usuario sobre #12 y #1–#3 incorporadas; ver Registro de cambios) · **Fecha:** 2026-10-09 · **Fuente:** únicamente el historial visible de la conversación de orquestación.

> **Cómo leer este documento.** Todo lo que aquí figura procede de la conversación. Nada se ha ejecutado dentro de ella: no hay código, archivos del proyecto ni salidas de comandos reales. Las versiones son candidatas, los prompts están aprobados pero no ejecutados (salvo las respuestas de Gemini descritas en 4.9), y ningún control de seguridad está implementado. Donde falta un dato figura `PENDIENTE DE CONFIRMACIÓN`.

---

## 1. Identidad y propósito del proyecto

### 1.1 Proyecto
- **Nombre:** ALMA CLOUD.
- **Qué es:** plano de control y plataforma de ciberseguridad SaaS **multi-tenant** orientada a **SOC/XDR** (Plan Maestro, sección 1).
- **Objetivo general:** gestión centralizada de sensores, ingesta y normalización de telemetría, detección de amenazas, correlación multi-fuente, gestión de incidentes y respuesta controlada (Plan Maestro, sección 1).
- **Visión de producto:** evolucionar de una solución de monitoreo y respuesta para servicios gestionados a una plataforma comercial SOC/XDR escalable (Plan Maestro, sección 2).
- **Independencia tecnológica:** el núcleo (autenticación, tenants, correlación, orquestación de respuesta, modelos de datos, APIs, portales) se desarrolla bajo control de ALMA. No debe depender funcionalmente de software SOC/XDR completo de terceros (Wazuh, Elastic Security). Wazuh es una integración **opcional** externa.
- **Doble experiencia:** Consola SOC/MSSP (operadores) y Portal del Cliente (ejecutivo, aislado por cliente).

### 1.2 Principios arquitectónicos establecidos (Plan Maestro, sección 3)
1. Soberanía sobre el plano de control (BD transaccional, estado de tenants, identidad de sensores, tokens, colas de respuesta, auditoría).
2. Separación de canales: **telemetría** (unidireccional, alta frecuencia) y **control** (bidireccional, alta prioridad, cero confianza, idempotente y auditable).
3. Suricata es el motor oficial de detección de red del ecosistema.
4. Fluent Bit es transportador puro (empaquetado, filtrado, buffer local, transporte seguro); no inspecciona paquetes ni correlaciona.
5. Wazuh y otros son conectores opcionales; su fallo no afecta a ALMA.
6. Defense in Depth multi-tenant en tres capas (API/JWT, PostgreSQL RLS, OpenSearch).

### 1.3 Alcance (Plan Maestro, secciones 2 y 14)
- **MVP:** enrolamiento y ciclo de vida del sensor; métricas de host y FIM; ingesta de Suricata EVE JSON vía Fluent Bit; transporte cifrado con buffer local; JWT, RBAC y RLS; detección determinista inicial; Consola SOC y Portal; notificaciones Telegram/SMTP.
- **Próximas fases:** correlación temporal multi-fuente, reglas Sigma (pySigma), mapeo MITRE ATT&CK, respuesta activa con aprobación humana (BLOCK_IP, ISOLATE_HOST), reportes básicos.
- **Evolución futura:** conectores externos, gestión de vulnerabilidades, playbooks SOAR, UEBA.
- **Roadmap del Plan Maestro (sección 14):** Fase 0 (entorno y contratos), Fase 1 (Auth, Tenants, Auditoría, RLS; semanas 1-2), Fase 2 (Sensor e ingesta; 3-4), Fase 3 (detección y notificaciones; 5-6), Fase 4 (Consola, Portal y respuesta controlada; 7-8).
- **Límites explícitos de lo discutido hasta ahora:** nada de backend, tablas, RLS, autenticación ni pipeline está implementado.

### 1.4 Rol del asistente (orquestador)
- Esta conversación es el **centro de control**: registra decisiones, redacta prompts de tarea, revisa lo que devuelven otras IAs, detecta contradicciones y propone el siguiente paso.
- **No ve** los otros chats (Gemini, DeepSeek, Claude en chats aparte) ni puede ejecutar nada en otras plataformas. El usuario ejecuta los prompts y pega aquí los resultados completos.
- **Reparto propuesto de IAs** (propuesta del orquestador, aceptada de forma general por el usuario): Claude para código/seguridad crítica y ADR; Gemini para contexto largo, documentación e investigación con búsqueda web; DeepSeek para boilerplate, tests, Docker Compose y configs. Regla: lo que escribe una IA lo revisa otra.
- El orquestador **no puede confirmar de memoria** que una versión o etiqueta exista (su conocimiento llega a junio de 2026 y no está contrastado con registros). La existencia real de etiquetas la confirma el usuario con comandos.
- **Aviso:** en varios mensajes, el usuario redactó compromisos en voz del orquestador ("revisaré...", "necesito que ejecute los prompts"). El orquestador aclaró que quien ejecuta los prompts en otras plataformas es el usuario.

---

## 2. Estado ejecutivo actual

**Estado global:** no existe ningún artefacto de Fase 0 aprobado. Hay prompts aprobados para ejecutar; se recibieron dos respuestas de Gemini al prompt 0.1 (rechazadas como matriz congelable). No hay resultados del 0.3b, del compose, del 0.3 ni del 0.4.

| ID | Elemento | Estado | Evidencia disponible | Próxima acción |
|---|---|---|---|---|
| D1 | Frontend Refine.dev + Next.js | `CERRADO` como línea base de diseño (con PoC de compatibilidad pendiente) | Sección 17 aportada por el usuario | PoC de compatibilidad de versiones |
| D2 | JWT RS256 | `CERRADO` como línea base (diseño de gestión de claves pendiente) | Sección 17 | Cubrir en ADR-0005 |
| D3 | Suricata como servicio nativo systemd | `CERRADO` como línea base (privilegios por modo de captura pendientes) | Sección 17 | Validar privilegios por modo |
| D4 | Fluent Bit como transporte independiente | `CERRADO` | Sección 17 | — |
| D5 | ALMA Agent independiente con canal de control propio | `CERRADO` | Sección 17 | — |
| A1 | Fluent Bit autentica con API key por header en MVP; mTLS después | `CERRADO` | Confirmación explícita del usuario | Documentar en ADR-0002 |
| A2 | Credenciales separadas Agent (control) / Fluent Bit (telemetría) | `CERRADO` | Aceptada por el usuario | Documentar en ADR-0002 |
| A3 | Rol de app sin ser dueño + `FORCE ROW LEVEL SECURITY` | `PROPUESTO` (se documenta en ADR-0003) | Propuesta del orquestador | ADR-0003 |
| A4 | Diagrama ER: `\|\|--o1` inválido en Mermaid, correcto `\|\|--o\|` | `PROPUESTO` (corrección menor, sin decisión formal registrada) | Observación del orquestador | Corregir al regenerar el plan |
| A5 | Fingerprint SHA-256 en vez de MD5 | `PROPUESTO` (se documenta en ADR-0004) | Propuesta | ADR-0004 |
| A6 | Refresh tokens con rotación y detección de reutilización | `PROPUESTO` (se documenta en ADR-0005) | Propuesta | ADR-0005 |
| T1 | TLS 1.2 mínimo, TLS 1.3 objetivo | `PENDIENTE DE APROBACIÓN` formal | Propuesta; usuario la marcó como pendiente | Aprobación humana |
| R1 | Persistencia del estado de refresh tokens | `PENDIENTE DE APROBACIÓN` | ADR-0005 recomendará; decide el usuario | Tras ADR-0005 |
| C1 | Redis vs Valkey | `PENDIENTE DE INVESTIGACIÓN` y revisión legal | Dos respuestas de Gemini sin verificar | Verificación externa + abogado |
| V1 | Matriz de versiones | `PENDIENTE DE VERIFICACIÓN EXTERNA` | Respuestas de Gemini rechazadas | Ejecutar comandos de 4.9 |
| V2 | Variante de imagen `-bookworm` (frente a `-alpine`) | `PROPUESTO` (recomendación del orquestador de aceptarla; el usuario no la ha aprobado formalmente) | Gemini ronda 2 | Aprobación |
| V3 | `uv` + `uv.lock` | `PROPUESTO` | Gemini ronda 2 | Aprobación |
| V4 | OpenSearch Dashboards solo como componente opcional de desarrollo | `PROPUESTO` | Gemini ronda 2; el prompt DeepSeek lo excluye de esa fase | Aprobación |
| P0.1 | Prompt de investigación de versiones | `APROBADO PARA EJECUTAR`; ejecutado en Gemini dos rondas | Respuestas pegadas por el usuario | Seguimiento/verificación |
| P0.2 | Prompt de entorno Docker Compose | `NO EJECUTADO` (el prompt original 0.2 no se lanzó) | Texto del prompt en el historial | Ver contradicción de numeración (4.6) |
| P0.C | Prompt DeepSeek de Compose en MODO AVANCE (renombrado operativamente a **0.2-MODO-AVANCE** en v1.1; ID histórico P0.C) | `APROBADO PARA EJECUTAR` (por el orquestador); `NO EJECUTADO` | Texto íntegro en Apéndice C | Ejecutar en DeepSeek |
| P0.3 | Prompt de esquema común Pydantic v2 | `NO EJECUTADO` | Texto del prompt en el historial | Tras versiones y 0.3b |
| P0.3b | Prompt de ADR de seguridad (13 ajustes) | `APROBADO PARA EJECUTAR`; `NO EJECUTADO` (sin resultado) | Apéndice B | Ejecutar en chat de Claude aparte |
| P0.4 | Prompt de auditoría independiente | `APROBADO`; `NO EJECUTADO` | Texto en el historial | Necesita artefactos reales |
| ADR-0002 a 0005 | ADRs de seguridad | `PROPUESTO` solo como plan; no existen | — | Generar vía 0.3b |
| MA | Reglas "MODO AVANCE" del usuario | Vigentes por instrucción del usuario | Mensaje del usuario | Ver 4.6 y 4.13 (conflicto parcial) |

Estados `IMPLEMENTADO Y VERIFICADO`: **ninguno**.

---

## 3. Arquitectura conceptual

Fuente: Plan Maestro y sección 17 del usuario. No se han definido puertos, endpoints definitivos ni protocolos más allá de lo citado.

### 3.1 ALMA Agent
- **Responsabilidad:** telemetría de endpoint, métricas de host, FIM, logs de aplicaciones, canal de control remoto (heartbeat, políticas, comandos).
- **Entradas/salidas:** métricas del SO (psutil), eventos FIM (watchdog), app logs → hacia Fluent Bit (sockets/archivos) y canal de control hacia ALMA CLOUD.
- **Relaciones:** independiente de Fluent Bit y Suricata; no debe depender de que Fluent Bit esté activo. Estado local en SQLite (caché de comandos/auditoría).
- **Decisiones que lo afectan:** D5, A2.
- **Pendientes:** enrolamiento, identidad, heartbeat, configuración, actualización, revocación, ejecución controlada de comandos; qué va al MVP y qué a fases posteriores (sección 17.5).
- **Riesgos:** compromiso del agente en host cliente; replay de comandos (mitigaciones del Plan: API key por sensor, sudoers acotado, lista blanca, `idempotency_key`).
- **Perfiles:** Endpoint (Agent + Fluent Bit) y Red/Combinado (Agent + Fluent Bit + Suricata).

### 3.2 Suricata
- **Responsabilidad:** inspección de tráfico y detección NIDS; genera EVE JSON.
- **Entradas/salidas:** paquetes de interfaces SPAN/TAP → EVE JSON en archivo → Fluent Bit.
- **Decisiones:** D3 (servicio nativo systemd; Docker no es el método predeterminado; si se contenerizara, hay que justificar acceso a interfaces, capacidades, permisos, rendimiento, aislamiento).
- **Pendientes:** privilegios mínimos por modo de captura (no asumir que `CAP_NET_RAW` basta; el Plan original mencionaba `CAP_NET_ADMIN`/`CAP_NET_RAW`), configuración, actualización de reglas, rotación de logs, recuperación.
- **Límite:** no accede al sistema de archivos local ni ejecuta comandos de host; desacoplado de Agent y Fluent Bit pero administrable desde el ecosistema ALMA.

### 3.3 Fluent Bit
- **Responsabilidad:** recolección, filtrado, buffer en disco, reintentos, backpressure y transporte seguro hacia la API de ingesta.
- **Entradas/salidas:** EVE JSON de Suricata, logs locales y sockets del Agent → HTTPS hacia ALMA CLOUD.
- **Decisiones:** D4, A1, A2.
- **Límites:** no inspecciona paquetes, no evalúa reglas, no ejecuta acciones, no es canal de control.
- **Pendientes:** autenticación (API key por header en MVP), límites de recursos y almacenamiento, comportamiento ante desconexión (PoC 2 del Plan: `mem_buf_limit`, `storage.type filesystem`).
- **Riesgos:** robo de la key del sensor permite inyectar telemetría falsa hasta revocarla.

### 3.4 Canal de control del Agent
Bidireccional, autenticado, idempotente y auditable. Credencial **separada** de la de telemetría (A2). Endpoints del Plan Maestro (Módulo 3): `POST /api/v1/agents/register`, `heartbeat`, `GET /api/v1/agents`, `POST /api/v1/agents/{agent_id}/command`, `POST /api/v1/agents/commands/ack`. **Los nombres definitivos no están cerrados.**

### 3.5 Canal de telemetría
Unidireccional, Fluent Bit → API/Ingestor por HTTPS. Endpoints del Plan: `POST /api/v1/telemetry/metrics`, `POST /api/v1/telemetry/security-events`. **No cerrados como definitivos.** El Plan original no definía la autenticación de Fluent Bit; se cerró con A1.

### 3.6 API de ingesta y normalización
- Valida con esquemas Pydantic v2, normaliza al ALMA Common Schema (basado en ECS, evaluación pendiente), enriquece e indexa.
- La identidad de tenant y sensor debe derivarse de la credencial autenticada, no del payload.
- **Pendiente:** diseño real; aún no hay código.

### 3.7 Esquema común de telemetría
Planificado en el prompt 0.3 (sección 4.10). Campos del Plan: `timestamp`, `tenant_id`, `sensor_id`, `event.category`, `source.ip`, `destination.ip`, `host.hostname`, `event.severity`. No implementado.

### 3.8 Correlación e incidentes
Del Plan: motor de detección multicapa (Suricata nativo, pySigma), correlación temporal (ventana configurable, Δt=5 min en el Plan), scoring y deduplicación por fingerprint (el Plan usaba MD5; propuesta A5 pasa a SHA-256). No es MVP completo (correlación multi-fuente es "próximas fases"). No implementado.

### 3.9 Plataforma SOC/XDR (backend)
FastAPI con siete módulos (Auth/RBAC, Tenant Manager, Agent Manager, Telemetry, Notifications, Audit, Dashboards). Roles iniciales: `super_admin`, `tenant_admin`, `tenant_viewer`. Notificaciones por Telegram/SMTP con workers asíncronos (Redis/Celery en el Plan; sujeto a la decisión Redis/Valkey). No implementado.

### 3.10 PostgreSQL y multi-tenant
- PostgreSQL es la base transaccional principal (identidad, tenants, configuración, RBAC, auditoría, comandos).
- Aislamiento en tres capas del Plan: middleware JWT (403 ante discrepancia de tenant), RLS con `SET LOCAL app.current_tenant_id`, y OpenSearch con filtros/índices.
- **Estado: solo diseñado.** Ni middleware, ni RLS, ni pruebas existen.
- **Riesgo identificado:** el dueño de la tabla y los superusuarios se saltan RLS (de ahí A3).

### 3.11 Redis / Valkey
- Uso en el Plan: heartbeats, caché de sesión, rate limiting, refresh tokens, colas.
- **Decisión C1 pendiente.** El prompt DeepSeek (MODO AVANCE) asume Valkey por defecto y Redis 7.2 solo si se indica.
- Principio documentado en ese prompt: Valkey/Redis **no es fuente de verdad**; lo que no pueda perderse (tokens revocados, auditoría) va en PostgreSQL. Esto sigue sujeto a R1.

### 3.12 OpenSearch y OpenSearch Dashboards
- OpenSearch 2.x para telemetría, eventos y alertas históricas. Índices del Plan: `alma-events-{tenant_id}-{yyyy.mm}`.
- **Requisito de seguridad acordado:** índices por tenant **no** son frontera de seguridad suficiente; el filtro de tenant se impone en el servidor en cada consulta, con pruebas negativas y revisión de permisos del usuario de OpenSearch.
- **Con el plugin de seguridad desactivado (desarrollo):** no existe aislamiento en OpenSearch y no puede presentarse como control de seguridad.
- Dashboards: solo opcional de desarrollo (propuesta V4), versión idéntica a OpenSearch.

### 3.13 Frontend candidato
Refine.dev + Next.js (D1). Debe mantenerse desacoplado del backend con contratos de API versionados; evitar duplicar responsabilidades Refine/Next; evaluar si SOC y Portal comparten componentes sin comprometer aislamiento (sección 17.1). Gemini propuso Refine Core 4.54.0 y Next.js 15.1.4, **no verificadas**; el orquestador advirtió que Next.js 15.1.4 podría tener avisos de seguridad conocidos (a comprobar con `npm audit`).

### 3.14 Autenticación, autorización y sesiones
- JWT RS256 (D2) con `kid`, validación de firma, emisor, audiencia, expiración y algoritmo permitido; clave privada no distribuida a verificadores; acceso de corta duración; refresh tokens revocables; Argon2id para contraseñas humanas.
- El Plan original ponía los refresh tokens en Redis; ahora R1 está pendiente.
- Nada implementado.

### 3.15 Entorno de desarrollo (Docker Compose)
Servicios previstos: PostgreSQL, Valkey (o Redis), OpenSearch (Dashboards opcional). Puertos solo en loopback, healthchecks reales, secretos por variables, volúmenes persistentes. **No existe aún ningún `docker-compose.yml`.**

---

## 4. Registro de decisiones y especificaciones

### 4.1 Convención
Cada entrada: Estado · Contexto · Alternativas · Decisión aprobada · Recomendación · Riesgos · Dependencias · Falta para cerrar.

### 4.2 Decisiones cerradas

**D1–D5 (línea base de la sección 17).** El usuario las presentó como "línea base de diseño, no una afirmación de que la implementación ya existe ni de que todo esté verificado". Reglas dadas: no reabrir sin razón técnica concreta; documentar motivación, consecuencias, riesgos, dependencias, requisitos operativos, alternativas descartadas y PoC necesarias.

**A1 – Autenticación de Fluent Bit.** CERRADA. API key enviada por header HTTP sobre TLS en el MVP; mTLS se evalúa en fase posterior. Alternativa discutida: mTLS desde el inicio (más fuerte, más operación). Riesgo residual: robo de key. Falta: detallar en ADR-0002 (nombres de header y endpoints no fijados).

**A2 – Credenciales separadas.** CERRADA. Una credencial de control (Agent) y otra de telemetría (Fluent Bit). Motivo: si hubiese una sola, el compromiso de un canal comprometería ambos.

### 4.3 Propuestas y asuntos pendientes

**A3 – RLS, rol de aplicación.** PROPUESTO. El rol de aplicación no es dueño de tablas ni tiene `BYPASSRLS`; `FORCE ROW LEVEL SECURITY`; rol de migraciones separado. Falta: ADR-0003, aprobación.

**A5 – Fingerprint SHA-256.** PROPUESTO. Reemplazar MD5 del Plan (`MD5(tenant + rule_id + source_ip + target_host)`).

**A6 – Refresh tokens.** PROPUESTO. Rotación en cada uso y detección de reutilización.

**T1 – TLS.** PENDIENTE DE APROBACIÓN. Propuesta: TLS 1.2 mínimo, TLS 1.3 objetivo en el MVP; criterios medibles para pasar a 1.3 obligatorio (porcentaje de sensores que negocian 1.3, inventario de bibliotecas TLS en sensores, fecha de revisión). Nota: el Plan Maestro mencionaba "TLS 1.3 / mTLS" en el gateway (posible contradicción sin resolver formalmente).

**R1 – Persistencia de refresh tokens.** PENDIENTE DE APROBACIÓN. Opciones: Redis/Valkey, PostgreSQL, combinada. Preocupación: si el almacén pierde datos o se reinicia sin persistencia se pierden revocaciones. Recomendación: la hará el ADR-0005; el orquestador no la ha emitido todavía. Depende de C1.

**C1 – Redis vs Valkey.** PENDIENTE DE INVESTIGACIÓN. Ver 4.9 y sección 7 (contradicciones).

### 4.4 Requisitos de seguridad transversales (acordados como requisitos, no implementados)
- API keys almacenadas solo como hash (SHA-256 suficiente al ser claves aleatorias de alta entropía; Argon2id es para contraseñas humanas); comparación en tiempo constante.
- Identidad de tenant y sensor derivada de la credencial validada; rechazar discrepancias con el payload.
- Alcance por canal y endpoint: la key de telemetría no sirve para control y viceversa.
- Revocación individual y rotación con solape.
- Secretos fuera de logs, trazas, errores y modo debug; Fluent Bit carga la key desde variable de entorno o archivo `0600`.
- Rate limiting por credencial (no solo IP) y límites de tamaño de petición.
- Respuestas de autenticación sin filtrar secretos.

### 4.5 Plan de ADR

Todos: `PROPUESTO`, no existen. Formato obligatorio de cada ADR: título/ID, estado propuesto, contexto, decisión, alternativas, consecuencias, riesgos residuales, requisitos de aceptación, pruebas, decisiones pendientes. Etiquetado `[HECHO]`, `[RECOMENDACIÓN]`, `[PENDIENTE]`. No declarar nada como implementado.

**`docs/adr/ADR-0002-telemetry-authentication.md`**
- API key por header sobre TLS (A1), TLS 1.2 mínimo / 1.3 objetivo (T1, con configuración segura de TLS 1.2, prohibición de protocolos obsoletos, criterios medibles).
- Generación criptográfica de claves, hash SHA-256, comparación en tiempo constante, identidad desde credencial, rechazo de discrepancias, scopes separados, revocación y rotación con solape, no filtración en logs, rate limiting y tamaño, respuestas sin filtrar secretos, riesgo residual, migración a mTLS con criterios de activación.
- Por qué SHA-256 y no Argon2id en este caso.
- No fijar endpoints ni nombres de header sin declararlos decisiones explícitas.
- Enrolamiento (también cubierto en ADR-0003): token almacenado como hash, de un solo uso, corta duración, consumo atómico, comportamiento si el canje falla a mitad.

**`docs/adr/ADR-0003-multitenant-postgresql-rls.md`**
- PostgreSQL principal, RLS como defensa en profundidad (no prueba de aislamiento completo por sí sola).
- Tabla de clasificación de tablas **candidatas** (no esquema definitivo): con `tenant_id` y RLS obligatorio; globales sin RLS por tenant con controles propios; de identidad/enrolamiento/infraestructura que requieren análisis.
- Rol de aplicación sin ser dueño ni `BYPASSRLS`; `FORCE ROW LEVEL SECURITY` donde proceda; rol de migraciones separado.
- Contexto de tenant por transacción (`SET LOCAL`), seguro con pools; restricciones sobre consultas administrativas e internas.
- Enrolamiento: token de un solo uso, corta duración, hash, consumo atómico, fallo a mitad. Si se propone `SECURITY DEFINER`: ver redacción final del ajuste 12 en Apéndice B.
- Pruebas negativas: leer, modificar y eliminar datos de otro tenant.
- Sección OpenSearch: índices por tenant no son frontera suficiente; filtro en servidor; pruebas negativas; permisos del usuario de OpenSearch; sin plugin de seguridad no existe aislamiento.

**`docs/adr/ADR-0004-event-fingerprints.md`**
- SHA-256 en lugar de MD5. Distinguir `event_id` (identificador único), `fingerprint` (agrupación/deduplicación de alertas) y `raw_hash` (integridad de la representación original recibida).
- Campos que entran al fingerprint y por qué; análisis de colisiones semánticas y manipulación para ocultar alertas; SHA-256 no corrige un fingerprint mal definido.
- Canonicalización JSON solo si hace falta. Conservar evento crudo o representación verificable según retención. Un hash no prueba autenticidad ni autoría. Pruebas de reproducibilidad.

**`docs/adr/ADR-0005-refresh-token-lifecycle.md`**
- Access JWT RS256; refresh tokens separados; rotación; almacenamiento seguro en servidor; detección de reutilización; revocación de la familia; concurrencia y reintentos legítimos; caducidad, revocación y logout; rotación de claves con `kid`; validación estricta de algoritmo, emisor, audiencia, expiración y claims.
- Comparar Redis/Valkey, PostgreSQL y combinada; consecuencias de reinicios, pérdida de datos, restauraciones. Recomendar pero dejar pendiente de aprobación. Duraciones solo como valores candidatos pendientes de aprobación.

### 4.6 Plan de trabajo y dependencias

Orden acordado:
1. **0.1** investigación y propuesta de matriz de versiones.
2. Aprobación humana de la matriz y decisión Redis/Valkey.
3. **0.2** entorno Docker Compose (sobre versiones aprobadas).
4. **0.3b** ADR de seguridad (puede correr en paralelo con 0.1; solo ADR-0005 toca Redis/Valkey y queda pendiente).
5. **0.3** esquema común Pydantic v2 (necesita la versión de Pydantic de 0.1; el orquestador recomendó 0.3b antes que 0.3).
6. **0.4** auditoría independiente sobre artefactos reales, por una IA distinta de la que los escribió.

Asignación: 0.1 → Gemini con búsqueda web activa; 0.2 → DeepSeek; 0.3b → Claude en chat aparte; 0.3 → Gemini o Claude; 0.4 → IA distinta a la autora.

**Numeración (resuelta en v1.2, #2).** El prompt de Compose para DeepSeek, generado inicialmente como "Fase 0.1", pasa a llamarse **0.2-MODO-AVANCE** (ID histórico P0.C, usado en este documento).

**Reglas MODO AVANCE del usuario (resumen).** No detenerse en verificación de versiones, licencias ni CVEs (son tareas paralelas); versiones provisionales: Python 3.11-slim-bookworm, PostgreSQL 16-bookworm, Valkey 8-bookworm (o Redis 7.2-bookworm), OpenSearch 2.19.6, FastAPI, SQLAlchemy 2.x async, Pydantic v2, Alembic, PyJWT, Argon2id; marcar lo no verificado como `PENDIENTE_VERIFICACION` en `VERSIONES.md`; máximo una ronda de revisión por entregable; asumir la opción más conservadora y documentar; Fase 0 completa con docker-compose.yml con healthchecks y volúmenes, `.env.example`, estructura de monorepo, esquemas Pydantic básicos, requirements/`uv.lock` inicial y README; no pedir ejecutar comandos para continuar; no reabrir decisiones cerradas (riesgos van a `RIESGOS.md`); cada respuesta termina con Estado, Siguiente tarea y máximo 3 preguntas bloqueantes.
**Precedencia (resuelta en v1.2, #3 y #12).** MODO AVANCE rige la precedencia para tareas independientes en paralelo con la matriz 0.1; los criterios de cierre están en 4.6-bis y 4.14. Los artefactos con tags flotantes se auditan como "aprobado con condiciones" hasta fijar versiones y digests.

### 4.6-bis Regla de precedencia y dependencias de Fase 0

**Estado:** `CERRADO` por decisión del usuario (v1.2, 2026-10-09) para las discrepancias #1, #2, #3 y #12. Alcance: modo de trabajo y criterios de cierre de la Fase 0. Esta regla complementa la definición original de MODO AVANCE; no se atribuye retroactivamente a su texto original.

- Para la Fase 0 prevalece `MODO AVANCE` sobre cualquier instrucción previa que convierta la matriz 0.1 en prerrequisito para empezar cualquier tarea.
- **0.2-MODO-AVANCE**, **0.3b** y **0.3** pueden prepararse en paralelo con la investigación de versiones, respetando solo dependencias técnicas reales (0.3 depende de la versión de Pydantic, no de toda la matriz; 0.3b depende de A1/A2 y del Plan).
- Las versiones no verificadas se marcan `PENDIENTE_VERIFICACION` en `VERSIONES.md` y en el propio entregable.
- La matriz 0.1 no bloquea por sí sola los demás entregables; es una tarea paralela con cierre propio.
- Producir un entregable con versión provisional **no equivale** a aprobar esa versión para la línea base; solo lo segundo entra en Fase 1.
- Un tag flotante (`16-bookworm`, `8-bookworm`) o un tag sin digest verificado no se presenta como referencia inmutable.
- No se afirma que una etiqueta Docker exista sin salida real de `docker buildx imagetools inspect` pegada por el usuario.
- **Dos estados de Fase 0 (decisión del usuario, #12):**
  1. `FASE_0_ENTREGABLES_COMPLETADOS`: los seis entregables de MODO AVANCE (regla 5) están producidos y las validaciones obligatorias tienen evidencia verificable.
  2. `FASE_0_CERRADA`: lo anterior, más matriz de versiones revisada y aprobada, e imágenes definitivas fijadas a referencias reproducibles (digest preferente).
  La matriz y los digests **no bloquean** la elaboración de entregables independientes; **sí bloquean** declarar `FASE_0_CERRADA`. No se eliminan las dependencias técnicas reales.
- **Qué son las "validaciones obligatorias":** el usuario no las enumeró. Mínimo propuesto por el orquestador, `PENDIENTE DE CONFIRMACIÓN`: `docker compose config` válido, `docker compose up -d` con servicios sanos y `docker compose ps` real, más ausencia de secretos versionados y puertos solo en loopback.

### 4.7 Prompts aprobados — referencia
- Texto íntegro del **0.1**: Apéndice A (texto original del usuario) más el bloque de reglas adicionales de evidencia (redactado por el orquestador y aprobado).
- Texto íntegro del **0.3b**: Apéndice B (texto original) más los 13 ajustes consolidados.
- **Aprobado ≠ ejecutado.** 0.3b no tiene resultado. 0.1 tuvo dos respuestas de Gemini, ninguna aceptada como matriz.

**Preferencias de versión (resuelta en v1.2, #1).** El prompt de continuidad mencionaba Python 3.13.x / PostgreSQL 17.x, que no aparecen en el historial. Por decisión del usuario, Python 3.11 / PostgreSQL 16 son líneas base **provisionales** para 0.2-MODO-AVANCE, pendientes de investigación y aprobación en la matriz 0.1; no son versiones definitivas ni hay etiquetas verificadas. Lagunas de dependencias señaladas por la ronda de Gemini (observación N6): `cryptography`, uvicorn, pytest-asyncio, httpx y clientes OpenSearch/Redis-Valkey, a decidir.

### 4.8 Prompts 0.2, 0.3 y 0.4 (requisitos establecidos; resumen, no texto original)

**0.2 – Entorno local reproducible (DevOps).** Entregables: `docker-compose.yml`, `.env.example`, `.gitignore`, `docs/development-environment.md`. Versiones candidatas explícitas: `postgres:16.15-bookworm`, `redis:7.4.11-bookworm` (tras comprobar etiqueta), `opensearchproject/opensearch:2.19.6`, Dashboards 2.19.6 solo si se justifica. Sin `latest`. PostgreSQL: volumen, variables, healthcheck real, loopback, instrucciones para roles separados futuros; sin tablas ni RLS. Redis: persistencia y política de memoria documentadas, autenticación configurable, healthcheck funcional, loopback, no es fuente de verdad. OpenSearch: nodo único, versión fija, volumen, límites de memoria, healthcheck compatible con la imagen, seguridad explícita (si se desactiva, documentar que es solo desarrollo), loopback, `vm.max_map_count`. Secretos ficticios, `.env` ignorado, red dedicada, `depends_on` con salud, comandos de inicio/inspección/parada/reinicio, diferencia entre detener y eliminar volúmenes. Criterios de aceptación: `docker compose config` válido; `up -d`; tres servicios sanos; Postgres acepta conexión; Redis responde autenticado; OpenSearch responde salud; persistencia tras reinicio; puertos no expuestos a la red; sin secretos versionados; errores externos documentados. No declarar pruebas no ejecutadas.

**0.3 – ALMA Common Schema (Pydantic v2).** Entregables mínimos: `schemas/__init__.py`, `schemas/common.py`, `schemas/enums.py` (si necesario), `schemas/suricata.py`, `schemas/agent.py`, `schemas/tests/`, `docs/alma-common-schema.md`. Campos a evaluar: versión de esquema, ID único de evento, tenant, sensor/host, fuente y tipo, timestamp UTC, categoría y severidad, datos normalizados, campos originales, ID de correlación, metadatos de recepción/procesamiento. Distinguir hora del evento y hora de recepción. No asumir `tenant_id` fiable en la fuente. Suricata: conversión EVE JSON, conservar campos originales, tipos de evento no soportados explícitos, no copiar ciegamente campos arbitrarios. Agent: separar inventario, métricas y detecciones; sin comandos ni respuestas automáticas. Validación y compatibilidad: límites de tamaño, comportamiento ante campos desconocidos y versiones futuras, ejemplos JSON válidos/inválidos, pruebas de fechas, campos faltantes, severidades desconocidas, malformados y extras; deduplicación sin usar hash como autenticación; evaluar ECS sin adoptarlo completo sin justificar. No SQL definitivo, ni pipeline, ni APIs, ni dashboard. Pendiente que el orquestador pidió añadir: test explícito del timestamp EVE con offset `+0000` (sin dos puntos).

**0.4 – Auditoría independiente.** Revisar con los archivos reales: tags exactas, consistencia OpenSearch/Dashboards, puertos, secretos, healthchecks, persistencia, requisitos del host, reinicios, dev vs prod, dependencias Python, reproducibilidad; control/telemetría con credenciales separadas; autenticación de Fluent Bit como decisión; identidad declarada vs autenticada; procedencia de eventos; validación de Suricata antes del modelo ALMA; Pydantic no sustituye autorización; no afirmar aislamiento multi-tenant sin middleware, RLS y pruebas; índices OpenSearch no son frontera; sin secretos reales. Formato por hallazgo: ID, severidad, archivo/ubicación, evidencia reproducible, impacto, corrección, prueba. Clasificación: aprobados, con condiciones, rechazados, pendientes. Lista final de bloqueos antes de Fase 1. Si no hay archivos: solo inventario de lo recibido, limitaciones y materiales necesarios; no inventar informe. Estado de verificación: "verificado / inspeccionado / inferido / no evaluable".

**Respuesta ya dada a un 0.4:** al recibir el prompt sin archivos, el orquestador respondió que no podía auditar y listó los materiales necesarios; no se emitió informe.

### 4.9 Matriz de versiones y compatibilidad

**Regla vigente:** cada versión debe tener fuente verificable; lo no confirmado figura `PENDIENTE`. La existencia de etiquetas Docker debe comprobarse con `docker buildx imagetools inspect`. No hay evidencia de que se haya ejecutado, ni de que las etiquetas existan.

**Candidatas históricas (no verificadas, no aprobadas; deben reevaluarse contra las preferencias vigentes y fuentes oficiales):**

| Componente | Versión candidata | Fuente | Fecha | Mantenimiento | Compatibilidad | Licencia | Verificación | Acción pendiente |
|---|---|---|---|---|---|---|---|---|
| Python | 3.11.17 (Gemini: "existe") | URL de Gemini: `python.org/downloads/latest/python3.11/` (página flotante) | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE DE VERIFICACIÓN EXTERNA | `uv python list --all-versions \| grep 3.11`; imagen `python:3.11.17-slim-bookworm` |
| FastAPI | 0.143.0 | `fastapi.tiangolo.com/release-notes/` | PENDIENTE | PENDIENTE | PENDIENTE | MIT (Plan) | PENDIENTE DE VERIFICACIÓN EXTERNA | `pip install --dry-run` |
| Pydantic | 2.14.0 | `pydantic.dev/articles/pydantic-v2-14-release` | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE DE VERIFICACIÓN EXTERNA | idem |
| SQLAlchemy | 2.0.54 | `sqlalchemy.org/blog/2026/09/15/sqlalchemy-2.0.54-released/` | Gemini sugiere 2026-09-15 | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE DE VERIFICACIÓN EXTERNA | idem |
| PostgreSQL | 16.15 | `postgresql.org/docs/release/16.15/` | PENDIENTE | PENDIENTE | PENDIENTE | PostgreSQL (BSD) (Plan) | PENDIENTE DE VERIFICACIÓN EXTERNA | `docker buildx imagetools inspect postgres:16.15-bookworm` |
| Redis | 7.4.11 | `redis.io` notas de release | PENDIENTE | PENDIENTE | PENDIENTE | RSALv2/SSPLv1 según Gemini; el Plan decía BSD (erróneo según Gemini; sin verificar) | PENDIENTE DE VERIFICACIÓN EXTERNA | idem con `redis:7.4.11-bookworm`; revisión legal |
| OpenSearch | 2.19.6 | `opensearch.org/artifacts/by-version/` (índice) | PENDIENTE | PENDIENTE | PENDIENTE | Apache 2.0 (Plan) | PENDIENTE DE VERIFICACIÓN EXTERNA | `docker buildx imagetools inspect opensearchproject/opensearch:2.19.6` |
| OpenSearch Dashboards | 2.19.6 (debe coincidir con OpenSearch) | idem | PENDIENTE | PENDIENTE | depende de OpenSearch | PENDIENTE | PENDIENTE DE VERIFICACIÓN EXTERNA | `...opensearch-dashboards:2.19.6` |
| Valkey | 8.0.2 histórica (Gemini); investigar si existe una línea más reciente (el orquestador recuerda ramas 8.1 y 9.x, sin verificar) | valkey.io + GitHub releases | ene-2025 (8.0.2, según Gemini) | PENDIENTE | PENDIENTE | BSD 3-Clause según Gemini, sin verificar | PENDIENTE DE VERIFICACIÓN EXTERNA | No asumir que una etiqueta concreta existe; seleccionar con fuentes oficiales y prueba de compatibilidad. `docker buildx imagetools inspect valkey/valkey:<tag>-bookworm`. |
| asyncpg 0.30.0, Alembic 1.14.0, PyJWT 2.10.1, argon2-cffi 23.1.0, pytest 8.3.4, ruff 0.9.1, mypy 1.14.1, uv 0.5.21 | propuestas de Gemini ronda 2 | URLs de GitHub/PyPI en la respuesta | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | **Sospechosas de estar desactualizadas** (observación N1) | `pip index versions <paquete>` |
| Refine Core 4.54.0, **Next.js 15.1.4** | propuestas de Gemini (ronda 2) | GitHub releases | PENDIENTE | PENDIENTE | PENDIENTE | MIT (Plan) | PENDIENTE; riesgo de seguridad **no verificado** | El orquestador recuerda, de memoria y sin verificar, el aviso CVE-2025-29927 (bypass de middleware, corregido supuestamente en 15.2.3). La candidata 15.1.4 es histórica y no debe aprobarse. Comprobar con `npm audit` y los GitHub Security Advisories oficiales; que una versión corrija esa CVE no la hace segura: revisar todos los avisos vigentes a la fecha de selección. |
| Docker Engine 27.5.1, Compose 2.32.4 | propuestas de Gemini | docs.docker.com / GitHub | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | verificar versión mínima |

**Nota:** el digest solo se registra si fue visto en un registro público. Los tags flotantes de 0.2-MODO-AVANCE son provisionales y se fijan a parche + digest antes de cerrar la Fase 0 (sujeto a la discrepancia #12).

**Etiquetas históricas del prompt 0.2:** `postgres:16.15-bookworm`, `redis:7.4.11-bookworm`, `opensearchproject/opensearch:2.19.6`, `opensearchproject/opensearch-dashboards:2.19.6`. Ninguna verificada.

**Comandos propuestos por el orquestador al usuario (no ejecutados que se sepa):**
```
docker buildx imagetools inspect postgres:16.15-bookworm
docker buildx imagetools inspect redis:7.4.11-bookworm
docker buildx imagetools inspect valkey/valkey:8.0.2-bookworm
docker buildx imagetools inspect opensearchproject/opensearch:2.19.6
docker buildx imagetools inspect opensearchproject/opensearch-dashboards:2.19.6
docker buildx imagetools inspect python:3.11.17-slim-bookworm
pip index versions asyncpg   # alembic, pyjwt, argon2-cffi
uv python list --all-versions | grep 3.11
npm view next versions --json | tail -5
npm audit
git clone --depth 1 --branch 7.2.4 https://github.com/redis/redis /tmp/r724 && head -5 /tmp/r724/LICENSE.txt   # repetir con 7.2.5 y la última 7.2.x
```
Los digests no deben inventarse; se registran solo los obtenidos de un registro real.

**Hallazgos del orquestador sobre las respuestas de Gemini (valoraciones, no hechos verificados):**
- **Ronda 1 (rechazada como matriz):** H1 estado `verificado` contradictorio con "No verificado"; H2 variante `-alpine` cambiada sin justificar; H3 faltan la mayoría de entregables; H4 comparación Redis/Valkey incompleta (sin versión de Valkey ni Redis 8/AGPLv3); H5 "Redis 7.2.x = BSD" necesita verificación; H6 URLs flotantes o envueltas en redirector de Google; H7 redacción legal imprecisa; H8 mención errónea de Free-Threading en Python 3.11.
- **Ronda 2 (rechazada como matriz; decisiones aceptables):** N1 versiones de dos épocas (indicio de memoria, no búsqueda); N2 Next.js 15.1.4 con posibles avisos de seguridad; N3 dictamen legal sobreafirmado y "citas textuales" de licencias que no coinciden con el texto oficial conocido; N4 frontera de licencia de Redis 7.2.x incierta; N5 Valkey 8.0.2 dudoso como "estable actual"; N6 faltan `cryptography`, uvicorn, pytest-asyncio, httpx, clientes; N7 tabla de "versión anterior" poco fiable; N8 prueba `nofile` no mide lo que dice y `limits.conf` no aplica a contenedores; N9 `curl | sh` para instalar `uv`; N10 posible fallo de `uv venv --python 3.11.17` si el binario no existe.
- Aceptadas como decisiones propuestas: imágenes `-bookworm`, `uv` + `uv.lock`, Valkey en vez de Redis 7.4 (decisión final legal y del usuario), Dashboards opcional.

**Requisitos del host para OpenSearch (propuesta de Gemini, parcialmente cuestionada):** `vm.max_map_count=262144`; `nofile` 65536; `nproc` 4096; swap. El orquestador señaló que `limits.conf` del host no aplica a contenedores (usar `--ulimit` en Compose) y que `swapoff -a` global es excesivo para desarrollo (bastan `bootstrap.memory_lock` y `memlock` ilimitado).

**Nota técnica del orquestador sobre OpenSearch:** desde 2.12, con el plugin de seguridad activo, la imagen exige `OPENSEARCH_INITIAL_ADMIN_PASSWORD`; el healthcheck dependiente de `curl` debe verificarse en la imagen real.

### 4.10 Esquema de telemetría (requisitos del 0.3)
Ver 4.8. Archivos planificados (**no creados**): `schemas/__init__.py`, `schemas/common.py`, `schemas/enums.py`, `schemas/suricata.py`, `schemas/agent.py`, `schemas/tests/`, `docs/alma-common-schema.md`. Requisitos clave: Pydantic v2; hora del evento vs recepción; tenant/sensor por autenticación; política de campos desconocidos y versiones futuras (`extra="forbid"` donde proceda, política documentada para eventos externos); conservar evento original y procedencia; hashes de integridad cuando corresponda; pruebas de zona horaria incluido `+0000`; sin afirmar aislamiento multi-tenant en el esquema.

### 4.11 Criterios de aceptación y auditoría
Comandos: `docker compose config`, `docker compose config --images`, `docker compose ps`, `docker compose logs --no-color`, `docker compose up -d`. Comprobaciones: compatibilidad e existencia de imágenes, salud de servicios, persistencia, secretos, puertos en loopback, configuración de seguridad, `vm.max_map_count=262144`, disponibilidad real de herramientas usadas en healthchecks (`curl`, `pg_isready`, `valkey-cli`/`redis-cli`). Categorías de evidencia: inspección documental, estática, prueba ejecutada, resultado reproducible, prueba no realizada, no evaluable por falta de archivos. **Hoy: ninguna prueba ejecutada.**

### 4.12 Registro de riesgos
Sin puntuaciones cuantitativas (no acordadas).

| Riesgo | Impacto | Mitigación conocida/propuesta | Estado | Dependencia | Evidencia pendiente |
|---|---|---|---|---|---|
| Fuga entre tenants | Exposición de datos de clientes | Middleware JWT + RLS + filtros OpenSearch + pruebas negativas | Solo diseñado | ADR-0003, Fase 1 | Código y pruebas de acceso cruzado |
| RLS eludida por dueño/superusuario | Aislamiento anulado | A3: rol app sin ser dueño, sin `BYPASSRLS`, `FORCE RLS` | Propuesto | ADR-0003 | Pruebas con roles |
| Fuga de contexto de tenant en pools | Datos de otro tenant | `SET LOCAL` por transacción (PoC 1 del Plan) | Solo diseñado | Fase 1 | PoC |
| Robo de API key de sensor | Telemetría falsa hasta revocar | Hash, scopes, revocación, rate limit, mTLS futuro | Riesgo residual declarado | ADR-0002 | — |
| Credencial compartida entre canales | Compromiso doble | A2 | Cerrada | — | — |
| Enrolamiento: canje paralelo o fallo a mitad | Doble uso del token | Consumo atómico, hash, expiración corta | Propuesto | ADR-0002/0003 | Prueba de concurrencia |
| `SECURITY DEFINER` mal configurada | Escalada de privilegios | `search_path` fijo, dueño sin privilegios, `REVOKE ... FROM PUBLIC`, `GRANT` explícito, prueba negativa | Propuesto | ADR-0003 | Prueba con rol no autorizado |
| Reutilización de refresh token / pérdida de estado de revocación | Sesiones robadas siguen vigentes | A6, familia de tokens, almacén persistente | Pendiente | R1, C1 | Decisión y pruebas |
| Fingerprint con colisión semántica | Alertas ocultas bajo una agrupación | Elegir campos con cuidado; SHA-256 no basta | Propuesto | ADR-0004 | Análisis |
| OpenSearch sin seguridad en desarrollo | Ningún aislamiento ni autenticación | Solo loopback, aviso visible, no producción | Aceptado en dev (propuesto) | Entorno 0.2/P0.C | Revisión en 0.4 |
| Índices por tenant tomados como frontera | Falsa sensación de seguridad | Filtros server-side + pruebas | Requisito | Fase 1/2 | Pruebas |
| Tags flotantes (`16-bookworm`, `8-bookworm`) | Falta de reproducibilidad | Fijar parche y digest antes de congelar | Abierto | V1 | Digests |
| Licencia Redis 7.4+ (RSALv2/SSPL) frente a SaaS | Riesgo legal | Valkey o Redis 7.2 (con verificación) | Pendiente | C1 y abogado | Dictamen legal |
| Contraseña de Valkey visible en la lista de procesos | Fuga local | Pasarla por variable de entorno / archivo | Propuesto | P0.C | Verificar `REDISCLI_AUTH` en imagen |
| Healthchecks sin verificar en imágenes reales | Falsos sanos/no sanos | Probar contra la imagen | Abierto | Ejecución de compose | `docker compose ps` real |
| Versiones desactualizadas o inexistentes | Instalación fallida/vulnerable | Verificación externa | Abierto | V1 | Comandos de 4.9 |
| Next.js con posibles CVE | Bypass de autenticación en frontend | `npm audit`, versión parcheada | Posible riesgo | D1 | Auditoría |
| Compromiso del Agent / replay de comandos | Ejecución indebida | API key por sensor, sudoers, lista blanca, `idempotency_key` | Solo diseñado | Fase 2/4 | Código y pruebas |
| Saturación (DoS, backpressure) | Caída de ingesta | SlowAPI, límites de Fluent Bit (PoC 2) | Solo diseñado | Fase 2 | PoC |
| Dependencia tecnológica | Pérdida de soberanía | Modularidad, conectores opcionales | Principio | — | — |
| Estancamiento por verificación infinita | Retraso indefinido de Fase 0 aunque haya tareas independientes | Regla de precedencia 4.6-bis, versiones provisionales explícitas, dependencias por componente, criterios de cierre en 4.14 | Mitigación propuesta; riesgo abierto | Confirmación del usuario | Ejecución real de 0.2-MODO-AVANCE |

### 4.13 Pendientes y bloqueos (priorizados) — v1.1

**A. Bloqueantes por estado de Fase 0**
- Para `FASE_0_ENTREGABLES_COMPLETADOS`: los seis entregables de MODO AVANCE producidos (compose, `.env.example`, monorepo, esquemas Pydantic básicos, requirements/`uv.lock`, README) y validaciones obligatorias con evidencia real. La estructura de monorepo se contrasta con la sección 13 del Plan (texto no transcrito aquí).
- Para `FASE_0_CERRADA`, además: matriz de versiones revisada y aprobada (0.1) e imágenes definitivas fijadas con referencia reproducible (digest preferente).
- Ni la matriz ni los digests bloquean la elaboración de 0.2-MODO-AVANCE, 0.3 o 0.3b.

**B. Bloqueantes de Fase 1, por componente (clasificación inferida por el parche y el orquestador; sin aprobación formal)**
- C1 Redis vs Valkey: workers de notificación, rate limiting y, según R1, refresh tokens.
- R1 Persistencia de refresh tokens: módulo Auth, tras ADR-0005.
- T1 TLS: canales de telemetría y control en producción; no bloquea desarrollo.
- A3 RLS + rol de aplicación: tablas multi-tenant.
- A5 Fingerprint SHA-256: módulo de deduplicación.
- A6 Rotación de refresh tokens: Auth.
Un bloqueante por componente no detiene componentes no dependientes (p. ej., el frontend puede avanzar sin C1).

**C. Tareas paralelas (no bloquean el inicio de otras)**
Investigación de versiones 0.1; verificación de licencias Redis/Valkey (fuente oficial + abogado); compatibilidad y vulnerabilidades (Next.js, Python 3.11, etc.; `npm audit`, `pip-audit`); preparación de los ADR (0.3b); auditoría 0.4 a medida que existan artefactos.

**D. Información faltante en el historial**
Resultado del 0.3b; salidas de los comandos de 4.9; resultado de 0.2-MODO-AVANCE (no ejecutado); dictamen legal Redis/Valkey; sección 13 del Plan Maestro.

**E. Inventario de archivos**

| Archivo | Categoría | Estado |
|---|---|---|
| `ALMA_CLOUD_MASTER_CONTEXT.md` | Existente (generado en esta conversación; v1.1) | Existe |
| `VERSIONES.md`, `RIESGOS.md` | Planificados (0.2-MODO-AVANCE) | No existen |
| `docker-compose.yml`, `.env.example`, `.gitignore`, `README.md` | Planificados (0.2-MODO-AVANCE) | No existen |
| `docs/adr/ADR-0002..0005-*.md` | Planificados (0.3b) | No existen |
| `schemas/*.py`, `schemas/tests/`, `docs/alma-common-schema.md` | Planificados (0.3) | No existen |
| `uv.lock`, `pyproject.toml` | Planificados | No existen |
| `docs/version-manifest.yaml` | Planificado (0.1) | No existe |
| Estructura de monorepo | Mencionada en el Plan (sección 13) | Texto no transcrito aquí |
| Prompts 0.1, 0.3b, P0.C | Texto íntegro en Apéndices A, B, C | Recuperados |
| Prompts 0.2 formal, 0.3, 0.4 | Resumen en 4.8 (el texto íntegro está en el historial de la conversación original) | No incluidos íntegros |

**F. Pruebas por ejecutar**
Las de 4.8/4.11; acceso cruzado entre tenants (Fase 1); reproducibilidad de fingerprints (ADR-0004); concurrencia de refresh tokens (ADR-0005); prueba negativa con rol no autorizado sobre `SECURITY DEFINER` (ADR-0003).

### 4.14 Definición de terminado — Fase 0 (regla única, v1.2)

**Estados:** `FASE_0_ENTREGABLES_COMPLETADOS` → `FASE_0_CERRADA` (ver 4.6-bis). Estado actual de la Fase 0: ninguno de los dos.

| Criterio | Cuenta para | Evidencia necesaria | Estado actual |
|---|---|---|---|
| `docker-compose.yml` con healthchecks y volúmenes | ENTREGABLES | Archivo + `docker compose config` + `up -d` + `ps` sanos | No existe |
| `.env.example` sin secretos reales | ENTREGABLES | Archivo + `.env` ignorado | No existe |
| Estructura de monorepo | ENTREGABLES | Árbol + contraste con sección 13 (`PENDIENTE DE VERIFICACIÓN CONTRA EL PLAN MAESTRO`) | No definida |
| Esquemas Pydantic básicos | ENTREGABLES | `schemas/*.py` + tests + doc | No existe |
| requirements / `uv.lock` inicial | ENTREGABLES | Archivo generado | No existe |
| README de arranque | ENTREGABLES | `README.md` | No existe |
| Validaciones obligatorias | ENTREGABLES | Salidas reales pegadas (mínimo propuesto en 4.6-bis, pendiente de confirmar) | Ninguna ejecutada |
| Matriz de versiones revisada y aprobada | CERRADA | `VERSIONES.md` con fuentes + aprobación humana | No existe; dos rondas Gemini rechazadas |
| Imágenes fijadas con referencia reproducible | CERRADA | Digests de registro público | No existen |

**No cuentan para ninguno de los dos estados** (seguimiento): ADR-0002 a 0005 (bloquean Fase 1), `RIESGOS.md`, auditoría 0.4.
Regla: ningún criterio pasa a `APROBADO` sin archivo, salida real y revisión cruzada.

### 4.15 Siguiente acción no bloqueada

**Tarea:** ejecutar **0.2-MODO-AVANCE** (texto íntegro en Apéndice C) en DeepSeek.
1. No hay que inventar el prompt; está en el Apéndice C.
2. Imágenes provisionales de ese prompt: `postgres:16-bookworm`, `valkey/valkey:8-bookworm` (Redis 7.2 solo si el usuario lo indica), `opensearchproject/opensearch:2.19.6`. **Nota:** el Apéndice C no incluye imagen de Python; `python:3.11-slim-bookworm` (línea base de MODO AVANCE) solo aplicaría a un Dockerfile futuro.
3. Todo lo no verificado se marca `PENDIENTE_VERIFICACION`.
4. No se afirma ejecución de comandos sin salida real pegada por el usuario.
5. Con los artefactos reales puede iniciarse la auditoría 0.4.

En paralelo: 0.1 (matriz) e investigación Redis/Valkey. **Advertencia:** el orquestador no ejecuta tareas en Gemini, DeepSeek ni Claude externos.

---

## 5. Contradicciones y discrepancias registradas

| # | Discrepancia | Estado | Resolución / nota |
|---|---|---|---|
| 1 | Python 3.13.x / PostgreSQL 17.x (prompt de continuidad) vs Python 3.11 / PostgreSQL 16 (historial) | `RESUELTO` por el usuario (v1.2) | 3.11 / 16 aceptados como líneas base **provisionales** para 0.2-MODO-AVANCE, pendientes de investigación y aprobación en la matriz 0.1. No son versiones definitivas; las etiquetas no están verificadas. |
| 2 | "Fase 0.1" para Compose vs numeración original | `RESUELTO` por el usuario (v1.2) | Nombre operativo **0.2-MODO-AVANCE**; P0.C se conserva como referencia histórica. |
| 3 | MODO AVANCE vs criterios de 0.4 y matriz congelada | `RESUELTO` por el usuario (v1.2) | MODO AVANCE rige la precedencia para tareas independientes en paralelo con la matriz 0.1. No elimina dependencias técnicas reales ni requisitos de cierre. |
| 4 | Licencia de Redis: Plan dice BSD; Gemini dice RSALv2/SSPLv1 desde 7.4 | Sin resolver | Revisión legal + `LICENSE.txt` por etiqueta. |
| 5 | Frontera BSD de Redis 7.2.x (Gemini: 7.2.4; orquestador dudó) | Sin resolver | Revisar 7.2.4, 7.2.5 y la última 7.2.x. |
| 6 | TLS: Plan (1.3/mTLS) vs T1 (1.2 mínimo) | T1 pendiente de aprobación | Decisión de Fase 1, no de Fase 0 (según parche). |
| 7 | `-alpine` (Gemini ronda 1) vs `-bookworm` | Propuesto `-bookworm` | Aprobación formal pendiente; 0.2-MODO-AVANCE ya usa `-bookworm`. |
| 8 | Dictamen de Gemini: Redis 7.4+ obligaría a liberar el código | Rechazado por sobreafirmación | Decisión del abogado. |
| 9 | Gemini marca `estado_imagen: verificado` en librerías sin imagen | **ABIERTO** (confirmado por el usuario) | El parche afirmaba que la ronda 2 lo corrigió; **no es cierto**: el YAML de la ronda 2 mantiene `estado_imagen: verificado` en componentes sin imagen (debe ser `N/A`). Se corrige al regenerar el manifiesto. |
| 10 | Sección 17 del Plan vs sección 17 aportada por el usuario | D1–D5 como línea base | Cerrado. |
| 11 | Valkey 8.0.2 citado como "estable actual" | Abierto | Investigar ramas posteriores con fuentes oficiales (ver 4.9). |
| 12 | Criterio de cierre de Fase 0: parche vs regla 5 de MODO AVANCE | `RESUELTO` por el usuario (v1.2) | Dos estados: `FASE_0_ENTREGABLES_COMPLETADOS` y `FASE_0_CERRADA` (ver 4.6-bis y 4.14). Complementa MODO AVANCE; no se atribuye a su texto original. Queda abierta la lista exacta de "validaciones obligatorias". |

---

## 6. Instrucciones de continuidad para el siguiente asistente

1. Lee este documento completo antes de proponer acciones.
2. Asume el rol de **orquestador técnico de ALMA CLOUD** descrito en 1.4.
3. Continúa desde el estado documentado, sin reiniciar la planificación.
4. Respeta **A1 y A2 como decisiones cerradas** (y D1–D5 como línea base).
5. No conviertas propuestas (A3, A5, A6, T1, R1, C1, V2–V4) en decisiones aprobadas.
6. No afirmes haber ejecutado pruebas, comandos o tareas externas sin evidencia pegada por el usuario.
7. Usa fuentes actuales para versiones, licencias y compatibilidad cuando tengas búsqueda; si no, mantén el estado `PENDIENTE`.
8. Mantén `PENDIENTE` cuando no puedas verificar un dato.
9. Pide solo la información indispensable que falte.
10. Antes de iniciar una fase, comprueba que se cumplieron sus dependencias (4.6, 4.13).
11. Mantén el registro de cambios al final de este documento.
12. Actualiza estados solo con evidencia suficiente.

**Inicio rápido v1.1.**
1. Leer este documento completo y, si está disponible, el Plan Maestro (secciones 1, 2, 3, 11, 13, 14, 17).
2. Pedir al usuario, solo si es necesario, que enumere las "validaciones obligatorias" de `FASE_0_ENTREGABLES_COMPLETADOS` (hay un mínimo propuesto en 4.6-bis). #1, #2, #3 y #12 están resueltas.
3. Preparar la ejecución de **0.2-MODO-AVANCE** (Apéndice C) en DeepSeek sin esperar a la matriz 0.1.
4. Mantener en paralelo 0.1 (matriz) y la investigación Redis/Valkey.
5. Auditar con 0.4 los artefactos reales cuando existan, con IA distinta a la autora.
6. Mantener pendientes de aprobación T1, R1, C1, V2–V4, A3, A5, A6 (ver 4.13.B).
7. No afirmar que una tarea externa se ejecutó si solo se propuso.
8. Cierre de cada respuesta: Estado, Siguiente tarea, máximo 3 preguntas bloqueantes.

### Registro de cambios
| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-09 | 1.0 | Creación inicial a partir del historial visible |
| 2026-10-09 | 1.1 | Parche aportado en la conversación, revisado y aplicado con correcciones: regla de precedencia (4.6-bis); pendientes reorganizados A–F (4.13); definición de terminado con columna de origen (4.14); siguiente acción (4.15); riesgo de estancamiento (4.12); notas CVE/Valkey marcadas como no verificadas (4.9); discrepancias #1–#3 resueltas provisionalmente, #9 reabierta, #12 nueva (sección 5); inicio rápido v1.1; sección 7. Apéndices A, B y C intactos. |
| 2026-10-09 | 1.2 | Decisiones del usuario: #12 resuelta con dos estados (`FASE_0_ENTREGABLES_COMPLETADOS` / `FASE_0_CERRADA`); #1, #2 y #3 resueltas; 4.6-bis, 4.13, 4.14 y sección 5 unificadas en una sola regla. #9, CVE-2025-29927 y Valkey 9.x siguen abiertos. La imagen de Python no se añade al prompt de Compose sin modificarlo explícitamente. |

---

## 7. Gobierno del proyecto

1. Este chat actúa como orquestador y es el único que declara aprobado un entregable dentro del flujo documentado (aprobación arquitectónica final: del usuario).
2. Gemini, DeepSeek, Claude u otras herramientas producen propuestas y artefactos; sus resultados no equivalen a aprobación arquitectónica.
3. Las pruebas ejecutadas se distinguen de las afirmaciones del modelo; una afirmación sin salida real se registra como `INFERIDO` o `PENDIENTE`.
4. Ante discrepancias entre asistentes prevalecen el Plan Maestro vigente y las decisiones aprobadas.
5. Si el Plan es ambiguo o contradictorio, se consulta al usuario antes de cerrar una decisión que cambie la arquitectura.
6. Si una incertidumbre no impide avanzar, se documenta en `RIESGOS.md` y se continúa solo con tareas independientes y reversibles.
7. Ningún asistente declara implementado o verificado un elemento sin evidencia suficiente.
8. Si estas reglas contradicen una regla ya aprobada, se registra en la sección 5; no se cambia en silencio.

---

## Apéndice A — Prompt 0.1 (texto original del usuario)

> Es el texto que el usuario pegó como versión definitiva "Fase 0.1: Investigación y congelación de la matriz tecnológica". El orquestador lo aprobó con el bloque de reglas adicionales que se recoge después. Existió una versión anterior más corta ("Validación de versiones y compatibilidad") con candidatas explícitas; no se reproduce aquí íntegra (resumen: validar Python 3.11.17, FastAPI 0.143.0, Pydantic 2.14.0, SQLAlchemy 2.0.54, PostgreSQL 16.15, Redis 7.4.11, OpenSearch 2.19.6, Dashboards 2.19.6 solo si se justifica y JWT RS256; comprobar dependencias, `uv`, digests, requisitos del host; distinguir compatibilidad documentada, resolución y pruebas).

~~~~
# ALMA CLOUD — Fase 0.1: Investigación y congelación de la matriz tecnológica

## Rol

Actúa como arquitecto de software y especialista en DevSecOps. Tienes acceso a búsqueda web y debes investigar las versiones actuales utilizando fuentes oficiales.

Tu tarea es proponer una matriz tecnológica reproducible para el desarrollo de ALMA CLOUD, una plataforma SaaS multi-tenant de monitorización, detección y respuesta ante incidentes de ciberseguridad.

No implementes todavía la aplicación ni generes Docker Compose. Primero investiga, compara y documenta.

## 1. Objetivo

Actualizar las versiones candidatas de Python, FastAPI, Pydantic, SQLAlchemy, PostgreSQL, Redis o Valkey, OpenSearch y sus dependencias.

Busca las versiones estables más recientes disponibles en la fecha de ejecución. No selecciones automáticamente la versión más nueva: evalúa compatibilidad, mantenimiento, seguridad, madurez, licencias y reproducibilidad.

## 2. Componentes que debes evaluar

Investiga y documenta versiones exactas para:

* Python.
* FastAPI.
* Pydantic v2.
* SQLAlchemy.
* Alembic.
* Controlador PostgreSQL asíncrono.
* PostgreSQL.
* Redis frente a Valkey.
* OpenSearch.
* OpenSearch Dashboards, si se utiliza.
* Biblioteca JWT compatible con RS256.
* Biblioteca para contraseñas con Argon2id.
* Pytest y herramientas de pruebas.
* Herramientas de linting y comprobación de tipos.
* Docker Compose y versión mínima del motor Docker.

Evalúa también la compatibilidad del candidato de frontend Refine.dev + Next.js, sin convertir esta investigación en una implementación.

## 3. Fuentes y verificación

Prioriza:

* Documentación oficial.
* Páginas oficiales de releases.
* PyPI y sus metadatos de paquetes.
* Repositorios oficiales de contenedores.
* Notas de compatibilidad y migración.
* Licencias originales de los proyectos.

Para cada componente, registra:

1. Versión estable candidata.
2. Versión anterior de referencia.
3. Fecha de publicación.
4. URL de la fuente.
5. Estado de mantenimiento.
6. Compatibilidad con Python y dependencias.
7. Cambios incompatibles relevantes.
8. Licencia aplicable.
9. Comando para verificar la versión o etiqueta.
10. Estado: verificado, pendiente o incompatible.

No afirmes haber descargado imágenes, instalado paquetes ni ejecutado pruebas si no lo hiciste.

## 4. Decisión de Redis y Valkey

Compara Redis y Valkey desde la perspectiva de un SaaS comercial.

Investiga licencias, restricciones de redistribución o de oferta como servicio gestionado, mantenimiento, compatibilidad del cliente y diferencias funcionales relevantes.

No describas Redis 7.4 o posteriores como BSD sin verificar la licencia concreta de la versión evaluada.

Recomienda una alternativa y explica el motivo. La decisión final requiere aprobación humana y, si corresponde, revisión legal.

## 5. Reglas de versiones

* No utilizar `latest`, rangos abiertos ni etiquetas ambiguas en la matriz congelada.
* Diferenciar versión de paquete, versión de imagen y digest.
* No inventar digests.
* Verificar la existencia de las etiquetas exactas de Docker.
* Para imágenes multiarquitectura, registrar la plataforma objetivo y el digest correspondiente.
* Mantener OpenSearch y OpenSearch Dashboards en versiones compatibles.
* Comprobar que las dependencias admitan la versión de Python seleccionada.
* Preferir versiones estables con correcciones de seguridad disponibles.
* Registrar las razones para no utilizar una versión principal más reciente.

Las versiones propuestas son candidatas hasta superar la prueba de compatibilidad.

## 6. Arquitectura que no debes modificar sin justificación

* Autenticación mediante JWT RS256.
* Credenciales separadas para el canal de control del agente y el canal de telemetría.
* ALMA Agent independiente, con canal de control propio.
* Suricata como servicio nativo systemd en sensores Linux.
* Fluent Bit como servicio independiente de recolección y transporte.
* PostgreSQL como base de datos principal.
* Aislamiento multi-tenant como requisito de seguridad.
* Docker Compose como entorno inicial de desarrollo.

No sustituyas ALMA por una plataforma SOC/XDR externa.

## 7. Resultado obligatorio

Entrega:

1. Tabla comparativa de versiones.
2. Fuentes oficiales de cada versión candidata.
3. Análisis de compatibilidad.
4. Comparación de licencias de Redis y Valkey.
5. Riesgos de actualización y cambios incompatibles.
6. Matriz recomendada con versiones exactas.
7. Lista de decisiones pendientes de aprobación humana.
8. Pruebas de compatibilidad que deberán ejecutarse en la siguiente fase.

No generes todavía `docker-compose.yml` ni los esquemas definitivos.

El resultado se considera una propuesta de matriz, no una aprobación de producción. No avances a la Fase 0.2 hasta que la matriz haya sido revisada y aprobada.
~~~~

**Bloque de reglas adicionales de evidencia para el 0.1 (redactado por el orquestador, aprobado por el usuario):**

~~~~
REGLAS ADICIONALES DE EVIDENCIA

1. Cada versión de la matriz debe llevar la URL de la fuente que la respalda.
   Si no pudiste abrir esa fuente, escribe "PENDIENTE" en lugar de la versión.
   No completes campos de memoria.
2. Las versiones candidatas que te di (Python 3.11.17, FastAPI 0.143.0,
   Pydantic 2.14.0, SQLAlchemy 2.0.54, PostgreSQL 16.15, Redis 7.4.11,
   OpenSearch 2.19.6) son hipótesis. Indica explícitamente cuáles existen
   y cuáles no.
3. Digests: registra solo los que hayas visto en un registro público.
   Para el resto, escribe "PENDIENTE: ejecutar docker buildx imagetools inspect <imagen>".
4. Redis: evalúa tres opciones (Redis 7.4.x, Redis 7.2.x, Valkey) y
   recomienda una, indicando qué licencia aplica a cada una y qué debe
   revisar un abogado.
5. Entrega además un manifiesto en YAML (docs/version-manifest.yaml) con el
   formato: componente, version_paquete, version_imagen, digest, fuente,
   estado (verificado | pendiente | incompatible).
6. Termina con una sección "No verificado" que liste todo lo que no pudiste
   comprobar y qué comando o fuente lo resolvería.
~~~~

**Prompt de seguimiento a Gemini propuesto por el orquestador tras la ronda 1** (se ejecutó; se obtuvo la ronda 2): corregir estados de imágenes, justificar `-alpine`, añadir Alembic, driver async, JWT, Argon2id, pytest, ruff, mypy, Docker/Compose mínimos, Dashboards y Refine + Next.js; Redis/Valkey con versión de Valkey y licencias de 7.2, Redis 8 y AGPLv3 citando texto original; versión anterior, fecha, mantenimiento, cambios incompatibles; decidir `uv`; requisitos del host; sin Free-Threading ni redirectores. Esto es un **resumen**, no el texto íntegro.

## Apéndice B — Prompt 0.3b (texto original del usuario + 13 ajustes)

> Texto original pegado por el usuario. `APROBADO PARA EJECUTAR`; no consta resultado.

~~~~
# ALMA CLOUD — Fase 0.3b: ADR de decisiones de seguridad

## Rol

Actúa como arquitecto de seguridad de aplicaciones y plataformas SaaS multi-tenant. Documenta las decisiones de arquitectura de seguridad de ALMA CLOUD mediante Architecture Decision Records (ADR).

No implementes todavía los mecanismos descritos ni afirmes que existen en el código. Debes producir decisiones técnicas verificables, sus requisitos de aceptación y las pruebas que serán necesarias en las fases de implementación.

## Contexto

ALMA CLOUD integra ALMA Agent, Suricata, Fluent Bit y una API central de ingesta. Fluent Bit transporta telemetría; Suricata inspecciona el tráfico que recibe mediante los mecanismos de captura configurados; ALMA Agent mantiene su propio canal de control.

Las decisiones A1 y A2 están cerradas:

* A1: Fluent Bit utilizará una API key enviada mediante header HTTP sobre TLS en el MVP. Se planifica evaluar mTLS en una fase posterior.
* A2: las credenciales del canal de control de ALMA Agent serán independientes de las credenciales del canal de telemetría de Fluent Bit.

No vuelvas a abrir estas decisiones salvo que encuentres una incompatibilidad o un riesgo técnico concreto.

## Entregables

Crea las propuestas de estos documentos:

### 1. `docs/adr/ADR-0002-telemetry-authentication.md`

Documenta:

* Contexto y problema.
* Decisión sobre API key por header.
* Requisitos de TLS: TLS 1.2 como mínimo y preferencia por TLS 1.3.
* Generación criptográficamente segura de claves aleatorias de alta entropía.
* Almacenamiento del hash de la clave, sin conservar el secreto recuperable.
* Comparación de hashes en tiempo constante cuando corresponda.
* Identificación del tenant y sensor a partir de la credencial validada, nunca confiando en valores aportados por el payload.
* Rechazo de discrepancias entre la identidad autenticada y los campos declarados en el evento.
* Separación de scopes y permisos entre telemetría y control.
* Revocación individual por credencial y rotación con periodo de solape controlado.
* Protección contra filtración de claves en logs, trazas, errores y herramientas de depuración.
* Rate limiting y límites de tamaño de peticiones.
* Manejo de respuestas de autenticación sin filtrar secretos.
* Riesgo residual por robo de una clave.
* Migración futura a mTLS y sus criterios de activación.

Para claves generadas aleatoriamente con alta entropía, evalúa SHA-256 para almacenamiento de fingerprints de credenciales; explica por qué no se requiere Argon2id en este caso, a diferencia del almacenamiento de contraseñas humanas.

No fijes endpoints ni nombres de headers definitivos sin declararlos como decisiones explícitas.

### 2. `docs/adr/ADR-0003-multitenant-postgresql-rls.md`

Documenta:

* PostgreSQL como base de datos principal.
* Row-Level Security (RLS) como defensa en profundidad para aislamiento entre tenants.
* Separación entre rol de migraciones y rol de aplicación.
* El rol de aplicación no será propietario de las tablas ni tendrá `BYPASSRLS`.
* Uso de `FORCE ROW LEVEL SECURITY` donde corresponda.
* Establecimiento seguro del contexto del tenant por transacción.
* Prevención de filtraciones de contexto mediante conexiones agrupadas en pool.
* Restricciones sobre consultas administrativas y procesos internos.
* Pruebas negativas que intenten leer, modificar y eliminar datos de otro tenant.

Aclara que RLS por sí sola no constituye una prueba de aislamiento completo. La autorización de aplicación, los permisos de base de datos y las pruebas de integración también deben verificarse.

### 3. `docs/adr/ADR-0004-event-fingerprints.md`

Documenta:

* Uso de SHA-256 en lugar de MD5 para fingerprints.
* Diferencia entre fingerprint de un evento, identificador de evento y hash de integridad del evento original.
* Tratamiento de JSON y canonicalización cuando se requiera un hash estable de contenido equivalente.
* Conservación del evento crudo o de una representación verificable cuando la política de retención lo permita.
* Limitaciones: un hash no demuestra por sí solo autenticidad, autoría ni ausencia de manipulación previa.
* Pruebas de reproducibilidad del fingerprint.

No impongas canonicalización universal si no es necesaria para el caso de uso.

### 4. `docs/adr/ADR-0005-refresh-token-lifecycle.md`

Documenta:

* JWT de acceso firmado mediante RS256.
* Separación entre tokens de acceso y refresh tokens.
* Rotación de refresh tokens.
* Almacenamiento seguro de refresh tokens en el servidor.
* Detección de reutilización de un token ya consumido.
* Revocación de la familia de tokens afectada ante reutilización confirmada.
* Tratamiento de solicitudes concurrentes y reintentos legítimos.
* Caducidad, revocación y cierre de sesión.
* Rotación de claves de firma mediante `kid`.
* Validación estricta de algoritmo, emisor, audiencia, expiración y claims.
* Pruebas negativas y escenarios de concurrencia.

No inventes duraciones de sesión ni políticas de retención: propón valores candidatos y márcalos como pendientes de aprobación.

## Formato de cada ADR

Cada archivo debe incluir:

1. Título e identificador.
2. Estado: propuesto.
3. Contexto.
4. Decisión.
5. Alternativas consideradas.
6. Consecuencias positivas y negativas.
7. Riesgos residuales.
8. Requisitos de aceptación.
9. Pruebas necesarias.
10. Decisiones pendientes.

## Reglas generales

* No inventes código existente, resultados de pruebas ni requisitos legales.
* Diferencia hechos, recomendaciones y decisiones pendientes.
* No cambies A1 ni A2.
* No afirmes que RLS, la autenticación o la rotación están implementadas.
* Mantén los documentos concisos, técnicos y adecuados para revisión por otro ingeniero.
* No generes aún Docker Compose ni implementes endpoints.
* Termina con un resumen de decisiones cerradas y pendientes.
~~~~

**Los 13 ajustes aprobados.** Los puntos 1 a 9 son del usuario (texto original resumido aquí por longitud; ver el historial para la redacción completa); los 10 a 13 los añadió el orquestador; el 12 se consolidó con la precisión del usuario. **Todo lo siguiente es resumen, salvo el punto 12, que es texto exacto.**

1. TLS: decisión propuesta TLS 1.2 mínimo / 1.3 objetivo en el MVP; configuración segura de TLS 1.2, prohibición de protocolos obsoletos, criterios para pasar a 1.3 obligatorio; marcar para aprobación humana.
2. ADR-0003, ámbito de RLS: tabla de tablas candidatas (con `tenant_id` y RLS obligatorio; globales sin RLS por tenant con controles propios; de identidad/enrolamiento/infraestructura que requieren análisis); sin esquema definitivo.
3. Enrolamiento de sensores: cómo se valida un sensor antes de tener identidad autenticada; token de un solo uso, duración limitada, vinculado a tenant o proceso autorizado; si hay `SECURITY DEFINER`, alcance, privilegios y parámetros limitados; sin bypass genérico de RLS.
4. OpenSearch: separar índices por tenant no es frontera suficiente; autorización y filtro en servidor en cada consulta; pruebas negativas; evaluar permisos del usuario de OpenSearch.
5. ADR-0004: distinguir `event_id`, `fingerprint`, `raw_hash`; campos del fingerprint y por qué; ataques de colisión semántica; SHA-256 no elimina colisiones semánticas por mala definición.
6. ADR-0005: comparar Redis/Valkey, PostgreSQL y combinada para familias de tokens, revocaciones y detección de reutilización; consecuencias de reinicios, pérdida y restauraciones; recomendar pero dejar pendiente de aprobación.
7. Etiquetado `[HECHO]`, `[RECOMENDACIÓN]`, `[PENDIENTE]`.
8. No declarar implementados RLS, autenticación, protección de OpenSearch, tokens ni TLS sin evidencia.
9. Revisar coherencia entre ADR (almacenamiento de hashes, identidad de sensores, aislamiento, persistencia de tokens, licencias Redis/Valkey).
10. TLS: criterios medibles para exigir 1.3 (porcentaje de sensores que negocian 1.3, inventario de bibliotecas TLS, fecha de revisión).
11. Enrolamiento: token almacenado como hash, consumo atómico, expiración corta y comportamiento si el canje falla a mitad.
12. **Texto exacto aprobado:**
~~~~
12. SECURITY DEFINER: search_path fijo dentro de la función, dueño sin
    privilegios amplios, REVOKE EXECUTE FROM PUBLIC y GRANT EXECUTE
    únicamente al rol de aplicación autorizado. Incluye una prueba que
    verifique con un rol no autorizado que la llamada falla.
~~~~
13. OpenSearch: con el plugin de seguridad desactivado (desarrollo) no existe aislamiento en OpenSearch y no debe presentarse como control de seguridad.

## Apéndice C — Prompt DeepSeek de Compose en MODO AVANCE (P0.C, texto íntegro, redactado por el orquestador)

> Estado: `APROBADO PARA EJECUTAR` por el orquestador; `NO EJECUTADO`. Etiquetas provisionales y flotantes; ver 4.12.

~~~~
ROL
Eres un ingeniero DevOps. Genera el entorno local de desarrollo de ALMA CLOUD
(plataforma SaaS multi-tenant SOC/XDR). No implementes backend, tablas, RLS ni
lógica de negocio.

MODO DE TRABAJO
- Entrega los archivos completos, con placeholders donde falte un dato. No me
  pidas ejecutar nada para continuar.
- Todo dato que no hayas podido verificar (etiquetas de imagen, comandos
  disponibles dentro de la imagen, nombres de variables) se marca
  PENDIENTE_VERIFICACION en VERSIONES.md. No afirmes haber ejecutado pruebas.
- Si dudas entre dos opciones, elige la más conservadora y documéntala en
  RIESGOS.md.
- No reabras estas decisiones cerradas: PostgreSQL como base principal,
  Valkey como caché/cola auxiliar (Redis 7.2 solo si se indica), OpenSearch
  para eventos, Docker Compose para desarrollo.

IMÁGENES (provisionales)
- postgres:16-bookworm
- valkey/valkey:8-bookworm
- opensearchproject/opensearch:2.19.6
- No uses latest. Declara cada tag en variables del .env.example
  (POSTGRES_IMAGE, VALKEY_IMAGE, OPENSEARCH_IMAGE) con el tag por defecto.
- Deja en VERSIONES.md una columna "digest" con el valor
  PENDIENTE_VERIFICACION y el comando:
  docker buildx imagetools inspect <imagen>

ARCHIVOS A ENTREGAR (ruta como encabezado, contenido completo)
1. docker-compose.yml
2. .env.example
3. .gitignore (ignora .env, volúmenes locales y secretos)
4. README.md (arranque)
5. VERSIONES.md
6. RIESGOS.md

REQUISITOS DE docker-compose.yml
General
- Red dedicada alma-dev. Nombre de proyecto fijo.
- Todos los puertos publicados solo en 127.0.0.1.
- restart: unless-stopped en desarrollo.
- Variables obligatorias con la sintaxis ${VAR:?mensaje} para que Compose
  falle si faltan secretos.
- Sin secretos reales ni valores por defecto de contraseñas.

PostgreSQL 16
- Volumen nombrado persistente.
- Usuario, base y contraseña por variables.
- Healthcheck con pg_isready usando usuario y base configurados.
- Puerto 127.0.0.1:${POSTGRES_PORT:-5432}:5432.
- No crees tablas ni roles de aplicación. Documenta en README que más
  adelante habrá un rol de migraciones y otro de aplicación sin ser dueño
  de las tablas.

Valkey 8
- Autenticación con requirepass tomada de variable de entorno.
- appendonly yes (persistencia AOF), volumen nombrado, maxmemory configurable
  y maxmemory-policy noeviction.
- Healthcheck con valkey-cli ping autenticado. Pasa la contraseña por variable
  de entorno del cliente (REDISCLI_AUTH o equivalente), no como argumento en
  la línea de comandos. Marca PENDIENTE_VERIFICACION si la variable no existe
  en la imagen.
- Puerto 127.0.0.1:${VALKEY_PORT:-6379}:6379.
- Documenta que Valkey NO es fuente de verdad: lo que no pueda perderse
  (tokens revocados, auditoría) va en PostgreSQL.

OpenSearch 2.19.6
- Nodo único: discovery.type=single-node.
- Volumen nombrado persistente.
- OPENSEARCH_JAVA_OPTS con Xms y Xmx configurables por variable (por defecto
  512m).
- bootstrap.memory_lock=true con ulimits memlock ilimitado y nofile 65536.
- Plugin de seguridad: DISABLE_SECURITY_PLUGIN=true SOLO para desarrollo
  local. Pon un comentario visible en el compose y en el README: en este
  modo OpenSearch no tiene autenticación ni aislamiento entre tenants y
  nunca debe usarse en producción ni expuesto fuera de loopback.
- Healthcheck: curl a /_cluster/health aceptando estado yellow o green.
  Confirma que curl existe en la imagen; si no, marca
  PENDIENTE_VERIFICACION y propón alternativa.
- start_period largo en el healthcheck (OpenSearch tarda en arrancar).
- Puerto 127.0.0.1:${OPENSEARCH_PORT:-9200}:9200. No publiques 9600.
- NO incluyas OpenSearch Dashboards en esta fase.

REQUISITOS DE .env.example
- Solo valores de ejemplo claramente ficticios del tipo CAMBIAR_ESTO_xxx.
- Instrucción en comentario para generar secretos locales:
  openssl rand -base64 32
- Variables: imágenes, puertos, credenciales de Postgres, contraseña de Valkey,
  límites de memoria, heap de OpenSearch.

REQUISITOS DE README.md
- Requisito del host: vm.max_map_count=262144 (comando para comprobarlo,
  aplicarlo temporalmente y hacerlo persistente).
- Pasos: copiar .env.example a .env, generar secretos, docker compose config,
  up -d, ps, logs, comprobaciones de salud de cada servicio, parada y
  reinicio.
- Diferencia entre `docker compose down` y `docker compose down -v`
  (este último borra los datos). Marca el segundo como destructivo.
- Tabla de puertos, volúmenes y persistencia.
- Sección "Qué NO está implementado todavía": backend, tablas, RLS,
  autenticación, aislamiento multi-tenant en OpenSearch.

REQUISITOS DE VERSIONES.md
- Tabla: componente, tag de imagen, digest (PENDIENTE_VERIFICACION), estado
  del tag (PENDIENTE_VERIFICACION), fuente (URL del registro o repositorio
  oficial si la conoces; si no, PENDIENTE_VERIFICACION).
- Nota: los tags de rama (16-bookworm, 8-bookworm) son flotantes y se
  fijarán a un parche exacto con su digest antes de congelar la matriz.

REQUISITOS DE RIESGOS.md
Incluye como mínimo:
- Tags flotantes de Postgres y Valkey (reproducibilidad).
- Seguridad de OpenSearch desactivada en desarrollo.
- Contraseña de Valkey visible en la lista de procesos del contenedor si va
  en la línea de comandos; mitigación propuesta.
- Licencia: decisión Valkey/Redis pendiente de revisión legal.
- Healthchecks sin verificar contra las imágenes reales.

FORMATO DE CIERRE
Termina con: archivos creados, supuestos hechos, lista de elementos
PENDIENTE_VERIFICACION y los comandos que yo ejecutaré después para validar
(docker compose config, up -d, ps).
~~~~

## Apéndice D — Limitaciones de este documento
- Basado solo en el historial visible. Los textos de los prompts 0.2, 0.3 y 0.4 y el Plan Maestro se resumen; no se reproducen íntegros (están en el historial).
- Los puntos 1-9 de los ajustes de 0.3b se resumen; el punto 12 es literal.
- No se puede garantizar que el documento contenga absolutamente todo lo conversado.
- v1.2: #1, #2, #3 y #12 resueltas por decisión explícita del usuario. Sigue sin definirse la lista de "validaciones obligatorias".
- Las afirmaciones sobre CVE-2025-29927 y sobre ramas 8.1/9.x de Valkey son recuerdos del orquestador, no verificados.
- Este documento no sustituye la verificación real: toda etiqueta Docker sigue sin confirmar hasta que el usuario pegue la salida de `docker buildx imagetools inspect`.
