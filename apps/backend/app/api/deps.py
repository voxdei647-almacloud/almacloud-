from typing import AsyncGenerator
from fastapi import Header, HTTPException, status
import redis.asyncio as redis
from opensearchpy import AsyncOpenSearch
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_tenant_db
from app.core.valkey import get_valkey_client
from app.core.opensearch import get_opensearch_client


async def get_db(x_tenant_id: str = Header(..., alias="X-Tenant-ID")) -> AsyncGenerator[AsyncSession, None]:
    if not x_tenant_id or not x_tenant_id.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Encabezado 'X-Tenant-ID' requerido."
        )

    async for session in get_tenant_db(x_tenant_id.strip()):
        yield session


async def get_valkey() -> redis.Redis:
    return await get_valkey_client()


async def get_opensearch() -> AsyncOpenSearch:
    return await get_opensearch_client()
