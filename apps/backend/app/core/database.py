from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.sql import text
from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

async def get_tenant_db(tenant_id: str, role: str = "") -> AsyncGenerator[AsyncSession, None]:
    """Provee una sesión con contexto RLS a nivel de TRANSACCIÓN (SET LOCAL)."""
    async with AsyncSessionLocal() as session:
        await session.execute(
            text("SELECT set_config('app.current_tenant_id', :tenant_id, true)"),
            {"tenant_id": tenant_id}
        )
        await session.execute(
            text("SELECT set_config('app.current_role', :role, true)"),
            {"role": role}
        )
        try:
            yield session
        finally:
            pass
