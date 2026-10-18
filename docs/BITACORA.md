
### 2026-10-18 — Limpieza Técnica Pre-Producción (Rama: `chore/tech-debt-cleanup`)
- **Docker Prod:** Eliminado el servicio y volumen de OpenSearch en `docker-compose.prod.yml`. Restaurada la red `alma_network`.
- **Pydantic v2:** Migrado `class Config` a `model_config = ConfigDict(...)` y `example=` a `json_schema_extra`.
- **FastAPI Lifespan:** Reemplazado `@app.on_event` por `@asynccontextmanager`.
- **Tests:** 6/6 pasando, 0 warnings.
