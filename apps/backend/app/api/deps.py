from typing import AsyncGenerator, Optional
from fastapi import Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_tenant_db


async def get_db(
    x_tenant_id: Optional[str] = Header(default=None, alias="X-Tenant-ID", description="UUID del tenant para RLS")
) -> AsyncGenerator[AsyncSession, None]:
    if not x_tenant_id or len(x_tenant_id.strip()) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El encabezado X-Tenant-ID es obligatorio para RLS."
        )
    async for session in get_tenant_db(x_tenant_id.strip()):
        yield session
