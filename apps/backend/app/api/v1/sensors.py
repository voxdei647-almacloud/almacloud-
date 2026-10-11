import secrets
from datetime import datetime, timezone
from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
import redis.asyncio as redis
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, get_valkey, require_roles
from app.core.config import settings
from app.models.domain import Sensor, AuditLog, User
from app.schemas.domain import SensorCreate, SensorRead, SensorEnrollRequest, SensorEnrollResponse

router = APIRouter(prefix="/sensors", tags=["Sensors"])


@router.post("/enrollment", response_model=SensorEnrollResponse, status_code=status.HTTP_201_CREATED)
async def enroll_sensor(
    enroll_in: SensorEnrollRequest,
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    expected_key = getattr(settings, "ENROLLMENT_KEY", "alma-secret-enroll-key-2026")
    if enroll_in.enrollment_key != expected_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Clave de enrolamiento inválida."
        )

    tenant_uuid = UUID(tenant_id_str)
    generated_api_key = f"ak_{secrets.token_hex(24)}"

    sensor = Sensor(
        tenant_id=tenant_uuid,
        hostname=enroll_in.hostname,
        profile=enroll_in.profile,
        lifecycle_status="active"
    )
    db.add(sensor)
    await db.flush()

    audit_entry = AuditLog(
        tenant_id=tenant_uuid,
        actor_type="sensor",
        actor_id=str(sensor.id),
        action="sensor.enrolled",
        resource=f"sensor:{sensor.id}",
        details={"hostname": sensor.hostname, "profile": sensor.profile}
    )
    db.add(audit_entry)

    await db.commit()
    await db.refresh(sensor)

    return SensorEnrollResponse(
        sensor_id=sensor.id,
        tenant_id=tenant_uuid,
        hostname=sensor.hostname,
        api_key=generated_api_key,
        status=sensor.lifecycle_status
    )


@router.get("", response_model=List[SensorRead])
async def list_sensors(
    current_user: User = Depends(require_roles("admin", "analyst")),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Sensor))
    return result.scalars().all()


@router.post("", response_model=SensorRead, status_code=status.HTTP_201_CREATED)
async def create_sensor(
    sensor_in: SensorCreate,
    current_user: User = Depends(require_roles("admin")),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    tenant_uuid = UUID(tenant_id_str)

    sensor = Sensor(
        tenant_id=tenant_uuid,
        hostname=sensor_in.hostname,
        profile=sensor_in.profile,
        lifecycle_status="active"
    )
    db.add(sensor)
    await db.flush()

    audit_entry = AuditLog(
        tenant_id=tenant_uuid,
        actor_type="user",
        actor_id=str(current_user.id),
        action="sensor.create",
        resource=f"sensor:{sensor.id}",
        details={
            "hostname": sensor.hostname,
            "profile": sensor.profile,
            "status": sensor.lifecycle_status
        }
    )
    db.add(audit_entry)

    await db.commit()
    await db.refresh(sensor)
    return sensor


@router.post("/{sensor_id}/heartbeat", status_code=status.HTTP_200_OK)
async def register_heartbeat(
    sensor_id: UUID,
    db: AsyncSession = Depends(get_db),
    cache: redis.Redis = Depends(get_valkey)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()

    sensor_res = await db.execute(select(Sensor).where(Sensor.id == sensor_id))
    sensor = sensor_res.scalar_one_or_none()

    if not sensor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sensor no encontrado o fuera de alcance."
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    cache_key = f"tenant:{tenant_id_str}:sensor:{sensor_id}:heartbeat"

    await cache.hset(cache_key, mapping={
        "status": "online",
        "last_seen": now_iso,
        "hostname": sensor.hostname
    })
    await cache.expire(cache_key, 300)

    return {
        "status": "online",
        "sensor_id": str(sensor_id),
        "last_seen": now_iso
    }


@router.get("/{sensor_id}/status", status_code=status.HTTP_200_OK)
async def get_sensor_status(
    sensor_id: UUID,
    current_user: User = Depends(require_roles("admin", "analyst")),
    db: AsyncSession = Depends(get_db),
    cache: redis.Redis = Depends(get_valkey)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()

    sensor_res = await db.execute(select(Sensor).where(Sensor.id == sensor_id))
    sensor = sensor_res.scalar_one_or_none()

    if not sensor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sensor no encontrado o fuera de alcance."
        )

    cache_key = f"tenant:{tenant_id_str}:sensor:{sensor_id}:heartbeat"
    cache_data = await cache.hgetall(cache_key)

    if not cache_data:
        return {
            "sensor_id": str(sensor_id),
            "hostname": sensor.hostname,
            "status": "offline",
            "last_seen": None
        }

    return {
        "sensor_id": str(sensor_id),
        "hostname": sensor.hostname,
        "status": cache_data.get("status", "unknown"),
        "last_seen": cache_data.get("last_seen")
    }
