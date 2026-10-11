import logging
from datetime import datetime, timezone
from typing import List, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Body
from opensearchpy import AsyncOpenSearch
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, get_opensearch, require_roles
from app.models.domain import User
from app.schemas.domain import TelemetryCreate, TelemetryRead, TelemetryBatchCreate
from app.services.suricata_parser import parse_eve_event
from app.services.alert_engine import AlertRuleEngine

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/telemetry", tags=["Telemetry"])
INDEX_NAME = "alma-telemetry-v1"


@router.post("/events", status_code=status.HTTP_201_CREATED)
async def ingest_telemetry_event(
    event_in: TelemetryCreate,
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch),
    current_user: User = Depends(require_roles("admin", "sensor", "system"))
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
    generated_alert = AlertRuleEngine.evaluate_event(tenant_id_str, doc)

    return {
        "id": response["_id"],
        "status": "indexed",
        "tenant_id": tenant_id_str,
        "alert_triggered": generated_alert is not None,
        "alert_details": generated_alert,
        "timestamp": now_iso
    }


@router.post("/events/batch", status_code=status.HTTP_201_CREATED)
async def ingest_telemetry_batch(
    batch_in: TelemetryBatchCreate,
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch),
    current_user: User = Depends(require_roles("admin", "sensor", "system"))
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    bulk_body = []
    events_for_alerts = []

    for item in batch_in.events:
        event_dict = {
            "tenant_id": tenant_id_str,
            "sensor_id": str(item.sensor_id) if item.sensor_id else None,
            "event_type": item.event_type,
            "severity": item.severity,
            "source_ip": item.source_ip,
            "destination_ip": item.destination_ip,
            "raw_event": item.raw_event,
            "timestamp": now_iso
        }
        bulk_body.append({"index": {"_index": INDEX_NAME}})
        bulk_body.append(event_dict)
        events_for_alerts.append(event_dict)

    if not bulk_body:
        return {"ingested_count": 0, "status": "empty_batch"}

    bulk_response = await os_client.bulk(body=bulk_body, refresh=True)
    alerts = AlertRuleEngine.process_batch(tenant_id_str, events_for_alerts)

    return {
        "ingested_count": len(batch_in.events),
        "alerts_generated": len(alerts),
        "errors": bulk_response.get("errors", False),
        "status": "processed",
        "timestamp": now_iso
    }


@router.post("/suricata/eve-batch", status_code=status.HTTP_201_CREATED)
async def ingest_suricata_eve_batch(
    eve_logs: List[Dict[str, Any]] = Body(...),
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch),
    current_user: User = Depends(require_roles("admin", "sensor", "system"))
):
    res = await db.execute(text("SELECT current_setting('app.current_tenant_id', true)"))
    tenant_id_str = res.scalar()
    if not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contexto de tenant no configurado."
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    bulk_body = []
    events_for_alerts = []

    for raw_eve in eve_logs:
        parsed = parse_eve_event(raw_eve)
        event_dict = {
            "tenant_id": tenant_id_str,
            "sensor_id": raw_eve.get("host"),
            "event_type": parsed["event_type"],
            "severity": parsed["severity"],
            "source_ip": parsed.get("source_ip"),
            "destination_ip": parsed.get("destination_ip"),
            "raw_event": raw_eve,
            "timestamp": raw_eve.get("timestamp", now_iso)
        }
        bulk_body.append({"index": {"_index": INDEX_NAME}})
        bulk_body.append(event_dict)
        events_for_alerts.append(event_dict)

    if not bulk_body:
        return {"ingested_count": 0, "status": "empty_batch"}

    bulk_response = await os_client.bulk(body=bulk_body, refresh=True)
    alerts = AlertRuleEngine.process_batch(tenant_id_str, events_for_alerts)

    return {
        "ingested_count": len(eve_logs),
        "alerts_generated": len(alerts),
        "errors": bulk_response.get("errors", False),
        "status": "normalized_and_indexed",
        "timestamp": now_iso
    }


@router.get("/events", response_model=List[TelemetryRead])
async def search_telemetry_events(
    db: AsyncSession = Depends(get_db),
    os_client: AsyncOpenSearch = Depends(get_opensearch),
    current_user: User = Depends(require_roles("admin", "analyst"))
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
                sensor_id=UUID(src["sensor_id"]) if src.get("sensor_id") and src["sensor_id"] != "None" else None,
                event_type=src.get("event_type", "unknown"),
                severity=src.get("severity", "info"),
                source_ip=src.get("source_ip"),
                destination_ip=src.get("destination_ip"),
                raw_event=src.get("raw_event", {}),
                timestamp=str(src.get("timestamp"))
            )
        )
    return results
