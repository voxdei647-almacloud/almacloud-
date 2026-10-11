from fastapi import FastAPI
from app.core.config import settings

app = FastAPI(
    title="ALMA CLOUD Control Plane API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)


@app.get("/healthz", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": "alma-backend",
        "version": "0.1.0"
    }
