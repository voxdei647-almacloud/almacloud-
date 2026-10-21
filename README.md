# ALMA CLOUD — Control Plane (Backend)

Backend FastAPI para la plataforma ALMA CLOUD (VOX DEI). Este servicio actúa exclusivamente como el **Plano de Control** (gestión de identidad, tenants, facturación y auditoría). El procesamiento de telemetría y eventos (Plano de Datos) ha sido delegado a un sistema SIEM externo.

## Stack Actual
| Componente | Versión | Rol |
|---|---|---|
| Python | 3.13 | Runtime |
| FastAPI | (instalada) | API HTTP |
| PostgreSQL | 16 | BD transaccional, RLS multi-tenant |
| Valkey | 8 | Rate limiting y caché |
| SQLAlchemy | 2.x async | ORM |
| PyJWT | RS256 | Firma/verificación de JWT |

*(Nota: OpenSearch, ML y Telemetría han sido eliminados del proyecto).*

## Requisitos del Host
- Docker Engine y Docker Compose v2.
- No requiere configuración de `vm.max_map_count` (ya no usamos OpenSearch).

## Arranque Rápido (Desarrollo / GCP)
1. **Clonar el repositorio** y entrar al directorio.
2. **Configurar variables de entorno:** Copiar `.env.example` a `.env` y configurar:
   - `POSTGRES_APP_PASSWORD` (contraseña de la base de datos).
   - `ALMA_SERVICE_TOKEN` (token maestro para que el SIEM consuma la API).
   - Claves JWT en `secrets/` (`jwt_private.pem` y `jwt_public.pem`).
3. **Levantar la Infraestructura:**
   ```bash
   docker compose -f docker-compose.prod.yml up -d
