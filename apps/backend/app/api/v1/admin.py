"""Router de administración — CAPA DE AGREGACIÓN para el dashboard admin."""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select, func, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, require_roles
from app.core.security import hash_password
from app.models.domain import Tenant, Sensor, AuditLog, User, BillingSnapshot

router = APIRouter(prefix="/admin", tags=["admin"])
SUPER = Depends(require_roles("super_admin"))


# ──────────────────────────────────────────────
# Modelos Pydantic para Escritura (POST/PATCH)
# ──────────────────────────────────────────────
class AdminUserCreate(BaseModel):
    email: EmailStr
    password: str
    role: str = "tenant_admin"


class TenantStatusUpdate(BaseModel):
    status: str  # 'active', 'past_due', 'suspended'


# ──────────────────────────────────────────────
# Helpers de serialización
# ──────────────────────────────────────────────
def _tenant(t: Tenant, agents: int) -> dict:
    return {
        "id": str(t.id),
        "name": t.name,
        "plan": getattr(t, "plan", "basic"),
        "status": getattr(t, "status", "active"),
        "mrr": 0,
        "agents": agents,
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }


def _audit(log: AuditLog) -> dict:
    return {
        "id": str(log.id),
        "action": log.action,
        "details": getattr(log, "details", None) or getattr(log, "detail", "") or "",
        "user_id": str(log.actor_id) if getattr(log, "actor_id", None) else None,
        "ip": str(getattr(log, "ip_address", "") or "") or None,
        "created_at": log.created_at.isoformat() if log.created_at else None,
    }


# ──────────────────────────────────────────────
# ENDPOINTS GET (Lectura)
# ──────────────────────────────────────────────
@router.get("/tenants")
async def list_tenants(
    response: Response,
    status: Optional[str] = None,
    q: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = SUPER,
):
    stmt = select(Tenant).order_by(Tenant.created_at.desc())
    if status:
        stmt = stmt.where(Tenant.status == status)
    if q:
        stmt = stmt.where(Tenant.name.ilike(f"%{q}%"))

    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    response.headers["X-Total-Count"] = str(total)

    stmt = stmt.offset((page - 1) * per_page).limit(per_page)
    tenants = (await db.execute(stmt)).scalars().all()

    if not tenants:
        return []
    ids = [t.id for t in tenants]
    counts = await db.execute(
        select(Sensor.tenant_id, func.count(Sensor.id))
        .where(Sensor.tenant_id.in_(ids) & (Sensor.status == "active"))
        .group_by(Sensor.tenant_id)
    )
    agent_counts = {str(tid): int(c) for tid, c in counts.all()}
    return [_tenant(t, agent_counts.get(str(t.id), 0)) for t in tenants]


@router.get("/tenants/{tenant_id}")
async def get_tenant(tenant_id: str, db: AsyncSession = Depends(get_db), _: User = SUPER):
    try:
        tid = UUID(tenant_id)
    except ValueError:
        raise HTTPException(404, "Tenant no encontrado")

    tenant = (await db.execute(select(Tenant).where(Tenant.id == tid))).scalar_one_or_none()
    if not tenant:
        raise HTTPException(404, "Tenant no encontrado")

    agents = (await db.execute(
        select(func.count(Sensor.id))
        .where((Sensor.tenant_id == tid) & (Sensor.status == "active"))
    )).scalar() or 0

    data = _tenant(tenant, int(agents))
    data["invoices"] = []
    data["_mock"] = True
    return data


@router.get("/billing/metrics")
async def billing_metrics(db: AsyncSession = Depends(get_db), _: User = SUPER):
    total = (await db.execute(select(func.count(Tenant.id)))).scalar() or 0
    active = (await db.execute(select(func.count(Tenant.id)).where(Tenant.status == "active"))).scalar() or 0
    past_due = (await db.execute(select(func.count(Tenant.id)).where(Tenant.status == "past_due"))).scalar() or 0

    now = datetime.now(timezone.utc)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    mrr_query = select(func.sum(BillingSnapshot.amount_usd)).where(
        BillingSnapshot.status == "paid",
        BillingSnapshot.snapshot_date >= start_of_month
    )
    mrr = float((await db.execute(mrr_query)).scalar() or 0)

    history_query = text("""
        SELECT TO_CHAR(snapshot_date, 'YYYY-MM') as month, SUM(amount_usd) as value
        FROM alma.billing_snapshots
        WHERE status = 'paid'
        GROUP BY month
        ORDER BY month DESC
        LIMIT 6
    """)
    history_res = await db.execute(history_query)
    mrr_history = [{"month": row.month, "value": float(row.value)} for row in history_res.all()]
    mrr_history.reverse()

    return {
        "mrr": mrr, "arr": mrr * 12, "gcp_cost": 0, "margin": 0,
        "tenants_total": int(total), "tenants_active": int(active), "tenants_past_due": int(past_due),
        "churn_rate": None, "mrr_history": mrr_history, "_mock": False,
    }


@router.get("/health/services")
async def health_services(db: AsyncSession = Depends(get_db), _: User = SUPER):
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    pg = "up"
    try:
        await db.execute(select(func.now()))
    except Exception:
        pg = "down"
    return {
        "services": [
            {"name": "PostgreSQL", "status": pg, "last_check": now},
            {"name": "Valkey", "status": "unknown", "last_check": None},
            {"name": "SIEM (on-prem)", "status": "unknown", "last_check": None},
            {"name": "WireGuard", "status": "unknown", "last_check": None},
        ],
        "uptime_30d": None, "latency_p99_ms": None, "error_rate_5xx": None, "_mock": True,
    }


@router.get("/audit/recent")
async def recent_audit(
    limit: int = Query(10, ge=1, le=100),
    action: Optional[str] = None,
    since: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    _: User = SUPER,
):
    stmt = select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)
    if action:
        stmt = stmt.where(AuditLog.action == action)
    if since:
        try:
            stmt = stmt.where(AuditLog.created_at >= datetime.fromisoformat(since.replace("Z", "+00:00")))
        except ValueError:
            pass
    return [_audit(log) for log in (await db.execute(stmt)).scalars().all()]


# ──────────────────────────────────────────────
# ENDPOINTS DE ESCRITURA (POST/DELETE/PATCH)
# ──────────────────────────────────────────────
@router.post("/tenants/{tenant_id}/users", status_code=status.HTTP_201_CREATED)
async def create_tenant_user(
    tenant_id: str,
    payload: AdminUserCreate,
    db: AsyncSession = Depends(get_db),
    _: User = SUPER
):
    try:
        tid = UUID(tenant_id)
    except ValueError:
        raise HTTPException(404, "Tenant no encontrado")

    tenant = (await db.execute(select(Tenant).where(Tenant.id == tid))).scalar_one_or_none()
    if not tenant:
        raise HTTPException(404, "Tenant no encontrado")

    existing = (await db.execute(select(User).where(User.tenant_id == tid, User.email == payload.email))).scalar_one_or_none()
    if existing:
        raise HTTPException(400, "El correo ya está registrado en este tenant")

    new_user = User(
        tenant_id=tid,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=payload.role
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return {"id": str(new_user.id), "email": new_user.email, "role": new_user.role}


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = SUPER
):
    try:
        uid = UUID(user_id)
    except ValueError:
        raise HTTPException(404, "Usuario no encontrado")

    user = (await db.execute(select(User).where(User.id == uid))).scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Usuario no encontrado")

    await db.delete(user)
    await db.commit()
    return None


@router.patch("/tenants/{tenant_id}/status")
async def update_tenant_status(
    tenant_id: str,
    payload: TenantStatusUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = SUPER
):
    try:
        tid = UUID(tenant_id)
    except ValueError:
        raise HTTPException(404, "Tenant no encontrado")

    tenant = (await db.execute(select(Tenant).where(Tenant.id == tid))).scalar_one_or_none()
    if not tenant:
        raise HTTPException(404, "Tenant no encontrado")

    if payload.status not in ('active', 'past_due', 'suspended'):
        raise HTTPException(400, "Estado inválido")

    tenant.status = payload.status
    await db.commit()
    
    return {"id": str(tenant.id), "status": tenant.status}
