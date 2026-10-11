from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
import os

from app.api.v1.sensors import router as sensors_router
from app.api.v1.audit import router as audit_router
from app.api.v1.telemetry import router as telemetry_router
from app.api.v1.auth import router as auth_router

app = FastAPI(
    title="ALMA Cloud API",
    version="1.0.0",
    description="Backend de Ciberseguridad Multitenant y Telemetría SOC (VOX DEI)"
)

# Rutas de API v1
app.include_router(auth_router, prefix="/api/v1")
app.include_router(sensors_router, prefix="/api/v1")
app.include_router(audit_router, prefix="/api/v1")
app.include_router(telemetry_router, prefix="/api/v1")


@app.get("/healthz", tags=["Health"])
async def healthz():
    return {"status": "healthy", "service": "ALMA Cloud API"}


# Montar interfaz de usuario estática en /ui
static_dir = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../frontend/public")
)

if os.path.exists(static_dir):
    app.mount("/ui", StaticFiles(directory=static_dir, html=True), name="ui")


@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/ui/index.html")
