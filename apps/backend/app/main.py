from fastapi import FastAPI
from app.api.v1.sensors import router as sensors_router
from app.api.v1.audit import router as audit_router
from app.core.config import settings

app = FastAPI(
    title="ALMA CLOUD Control Plane API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.include_router(sensors_router, prefix="/api/v1")
app.include_router(audit_router, prefix="/api/v1")


@app.get("/healthz", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": "alma-backend",
        "version": "0.1.0"
    }
