from datetime import datetime
from typing import Literal, Optional, Dict, Any
from uuid import UUID
from pydantic import BaseModel, ConfigDict, EmailStr, Field


RoleType = Literal["super_admin", "tenant_admin", "admin", "analyst", "sensor", "system"]

class UserBase(BaseModel):
    email: EmailStr
    role: RoleType = Field(default="analyst", description="Roles válidos en el sistema ALMA.")


class UserCreate(UserBase):
    password: str


class UserRead(UserBase):
    id: UUID
    tenant_id: UUID
    is_active: bool = True
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenRead(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: Optional[str] = None
    tenant_id: Optional[str] = None
    role: Optional[str] = None


class SensorBase(BaseModel):
    name: Optional[str] = "srv-app-01"
    hostname: Optional[str] = None
    sensor_type: str = Field(default="network")
    ip_address: Optional[str] = None


class SensorCreate(SensorBase):
    pass


class SensorEnroll(BaseModel):
    hostname: str
    profile: Optional[str] = "endpoint"
    enrollment_key: str


class SensorRead(SensorBase):
    id: UUID
    tenant_id: UUID
    name: str
    sensor_type: str
    ip_address: Optional[str] = None
    status: str
    is_active: bool = True
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class TelemetryCreate(BaseModel):
    sensor_id: Optional[UUID] = None
    event_type: str = Field(..., json_schema_extra={"example": "alert"})
    severity: str = Field(..., json_schema_extra={"example": "high"})
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
