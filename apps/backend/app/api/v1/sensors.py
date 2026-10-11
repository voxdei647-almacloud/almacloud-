from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db
from app.models.domain import Sensor
from app.schemas.domain import SensorCreate, SensorRead

router = APIRouter(prefix="/sensors", tags=["Sensors"])


@router.get("", response_model=List[SensorRead])
async def list_sensors(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Sensor))
    return result.scalars().all()


@router.post("", response_model=SensorRead, status_code=status.HTTP_201_CREATED)
async def create_sensor(
    sensor_in: SensorCreate,
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    sensor = Sensor(
        tenant_id=UUID(tenant_id_str),
        hostname=sensor_in.hostname,
        profile=sensor_in.profile,
        lifecycle_status="active"
    )
    db.add(sensor)
    await db.commit()
    await db.refresh(sensor)
    return sensor
