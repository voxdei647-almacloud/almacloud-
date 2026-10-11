from typing import AsyncGenerator, Dict, Any, Optional
from uuid import UUID
from fastapi import Header, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import redis.asyncio as redis
from opensearchpy import AsyncOpenSearch
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_tenant_db
from app.core.valkey import get_valkey_client
from app.core.opensearch import get_opensearch_client
from app.core.security import decode_access_token
from app.models.domain import User

security_scheme = HTTPBearer(auto_error=False)


async def get_db(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    token: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)
) -> AsyncGenerator[AsyncSession, None]:
    tenant_id: Optional[str] = None

    if token:
        payload = decode_access_token(token.credentials)
        if not payload or "tenant_id" not in payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token de acceso inválido o expirado."
            )
        tenant_id = payload["tenant_id"]

    if not tenant_id and x_tenant_id:
        tenant_id = x_tenant_id.strip()

    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Se requiere un token Bearer o el encabezado 'X-Tenant-ID'."
        )

    async for session in get_tenant_db(tenant_id):
        yield session


async def verify_token(
    token: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme)
) -> Dict[str, Any]:
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Se requiere cabecera 'Authorization: Bearer <token>'."
        )

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
    res = await db.execute(select(User).where(User.id == user_id))
    user = res.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no encontrado o fuera de contexto."
        )

    return user


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


async def get_opensearch() -> AsyncOpenSearch:
    return await get_opensearch_client()
