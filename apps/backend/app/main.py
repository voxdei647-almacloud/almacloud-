from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.api.v1.sensors import router as sensors_router
from app.api.v1.audit import router as audit_router
from app.api.v1.telemetry import router as telemetry_router
from app.api.v1.auth import router as auth_router
from app.core.valkey import init_valkey, close_valkey
from app.core.opensearch import init_opensearch, close_opensearch


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_valkey()
    await init_opensearch()
    yield
    await close_opensearch()
    await close_valkey()


app = FastAPI(
    title="ALMA CLOUD Control Plane API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(sensors_router, prefix="/api/v1")
app.include_router(audit_router, prefix="/api/v1")
app.include_router(telemetry_router, prefix="/api/v1")


@app.get("/healthz", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": "alma-backend",
        "version": "0.1.0"
    }
