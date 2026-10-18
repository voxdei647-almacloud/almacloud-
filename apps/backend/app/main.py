import logging
import os
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse

from app.api.v1.auth import router as auth_router
from app.api.v1.sensors import router as sensors_router
from app.api.v1.audit import router as audit_router
from app.api.v1.admin import router as admin_router

from app.core.valkey import init_valkey, close_valkey, get_valkey_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("alma-backend")


from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_valkey()
    logger.info("Conexiones inicializadas: Valkey")
    yield
    # Shutdown
    await close_valkey()
    logger.info("Conexiones cerradas: Valkey")

app = FastAPI(lifespan=lifespan, 
    title="ALMA Cloud Backend API",
    version="1.0.0",
    description="Backend de Ciberseguridad Multitenant y Telemetría SOC (VOX DEI)",
    docs_url=None,  # Deshabilitar Swagger UI por seguridad
    redoc_url=None   # Deshabilitar ReDoc por seguridad
)

# 1. Configuración Estricta de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Tenant-ID", "X-API-Key"],
)



# 3. Middleware de Seguridad: Rate Limiting y Cabeceras HTTP
@app.middleware("http")
async def security_headers_and_rate_limit(request: Request, call_next):
    client_ip = request.client.host if request.client else "127.0.0.1"

    # Evaluamos si el limitador está activo (por defecto activo, salvo en pruebas)
    rate_limit_enabled = os.getenv("ENABLE_RATE_LIMIT", "true").lower() == "true"
    max_login_attempts = int(os.getenv("RATE_LIMIT_MAX_LOGIN", "100" if not rate_limit_enabled else "5"))

    # Rate Limit en Login
    if rate_limit_enabled and request.url.path == "/api/v1/auth/login" and request.method == "POST":
        try:
            valkey = await get_valkey_client()
            rate_key = f"rate_limit:login:{client_ip}"
            attempts = await valkey.incr(rate_key)
            if attempts == 1:
                await valkey.expire(rate_key, 60)
            if attempts > max_login_attempts:
                return Response(
                    content='{"detail": "Demasiados intentos de inicio de sesión. Intente más tarde."}',
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    media_type="application/json"
                )
        except Exception as e:
            logger.warning(f"Error consultando Valkey para rate limiting: {e}")

    response: Response = await call_next(request)

    # Inyección de Cabeceras de Seguridad HTTP
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self';"

    return response

# 4. Inclusión de Routers API v1
app.include_router(auth_router, prefix="/api/v1")
app.include_router(sensors_router, prefix="/api/v1")
app.include_router(audit_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")

# 5. Archivos Estáticos de la Interfaz Web
static_dir = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../frontend/public")
)

if os.path.exists(static_dir):
    app.mount("/ui", StaticFiles(directory=static_dir, html=True), name="ui")

@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/ui/index.html")

@app.get("/healthz", tags=["Health"])
async def healthz():
    return {"status": "healthy", "service": "ALMA Cloud API"}
