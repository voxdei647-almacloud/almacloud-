from datetime import datetime
from typing import Any, Dict
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class TenantBase(BaseModel):
    slug: str = Field(..., max_length=64)
    name: str = Field(..., max_length=128)


class TenantCreate(TenantBase):
    pass


class TenantRead(TenantBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SensorBase(BaseModel):
    hostname: str = Field(..., max_length=253)
    profile: str = Field(..., max_length=64)


class SensorCreate(SensorBase):
    pass


class SensorRead(SensorBase):
    id: UUID
    tenant_id: UUID
    lifecycle_status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AuditLogRead(BaseModel):
    id: UUID
    tenant_id: UUID
    actor: str
    action: str
    resource: str
    details: Dict[str, Any]
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)
