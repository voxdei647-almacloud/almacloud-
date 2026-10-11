import logging
from typing import List, Dict, Any
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, require_roles
from app.models.domain import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


@router.get("", response_model=List[Dict[str, Any]])
async def get_audit_logs(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("super_admin", "tenant_admin", "admin"))
):
    res = await db.execute(
        text("SELECT id, tenant_id, actor_type, actor_id AS user_id, action, resource, details, created_at FROM alma.audit_logs ORDER BY created_at DESC LIMIT 100")
    )
    rows = res.mappings().all()
    results = []
    for r in rows:
        d = dict(r)
        if d.get("id"):
            d["id"] = str(d["id"])
        if d.get("tenant_id"):
            d["tenant_id"] = str(d["tenant_id"])
        if d.get("created_at"):
            d["created_at"] = d["created_at"].isoformat()
        results.append(d)
    return results
