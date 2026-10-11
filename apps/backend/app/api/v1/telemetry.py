import logging
from datetime import datetime, timezone
from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from opensearchpy import AsyncOpenSearch
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, get_opensearch
from app.schemas.domain import TelemetryCreate, TelemetryRead

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/telemetry", tags=["Telemetry"])
INDEX_NAME = "alma-telemetry-v1"


@router.post("/events", status_code=status.HTTP_201_CREATED)
async def ingest_telemetry_event(
    event_in: TelemetryCreate,
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    doc = {
        "tenant_id": tenant_id_str,
        "sensor_id": str(event_in.sensor_id) if event_in.sensor_id else None,
        "event_type": event_in.event_type,
        "severity": event_in.severity,
        "source_ip": event_in.source_ip,
        "destination_ip": event_in.destination_ip,
        "raw_event": event_in.raw_event,
        "timestamp": now_iso
    }

    response = await os_client.index(index=INDEX_NAME, body=doc, refresh=True)
    return {
        "id": response["_id"],
        "status": "indexed",
        "tenant_id": tenant_id_str,
        "timestamp": now_iso
    }


@router.get("/events", response_model=List[TelemetryRead])
async def search_telemetry_events(
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch)
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()

    query = {
        "query": {
            "bool": {
                "filter": [
                    {"term": {"tenant_id": tenant_id_str}}
                ]
            }
        },
        "sort": [
            {"timestamp": {"order": "desc"}}
        ],
        "size": 50
    }

    try:
        search_res = await os_client.search(index=INDEX_NAME, body=query)
    except Exception as exc:
        logger.error(f"Error consultando OpenSearch: {exc}")
        return []

    hits = search_res.get("hits", {}).get("hits", [])
    results = []
    for hit in hits:
        src = hit["_source"]
        results.append(
            TelemetryRead(
                id=hit["_id"],
                tenant_id=UUID(src["tenant_id"]),
                sensor_id=UUID(src["sensor_id"]) if src.get("sensor_id") else None,
                event_type=src.get("event_type", "unknown"),
                severity=src.get("severity", "info"),
                source_ip=src.get("source_ip"),
                destination_ip=src.get("destination_ip"),
                raw_event=src.get("raw_event", {}),
                timestamp=src.get("timestamp")
            )
        )
    return results
