"""Router de administración — CAPA DE AGREGACIÓN para el dashboard admin.

NO reemplaza los endpoints base de ALMA (`/tenants`, `/audit-logs`, `/healthz`).
Consumido solo por el proxy del SIEM (Bearer ALMA_SERVICE_TOKEN).
Contrato v1 CONGELADO — no cambiar formatos JSON.

TODO(billing): MRR real cuando exista `billing_snapshots`.
TODO(B11): migrar de alma_dev (superusuario) a alma_app con RLS forzado.
TODO(auth): JWT de servicio (aud=siem, scope=admin, 15 min) vs token estático.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, require_roles
from app.models.domain import Tenant, Sensor, AuditLog, User

router = APIRouter(prefix="/admin", tags=["admin"])
SUPER = Depends(require_roles("super_admin"))


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
    return {
        "mrr": 0, "arr": 0, "gcp_cost": 0, "margin": 0,
        "tenants_total": int(total), "tenants_active": int(active), "tenants_past_due": int(past_due),
        "churn_rate": None, "mrr_history": [], "_mock": True,
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
