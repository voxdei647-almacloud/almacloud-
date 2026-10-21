from typing import AsyncGenerator, Dict, Any, Optional
from uuid import UUID
from fastapi import Header, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import redis.asyncio as redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_tenant_db
from app.core.valkey import get_valkey_client
from app.core.security import decode_access_token
from app.core.config import settings
from app.models.domain import User, Sensor

security_scheme = HTTPBearer(auto_error=False)

async def get_db(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    token: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)
) -> AsyncGenerator[AsyncSession, None]:
    tenant_id: Optional[str] = None
    role: str = ""

    if token:
        # 1. BYPASS: Token de servicio (SIEM -> ALMA)
        if settings.ALMA_SERVICE_TOKEN and token.credentials == settings.ALMA_SERVICE_TOKEN:
            tenant_id = "00000000-0000-0000-0000-000000000000"
            role = "super_admin"
        else:
            # 2. Flujo normal de JWT
            payload = decode_access_token(token.credentials)
            if payload:
                tenant_id = payload.get("tenant_id")
                role = payload.get("role", "")

    if not tenant_id and x_tenant_id:
        tenant_id = x_tenant_id.strip()

    if not tenant_id:
        # BYPASS TEMPORAL PARA LOGIN: Si no hay token, asumimos super_admin
        # para poder buscar al usuario por su email en la tabla users.
        tenant_id = "00000000-0000-0000-0000-000000000000"
        role = "super_admin"

    async for session in get_tenant_db(tenant_id, role):
        yield session

async def verify_token(
    token: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)
) -> Dict[str, Any]:
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Se requiere cabecera 'Authorization: Bearer <token>'."
        )

    # BYPASS: Token de servicio
    if settings.ALMA_SERVICE_TOKEN and token.credentials == settings.ALMA_SERVICE_TOKEN:
        return {
            "sub": "00000000-0000-0000-0000-000000000000",
            "tenant_id": "00000000-0000-0000-0000-000000000000",
            "role": "super_admin"
        }

    payload = decode_access_token(token.credentials)
    if not payload or "sub" not in payload or "tenant_id" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de acceso inválido o expirado."
        )

    return payload

async def get_current_user(
    payload: Dict[str, Any] = Depends(verify_token),
    db: AsyncSession = Depends(get_db)
) -> User:
    user_id = UUID(payload["sub"])
    
    # BYPASS: Usuario de servicio
    if str(user_id) == "00000000-0000-0000-0000-000000000000":
        return User(id=user_id, tenant_id=user_id, email="service@alma.cloud", role="super_admin")

    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado o fuera de contexto."
        )

    return user

async def get_current_sensor(
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    db: AsyncSession = Depends(get_db),
) -> Sensor:
    raise NotImplementedError("Implementación pendiente en Inc. 0006")

def require_roles(*allowed_roles: str):
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permiso denegado. Se requiere uno de los roles: {allowed_roles}"
            )
        return current_user
    return role_checker

async def get_valkey() -> redis.Redis:
    return await get_valkey_client()
