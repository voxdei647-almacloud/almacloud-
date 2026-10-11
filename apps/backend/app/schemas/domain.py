from datetime import datetime
from typing import Any, Dict, Optional
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
    actor_type: str
    actor_id: str
    action: str
    resource: str
    details: Dict[str, Any]
    ip_address: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TelemetryCreate(BaseModel):
    event_type: str = Field(..., max_length=64)
    severity: str = Field("info", max_length=16)
    source_ip: Optional[str] = None
    destination_ip: Optional[str] = None
    sensor_id: Optional[UUID] = None
    raw_event: Dict[str, Any] = Field(default_factory=dict)


class TelemetryRead(BaseModel):
    id: str
    tenant_id: UUID
    sensor_id: Optional[UUID] = None
    event_type: str
    severity: str
    source_ip: Optional[str] = None
    destination_ip: Optional[str] = None
    raw_event: Dict[str, Any]
    timestamp: datetime
