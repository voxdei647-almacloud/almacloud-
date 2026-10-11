from typing import AsyncGenerator, Optional
from fastapi import Header, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import redis.asyncio as redis
from opensearchpy import AsyncOpenSearch
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_tenant_db
from app.core.valkey import get_valkey_client
from app.core.opensearch import get_opensearch_client
from app.core.security import decode_access_token

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
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Se requiere un token Bearer o el encabezado 'X-Tenant-ID'."
        )

    async for session in get_tenant_db(tenant_id):
        yield session


async def get_valkey() -> redis.Redis:
    return await get_valkey_client()


async def get_opensearch() -> AsyncOpenSearch:
    return await get_opensearch_client()
