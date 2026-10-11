from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, require_roles
from app.models.domain import AuditLog, User
from app.schemas.domain import AuditLogRead

router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("", response_model=List[AuditLogRead])
async def list_audit_logs(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("admin"))
):
    result = await db.execute(
        select(AuditLog).order_by(AuditLog.created_at.desc()).limit(100)
    )
    return result.scalars().all()
