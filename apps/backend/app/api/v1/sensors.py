import json
import logging
import os
from typing import List, Optional
from uuid import UUID, uuid4
from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis as Valkey
from app.api.deps import get_db, get_valkey, require_roles
from app.models.domain import User
from app.schemas.domain import SensorCreate, SensorEnroll, SensorRead
from fastapi import Request
import hashlib

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sensors", tags=["Sensors"])


@router.get("", response_model=List[SensorRead])
async def list_sensors(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("super_admin", "tenant_admin", "admin", "analyst"))
):
    res = await db.execute(text("SELECT id, tenant_id, hostname, profile, lifecycle_status, last_seen_at, created_at FROM alma.sensors"))
    rows = res.mappings().all()
    results = []
    for r in rows:
        d = dict(r)
        results.append(SensorRead(
            id=d["id"],
            tenant_id=d["tenant_id"],
            name=d["hostname"] or f"Sensor-{str(d['id'])[:8]}",
            sensor_type=d["profile"] or "network",
            ip_address=None,
            status=d["lifecycle_status"] or "active",
            is_active=True,
            created_at=d["created_at"]
        ))
    return results


@router.post("", response_model=SensorRead, status_code=status.HTTP_201_CREATED)
async def create_sensor(
    sensor_in: SensorCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("super_admin", "tenant_admin", "admin"))
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Contexto de tenant no configurado.")

    tenant_id = UUID(tenant_id_str)
    sensor_name = sensor_in.hostname or sensor_in.name or "srv-app-01"

    profile_val = sensor_in.sensor_type.lower() if sensor_in.sensor_type else "network"
    if profile_val not in ("endpoint", "network"):
        profile_val = "network"

    res = await db.execute(
        text("""
            INSERT INTO alma.sensors (tenant_id, hostname, profile, lifecycle_status)
            VALUES (:tenant_id, :hostname, :profile, 'active')
            RETURNING id, tenant_id, hostname, profile, lifecycle_status, last_seen_at, created_at
        """),
        {
            "tenant_id": tenant_id,
            "hostname": sensor_name,
            "profile": profile_val
        }
    )
    row = res.mappings().one()
    await db.commit()

    audit_details = json.dumps({"sensor_id": str(row["id"]), "name": sensor_name})

    await db.execute(
        text("""
            INSERT INTO alma.audit_logs (tenant_id, actor_type, actor_id, action, resource, details)
            VALUES (:t, 'user', :a_id, :a, 'sensor', CAST(:d AS jsonb))
        """),
        {
            "t": tenant_id,
            "a_id": str(current_user.id),
            "a": "sensor.create",
            "d": audit_details
        }
    )
    await db.commit()

    return SensorRead(
        id=row["id"],
        tenant_id=row["tenant_id"],
        name=row["hostname"] or sensor_name,
        sensor_type=row["profile"] or profile_val,
        ip_address=sensor_in.ip_address,
        status=row["lifecycle_status"] or "active",
        is_active=True,
        created_at=row["created_at"]
    )


@router.post("/enrollment", status_code=status.HTTP_201_CREATED)
async def enroll_sensor(
    enroll_in: SensorEnroll,
    db: AsyncSession = Depends(get_db),
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID")
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar() or x_tenant_id

    if not tenant_id_str:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Contexto de tenant no configurado.")

    expected_key = os.getenv("ENROLLMENT_KEY", "alma-secret-enroll-key-2026")
    if enroll_in.enrollment_key != expected_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Clave de enrolamiento inválida.")

    tenant_id = UUID(tenant_id_str)
    profile_val = enroll_in.profile.lower() if enroll_in.profile else "endpoint"
    if profile_val not in ("endpoint", "network"):
        profile_val = "endpoint"

    res = await db.execute(
        text("""
            INSERT INTO alma.sensors (tenant_id, hostname, profile, lifecycle_status)
            VALUES (:tenant_id, :hostname, :profile, 'active')
            RETURNING id, tenant_id, hostname, profile, lifecycle_status, created_at
        """),
        {
            "tenant_id": tenant_id,
            "hostname": enroll_in.hostname,
            "profile": profile_val
        }
    )
    row = res.mappings().one()
    await db.commit()

    api_key = f"ak_{uuid4().hex}"
    key_prefix = api_key[:8]
    key_hash = hashlib.sha256(api_key.encode("utf-8")).hexdigest()

    await db.execute(
        text("""
            INSERT INTO alma.sensor_credentials
                (id, tenant_id, sensor_id, channel, key_prefix, key_hash, status, created_at)
            VALUES
                (:id, :tenant_id, :sensor_id, 'control', :key_prefix, :key_hash, 'active', NOW())
        """),
        {
            "id": str(uuid4()),
            "tenant_id": str(tenant_id),
            "sensor_id": str(row["id"]),
            "key_prefix": key_prefix,
            "key_hash": key_hash,
        }
    )
    await db.commit()

    return {
        "status": "enrolled",
        "sensor_id": str(row["id"]),
        "hostname": row["hostname"],
        "api_key": api_key
    }


@router.post("/{sensor_id}/heartbeat", status_code=status.HTTP_200_OK)
async def register_heartbeat(
    sensor_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    valkey_client: Valkey = Depends(get_valkey),
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    import hashlib
    import hmac

    effective_tenant_id = None

    # --- CAMINO 1: Autenticación por Bearer JWT (Usuario Humano / Dashboard) ---
    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        try:
            from app.core.security import decode_access_token
            payload = decode_access_token(token)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token JWT inválido o expirado."
            )

        if not payload or not isinstance(payload, dict):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token JWT inválido o expirado."
            )

        effective_tenant_id = (
            payload.get("tenant_id")
            or payload.get("tid")
            or payload.get("tenant")
        )

        if not effective_tenant_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token JWT sin tenant_id válido."
            )

        sensor_res = await db.execute(
            text("SELECT id FROM alma.sensors WHERE id = :sensor_id AND tenant_id = :tenant_id"),
            {"sensor_id": str(sensor_id), "tenant_id": str(effective_tenant_id)}
        )
        if not sensor_res.first():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sensor no encontrado para este tenant."
            )

    # --- CAMINO 2: Autenticación por API Key + Tenant ID (Agente) ---
    elif x_api_key and x_tenant_id:
        from datetime import datetime, timezone
        effective_tenant_id = x_tenant_id
        computed_hash = hashlib.sha256(x_api_key.encode("utf-8")).hexdigest()

        sensor_res = await db.execute(
            text("""
                SELECT s.id,
                       s.lifecycle_status,
                       c.key_hash,
                       c.status        AS cred_status,
                       c.revoked_at,
                       c.expires_at
                FROM alma.sensors s
                JOIN alma.sensor_credentials c
                  ON c.sensor_id = s.id
                 AND c.tenant_id = s.tenant_id
                WHERE s.id = :sensor_id
                  AND s.tenant_id = :tenant_id
                ORDER BY c.created_at DESC
                LIMIT 1
            """),
            {"sensor_id": str(sensor_id), "tenant_id": x_tenant_id}
        )
        sensor_row = sensor_res.mappings().first()

        if not sensor_row:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="API Key o Tenant ID inválido para este sensor."
            )

        if sensor_row.get("lifecycle_status") == "inactive":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="El sensor está inactivo."
            )

        if sensor_row.get("cred_status") != "active":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La credencial del sensor no está activa."
            )

        if sensor_row.get("revoked_at") is not None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La credencial ha sido revocada."
            )

        expires_at = sensor_row.get("expires_at")
        if expires_at is not None and expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La credencial ha expirado."
            )

        stored_hash = sensor_row.get("key_hash")
        if not stored_hash or not hmac.compare_digest(stored_hash, computed_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="API Key inválida."
            )

    # --- CAMINO 3: Sin credenciales válidas ---
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticación requerida: Bearer JWT o X-API-Key + X-Tenant-ID."
        )

    # Registrar estado online en Valkey
    valkey_key = f"sensor:{effective_tenant_id}:{sensor_id}:status"
    await valkey_client.set(valkey_key, "online", ex=120)

    return {"status": "online", "sensor_id": str(sensor_id), "tenant_id": effective_tenant_id}

@router.get("/{sensor_id}/status")
async def get_sensor_status(
    sensor_id: UUID,
    db: AsyncSession = Depends(get_db),
    valkey_client: Valkey = Depends(get_valkey),
    current_user: User = Depends(require_roles("super_admin", "tenant_admin", "admin", "analyst"))
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()

    sensor_res = await db.execute(
        text("SELECT id FROM alma.sensors WHERE id = :s_id"),
        {"s_id": sensor_id}
    )
    if not sensor_res.scalar():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor no encontrado o fuera de alcance.")

    valkey_key = f"sensor:{tenant_id_str}:{sensor_id}:status"
    status_val = await valkey_client.get(valkey_key)

    if isinstance(status_val, bytes):
        status_str = status_val.decode("utf-8")
    elif status_val:
        status_str = str(status_val)
    else:
        status_str = "offline"

    return {
        "sensor_id": str(sensor_id),
        "tenant_id": tenant_id_str,
        "status": status_str
    }
