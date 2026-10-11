from datetime import datetime
from typing import Optional, Any, Dict, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, EmailStr, Field


# --- Tenant Schemas ---
class TenantBase(BaseModel):
    name: str = Field(..., max_length=100)
    slug: str = Field(..., max_length=50)


class TenantCreate(TenantBase):
    pass


class TenantRead(TenantBase):
    id: UUID
    status: str = "active"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr
    role: str = Field(default="analyst")


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserRead(UserBase):
    id: UUID
    tenant_id: UUID
    status: str = "active"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- Auth Schemas ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenRead(BaseModel):
    access_token: str
    token_type: str = "bearer"
    tenant_id: UUID


# --- Sensor Schemas ---
class SensorBase(BaseModel):
    hostname: str = Field(..., max_length=100)
    profile: str = Field(default="endpoint")


class SensorCreate(SensorBase):
    pass


class SensorRead(SensorBase):
    id: UUID
    tenant_id: UUID
    lifecycle_status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SensorEnrollRequest(BaseModel):
    hostname: str
    profile: str
    enrollment_key: str


class SensorEnrollResponse(BaseModel):
    sensor_id: UUID
    tenant_id: UUID
    hostname: str
    api_key: str
    status: str


# --- Audit Log Schemas ---
class AuditLogRead(BaseModel):
    id: UUID
    tenant_id: UUID
    actor_type: str
    actor_id: str
    action: str
    resource: str
    details: Dict[str, Any]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- Telemetry Schemas ---
class TelemetryCreate(BaseModel):
    sensor_id: Optional[UUID] = None
    event_type: str
    severity: str = "info"
    source_ip: Optional[str] = None
    destination_ip: Optional[str] = None
    raw_event: Dict[str, Any] = Field(default_factory=dict)


class TelemetryBatchCreate(BaseModel):
    events: list[TelemetryCreate]


class TelemetryRead(BaseModel):
    id: str
    tenant_id: UUID
    sensor_id: Optional[UUID] = None
    event_type: str
    severity: str
    source_ip: Optional[str] = None
    destination_ip: Optional[str] = None
    raw_event: Dict[str, Any]
    timestamp: str
